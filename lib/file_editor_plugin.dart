
import 'package:file_editor/pdf/pdf_annotator.dart';
import 'package:flutter/material.dart';

class FileEditorPlugin {
  /// Opens the file editor for the specified [filePath].
  static Future<void> openFileEditor(
    BuildContext context,
    String filePath,
  ) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfAnnotator(filePath)),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unsupported file type')));
    }
  }
}
