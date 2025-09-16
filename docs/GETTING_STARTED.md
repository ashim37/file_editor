# Getting Started Guide

## Installation and Setup

### 1. Add Dependencies

First, add the PDF editor library to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  file_editor: ^0.0.1
  flutter_riverpod: ^2.6.1  # Required for state management
```

### 2. Configure Permissions

Add the following permissions to your platform-specific configuration files:

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to documents to load and save PDF files</string>
<key>NSDownloadsFolderUsageDescription</key>
<string>This app needs access to downloads to load PDF files</string>
```

### 3. Basic Implementation

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_editor/pdf_editor_lib.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Editor Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PdfEditorScreen(),
    );
  }
}

class PdfEditorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PdfAnnotator('/path/to/your/document.pdf');
  }
}
```

## Step-by-Step Tutorial

### Step 1: File Selection

Implement file picking to allow users to select PDF files:

```dart
import 'package:file_picker/file_picker.dart';

class FileSelectionScreen extends StatefulWidget {
  @override
  _FileSelectionScreenState createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {
  String? selectedFilePath;

  Future<void> pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        selectedFilePath = result.files.single.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select PDF')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: pickPdfFile,
              child: Text('Select PDF File'),
            ),
            if (selectedFilePath != null) ...[
              SizedBox(height: 20),
              Text('Selected: ${selectedFilePath!.split('/').last}'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfAnnotator(selectedFilePath),
                    ),
                  );
                },
                child: Text('Open PDF Editor'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Step 2: Understanding the Interface

The PDF editor interface consists of:

1. **Top App Bar**:
   - Pen color selector (dropdown with color circles)
   - Comment toggle button (enables tap-to-add-comment mode)
   - Draw/Shapes menu (popup menu with drawing and shape options)
   - Save button (exports annotated PDF)

2. **Main Canvas**:
   - PDF page display with zoom/pan capabilities
   - Interactive annotation layers
   - Real-time drawing feedback

3. **Floating Controls**:
   - Page navigation (previous/next buttons)
   - Page counter display
   - Undo/Redo buttons

### Step 3: Basic Annotations

#### Adding Comments
1. Tap the comment button in the toolbar (turns orange when active)
2. Tap anywhere on the PDF to place a comment
3. Enter your comment text in the dialog
4. The comment appears as an orange comment icon

#### Drawing
1. Tap the draw/shapes menu and select the pencil icon
2. Choose your pen color from the dropdown
3. Draw directly on the PDF with your finger or stylus
4. Drawing mode remains active until you select another tool

#### Adding Text
1. Tap the draw/shapes menu and select "Text"
2. Enter your text in the dialog
3. The text appears on the PDF and can be dragged to reposition
4. Tap and hold to resize the text

#### Adding Shapes
1. Tap the draw/shapes menu
2. Select from: Circle, Rectangle, Line, Arrow, or Triangle
3. The shape appears on the PDF
4. Drag to reposition, use corner handles to resize

### Step 4: Advanced Features

#### Custom Colors and Styling

```dart
// You can extend the color palette by modifying the dropdown items
final customColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.black,
  Colors.yellow,
  Colors.purple,
  Colors.orange,
  Colors.pink,
];
```

#### Programmatic Annotations

```dart
class CustomPdfEditor extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PdfAnnotator('/path/to/file.pdf'),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add programmatic annotations
          ref.read(pdfEditorProvider.notifier)
            .addTextAnnotation('Programmatically added text');
          
          ref.read(pdfEditorProvider.notifier)
            .addCommentAnnotation('Auto comment', Offset(100, 100));
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Common Use Cases

### 1. Document Review Workflow

```dart
class DocumentReviewApp extends StatelessWidget {
  final String documentPath;
  
  const DocumentReviewApp({required this.documentPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ProviderScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Document Review'),
            actions: [
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () => shareAnnotatedPdf(context),
              ),
            ],
          ),
          body: PdfAnnotator(documentPath),
        ),
      ),
    );
  }

  void shareAnnotatedPdf(BuildContext context) {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved and ready to share')),
    );
  }
}
```

### 2. Educational Content Creation

```dart
class EducationalPdfEditor extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PdfAnnotator('/path/to/educational/content.pdf'),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.highlight),
              onPressed: () {
                ref.read(pdfEditorProvider.notifier)
                  .setPenColor(Colors.yellow);
              },
            ),
            IconButton(
              icon: Icon(Icons.note_add),
              onPressed: () {
                // Quick note functionality
                _showQuickNoteDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickNoteDialog(BuildContext context, WidgetRef ref) {
    // Implementation for quick note dialog
  }
}
```

### 3. Form Filling

```dart
class FormFillingEditor extends StatelessWidget {
  final String formPath;
  
  const FormFillingEditor({required this.formPath});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Fill Form'),
          actions: [
            IconButton(
              icon: Icon(Icons.check_circle),
              onPressed: () => _validateAndSave(context),
            ),
          ],
        ),
        body: PdfAnnotator(formPath),
      ),
    );
  }

  void _validateAndSave(BuildContext context) {
    // Implement form validation and saving
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Form Complete'),
        content: Text('Your form has been filled and saved successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

## Best Practices

### 1. Error Handling

```dart
class RobustPdfEditor extends ConsumerWidget {
  final String? filePath;

  const RobustPdfEditor({this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filePath == null || !File(filePath!).existsSync()) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('File not found or invalid path'),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return PdfAnnotator(filePath);
  }
}
```

### 2. Memory Management

```dart
class OptimizedPdfEditor extends ConsumerStatefulWidget {
  final String filePath;

  const OptimizedPdfEditor({required this.filePath});

  @override
  ConsumerState<OptimizedPdfEditor> createState() => _OptimizedPdfEditorState();
}

class _OptimizedPdfEditorState extends ConsumerState<OptimizedPdfEditor> {
  @override
  void dispose() {
    // Clean up resources when widget is disposed
    ref.read(pdfEditorProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfAnnotator(widget.filePath);
  }
}
```

### 3. Custom Theming

```dart
class ThemedPdfEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: PdfAnnotator('/path/to/document.pdf'),
    );
  }
}
```

## Troubleshooting Common Issues

### Issue 1: PDF Not Loading
**Solution**: Check file permissions and path validity
```dart
Future<bool> validatePdfFile(String path) async {
  final file = File(path);
  return await file.exists() && path.toLowerCase().endsWith('.pdf');
}
```

### Issue 2: Annotations Not Saving
**Solution**: Ensure storage permissions are granted
```dart
Future<void> checkPermissions() async {
  final hasPermission = await PermissionRequestHandler.checkStoragePermission();
  if (!hasPermission) {
    await PermissionRequestHandler.requestStoragePermission();
  }
}
```

### Issue 3: Performance Issues with Large PDFs
**Solution**: Implement page-by-page loading and memory management
```dart
// The library automatically handles this, but you can monitor memory usage
void monitorMemoryUsage() {
  // Implement memory monitoring if needed
}
```

This completes the getting started guide with practical examples and solutions for common implementation scenarios.
