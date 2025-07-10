import 'package:flutter/material.dart';

class TextAnnotation {
  String text;
  Offset position;
  double fontSize;
  Color color;

  TextAnnotation({
    required this.text,
    required this.position,
    this.fontSize = 12.0,
    this.color = Colors.black,
  });
}
