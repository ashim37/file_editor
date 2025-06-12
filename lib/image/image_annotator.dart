import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_editor/text_annotation/text_annotation.dart';
import 'package:file_editor/text_annotation/text_sticker.dart';
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:flutter/material.dart';

import '../pdf/pdf_annotator.dart';

class ImageAnnotator extends StatefulWidget {
  final String? filePath;

  const ImageAnnotator(this.filePath, {super.key});

  @override
  State<ImageAnnotator> createState() => _ImageAnnotatorState();
}

class _ImageAnnotatorState extends State<ImageAnnotator> {
  final GlobalKey _imageKey = GlobalKey();
  ui.Image? image;
  String? imagePath;
  final List<StrokeSegment> strokes = [];
  final List<TextAnnotation> textAnnotations = [];
  List<Offset?> currentPoints = [];
  Color penColor = Colors.red;
  double strokeWidth = 3.0;
  double scaleFactorX = 1.0;
  double scaleFactorY = 1.0;
  double displayWidth = 0;
  double displayHeight = 0;

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  void _pickImage() async {
    final bytes = await File(widget.filePath ?? "").readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      image = frame.image;
      imagePath = widget.filePath;
      strokes.clear();
      textAnnotations.clear();
      currentPoints.clear();
    });
  }

  void _saveAnnotatedImage() async {
    if (image == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
    );
    canvas.drawImage(image!, Offset.zero, Paint());

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
        text.position.dx * scaleFactorX,
        text.position.dy * scaleFactorY,
      );
      painter.paint(canvas, scaledOffset);
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image!.width, image!.height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    await requestStoragePermission();
    final path = await getExportPath(
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(path);
    await file.writeAsBytes(pngBytes);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $path')));
      Navigator.pop(context);
    }
  }

  void _addTextAnnotation(String text) {
    setState(() {
      textAnnotations.add(
        TextAnnotation(
          text: text,
          position: Offset(displayWidth / 2, displayHeight / 2),
          fontSize: 20.0,
          color: penColor,
        ),
      );
    });
  }

  bool _isInsideImage(Offset point) {
    return point.dx >= 0 &&
        point.dy >= 0 &&
        point.dx <= displayWidth &&
        point.dy <= displayHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Annotator'),
        actions: [
          DropdownButton<Color>(
            value: penColor,
            onChanged: (Color? newColor) {
              if (newColor != null) {
                setState(() => penColor = newColor);
              }
            },
            items:
                [
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.black,
                      Colors.yellow,
                    ]
                    .map(
                      (color) => DropdownMenuItem(
                        value: color,
                        child: Container(width: 24, height: 24, color: color),
                      ),
                    )
                    .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () async {
              final controller = TextEditingController();
              final result = await showDialog<String>(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: const Text('Enter Text'),
                      content: TextField(controller: controller),
                      actions: [
                        TextButton(
                          onPressed:
                              () => Navigator.pop(context, controller.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
              );
              if (result != null && result.trim().isNotEmpty) {
                _addTextAnnotation(result.trim());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAnnotatedImage,
          ),
        ],
      ),
      body:
          image == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  displayWidth = constraints.maxWidth;
                  displayHeight = image!.height * displayWidth / image!.width;
                  scaleFactorX = image!.width / displayWidth;
                  scaleFactorY = image!.height / displayHeight;

                  return GestureDetector(
                    onPanUpdate: (details) {
                      final box =
                          _imageKey.currentContext!.findRenderObject()
                              as RenderBox;
                      Offset local = box.globalToLocal(details.globalPosition);
                      if (_isInsideImage(local)) {
                        setState(() => currentPoints.add(local));
                      }
                    },
                    onPanEnd: (_) {
                      setState(() {
                        strokes.add(
                          StrokeSegment(
                            List.from(currentPoints),
                            penColor,
                            strokeWidth,
                          ),
                        );
                        currentPoints.clear();
                      });
                    },
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: Stack(
                        key: _imageKey,
                        children: [
                          Image.file(
                            File(imagePath!),
                            fit: BoxFit.fill,
                            width: displayWidth,
                            height: displayHeight,
                          ),
                          CustomPaint(
                            painter: _ImageDrawingPainter(
                              strokes,
                              currentPoints,
                              penColor,
                              strokeWidth,
                            ),
                            size: Size(displayWidth, displayHeight),
                          ),
                          ...textAnnotations.map((annotation) {
                            return TextSticker(
                              key: ValueKey(annotation),
                              text: annotation.text,
                              color: annotation.color,
                              initialFontSize: annotation.fontSize,
                              initialPosition: annotation.position,
                              onChanged: (pos, size) {
                                annotation.position = pos;
                                annotation.fontSize = size;
                              },
                              onDelete: () {
                                setState(() {
                                  textAnnotations.remove(annotation);
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _ImageDrawingPainter extends CustomPainter {
  final List<StrokeSegment> strokes;
  final List<Offset?> current;
  final Color currentColor;
  final double currentWidth;

  _ImageDrawingPainter(
    this.strokes,
    this.current,
    this.currentColor,
    this.currentWidth,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.strokeWidth
            ..strokeCap = StrokeCap.round;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
        }
      }
    }

    final paint =
        Paint()
          ..color = currentColor
          ..strokeWidth = currentWidth
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < current.length - 1; i++) {
      if (current[i] != null && current[i + 1] != null) {
        canvas.drawLine(current[i]!, current[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ImageDrawingPainter oldDelegate) => true;
}
