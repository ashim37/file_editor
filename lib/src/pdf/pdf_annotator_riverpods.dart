import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_editor/src/pdf/comment_annotation.dart';
import 'package:file_editor/src/pdf/pdf_annotator_state.dart';
import 'package:file_editor/src/shape/shape.dart';
import 'package:file_editor/src/text_annotation/stroke_segment.dart';
import 'package:file_editor/src/text_annotation/text_annotation.dart';
import 'package:file_editor/src/utils/permission_request_handler.dart';
import 'package:file_editor/src/utils/shape_type.dart';
import 'package:file_editor/src/utils/storage_directory_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PDFAnnotatorRiverPods extends StateNotifier<PdfAnnotatorState> {
  PDFAnnotatorRiverPods()
    : super(
        PdfAnnotatorState(
          isLoading: true,
          document: null,
          currentPage: 1,
          totalPages: 0,
          drawingsPerPage: {},
          currentPoints: [],
          textPerPage: {},
          undoStack: [],
          penColor: Colors.red,
          scaleFactor: 1.0,
          strokeWidth: 3.0,
          shapePerPage: {},
          commentsPerPage: {},
          addTagMode: false,
          originalFilePath: null,
        ),
      );

  TransformationController get getTransformationController =>
      state.transformationController;
  StrokeSegment? _currentStroke;

  Future<void> loadPDF(String filePath) async {
    state = state.copyWith(isLoading: true);
    final doc = await pdfx.PdfDocument.openFile(filePath);
    final pagesCount = doc.pagesCount;

    state = state.copyWith(
      isLoading: false,
      document: doc,
      totalPages: pagesCount,
      currentPage: 1,
      drawingsPerPage: {for (var i = 1; i <= pagesCount; i++) i: []},
      textPerPage: {for (var i = 1; i <= pagesCount; i++) i: []},
      currentPoints: [],
      originalFilePath: filePath,
    );

    setPDFPageSize();
  }

  void setPDFPageSize() async {
    final page = await state.document?.getPage(state.currentPage);
    final size = Size(
      page?.width.toDouble() ?? 0,
      page?.height.toDouble() ?? 0,
    );
    state = state.copyWith(pdfPageSize: size);
    await page?.close();
  }

  void undoDrawing() {
    final List<StrokeSegment> current = [
      ...state.drawingsPerPage[state.currentPage] ?? [],
    ];
    if (current.isNotEmpty) {
      final last = current.removeLast();
      final List<StrokeSegment> updatedUndoStack = [...state.undoStack, last];

      final Map<int, List<StrokeSegment>> updatedMap = {
        ...state.drawingsPerPage,
        state.currentPage: current,
      };

      state = state.copyWith(
        drawingsPerPage: updatedMap,
        undoStack: updatedUndoStack,
      );
    }
  }

  void redoDrawing() {
    final List<StrokeSegment> current = [
      ...state.drawingsPerPage[state.currentPage] ?? [],
    ];
    if (state.undoStack.isNotEmpty) {
      final StrokeSegment last = state.undoStack.last;
      state.undoStack.removeLast();

      final List<StrokeSegment> updatedStack = [...current, last];

      final Map<int, List<StrokeSegment>> updatedMap = {
        ...state.drawingsPerPage,
        state.currentPage: updatedStack,
      };

      state = state.copyWith(drawingsPerPage: updatedMap);
    }
  }

  void addTextAnnotation(String text) {
    final List<TextAnnotation> updatedTexts = [
      ...state.textPerPage[state.currentPage] ?? [],
      TextAnnotation(
        text: text,
        position: const Offset(100, 100),
        fontSize: 20.0,
        color: state.penColor,
      ),
    ];

    final Map<int, List<TextAnnotation>> updatedMap = {
      ...state.textPerPage,
      state.currentPage: updatedTexts,
    };

    state = state.copyWith(textPerPage: updatedMap);
  }

  void deleteText(TextAnnotation annotation) {
    final List<TextAnnotation> updatedTexts = [
      ...state.textPerPage[state.currentPage] ?? [],
    ]..remove(annotation);

    final Map<int, List<TextAnnotation>> updatedMap = {
      ...state.textPerPage,
      state.currentPage: updatedTexts,
    };

    state = state.copyWith(textPerPage: updatedMap);
  }

  void goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) {
      saveCurrentStroke();
      state = state.copyWith(currentPage: page, currentPoints: []);
    }
    setPDFPageSize();
  }

  void setPenColor(Color color) {
    state = state.copyWith(penColor: color);
  }

  void updateScaleFactor(double factor) {
    state = state.copyWith(scaleFactor: factor);
  }

  void onPanStart(DragStartDetails details, RenderBox box) {
    final local = details.localPosition;
    _currentStroke = StrokeSegment([local], state.penColor, state.strokeWidth);
    state = state.copyWith(currentPoints: [local]);
  }

  void onPanUpdate(DragUpdateDetails details, RenderBox box) {
    if (_currentStroke == null) return;
    final local = details.localPosition;
    _currentStroke!.points.add(local);
    state = state.copyWith(currentPoints: List.from(_currentStroke!.points));
  }

  void saveCurrentStroke() {
    if (_currentStroke == null) return;
    final page = state.currentPage;
    final existing = state.drawingsPerPage[page] ?? [];
    final updated = [...existing, _currentStroke!];
    _currentStroke = null;
    state = state.copyWith(
      drawingsPerPage: {...state.drawingsPerPage, page: updated},
      currentPoints: [],
    );
  }

  /// Export the annotated PDF by scaling widget-space annotations into image-space.
  /// [displaySize] is the logical size (width x height) of the PDF widget.
  Future<String> saveAnnotatedPdf({required Size displaySize}) async {
    saveCurrentStroke();
    final pdf = pw.Document();
    for (int i = 1; i <= state.totalPages; i++) {
      final page = await state.document!.getPage(i);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final uiImage = await decodeImageFromList(pageImage!.bytes);
      canvas.drawImage(uiImage, Offset.zero, Paint());

      final sx = pageImage.width! / displaySize.width;
      final sy = pageImage.height! / displaySize.height;

      // Draw strokes
      for (final stroke in state.drawingsPerPage[i] ?? []) {
        final paint =
            Paint()
              ..color = stroke.color
              ..strokeWidth = stroke.strokeWidth
              ..strokeCap = StrokeCap.round;
        for (int j = 0; j < stroke.points.length - 1; j++) {
          final o1 = stroke.points[j];
          final o2 = stroke.points[j + 1];
          canvas.drawLine(
            Offset(o1.dx * sx, o1.dy * sy),
            Offset(o2.dx * sx, o2.dy * sy),
            paint,
          );
        }
      }

      // Draw comments
      for (final comment in state.commentsPerPage[i] ?? []) {
        final iconSize = 24.0;
        final iconRadius = iconSize / 2;
        final offset = comment.position; // already PDF space!
        final centeredOffset = offset - Offset(iconRadius, iconRadius);
        canvas.drawCircle(
          centeredOffset + Offset(iconRadius, iconRadius),
          iconRadius,
          Paint()..color = Colors.orange,
        );
        // Draw the comment text (optional)
        final textPainter = TextPainter(
          text: TextSpan(
            text: comment.comment,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, centeredOffset + Offset(iconSize + 2, -8));
      }

      // 2) Draw text annotations
      for (final txt in state.textPerPage[i] ?? []) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: txt.text,
            style: TextStyle(fontSize: txt.fontSize * sx, color: txt.color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = txt.position.dx * sx;
        final dy = txt.position.dy * sy;
        textPainter.paint(canvas, Offset(dx, dy));
      }

      // 3) Draw shapes
      for (final shape in state.shapePerPage?[i] ?? []) {
        final shapePaint =
            Paint()
              ..color = shape.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * ((sx + sy) / 2);
        final rect = Rect.fromLTWH(
          shape.position.dx * sx,
          shape.position.dy * sy,
          shape.size.width * sx,
          shape.size.height * sy,
        );
        switch (shape.type) {
          case ShapeType.circle:
            canvas.drawOval(rect, shapePaint);
            break;
          case ShapeType.rectangle:
            canvas.drawRect(rect, shapePaint);
            break;
          case ShapeType.line:
            canvas.drawLine(
              Offset(rect.left, rect.bottom),
              Offset(rect.right, rect.top),
              shapePaint,
            );
            break;
          case ShapeType.arrow:
            _drawArrowOnPdfCanvas(canvas, rect, shapePaint);
            break;
          case ShapeType.triangle:
            _drawTriangleOnPdfCanvas(canvas, rect, shapePaint);
            break;
          default:
            break;
        }
      }

      // Finalize PDF page
      final pic = recorder.endRecording();
      final img = await pic.toImage(pageImage.width!, pageImage.height!);
      final bytes = await img.toByteData(format: ImageByteFormat.png);
      final mem = pw.MemoryImage(bytes!.buffer.asUint8List());

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            pageImage.width!.toDouble(),
            pageImage.height!.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(mem, fit: pw.BoxFit.cover),
        ),
      );
    }
    return await savePdfFile(await pdf.save());
  }

  void _drawArrowOnPdfCanvas(Canvas canvas, Rect rect, Paint paint) {
    // Draw shaft
    final p1 = Offset(rect.left, rect.bottom);
    final p2 = Offset(rect.right, rect.top);
    canvas.drawLine(p1, p2, paint);

    // Draw arrowhead
    final arrowHeadLength = 18.0;
    final angle = (p2 - p1).direction;
    final headAngle = 0.5; // radians, ~30 degrees

    final arrowLeft = Offset(
      p2.dx - arrowHeadLength * cos(angle - headAngle),
      p2.dy - arrowHeadLength * sin(angle - headAngle),
    );
    final arrowRight = Offset(
      p2.dx - arrowHeadLength * cos(angle + headAngle),
      p2.dy - arrowHeadLength * sin(angle + headAngle),
    );
    canvas.drawLine(p2, arrowLeft, paint);
    canvas.drawLine(p2, arrowRight, paint);
  }

  void _drawTriangleOnPdfCanvas(Canvas canvas, Rect rect, Paint paint) {
    final path = Path();
    path.moveTo(rect.center.dx, rect.top); // Top center
    path.lineTo(rect.right, rect.bottom); // Bottom right
    path.lineTo(rect.left, rect.bottom); // Bottom left
    path.close();
    canvas.drawPath(path, paint);
  }

  Future<String> savePdfFile(Uint8List pdfBytes) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied');
    }

    String filename;
    filename = '${DateTime.now().millisecondsSinceEpoch}.pdf';

    final filePath = await getExportPath(filename);
    final file = File(filePath);

    try {
      await file.writeAsBytes(pdfBytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  void addShape(ShapeType value) {
    final shape = Shape(
      type: value,
      position: const Offset(100, 100),
      size: const Size(100, 100),
      color: state.penColor,
    );

    final List<Shape> updatedShape = [
      ...state.shapePerPage?[state.currentPage] ?? [],
      shape,
    ];

    final Map<int, List<Shape>> updatedMap = {
      ...?state.shapePerPage,
      state.currentPage: updatedShape,
    };

    state = state.copyWith(shapePerPage: updatedMap);
  }

  void updateShape(int index, Offset pos, Size size, Shape shape) {
    final List<Shape> shapes = [
      ...state.shapePerPage?[state.currentPage] ?? [],
    ];
    if (index >= 0 && index < shapes.length) {
      shapes[index] = shape.copyWith(position: pos, size: size);
      final Map<int, List<Shape>> updatedMap = {
        ...?state.shapePerPage,
        state.currentPage: shapes,
      };
      state = state.copyWith(shapePerPage: updatedMap);
    }
  }

  void deleteShape(int index) {
    final List<Shape> shapes = [
      ...state.shapePerPage?[state.currentPage] ?? [],
    ];
    if (index >= 0 && index < shapes.length) {
      shapes.removeAt(index);
      final Map<int, List<Shape>> updatedMap = {
        ...?state.shapePerPage,
        state.currentPage: shapes,
      };
      state = state.copyWith(shapePerPage: updatedMap);
    }
  }

  void addCommentAnnotation(String comment, Offset position) {
    final page = state.currentPage;
    final existing = state.commentsPerPage[page] ?? [];
    final updated = [
      ...existing,
      CommentAnnotation(comment: comment, position: position),
    ];
    state = state.copyWith(
      commentsPerPage: {...state.commentsPerPage, page: updated},
    );
  }

  void deleteCommentAnnotation(CommentAnnotation annotation) {
    final List<CommentAnnotation> updated = [
      ...state.commentsPerPage[state.currentPage] ?? [],
    ]..remove(annotation);
    final Map<int, List<CommentAnnotation>> updatedMap = {
      ...state.commentsPerPage,
      state.currentPage: updated,
    };
    state = state.copyWith(commentsPerPage: updatedMap);
  }

  void setToggle(bool value) {
    state = state.copyWith(addTagMode: value);
  }

  void setDrawingEnabled() {
    state = state.copyWith(drawingEnabled: !state.drawingEnabled);
  }
}

final pdfEditorProvider =
    StateNotifierProvider.autoDispose<PDFAnnotatorRiverPods, PdfAnnotatorState>(
      (ref) => PDFAnnotatorRiverPods(),
    );
