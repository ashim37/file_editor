import 'dart:ui';

import '../shape_type.dart';

class Shape {
  ShapeType type;
  Offset position;
  Size size;

  Shape({required this.type, required this.position, required this.size});
}
