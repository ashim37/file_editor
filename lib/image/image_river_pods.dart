import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/shape/shape.dart';
import 'package:file_editor/shape_type.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:file_editor/text_annotation/text_annotation.dart';
import 'package:file_editor/text_annotation/stroke_segment.dart';

class ImageEditorState {
  final ui.Image? image;
  final String? imagePath;
  final List<StrokeSegment> strokes;
  final List<TextAnnotation> textAnnotations;
  final List<Offset?> currentPoints;
  final Color penColor;
  final double strokeWidth;
  final double scaleFactorX;
  final double scaleFactorY;
  final double displayWidth;
  final double displayHeight;
  final List<Shape> shapes;

  factory ImageEditorState.initial() {
    return ImageEditorState(
      image: null,
      imagePath: null,
      penColor: Colors.red,
      strokeWidth: 3.0,
      strokes: [],
      currentPoints: [],
      textAnnotations: [],
      shapes: [],
      displayWidth: 0,
      displayHeight: 0,
      scaleFactorX: 1.0,
      scaleFactorY: 1.0,
    );
  }

  ImageEditorState({
    this.image,
    this.imagePath,
    this.strokes = const [],
    this.textAnnotations = const [],
    this.currentPoints = const [],
    this.penColor = Colors.red,
    required this.strokeWidth,
    required this.scaleFactorX,
    required this.scaleFactorY,
    required this.displayWidth,
    required this.displayHeight,
    required this.shapes,
  });

  ImageEditorState copyWith({
    ui.Image? image,
    String? imagePath,
    List<StrokeSegment>? strokes,
    List<TextAnnotation>? textAnnotations,
    List<Offset?>? currentPoints,
    Color? penColor,
    double? strokeWidth,
    double? scaleFactorX,
    double? scaleFactorY,
    double? displayWidth,
    double? displayHeight,
    List<Shape>? shapes,
  }) {
    return ImageEditorState(
      image: image ?? this.image,
      imagePath: imagePath ?? this.imagePath,
      strokes: strokes ?? this.strokes,
      textAnnotations: textAnnotations ?? this.textAnnotations,
      currentPoints: currentPoints ?? this.currentPoints,
      penColor: penColor ?? this.penColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      scaleFactorX: scaleFactorX ?? this.scaleFactorX,
      scaleFactorY: scaleFactorY ?? this.scaleFactorY,
      displayWidth: displayWidth ?? this.displayWidth,
      displayHeight: displayHeight ?? this.displayHeight,
      shapes: shapes ?? this.shapes,
    );
  }
}

class ImageEditorNotifier extends StateNotifier<ImageEditorState> {
  ImageEditorNotifier() : super(ImageEditorState.initial());

