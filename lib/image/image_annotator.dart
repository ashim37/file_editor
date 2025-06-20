import 'dart:io';
import 'package:file_editor/shape_type.dart';
import 'package:file_editor/text_annotation/text_sticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import '../shape/draggable_resizable_shape.dart';
import '../text_annotation/stroke_segment.dart';
import 'image_river_pods.dart';

class ImageAnnotator extends ConsumerStatefulWidget {
  final String? filePath;

  const ImageAnnotator(this.filePath, {super.key});

  @override
  ConsumerState<ImageAnnotator> createState() => _ImageAnnotatorState();
}

class _ImageAnnotatorState extends ConsumerState<ImageAnnotator> {
  final GlobalKey imageKey = GlobalKey();
  double? _lastScaleFactor;

  @override
  void initState() {
    super.initState();
    Future(() {
      ref.read(imageEditorProvider.notifier).loadImage(widget.filePath ?? "");
    });
  }

  void saveImage() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text("Saving Image..."),
              ],
            ),
          ),
    );
    final path =
        await ref.read(imageEditorProvider.notifier).saveAnnotatedImage();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to $path'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              openFile(path); // Implement this function to open the file
            },
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageEditorProvider);
    if (state.image == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Annotator'),
        actions: [
          DropdownButton<Color>(
            value: state.penColor,
            onChanged: (Color? newColor) {
              if (newColor != null) {
                ref.read(imageEditorProvider.notifier).setPenColor(newColor);
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
            icon: const Icon(Icons.undo),
            onPressed:
                () => ref.read(imageEditorProvider.notifier).clearDrawing(),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: saveImage),
          PopupMenuButton<ShapeType>(
            onSelected: (value) {
              if (value == ShapeType.text) {
                showTextDialog();
              } else {
                ref.read(imageEditorProvider.notifier).addShape(value);
              }
            },
            itemBuilder: getPopUpItems,
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final document = ref.watch(
            imageEditorProvider.select((s) => s.image),
          );

          if (document == null) {
            return const Center(child: Text('No document loaded'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              if (_lastScaleFactor != state.scaleFactorX) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(imageEditorProvider.notifier)
                      .setScaleAndWidth(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                });
              }
              return GestureDetector(
                onPanUpdate: (details) {
                  ref
                      .read(imageEditorProvider.notifier)
                      .onPanUpdate(details, imageKey);
                },
                onPanEnd: (_) {
                  ref.read(imageEditorProvider.notifier).addStore();
                },
                child: SizedBox(
                  width: state.displayWidth,
                  height: state.displayHeight,
                  child: Stack(
                    key: imageKey,
                    children: [
                      Image.file(
                        File(state.imagePath!),
                        width: state.displayWidth,
                        height: state.displayHeight,
                        fit: BoxFit.fill,
                      ),
                      CustomPaint(
                        painter: _ImageDrawingPainter(
                          state.strokes,
                          state.currentPoints,
                          state.penColor,
                          state.strokeWidth,
                        ),
                        size: Size(state.displayWidth, state.displayHeight),
                      ),
                      ...state.textAnnotations.map((annotation) {
                        return Stack(
                          children: [
                            TextSticker(
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
                                ref
                                    .read(imageEditorProvider.notifier)
                                    .deleteTextAnnotation(annotation);
                              },
                            ),
                          ],
                        );
                      }),
                      ...state.shapes.asMap().entries.map((entry) {
                        final i = entry.key;
                        final shape = entry.value;
                        return Stack(
                          children: [
                            DraggableResizableShape(
                              key: ValueKey(i),
                              shape: shape,
                              color: state.penColor,
                              onUpdate: (pos, size) {
                                ref
                                    .read(imageEditorProvider.notifier)
                                    .updateShape(i, pos, size);
                              },
                              onDelete: () {
                                ref
                                    .read(imageEditorProvider.notifier)
                                    .deleteShape(i);
                              },
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void showTextDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Enter Text'),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (result != null && result.trim().isNotEmpty) {
      ref.read(imageEditorProvider.notifier).addTextAnnotation(result.trim());
    }
  }

  void openFile(String path) {
    OpenFile.open(path);
  }

  List<PopupMenuEntry<ShapeType>> getPopUpItems(BuildContext context) {
    return [
      PopupMenuItem(
        value: ShapeType.text,
        child: Icon(Icons.text_fields_outlined),
      ),
      PopupMenuItem(
        value: ShapeType.circle,
        child: Icon(Icons.circle_outlined),
      ),
      PopupMenuItem(
        value: ShapeType.line,
        child: Icon(Icons.shape_line_outlined),
      ),
      PopupMenuItem(
        value: ShapeType.rectangle,
        child: Icon(Icons.rectangle_outlined),
      ),
    ];
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
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
