import 'package:file_editor/src/pdf/comment_annotation.dart';
import 'package:file_editor/src/pdf/pdf_annotator_riverpods.dart';
import 'package:file_editor/src/shape/draggable_resizable_shape.dart';
import 'package:file_editor/src/text_annotation/stroke_segment.dart';
import 'package:file_editor/src/text_annotation/text_sticker.dart';
import 'package:file_editor/src/utils/shape_type.dart';
import 'package:file_editor/src/utils/string_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfAnnotator extends ConsumerStatefulWidget {
  final String? filePath;

  const PdfAnnotator(this.filePath, {super.key});

  @override
  ConsumerState<PdfAnnotator> createState() => _PdfAnnotatorState();
}

class _PdfAnnotatorState extends ConsumerState<PdfAnnotator> {
  double? _lastScaleFactor;
  int? _lastPageForScale;

  TransformationController? tranformationController;
  late pdfx.PdfPageImage image;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (mounted) {
        if (widget.filePath?.isPdf() ?? false) {
          ref.read(pdfEditorProvider.notifier).loadPDF(widget.filePath ?? '');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File type is not supported: ${widget.filePath}'),
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    tranformationController ??=
        ref.watch(pdfEditorProvider.notifier).getTransformationController;
    final _ = ref.watch(pdfEditorProvider.select((s) => s.currentPage));
    final totalPages = ref.watch(pdfEditorProvider.select((s) => s.totalPages));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'PDF Annotator',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Pen color dropdown
                Tooltip(
                  message: 'Pen Color',
                  child: Consumer(
                    builder: (context, ref, _) {
                      final penColor = ref.watch(
                        pdfEditorProvider.select((s) => s.penColor),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Color>(
                            value: penColor,
                            icon: const Icon(Icons.arrow_drop_down, size: 22),
                            onChanged: (color) {
                              if (color != null) {
                                ref
                                    .read(pdfEditorProvider.notifier)
                                    .setPenColor(color);
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
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Tooltip(
                  message: 'Add Comment',
                  child: Consumer(
                    builder: (context, ref, _) {
                      final addTagMode = ref.watch(
                        pdfEditorProvider.select((s) => s.addTagMode),
                      );
                      return IconButton(
                        icon: Icon(
                          Icons.add_comment,
                          color: addTagMode ? Colors.orange : Colors.grey[800],
                        ),
                        onPressed: () {
                          ref
                              .read(pdfEditorProvider.notifier)
                              .setToggle(!addTagMode);
                        },
                      );
                    },
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final drawingEnabled = ref.watch(
                      pdfEditorProvider.select((s) => s.drawingEnabled),
                    );
                    return Tooltip(
                      message: 'Draw/Shapes/Text',
                      child: PopupMenuButton<ShapeType>(
                        onSelected: (value) {
                          if (value == ShapeType.text) {
                            showTextDialog();
                          } else if (value == ShapeType.drawing) {
                            ref
                                .read(pdfEditorProvider.notifier)
                                .setDrawingEnabled();
                          } else {
                            ref
                                .read(pdfEditorProvider.notifier)
                                .addShape(value);
                          }
                        },
                        icon: Icon(
                          Icons.edit_rounded,
                          color:
                              drawingEnabled ? Colors.blue : Colors.grey[800],
                        ),
                        itemBuilder:
                            (context) => getPopUpItems(context, drawingEnabled),
                      ),
                    );
                  },
                ),
                Tooltip(
                  message: 'Save Annotated PDF',
                  child: IconButton(
                    icon: const Icon(
                      Icons.save_sharp,
                      color: Colors.deepPurple,
                    ),
                    onPressed: savePdf,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
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
              image = snapshot.data!;
              final ratio = image.width! / image.height!;
              final displayWidth = MediaQuery.of(context).size.width;
              final displayHeight = displayWidth / ratio;
              final double scale =
                  tranformationController?.value.getMaxScaleOnAxis() ?? 1.0;
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

              return Stack(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 100),
                      color: Colors.white,
                      width: displayWidth,
                      height: displayHeight,
                      child: InteractiveViewer(
                        transformationController: tranformationController,
                        minScale: 1,
                        maxScale: 6,
                        panEnabled: true,
                        child: GestureDetector(
                          onPanStart:
                              drawingEnabled
                                  ? (details) {
                                    final box =
                                        context.findRenderObject() as RenderBox;
                                    ref
                                        .read(pdfEditorProvider.notifier)
                                        .onPanStart(details, box);
                                  }
                                  : null,
                          onPanUpdate:
                              drawingEnabled
                                  ? (details) {
                                    final box =
                                        context.findRenderObject() as RenderBox;
                                    ref
                                        .read(pdfEditorProvider.notifier)
                                        .onPanUpdate(details, box);
                                  }
                                  : null,
                          onPanEnd:
                              drawingEnabled
                                  ? (_) {
                                    ref
                                        .read(pdfEditorProvider.notifier)
                                        .saveCurrentStroke();
                                  }
                                  : null,
                          onTapDown: (details) async {
                            onTapDown(
                              details,
                              context,
                              ref,
                              displayWidth,
                              displayHeight,
                            );
                          },
                          child: Stack(
                            children: [
                              // PDF Page Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  image.bytes,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              // Drawing Layer
                              Consumer(
                                builder: (context, ref, _) {
                                  final strokes = ref.watch(
                                    pdfEditorProvider.select(
                                      (s) =>
                                          s.drawingsPerPage[currentPage] ?? [],
                                    ),
                                  );
                                  final currentPoints = ref.watch(
                                    pdfEditorProvider.select(
                                      (s) => s.currentPoints,
                                    ),
                                  );
                                  final penColor = ref.watch(
                                    pdfEditorProvider.select((s) => s.penColor),
                                  );
                                  final strokeWidth = ref.watch(
                                    pdfEditorProvider.select(
                                      (s) => s.strokeWidth,
                                    ),
                                  );
                                  return CustomPaint(
                                    painter: _PdfDrawingPainter(
                                      strokes,
                                      currentPoints,
                                      penColor,
                                      strokeWidth,
                                    ),
                                    size: Size(displayWidth, displayHeight),
                                  );
                                },
                              ),
                              // Text overlays (with slight shadow for UX)
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
                                            initialFontSize:
                                                annotation.fontSize,
                                            initialPosition:
                                                annotation.position,
                                            onChanged: (pos, size) {
                                              annotation.position = pos;
                                              annotation.fontSize = size;
                                            },
                                            onDelete: () {
                                              ref
                                                  .read(
                                                    pdfEditorProvider.notifier,
                                                  )
                                                  .deleteText(annotation);
                                            },
                                          );
                                        }).toList(),
                                  );
                                },
                              ),
                              // Comments (modern floating style)
                              // ... other Consumer builders (drawings, text, etc.)
                              Consumer(
                                builder: (context, ref, _) {
                                  final comments = ref.watch(
                                    pdfEditorProvider.select(
                                      (s) =>
                                          s.commentsPerPage[currentPage] ?? [],
                                    ),
                                  );
                                  final pdfPageSize = ref.watch(
                                    pdfEditorProvider.select(
                                      (s) => s.pdfPageSize,
                                    ),
                                  );
                                  return Stack(
                                    children:
                                        comments.asMap().entries.map((entry) {
                                          final _ = entry.key;
                                          final annotation = entry.value;
                                          const iconSize = 30.0;
                                          final scaleX =
                                              displayWidth / pdfPageSize.width;
                                          final scaleY =
                                              displayHeight /
                                              pdfPageSize.height;
                                          final widgetPos = Offset(
                                            annotation.position.dx * scaleX,
                                            annotation.position.dy * scaleY,
                                          );
                                          return Positioned(
                                            left: widgetPos.dx - iconSize,
                                            top: widgetPos.dy - iconSize,
                                            child: Stack(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.comment,
                                                    size: iconSize,
                                                  ),
                                                  color: Colors.orange[800],
                                                  splashRadius: 20,
                                                  tooltip: annotation.comment,
                                                  onPressed:
                                                      () => showCommentDialog(
                                                        context,
                                                        annotation,
                                                      ),
                                                ),
                                                Positioned(
                                                  top: -15,
                                                  right: -15,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.cancel_outlined,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    splashRadius: 18,
                                                    tooltip: 'Delete comment',
                                                    onPressed: () {
                                                      ref
                                                          .read(
                                                            pdfEditorProvider
                                                                .notifier,
                                                          )
                                                          .deleteCommentAnnotation(
                                                            annotation,
                                                          );
                                                    },
                                                  ),
                                                ),

                                                // Delete button for comment
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  );
                                },
                              ),
                              // Shapes
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
                                          final idx = entry.key;
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
                                                  .read(
                                                    pdfEditorProvider.notifier,
                                                  )
                                                  .deleteShape(idx);
                                            },
                                          );
                                        }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Floating page controls
                  Positioned(
                    bottom: 60,
                    left: MediaQuery.of(context).size.width * 0.07,
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.98),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Previous Page',
                              onPressed:
                                  currentPage > 1
                                      ? () => ref
                                          .read(pdfEditorProvider.notifier)
                                          .goToPage(currentPage - 1)
                                      : null,
                              icon: const Icon(Icons.chevron_left, size: 28),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                'Page $currentPage / $totalPages',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next Page',
                              onPressed:
                                  currentPage < totalPages
                                      ? () => ref
                                          .read(pdfEditorProvider.notifier)
                                          .goToPage(currentPage + 1)
                                      : null,
                              icon: const Icon(Icons.chevron_right, size: 28),
                            ),
                            IconButton(
                              tooltip: 'Undo',
                              onPressed:
                                  () =>
                                      ref
                                          .read(pdfEditorProvider.notifier)
                                          .undoDrawing(),
                              icon: const Icon(Icons.undo, size: 22),
                            ),
                            IconButton(
                              tooltip: 'Redo',
                              onPressed:
                                  () =>
                                      ref
                                          .read(pdfEditorProvider.notifier)
                                          .redoDrawing(),
                              icon: const Icon(Icons.redo, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<PopupMenuEntry<ShapeType>> getPopUpItems(
    BuildContext context,
    bool drawingEnabled,
  ) {
    return [
      const PopupMenuItem(
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
      const PopupMenuItem(
        value: ShapeType.circle,
        child: Icon(Icons.circle_outlined),
      ),
      const PopupMenuItem(
        value: ShapeType.line,
        child: Icon(Icons.shape_line_outlined),
      ),
      const PopupMenuItem(
        value: ShapeType.rectangle,
        child: Icon(Icons.rectangle_outlined),
      ),
      const PopupMenuItem(
        value: ShapeType.line,
        child: Icon(Icons.remove_rounded),
      ),
      const PopupMenuItem(
        value: ShapeType.arrow,
        child: Icon(Icons.arrow_right_alt_rounded, color: Colors.black),
      ),
      const PopupMenuItem(
        value: ShapeType.triangle,
        child: Icon(Icons.change_history_rounded),
      ),
    ];
  }

  void savePdf() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const SizedBox(
              width: 260,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    backgroundColor: Colors.blueAccent,
                    strokeWidth: 3,
                  ),
                  SizedBox(width: 18),
                  Flexible(
                    child: Text(
                      'Saving PDF...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    final ratio = image.width! / image.height!;
    final displaySize = Size(
      MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.width / ratio,
    );
    final path = await ref
        .read(pdfEditorProvider.notifier)
        .saveAnnotatedPdf(displaySize: displaySize);

    if (mounted) {
      Navigator.pop(context); // Close the loading dialog
      Navigator.pop(context, path); // Return the path to the calling project
    }
  }

  void showTextDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Enter Text',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Type your text here...',
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
    if (!addTagMode) return;

    final local = details.localPosition;
    final pdfPageSize = ref.read(
      pdfEditorProvider.select((s) => s.pdfPageSize),
    );
    final sx = pdfPageSize.width / displayWidth;
    final sy = pdfPageSize.height / displayHeight;
    final pdfPos = Offset(local.dx * sx, local.dy * sy);

    final comment = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Comment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Type your comment here...',
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (comment != null && comment.trim().isNotEmpty) {
      ref
          .read(pdfEditorProvider.notifier)
          .addCommentAnnotation(comment.trim(), pdfPos);
    }
    ref.read(pdfEditorProvider.notifier).setToggle(false);
  }
}

class _PdfDrawingPainter extends CustomPainter {
  final List<StrokeSegment> strokes;
  final List<Offset?> current;
  final Color currentColor;
  final double currentWidth;

  _PdfDrawingPainter(
    this.strokes,
    this.current,
    this.currentColor,
    this.currentWidth,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final stroke in strokes) {
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i]!, stroke.points[i + 1]!, paint);
      }
    }
    paint
      ..color = currentColor
      ..strokeWidth = currentWidth;
    for (int i = 0; i < current.length - 1; i++) {
      canvas.drawLine(current[i]!, current[i + 1]!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PdfDrawingPainter old) => true;
}
