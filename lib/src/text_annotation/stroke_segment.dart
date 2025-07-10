import 'dart:ui';

class StrokeSegment {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  StrokeSegment(this.points, this.color, this.strokeWidth);
}
