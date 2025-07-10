import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../shape/shape.dart';
import '../text_annotation/stroke_segment.dart';
import '../text_annotation/text_annotation.dart';
import 'comment_annotation.dart';

class PdfAnnotatorState {
  final bool isLoading;
  final PdfDocument? document;
  final int currentPage;
  final int totalPages;
  final Map<int, List<StrokeSegment>> drawingsPerPage;
  final List<Offset?> currentPoints;
  final Map<int, List<TextAnnotation>> textPerPage;
  final List<StrokeSegment> undoStack;
  final Color penColor;
  final double scaleFactor;
  final double strokeWidth;
  final Map<int, List<Shape>>? shapePerPage;
  final Map<int, List<CommentAnnotation>> commentsPerPage;
  final bool addTagMode;
  final Size pdfPageSize;
  final bool drawingEnabled;
  final TransformationController transformationController =
      TransformationController();

  PdfAnnotatorState({
    required this.isLoading,
    this.document,
    required this.currentPage,
    required this.totalPages,
    required this.drawingsPerPage,
    required this.currentPoints,
    required this.textPerPage,
    required this.undoStack,
    required this.penColor,
    required this.scaleFactor,
    required this.strokeWidth,
    required this.shapePerPage,
    required this.commentsPerPage,
    required this.addTagMode,
    this.pdfPageSize = const Size(0, 0),
    this.drawingEnabled = false,
  });

  PdfAnnotatorState copyWith({
    bool? isLoading,
    PdfDocument? document,
    int? currentPage,
    int? totalPages,
    Map<int, List<StrokeSegment>>? drawingsPerPage,
    List<Offset?>? currentPoints,
    Map<int, List<TextAnnotation>>? textPerPage,
    Map<int, List<Shape>>? shapePerPage,
    List<StrokeSegment>? undoStack,
    Color? penColor,
    double? scaleFactor,
    double? strokeWidth,
    Map<int, List<CommentAnnotation>>? commentsPerPage,
    bool? addTagMode,
    Size? pdfPageSize,
    bool? drawingEnabled,
    StrokeSegment? currentStroke,
  }) {
    return PdfAnnotatorState(
      isLoading: isLoading ?? this.isLoading,
      document: document ?? this.document,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      drawingsPerPage: drawingsPerPage ?? this.drawingsPerPage,
      currentPoints: currentPoints ?? this.currentPoints,
      textPerPage: textPerPage ?? this.textPerPage,
      undoStack: undoStack ?? this.undoStack,
      penColor: penColor ?? this.penColor,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shapePerPage: shapePerPage ?? this.shapePerPage,
      commentsPerPage: commentsPerPage ?? this.commentsPerPage,
      addTagMode: addTagMode ?? this.addTagMode,
      pdfPageSize: pdfPageSize ?? this.pdfPageSize,
      drawingEnabled: drawingEnabled ?? this.drawingEnabled,
    );
  }
}
