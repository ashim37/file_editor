import 'package:flutter/material.dart';

import 'package:file_editor/shape_type.dart';

class Shape {
  ShapeType type;
  Offset position;
  Size size;
  Color color;

  Shape({
    required this.type,
    required this.position,
    required this.size,
    this.color = Colors.black,
  });

  Shape copyWith({required Offset position, required Size size}) {
    return Shape(type: type, position: position, size: size, color: color);
  }
}
