import 'package:file_editor/pdf/comment_annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../shape/draggable_resizable_shape.dart';
import '../shape_type.dart';
import '../text_annotation/stroke_segment.dart';
import '../text_annotation/text_sticker.dart';
import '../pdf/pdf_annotator_riverpods.dart';

class PdfAnnotator extends ConsumerStatefulWidget {
  final String? filePath;

  const PdfAnnotator(this.filePath, {super.key});

  @override
  ConsumerState<PdfAnnotator> createState() => _PdfAnnotatorState();
}

class _PdfAnnotatorState extends ConsumerState<PdfAnnotator> {
  double? _lastScaleFactor;
  int? _lastPageForScale;

  @override
  void initState() {
    super.initState();
    Future(() {
      ref.read(pdfEditorProvider.notifier).loadPDF(widget.filePath ?? "");
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(
      pdfEditorProvider.select((s) => s.currentPage),
    );
    final totalPages = ref.watch(pdfEditorProvider.select((s) => s.totalPages));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Annotator'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final penColor = ref.watch(
                pdfEditorProvider.select((s) => s.penColor),
              );
              return DropdownButton<Color>(
                value: penColor,
                onChanged: (color) {
                  if (color != null) {
                    ref.read(pdfEditorProvider.notifier).setPenColor(color);
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
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final addTagMode = ref.watch(
                pdfEditorProvider.select((s) => s.addTagMode),
              );
              return IconButton(
                icon: Icon(
                  Icons.add_comment,
                  color: addTagMode ? Colors.orange : null,
                ),
                onPressed: () {
                  ref.read(pdfEditorProvider.notifier).setToggle(!addTagMode);
                },
              );
            },
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: savePdf),

          Consumer(
            builder: (context, ref, _) {
              final drawingEnabled = ref.watch(
                pdfEditorProvider.select((s) => s.drawingEnabled),
              );
              return PopupMenuButton<ShapeType>(
                onSelected: (value) {
                  if (value == ShapeType.text) {
                    showTextDialog();
                  } else if (value == ShapeType.drawing) {
                    ref.read(pdfEditorProvider.notifier).setDrawingEnabled();
                  } else {
                    ref.read(pdfEditorProvider.notifier).addShape(value);
                  }
                },
                itemBuilder:
                    (context) => getPopUpItems(context, drawingEnabled),
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final isLoading = ref.watch(
            pdfEditorProvider.select((s) => s.isLoading),
          );
          final document = ref.watch(
            pdfEditorProvider.select((s) => s.document),
          );
          final currentPage = ref.watch(
            pdfEditorProvider.select((s) => s.currentPage),
          );

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (document == null) {
            return const Center(child: Text('No document loaded'));
          }
          return FutureBuilder<pdfx.PdfPageImage?>(
            future: document
                .getPage(currentPage)
                .then(
                  (page) => page
                      .render(width: page.width, height: page.height)
                      .whenComplete(() => page.close()),
                ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final image = snapshot.data!;
              final ratio = image.width! / image.height!;
              final displayWidth = MediaQuery.of(context).size.width;
              final displayHeight = displayWidth / ratio;
              final scale = image.width! / displayWidth;

              if (_lastScaleFactor != scale ||
                  _lastPageForScale != currentPage) {
                _lastScaleFactor = scale;
                _lastPageForScale = currentPage;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(pdfEditorProvider.notifier).updateScaleFactor(scale);
                });
              }

              final drawingEnabled = ref.watch(
                pdfEditorProvider.select((s) => s.drawingEnabled),
              );
              return Container(
                color: Colors.white,
                width: displayWidth,
                height: displayHeight,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (drawingEnabled) {
                      ref
                          .read(pdfEditorProvider.notifier)
                          .onPanUpdate(
                            details,
                            context.findRenderObject() as RenderBox,
                          );
                    }
                  },
                  onTapDown: (details) async {
                    onTapDown(
                      details,
                      context,
                      ref,
                      displayWidth,
                      displayHeight,
                    );
                  },
                  onPanEnd: (_) {
                    if (drawingEnabled) {
                      ref.read(pdfEditorProvider.notifier).saveCurrentStroke();
                    }
                  },
                  child: Stack(
                    children: [
                      // In your Stack, overlay comment icons:
                      Image.memory(image.bytes, fit: BoxFit.fill),

                      Consumer(
                        builder: (context, ref, _) {
                          final strokes = ref.watch(
                            pdfEditorProvider.select(
                              (s) => s.drawingsPerPage[currentPage] ?? [],
                            ),
                          );
                          final currentPoints = ref.watch(
                            pdfEditorProvider.select((s) => s.currentPoints),
                          );
                          final penColor = ref.watch(
                            pdfEditorProvider.select((s) => s.penColor),
                          );
                          final strokeWidth = ref.watch(
                            pdfEditorProvider.select((s) => s.strokeWidth),
                          );
                          final scaleFactor = ref.watch(
                            pdfEditorProvider.select((s) => s.scaleFactor),
                          );
                          return CustomPaint(
                            painter: _PdfDrawingPainter(
                              strokes,
                              currentPoints,
                              penColor,
                              strokeWidth,
                              scaleFactor,
                            ),
                            size: Size(displayWidth, displayHeight),
                          );
                        },
                      ),

                      Consumer(
                        builder: (context, ref, _) {
                          final texts = ref.watch(
                            pdfEditorProvider.select(
                              (s) => s.textPerPage[currentPage] ?? [],
                            ),
                          );
                          return Stack(
                            children:
                                texts.map((annotation) {
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
                                      ref
                                          .read(pdfEditorProvider.notifier)
                                          .deleteText(annotation);
                                    },
                                  );
                                }).toList(),
                          );
                        },
                      ),

                      Consumer(
                        builder: (context, ref, _) {
                          final comments = ref.watch(
                            pdfEditorProvider.select(
                              (s) => s.commentsPerPage[currentPage] ?? [],
                            ),
                          );

                          // Get display and PDF page sizes
                          final displaySize = Size(displayWidth, displayHeight);
                          final pdfPageSize = ref.watch(
                            pdfEditorProvider.select((s) => s.pdfPageSize),
                          );

                          return Stack(
                            children:
                                comments.map((annotation) {
                                  final scaleX =
                                      displaySize.width / pdfPageSize.width;
                                  final scaleY =
                                      displaySize.height / pdfPageSize.height;
                                  final widgetPos = Offset(
                                    annotation.position.dx * scaleX,
                                    annotation.position.dy * scaleY,
                                  );

                                  const double iconSize = 24;
                                  return Positioned(
                                    left: widgetPos.dx - iconSize / 2,
                                    top: widgetPos.dy - iconSize / 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        showCommentDialog(context, annotation);
                                      },
                                      child: const Icon(
                                        Icons.message_outlined,
                                        color: Colors.orange,
                                        size: iconSize,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final shapes = ref.watch(
                            pdfEditorProvider.select(
                              (s) => s.shapePerPage?[currentPage] ?? [],
                            ),
                          );
                          return Stack(
                            children:
                                shapes.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final shape = entry.value;
                                  return DraggableResizableShape(
                                    key: ValueKey(shape),
                                    shape: shape,
                                    color: shape.color,
                                    onUpdate: (pos, size) {
                                      shape.position = pos;
                                      shape.size = size;
                                    },
                                    onDelete: () {
                                      ref
                                          .read(pdfEditorProvider.notifier)
                                          .deleteShape(i);
                                    },
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed:
                  currentPage > 1
                      ? () => ref
                          .read(pdfEditorProvider.notifier)
                          .goToPage(currentPage - 1)
                      : null,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('Page $currentPage / $totalPages'),
            IconButton(
              onPressed:
                  currentPage < totalPages
                      ? () => ref
                          .read(pdfEditorProvider.notifier)
                          .goToPage(currentPage + 1)
                      : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              icon: const Icon(Icons.undo_outlined),
              onPressed:
                  () => ref.read(pdfEditorProvider.notifier).undoDrawing(),
            ),
            IconButton(
              icon: const Icon(Icons.redo_outlined),
              onPressed:
                  () => ref.read(pdfEditorProvider.notifier).redoDrawing(),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<ShapeType>> getPopUpItems(
    BuildContext context,
    bool drawingEnabled,
  ) {
    return [
      PopupMenuItem(
        value: ShapeType.text,
        child: Icon(Icons.text_fields_outlined),
      ),
      PopupMenuItem(
        value: ShapeType.drawing,
        child: Icon(
          Icons.draw_outlined,
          color: drawingEnabled ? Colors.black : Colors.grey,
        ),
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

  void savePdf() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text("Saving PDF..."),
              ],
            ),
          ),
    );
    final path = await ref.read(pdfEditorProvider.notifier).saveAnnotatedPdf();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to $path'),
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

  void openFile(String path) {
    OpenFile.open(path);
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
      ref.read(pdfEditorProvider.notifier).addTextAnnotation(result.trim());
    }
  }

  void showCommentDialog(BuildContext context, CommentAnnotation annotation) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            content: Text(annotation.comment),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void onTapDown(
    TapDownDetails details,
    BuildContext context,
    WidgetRef ref,
    double displayWidth,
    double displayHeight,
  ) async {
    final addTagMode = ref.watch(pdfEditorProvider.select((s) => s.addTagMode));
    if (addTagMode) {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPos = box.globalToLocal(details.globalPosition);
      final comment = await showDialog<String>(
        context: context,
        builder: (_) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Add Comment'),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
      if (comment != null && comment.trim().isNotEmpty) {
        ref
            .read(pdfEditorProvider.notifier)
            .addCommentAnnotation(comment.trim(), localPos * _lastScaleFactor!);
      }
      ref.read(pdfEditorProvider.notifier).setToggle(false);
    }
  }
}

class _PdfDrawingPainter extends CustomPainter {
  final List<StrokeSegment> strokes;
  final List<Offset?> current;
  final Color currentColor;
  final double currentWidth;
  final double scaleFactor;

  _PdfDrawingPainter(
    this.strokes,
    this.current,
    this.currentColor,
    this.currentWidth,
    this.scaleFactor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.strokeWidth / scaleFactor
            ..strokeCap = StrokeCap.round;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != null && stroke.points[i + 1] != null) {
          canvas.drawLine(
            stroke.points[i]! / scaleFactor,
            stroke.points[i + 1]! / scaleFactor,
            paint,
          );
        }
      }
    }

    final livePaint =
        Paint()
          ..color = currentColor
          ..strokeWidth = currentWidth / scaleFactor
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < current.length - 1; i++) {
      if (current[i] != null && current[i + 1] != null) {
        canvas.drawLine(
          current[i]! / scaleFactor,
          current[i + 1]! / scaleFactor,
          livePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PdfDrawingPainter oldDelegate) => true;
}