  void loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    state = state.copyWith(
      image: frame.image,
      imagePath: path,
      strokes: [],
      textAnnotations: [],
      currentPoints: [],
    );
  }

  void setPenColor(Color color) {
    state = state.copyWith(penColor: color);
  }

  void onPanUpdate(DragUpdateDetails details, GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    state = state.copyWith(currentPoints: [...state.currentPoints, local]);
  }

  void addStore() {
    if (state.currentPoints.isEmpty) return;
    final stroke = StrokeSegment(
      List<Offset?>.from(state.currentPoints),
      state.penColor,
      state.strokeWidth,
    );
    state = state.copyWith(
      strokes: [...state.strokes, stroke],
      currentPoints: [],
    );
  }

  void addTextAnnotation(String text) {
    final position = Offset(150 * state.scaleFactorX, 150 * state.scaleFactorY);
    final annotation = TextAnnotation(
      text: text,
      position: position,
      fontSize: 20.0 * state.scaleFactorX,
      color: state.penColor,
    );
    state = state.copyWith(
      textAnnotations: [...state.textAnnotations, annotation],
    );
  }

  void deleteTextAnnotation(TextAnnotation annotation) {
    final updated = [...state.textAnnotations]..remove(annotation);
    state = state.copyWith(textAnnotations: updated);
  }

  Future<String> saveAnnotatedImage() async {
    final image = state.image;
    if (image == null) return '';

    final strokes = state.strokes;
    final scaleFactorX = state.scaleFactorX;
    final scaleFactorY = state.scaleFactorY;
    final textAnnotations = state.textAnnotations;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw strokes
    for (final stroke in strokes) {
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.strokeWidth
            ..strokeCap = StrokeCap.round;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        if (p1 != null && p2 != null) {
          final scaledP1 = Offset(p1.dx * scaleFactorX, p1.dy * scaleFactorY);
          final scaledP2 = Offset(p2.dx * scaleFactorX, p2.dy * scaleFactorY);
          canvas.drawLine(scaledP1, scaledP2, paint);
        }
      }
    }

    // Calculate letterboxing offsets
    final double horizontalOffset =
        (state.displayWidth - (image.width / state.scaleFactorX)) / 2;
    final double verticalOffset =
        (state.displayHeight - (image.height / state.scaleFactorY)) / 2;

    // Draw text
    for (final text in textAnnotations) {
      final painter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            fontSize: text.fontSize * scaleFactorX,
            color: text.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      final scaledOffset = Offset(
        (text.position.dx - horizontalOffset) * scaleFactorX,
        (text.position.dy - verticalOffset) * scaleFactorY,
      );
      painter.paint(canvas, scaledOffset);
    }

    for (final shape in state.shapes) {
      final paint =
          Paint()
            ..color = state.penColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
      final pos = Offset(
        (shape.position.dx - horizontalOffset) * scaleFactorX,
        (shape.position.dy - verticalOffset) * scaleFactorY,
      );
      final size = Size(
        shape.size.width * scaleFactorX,
        shape.size.height * scaleFactorY,
      );
      switch (shape.type) {
        case ShapeType.circle:
          canvas.drawOval(pos & size, paint);
          break;
        case ShapeType.rectangle:
          canvas.drawRect(pos & size, paint);
          break;
        case ShapeType.line:
          canvas.drawLine(
            Offset(pos.dx, pos.dy + size.height),
            Offset(pos.dx + size.width, pos.dy),
            paint,
          );
          break;
        default:
          break;
      }
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    await requestStoragePermission();
    final path = await getExportPath(
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(path);
    await file.writeAsBytes(pngBytes);
    return path;
  }

  void clearDrawing() {
    final List<StrokeSegment> current = [...state.strokes];
    if (current.isNotEmpty) {
      current.removeLast();

      state = state.copyWith(strokes: current);
    }
  }

  void setScaleAndWidth(double width, double height) {
    state = state.copyWith(
      displayWidth: width,
      displayHeight: height,
      scaleFactorX: state.image!.width / width,
      scaleFactorY: state.image!.height / height,
    );
  }

  void updateShape(int i, ui.Offset pos, ui.Size size) {
    final shapes = Shape(type: state.shapes[i].type, position: pos, size: size);
    state = state.copyWith(shapes: [...state.shapes]..[i] = shapes);
  }

  void addShape(ShapeType type) {
    final shape = Shape(
      type: type,
      position: const Offset(100, 100),
      size: const Size(100, 100),
    );
    state = state.copyWith(shapes: [...state.shapes, shape]);
  }

  void deleteShape(int index) {
    final updated =
        [...state.shapes]
          ..removeAt(index)
          ..insert(
            index,
            Shape(
              type: ShapeType.empty,
              position: const Offset(0, 0),
              size: const Size(0, 0),
            ),
          );

    state = state.copyWith(shapes: updated);
  }

  @override
  void dispose() {
    state = ImageEditorState.initial();
    super.dispose();
  }
}

final imageEditorProvider =
    StateNotifierProvider.autoDispose<ImageEditorNotifier, ImageEditorState>(
      (ref) => ImageEditorNotifier(),
    );
