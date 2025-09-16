# PDF Editor Library

A comprehensive Flutter package for PDF annotation and editing with support for drawing, text annotations, shapes, and comments.

## Features

- ✅ **PDF Viewing**: Load and display PDF documents with zoom and pan support
- ✅ **Drawing Tools**: Free-hand drawing with customizable pen colors and stroke width
- ✅ **Text Annotations**: Add text overlays with customizable positioning and font size
- ✅ **Shape Tools**: Insert circles, rectangles, lines, arrows, and triangles
- ✅ **Comment System**: Add comment annotations with tap-to-place functionality
- ✅ **Undo/Redo**: Full undo/redo support for all annotation types
- ✅ **Page Navigation**: Navigate between PDF pages with intuitive controls
- ✅ **Export**: Save annotated PDFs to device storage
- ✅ **Interactive Viewer**: Zoom, pan, and scale support with transformation controls

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  file_editor: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Dependencies

This package relies on the following dependencies:

- `pdfx: ^2.9.1` - PDF rendering and document handling
- `pdf: ^3.11.3` - PDF generation and manipulation
- `flutter_riverpod: ^2.6.1` - State management
- `permission_handler: ^12.0.0+1` - Storage permissions
- `path_provider: ^2.1.5` - File path management

## Quick Start

### Basic Usage

```dart
import 'package:file_editor/pdf_editor_lib.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PdfAnnotator('/path/to/your/pdf/file.pdf'),
    );
  }
}
```

### With Provider Wrapper

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

## API Reference

### PdfAnnotator Widget

The main widget for PDF annotation functionality.

#### Constructor

```dart
PdfAnnotator(
  String? filePath, {
  Key? key,
})
```

#### Parameters

- `filePath`: Path to the PDF file to be loaded and annotated

#### Features Available

1. **Drawing Mode**: Enable/disable free-hand drawing
2. **Pen Color Selection**: Choose from red, blue, green, black, or yellow
3. **Text Annotations**: Add positioned text with customizable size
4. **Shape Tools**: Insert various geometric shapes
5. **Comment System**: Add comment annotations at specific positions
6. **Page Navigation**: Move between PDF pages
7. **Undo/Redo**: Revert or restore annotation changes
8. **Save Functionality**: Export annotated PDF

## Annotation Types

### 1. Drawing Annotations

Free-hand drawing with customizable pen properties:

- **Colors**: Red, Blue, Green, Black, Yellow
- **Stroke Width**: Adjustable stroke width (default: 3.0)
- **Stroke Cap**: Rounded line endings

### 2. Text Annotations

Positioned text overlays with:

- **Editable Text**: Multi-line text input
- **Repositioning**: Drag to move text annotations
- **Font Size**: Adjustable text size
- **Color Support**: Customizable text colors

### 3. Shape Annotations

Geometric shapes including:

- **Circle**: Perfect circles with drag-resize capability
- **Rectangle**: Rectangles with corner handles
- **Line**: Straight lines with endpoint controls
- **Arrow**: Directional arrows
- **Triangle**: Triangular shapes

### 4. Comment Annotations

Positioned comment bubbles:

- **Tap-to-Place**: Click anywhere to add comments
- **Comment Dialog**: Rich text input for comments
- **Visual Indicators**: Orange comment icons
- **Delete Functionality**: Remove comments with delete button

## User Interface

### Toolbar Features

The top app bar includes:

1. **Pen Color Dropdown**: Select drawing color
2. **Comment Toggle**: Enable/disable comment placement mode
3. **Draw/Shapes Menu**: Access drawing and shape tools
4. **Save Button**: Export annotated PDF

### Navigation Controls

Floating page controls provide:

- **Previous/Next Page**: Navigate between pages
- **Page Counter**: Current page / total pages display
- **Undo/Redo**: Quick access to undo/redo functions

## State Management

The library uses Riverpod for state management with the following providers:

- `pdfEditorProvider`: Main state provider for PDF editor functionality
- Manages document state, annotations, current page, and user interactions

## Permissions

The library handles the following permissions automatically:

- **Storage Access**: For reading PDF files and saving annotated versions
- **File System**: Access to device storage directories

## File Structure

```
lib/
├── pdf_editor_lib.dart          # Main library export
└── src/
    ├── pdf/
    │   ├── pdf_annotator.dart           # Main PDF annotator widget
    │   ├── pdf_annotator_riverpods.dart # State management
    │   ├── pdf_annotator_state.dart     # State model
    │   ├── comment_annotation.dart      # Comment annotation model
    │   └── PdfEditorWidgetWrapper.dart  # Widget wrapper
    ├── shape/
    │   ├── shape.dart                   # Shape model
    │   └── draggable_resizable_shape.dart # Interactive shape widget
    ├── text_annotation/
    │   ├── text_annotation.dart         # Text annotation model
    │   ├── text_sticker.dart           # Text overlay widget
    │   └── stroke_segment.dart         # Drawing stroke model
    └── utils/
        ├── shape_type.dart              # Shape type enumeration
        ├── string_extension.dart        # String utilities
        ├── permission_request_handler.dart # Permission handling
        └── storage_directory_path.dart  # File path utilities
```

## Examples

### Basic PDF Viewer

```dart
import 'package:file_editor/pdf_editor_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BasicPdfViewer extends ConsumerWidget {
  final String pdfPath;

  const BasicPdfViewer({required this.pdfPath, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PdfAnnotator(pdfPath),
    );
  }
}
```

### Custom App Integration

```dart
class CustomPdfEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ProviderScope(
        child: PdfAnnotator('/storage/emulated/0/Documents/sample.pdf'),
      ),
    );
  }
}
```

## Troubleshooting

### Common Issues

1. **PDF Not Loading**
   - Ensure the file path is correct and accessible
   - Check file permissions
   - Verify the file is a valid PDF format

2. **Annotations Not Saving**
   - Confirm storage permissions are granted
   - Check available storage space
   - Ensure write permissions to the target directory

3. **Performance Issues**
   - Large PDF files may require more memory
   - Consider implementing pagination for very large documents
   - Monitor device memory usage

### Error Handling

The library includes built-in error handling for:

- Invalid file paths
- Unsupported file formats
- Permission denied scenarios
- Storage access failures

## Contributing

This library is actively being developed. Key areas for contribution:

1. **Additional Shape Types**: Extend the shape toolkit
2. **Advanced Text Formatting**: Rich text support
3. **Annotation Export**: Export annotations to various formats
4. **Performance Optimization**: Improve rendering for large documents
5. **Accessibility**: Add screen reader and keyboard navigation support

## License

This project is licensed under the terms specified in the LICENSE file.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and updates.

---

**Note**: This library is currently in version 0.0.1 and under active development. Some features may be experimental or subject to change in future releases.
