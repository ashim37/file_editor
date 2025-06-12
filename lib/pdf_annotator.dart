import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_editor/permission_request_handler.dart';
import 'package:file_editor/storage_directory_path.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class StrokeSegment {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  StrokeSegment(this.points, this.color, this.strokeWidth);
}

class PdfAnnotator extends StatefulWidget {
  final String? filePath;

  const PdfAnnotator(this.filePath, {super.key});

  @override
  State<PdfAnnotator> createState() => _PdfAnnotatorState();
}

class _PdfAnnotatorState extends State<PdfAnnotator> {
  Color penColor = Colors.red;
  double strokeWidth = 3.0;
  final List<StrokeSegment> undoStack = [];
  pdfx.PdfDocument? document;
  int currentPage = 1;
  int totalPages = 0;
  final Map<int, List<StrokeSegment>> _drawingsPerPage = {};
  List<Offset?> currentPoints = [];
  double scaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _pickPdf();
  }

  void _pickPdf() async {
    final doc = await pdfx.PdfDocument.openFile(widget.filePath!);
    setState(() {
      document = doc;
      totalPages = doc.pagesCount;
      currentPage = 1;
      _drawingsPerPage.clear();
      for (int i = 1; i <= totalPages; i++) {
        _drawingsPerPage[i] = [];
      }
      currentPoints = [];
    });
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _saveCurrentStroke();
      setState(() {
        currentPage = page;
        currentPoints = [];
      });
    }
  }

  void _saveCurrentStroke() {
    if (currentPoints.isNotEmpty) {
      _drawingsPerPage[currentPage]?.add(
        StrokeSegment(List.from(currentPoints), penColor, strokeWidth),
      );
      currentPoints.clear();
    }
  }

  void _clearDrawing() {
    setState(() {
      if (_drawingsPerPage[currentPage]!.isNotEmpty) {
        undoStack.add(_drawingsPerPage[currentPage]!.removeLast());
      }
    });
  }

  Future<void> _saveAnnotatedPdf() async {
    _saveCurrentStroke();
    final pdf = pw.Document();
    final dir = await getExternalStorageDirectory();

    for (int i = 1; i <= totalPages; i++) {
      final page = await document!.getPage(i);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      final uiImage = await decodeImageFromList(image!.bytes);
      canvas.drawImage(uiImage, Offset.zero, paint);

      for (final stroke in _drawingsPerPage[i]!) {
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

      final pic = recorder.endRecording();
      final annotatedImage = await pic.toImage(image.width!, image.height!);
      final pngBytes = await annotatedImage.toByteData(
        format: ui.ImageByteFormat.png,
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

    savePdfFile(await pdf.save());
  }

  Future<void> savePdfFile(Uint8List pdfBytes) async {
    await requestStoragePermission();
    final path = await getExportPath(
      '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    final file = File(path);
    await file.writeAsBytes(pdfBytes);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Annotator'),
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
            onPressed: _saveAnnotatedPdf,
          ),
        ],
      ),
      body: FutureBuilder<pdfx.PdfPageImage?>(
        future: document!
            .getPage(currentPage)
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
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = snapshot.data!.width! / snapshot.data!.height!;
                  final displayWidth = constraints.maxWidth;
                  final displayHeight = displayWidth / ratio;
                  scaleFactor = snapshot.data!.width! / displayWidth;

                  return GestureDetector(
                    onPanUpdate: (details) {
                      RenderBox box = context.findRenderObject() as RenderBox;
                      Offset local = box.globalToLocal(details.globalPosition);
                      setState(() {
                        currentPoints.add(local * scaleFactor);
                      });
                    },
                    onPanEnd:
                        (_) => setState(() {
                          _saveCurrentStroke();
                        }),
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: Stack(
                        children: [
                          Image.memory(snapshot.data!.bytes, fit: BoxFit.fill),
                          CustomPaint(
                            painter: _PdfDrawingPainter(
                              _drawingsPerPage[currentPage]!,
                              currentPoints,
                              penColor,
                              strokeWidth,
                              scaleFactor,
                            ),
                            size: Size(displayWidth, displayHeight),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
                  currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('Page $currentPage / $totalPages'),
            IconButton(
              onPressed:
                  currentPage < totalPages
                      ? () => _goToPage(currentPage + 1)
                      : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(icon: const Icon(Icons.clear), onPressed: _clearDrawing),
          ],
        ),
      ),
    );
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
