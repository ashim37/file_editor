import 'package:file_editor/image/image_annotator.dart';
import 'package:file_editor/pdf/pdf_annotator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(ProviderScope(child: const MaterialApp(home: MyApp())));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? filePath;

  void _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpeg', 'jpg', 'png', 'webp'],
    );
    if (result != null && result.files.single.path != null) {
      filePath = result.files.single.path!;
      var fileType = getFileExtension(filePath ?? "");
      if (fileType == '.jpeg' ||
          fileType == '.jpg' ||
          fileType == '.png' ||
          fileType == '.webp') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              return ImageAnnotator(filePath);
            },
          ),
        );
      } else if (fileType == '.pdf') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              return PdfAnnotator(filePath);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("File type is not supported")));
      }
    }
  }

  String getFileExtension(String fileName) {
    return ".${fileName.split('.').last}".toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MaterialButton(
          height: 40,
          onPressed: _pickPdf,
          color: Colors.black,
          child: const Text(
            "Pick Image or PDF",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
