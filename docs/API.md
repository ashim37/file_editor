# API Documentation

## Core Classes

### PdfAnnotator

The main widget class for PDF annotation functionality.

```dart
class PdfAnnotator extends ConsumerStatefulWidget {
  final String? filePath;
  
  const PdfAnnotator(this.filePath, {super.key});
}
```

#### Methods

- `initState()`: Initializes the PDF document and loads the file
- `build(BuildContext context)`: Builds the main UI with all annotation tools
- `savePdf()`: Exports the annotated PDF to device storage
- `showTextDialog()`: Displays dialog for text annotation input
- `showCommentDialog()`: Shows comment content in a dialog
- `onTapDown()`: Handles tap events for comment placement

#### Key Features

- **Interactive Viewer**: Zoom, pan, and scale PDF pages
- **Multi-layer Rendering**: Separate layers for PDF, drawings, text, comments, and shapes
- **Real-time Updates**: Live preview of all annotations
- **Page Navigation**: Seamless navigation between PDF pages

### PDFAnnotatorRiverPods

State management class using Riverpod for PDF editor functionality.

```dart
class PDFAnnotatorRiverPods extends StateNotifier<PdfAnnotatorState>
```

#### Key Methods

- `loadPDF(String filePath)`: Loads PDF document from file path
- `goToPage(int page)`: Navigates to specific page
- `setPenColor(Color color)`: Sets drawing pen color
- `setDrawingEnabled()`: Toggles drawing mode
- `addShape(ShapeType type)`: Adds geometric shapes
- `addTextAnnotation(String text)`: Adds text annotations
- `addCommentAnnotation(String comment, Offset position)`: Adds comment at position
- `saveAnnotatedPdf({required Size displaySize})`: Exports annotated PDF
- `undoDrawing()`: Undoes last drawing action
- `redoDrawing()`: Redoes previously undone action

### PdfAnnotatorState

Data class representing the current state of the PDF editor.

```dart
class PdfAnnotatorState {
  final bool isLoading;
  final pdfx.PdfDocument? document;
  final int currentPage;
  final int totalPages;
  final Map<int, List<StrokeSegment>> drawingsPerPage;
  final List<Offset?> currentPoints;
  final Map<int, List<TextAnnotation>> textPerPage;
  final Map<int, List<CommentAnnotation>> commentsPerPage;
  final Map<int, List<Shape>>? shapePerPage;
  final List<Map<int, List<StrokeSegment>>> undoStack;
  final Color penColor;
  final double scaleFactor;
  final double strokeWidth;
  final bool drawingEnabled;
  final bool addTagMode;
  final Size pdfPageSize;
  final TransformationController transformationController;
}
```

## Annotation Models

### TextAnnotation

Represents text annotations placed on PDF pages.

```dart
class TextAnnotation {
  String text;
  Offset position;
  double fontSize;
  Color color;
}
```

### CommentAnnotation

Represents comment annotations with position and content.

```dart
class CommentAnnotation {
  final String comment;
  Offset position;
}
```

### StrokeSegment

Represents drawing strokes with color and width properties.

```dart
class StrokeSegment {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;
}
```

### Shape

Base class for geometric shapes that can be added to PDFs.

```dart
class Shape {
  ShapeType type;
  Offset position;
  Size size;
  Color color;
}
```

## Enumerations

### ShapeType

Defines available shape types for annotation.

```dart
enum ShapeType {
  circle,
  rectangle,
  line,
  arrow,
  triangle,
  text,
  drawing,
}
```

## Utility Classes

### StringExtension

Extensions for string manipulation and validation.

```dart
extension StringExtension on String? {
  bool isPdf(); // Checks if string represents a PDF file path
}
```

### PermissionRequestHandler

Handles storage and file system permissions.

```dart
class PermissionRequestHandler {
  static Future<bool> requestStoragePermission();
  static Future<bool> checkStoragePermission();
}
```

### StorageDirectoryPath

Provides access to device storage directories.

```dart
class StorageDirectoryPath {
  static Future<String> getDownloadsDirectory();
  static Future<String> getDocumentsDirectory();
}
```

## Widget Components

### TextSticker

Interactive text overlay widget for PDF annotations.

```dart
class TextSticker extends StatefulWidget {
  final String text;
  final Color color;
  final double initialFontSize;
  final Offset initialPosition;
  final Function(Offset, double) onChanged;
  final VoidCallback onDelete;
}
```

### DraggableResizableShape

Interactive shape widget with drag and resize capabilities.

```dart
class DraggableResizableShape extends StatefulWidget {
  final Shape shape;
  final Color color;
  final Function(Offset, Size) onUpdate;
  final VoidCallback onDelete;
}
```

## Provider Usage

### Setting up Riverpod

```dart
// In main.dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Accessing PDF Editor State

```dart
// In your widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      pdfEditorProvider.select((s) => s.isLoading),
    );
    
    final currentPage = ref.watch(
      pdfEditorProvider.select((s) => s.currentPage),
    );
    
    // Use the state values...
    return Widget();
  }
}
```

### Triggering Actions

```dart
// In your widget
onPressed: () {
  ref.read(pdfEditorProvider.notifier).goToPage(2);
  ref.read(pdfEditorProvider.notifier).setPenColor(Colors.blue);
  ref.read(pdfEditorProvider.notifier).addTextAnnotation("Hello World");
}
```

## Event Handling

### Drawing Events

```dart
onPanStart: (details) {
  final box = context.findRenderObject() as RenderBox;
  ref.read(pdfEditorProvider.notifier).onPanStart(details, box);
}

onPanUpdate: (details) {
  final box = context.findRenderObject() as RenderBox;
  ref.read(pdfEditorProvider.notifier).onPanUpdate(details, box);
}

onPanEnd: (_) {
  ref.read(pdfEditorProvider.notifier).saveCurrentStroke();
}
```

### Tap Events

```dart
onTapDown: (details) {
  onTapDown(details, context, ref, displayWidth, displayHeight);
}
```

## Custom Painters

### _PdfDrawingPainter

Custom painter for rendering drawing strokes on PDF pages.

```dart
class _PdfDrawingPainter extends CustomPainter {
  final List<StrokeSegment> strokes;
  final List<Offset?> current;
  final Color currentColor;
  final double currentWidth;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Renders all strokes and current drawing
  }
}
```

## Error Handling

The library provides built-in error handling for common scenarios:

1. **File Loading Errors**: Invalid paths or corrupted PDFs
2. **Permission Errors**: Storage access denied
3. **Memory Errors**: Large PDF files exceeding device capabilities
4. **Export Errors**: Insufficient storage space or write permissions

## Performance Considerations

- **Memory Management**: Large PDFs are rendered page by page
- **State Optimization**: Only re-render when necessary using selective watching
- **Efficient Drawing**: Custom painters minimize rendering overhead
- **Background Processing**: PDF operations run on separate isolates when possible
