import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:flutter/material.dart';

class StrokeSegment {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  StrokeSegment(this.points, this.color, this.strokeWidth);
}

class ImageAnnotator extends StatefulWidget {
  final String? filePath;

  const ImageAnnotator(this.filePath, {super.key});

  @override
  State<ImageAnnotator> createState() => _ImageAnnotatorState();
}

class _ImageAnnotatorState extends State<ImageAnnotator> {
  ui.Image? image;
  String? imagePath;
  final List<StrokeSegment> strokes = [];
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
      currentPoints = [];
    });
  }

  void _saveAnnotatedImage() async {
    if (image == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
    );
    final paint = Paint();
    canvas.drawImage(image!, Offset.zero, paint);

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

    final pic = recorder.endRecording();
    final finalImage = await pic.toImage(image!.width, image!.height);
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final pngBytes = byteData!.buffer.asUint8List();
    saveImageFile(pngBytes);
  }

  bool _isInsideImage(Offset point) {
    return point.dx >= 0 &&
        point.dy >= 0 &&
        point.dx <= displayWidth &&
        point.dy <= displayHeight;
  }

  Future<void> saveImageFile(Uint8List imageBytes) async {

    await requestStoragePermission();
    final path = await getExportPath(
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(path);
    await file.writeAsBytes(imageBytes as List<int>);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Image saved to $path')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Annotator'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
                            child: Container(
                              width: 24,
                              height: 24,
                              color: color,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
        actions: [
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
                      RenderBox box = context.findRenderObject() as RenderBox;
                      Offset localPos = box.globalToLocal(
                        details.globalPosition,
                      );
                      if (_isInsideImage(localPos)) {
                        setState(() {
                          currentPoints.add(localPos);
                        });
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

    final livePaint =
        Paint()
          ..color = currentColor
          ..strokeWidth = currentWidth
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < current.length - 1; i++) {
      if (current[i] != null && current[i + 1] != null) {
        canvas.drawLine(current[i]!, current[i + 1]!, livePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ImageDrawingPainter oldDelegate) => true;
}
