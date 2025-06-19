import 'package:file_editor/pdf/pdf_annotator_riverpods.dart';
import 'package:file_editor/pdf/pdf_annotator_state.dart';
import 'package:file_editor/text_annotation/text_sticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../text_annotation/stroke_segment.dart';

final pdfEditorProvider =
    StateNotifierProvider<PDFAnnotatorRiverPods, PdfAnnotatorState>(
      (ref) => PDFAnnotatorRiverPods(),
    );

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
    final state = ref.watch(pdfEditorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Annotator'),
        actions: [
          DropdownButton<Color>(
            value: state.penColor,
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
                ref
                    .read(pdfEditorProvider.notifier)
                    .addTextAnnotation(result.trim());
              }
            },
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: savePdf),
        ],
      ),
      body:
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<pdfx.PdfPageImage?>(
                future: state.document!
                    .getPage(state.currentPage)
                    .then(
                      (page) => page
                          .render(
                            width: page.width,
                            height: page.height,
                            format: pdfx.PdfPageImageFormat.png,
                          )
                          .whenComplete(() => page.close()),
                    ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Container(
                    color: Colors.white,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ratio =
                            snapshot.data!.width! / snapshot.data!.height!;
                        final displayWidth = constraints.maxWidth;
                        final displayHeight = displayWidth / ratio;
                        final scale = snapshot.data!.width! / displayWidth;

                        if (_lastScaleFactor != scale ||
                            _lastPageForScale != state.currentPage) {
                          _lastScaleFactor = scale;
                          _lastPageForScale = state.currentPage;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref
                                .read(pdfEditorProvider.notifier)
                                .updateScaleFactor(scale);
                          });
                        }
                        return GestureDetector(
                          onPanUpdate: (details) {
                            ref
                                .read(pdfEditorProvider.notifier)
                                .onPanUpdate(
                                  details,
                                  context.findRenderObject() as RenderBox,
                                );
                          },
                          onPanEnd:
                              (_) =>
                                  ref
                                      .read(pdfEditorProvider.notifier)
                                      .saveCurrentStroke(),
                          child: SizedBox(
                            width: displayWidth,
                            height: displayHeight,
                            child: Stack(
                              children: [
                                Image.memory(
                                  snapshot.data!.bytes,
                                  fit: BoxFit.fill,
                                ),
                                CustomPaint(
                                  painter: _PdfDrawingPainter(
                                    state.drawingsPerPage[state.currentPage] ??
                                        [],
                                    state.currentPoints,
                                    state.penColor,
                                    state.strokeWidth,
                                    state.scaleFactor,
                                  ),
                                  size: Size(displayWidth, displayHeight),
                                ),
                                ...state.textPerPage[state.currentPage]!.map((
                                  annotation,
                                ) {
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed:
                  state.currentPage > 1
                      ? () => ref
                          .read(pdfEditorProvider.notifier)
                          .goToPage(state.currentPage - 1)
                      : null,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('Page ${state.currentPage} / ${state.totalPages}'),
            IconButton(
              onPressed:
                  state.currentPage < state.totalPages
                      ? () => ref
                          .read(pdfEditorProvider.notifier)
                          .goToPage(state.currentPage + 1)
                      : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed:
                  () => ref.read(pdfEditorProvider.notifier).clearDrawing(),
            ),
          ],
        ),
      ),
    );
  }

  void savePdf() async {
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          Container(
            margin: EdgeInsets.only(left: 7),
            child: Text("Saving PDF..."),
          ),
        ],
      ),
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
    final path = await ref.read(pdfEditorProvider.notifier).saveAnnotatedPdf();

    if (mounted) {
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
      Navigator.pop(context); // close editor
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

    final paint =
        Paint()
          ..color = currentColor
          ..strokeWidth = currentWidth / scaleFactor
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < current.length - 1; i++) {
      if (current[i] != null && current[i + 1] != null) {
        canvas.drawLine(
          current[i]! / scaleFactor,
          current[i + 1]! / scaleFactor,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PdfDrawingPainter oldDelegate) => true;
}
