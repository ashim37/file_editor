import 'package:file_editor/src/pdf/pdf_annotator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PdfEditorWidgetWrapper extends StatelessWidget {
  final String pdfFile;

  const PdfEditorWidgetWrapper({super.key, required this.pdfFile});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      child: ProviderScope(child: PdfAnnotator(pdfFile)),
    );
  }
}
