import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_editor/pdf/pdf_annotator_state.dart';
import 'package:file_editor/shape/shape.dart';
import 'package:file_editor/shape_type.dart';
import 'package:file_editor/text_annotation/text_annotation.dart';
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../text_annotation/stroke_segment.dart';
import 'comment_annotation.dart';

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
        ),
      );

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

  void onPanUpdate(DragUpdateDetails details, RenderBox box) {
    Offset local = box.globalToLocal(details.globalPosition);
    final updatedPoints = [...state.currentPoints, local * state.scaleFactor];
    state = state.copyWith(currentPoints: updatedPoints);
  }

  void saveCurrentStroke() {
    if (state.currentPoints.isNotEmpty) {
      List<StrokeSegment> updatedStrokes = [
        ...state.drawingsPerPage[state.currentPage] ?? [],
        StrokeSegment(
          List.from(state.currentPoints),
          state.penColor,
          state.strokeWidth,
        ),
      ];

      Map<int, List<StrokeSegment>> updatedMap = {
        ...state.drawingsPerPage,
        state.currentPage: updatedStrokes,
      };

      state = state.copyWith(drawingsPerPage: updatedMap, currentPoints: []);
    }
  }

  void undoDrawing() {
    List<StrokeSegment> current = [
      ...state.drawingsPerPage[state.currentPage] ?? [],
    ];
    if (current.isNotEmpty) {
      final last = current.removeLast();
      List<StrokeSegment> updatedUndoStack = [...state.undoStack, last];

      Map<int, List<StrokeSegment>> updatedMap = {
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
    List<StrokeSegment> current = [
      ...state.drawingsPerPage[state.currentPage] ?? [],
    ];
    if (state.undoStack.isNotEmpty) {
      StrokeSegment last = state.undoStack.last;
      state.undoStack.removeLast();

      List<StrokeSegment> updatedStack = [...current, last];

      Map<int, List<StrokeSegment>> updatedMap = {
        ...state.drawingsPerPage,
        state.currentPage: updatedStack,
      };

      state = state.copyWith(drawingsPerPage: updatedMap);
    }
  }

  void addTextAnnotation(String text) {
    List<TextAnnotation> updatedTexts = [
      ...state.textPerPage[state.currentPage] ?? [],
      TextAnnotation(
        text: text,
        position: const Offset(100, 100),
        fontSize: 20.0,
        color: state.penColor,
      ),
    ];

    Map<int, List<TextAnnotation>> updatedMap = {
      ...state.textPerPage,
      state.currentPage: updatedTexts,
    };

    state = state.copyWith(textPerPage: updatedMap);
  }

  void deleteText(TextAnnotation annotation) {
    List<TextAnnotation> updatedTexts = [
      ...state.textPerPage[state.currentPage] ?? [],
    ]..remove(annotation);

    Map<int, List<TextAnnotation>> updatedMap = {
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

  Future<String> saveAnnotatedPdf() async {
    saveCurrentStroke(); // commit strokes

    return await Future.microtask(() async {
      final pdf = pw.Document();

      for (int i = 1; i <= state.totalPages; i++) {
        final page = await state.document!.getPage(i);
        final image = await page.render(
          width: page.width,
          height: page.height,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final paint = Paint();
        final uiImage = await decodeImageFromList(image!.bytes);
        canvas.drawImage(uiImage, Offset.zero, paint);

        for (final stroke in state.drawingsPerPage[i]!) {
          final paint =
              Paint()
                ..color = stroke.color
                ..strokeWidth = stroke.strokeWidth
                ..strokeCap = StrokeCap.round;
          for (int j = 0; j < stroke.points.length - 1; j++) {
            if (stroke.points[j] != null && stroke.points[j + 1] != null) {
              canvas.drawLine(stroke.points[j]!, stroke.points[j + 1]!, paint);
            }
          }
        }

        for (final text in state.textPerPage[i]!) {
          final scaledFontSize = text.fontSize * state.scaleFactor;
          final scaledOffset = Offset(
            text.position.dx * state.scaleFactor,
            text.position.dy * state.scaleFactor,
          );
          final textPainter = TextPainter(
            text: TextSpan(
              text: text.text,
              style: TextStyle(fontSize: scaledFontSize, color: text.color),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, scaledOffset);
        }

        for (final shape in state.shapePerPage?[i] ?? []) {
          final paint =
              Paint()
                ..color = shape.color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3;

          final rect = Rect.fromLTWH(
            shape.position.dx * state.scaleFactor,
            shape.position.dy * state.scaleFactor,
            shape.size.width * state.scaleFactor,
            shape.size.height * state.scaleFactor,
          );

          switch (shape.type) {
            case ShapeType.circle:
              canvas.drawOval(rect, paint);
              break;
            case ShapeType.rectangle:
              canvas.drawRect(rect, paint);
              break;
            case ShapeType.line:
              canvas.drawLine(
                Offset(rect.left, rect.bottom),
                Offset(rect.right, rect.top),
                paint,
              );
              break;
            default:
              break;
          }
        }

        const double iconSize = 24;
        const double iconRadius = iconSize / 2;
        for (final comment in state.commentsPerPage[i] ?? []) {
          final offset = comment.position; // Already in PDF coordinates
          final centeredOffset = offset - Offset(iconRadius, iconRadius);
          canvas.drawCircle(
            centeredOffset + Offset(iconRadius, iconRadius),
            iconRadius,
            Paint()..color = Colors.orange,
          );

          final textPainter = TextPainter(
            text: TextSpan(
              text: comment.comment,
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, centeredOffset + Offset(iconSize + 2, -8));
        }

        final pic = recorder.endRecording();
        final annotatedImage = await pic.toImage(image.width!, image.height!);
        final pngBytes = await annotatedImage.toByteData(
          format: ImageByteFormat.png,
        );

        final memImage = pw.MemoryImage(pngBytes!.buffer.asUint8List());
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              image.width!.toDouble(),
              image.height!.toDouble(),
            ),
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Image(memImage, fit: pw.BoxFit.cover),
          ),
        );
      }

      return await savePdfFile(await pdf.save());
    });
  }

  Future<String> savePdfFile(Uint8List pdfBytes) async {
    await requestStoragePermission();
    final path = await getExportPath(
      '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final file = File(path);
    await file.writeAsBytes(pdfBytes);
    return path;
  }

  void addShape(ShapeType value) {
    final shape = Shape(
      type: value,
      position: const Offset(100, 100),
      size: const Size(100, 100),
      color: state.penColor,
    );

    List<Shape> updatedShape = [
      ...state.shapePerPage?[state.currentPage] ?? [],
      shape,
    ];

    Map<int, List<Shape>> updatedMap = {
      ...?state.shapePerPage,
      state.currentPage: updatedShape,
    };

    state = state.copyWith(shapePerPage: updatedMap);
  }

  void updateShape(int index, Offset pos, Size size, Shape shape) {
    List<Shape> shapes = [...state.shapePerPage?[state.currentPage] ?? []];
    if (index >= 0 && index < shapes.length) {
      shapes[index] = shape.copyWith(position: pos, size: size);
      Map<int, List<Shape>>? updatedMap = {
        ...?state.shapePerPage,
        state.currentPage: shapes,
      };
      state = state.copyWith(shapePerPage: updatedMap);
    }
  }

  void deleteShape(int index) {
    List<Shape> shapes = [...state.shapePerPage?[state.currentPage] ?? []];
    if (index >= 0 && index < shapes.length) {
      shapes.removeAt(index);
      Map<int, List<Shape>>? updatedMap = {
        ...?state.shapePerPage,
        state.currentPage: shapes,
      };
      state = state.copyWith(shapePerPage: updatedMap);
    }
  }

  void addCommentAnnotation(String comment, Offset position) {
    List<CommentAnnotation> updated = [
      ...state.commentsPerPage[state.currentPage] ?? [],
      CommentAnnotation(comment: comment, position: position),
    ];
    Map<int, List<CommentAnnotation>>? updatedMap = {
      ...state.commentsPerPage,
      state.currentPage: updated,
    };
    state = state.copyWith(commentsPerPage: updatedMap);
  }

  void deleteCommentAnnotation(CommentAnnotation annotation) {
    List<CommentAnnotation> updated = [
      ...state.commentsPerPage[state.currentPage] ?? [],
    ]..remove(annotation);
    Map<int, List<CommentAnnotation>>? updatedMap = {
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
