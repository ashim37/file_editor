import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_editor/pdf/pdf_annotator_state.dart';
import 'package:file_editor/text_annotation/text_annotation.dart';
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../text_annotation/stroke_segment.dart';

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

  void clearDrawing() {
    List<StrokeSegment> current = [...state.drawingsPerPage[state.currentPage] ?? []];
    if (current.isNotEmpty) {
      final last = current.removeLast();
      List<StrokeSegment> updatedUndoStack = [...state.undoStack, last];

      Map<int, List<StrokeSegment>> updatedMap = {...state.drawingsPerPage, state.currentPage: current};

      state = state.copyWith(
        drawingsPerPage: updatedMap,
        undoStack: updatedUndoStack,
      );
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

    Map<int, List<TextAnnotation>> updatedMap = {...state.textPerPage, state.currentPage: updatedTexts};

    state = state.copyWith(textPerPage: updatedMap);
  }

  void deleteText(TextAnnotation annotation) {
    List<TextAnnotation> updatedTexts = [...state.textPerPage[state.currentPage] ?? []]
      ..remove(annotation);

    Map<int, List<TextAnnotation>> updatedMap = {...state.textPerPage, state.currentPage: updatedTexts};

    state = state.copyWith(textPerPage: updatedMap);
  }

  void goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) {
      saveCurrentStroke();
      state = state.copyWith(currentPage: page, currentPoints: []);
    }
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
          final paint = Paint()
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
}
