import 'package:file_editor/shape/shape.dart';
import 'package:file_editor/shape_type.dart';
import 'package:flutter/material.dart';

class DraggableResizableShape extends StatefulWidget {
  final Shape shape;
  final void Function(Offset, Size) onUpdate;
  final void Function() onDelete;
  final Color color;

  const DraggableResizableShape({
    super.key,
    required this.shape,
    required this.onUpdate,
    required this.color,
    required this.onDelete,
  });

  @override
  State<DraggableResizableShape> createState() =>
      _DraggableResizableShapeState();
}

class _DraggableResizableShapeState extends State<DraggableResizableShape> {
  late Offset position;
  late Size size;
  static const double minSize = 30;
  static const double maxSize = 500;
  static const double handleSize = 18;

  @override
  void initState() {
    super.initState();
    position = widget.shape.position;
    size = widget.shape.size;
  }

  void _update(Offset newPosition, Size newSize) {
    setState(() {
      position = newPosition;
      size = newSize;
      widget.onUpdate(position, size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position += details.delta;
            widget.onUpdate(position, size);
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: _ShapePainter(widget.shape.type, widget.color),
            ),
            // Side handles
            _buildHandle(
              left: size.width / 2 - handleSize / 2,
              top: -handleSize / 2,
              onPanUpdate: (details) {
                double newHeight = (size.height - details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                double dy = position.dy;
                if (newHeight != size.height) {
                  dy = position.dy + details.delta.dy;
                  if (newHeight == minSize) {
                    dy = position.dy + (size.height - minSize);
                  }
                  _update(Offset(position.dx, dy), Size(size.width, newHeight));
                }
              },
            ),
            _buildHandle(
              left: size.width / 2 - handleSize / 2,
              top: size.height - handleSize / 2,
              onPanUpdate: (details) {
                double newHeight = (size.height + details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                if (newHeight != size.height) {
                  _update(position, Size(size.width, newHeight));
                }
              },
            ),
            _buildHandle(
              left: -handleSize / 2,
              top: size.height / 2 - handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width - details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                double dx = position.dx;
                if (newWidth != size.width) {
                  dx = position.dx + details.delta.dx;
                  if (newWidth == minSize) {
                    dx = position.dx + (size.width - minSize);
                  }
                  _update(Offset(dx, position.dy), Size(newWidth, size.height));
                }
              },
            ),
            _buildHandle(
              left: size.width - handleSize / 2,
              top: size.height / 2 - handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width + details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                if (newWidth != size.width) {
                  _update(position, Size(newWidth, size.height));
                }
              },
            ),
            // Corner handles (independent axis logic)
            _buildHandle(
              left: -handleSize / 2,
              top: -handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width - details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                double newHeight = (size.height - details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                double dx = position.dx;
                double dy = position.dy;
                if (newWidth != size.width) {
                  dx = position.dx + details.delta.dx;
                  if (newWidth == minSize) {
                    dx = position.dx + (size.width - minSize);
                  }
                }
                if (newHeight != size.height) {
                  dy = position.dy + details.delta.dy;
                  if (newHeight == minSize) {
                    dy = position.dy + (size.height - minSize);
                  }
                }
                if (newWidth != size.width || newHeight != size.height) {
                  _update(Offset(dx, dy), Size(newWidth, newHeight));
                }
              },
            ),

            _buildHandle(
              left: size.width - handleSize / 2,
              top: -handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width + details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                double newHeight = (size.height - details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                double dy = position.dy;
                if (newHeight != size.height) {
                  dy = position.dy + details.delta.dy;
                  if (newHeight == minSize) {
                    dy = position.dy + (size.height - minSize);
                  }
                }
                if (newWidth != size.width || newHeight != size.height) {
                  _update(Offset(position.dx, dy), Size(newWidth, newHeight));
                }
              },
            ),
            _buildHandle(
              left: -handleSize / 2,
              top: size.height - handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width - details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                double newHeight = (size.height + details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                double dx = position.dx;
                if (newWidth != size.width) {
                  dx = position.dx + details.delta.dx;
                  if (newWidth == minSize) {
                    dx = position.dx + (size.width - minSize);
                  }
                }
                if (newWidth != size.width || newHeight != size.height) {
                  _update(Offset(dx, position.dy), Size(newWidth, newHeight));
                }
              },
            ),
            _buildHandle(
              left: size.width - handleSize / 2,
              top: size.height - handleSize / 2,
              onPanUpdate: (details) {
                double newWidth = (size.width + details.delta.dx).clamp(
                  minSize,
                  maxSize,
                );
                double newHeight = (size.height + details.delta.dy).clamp(
                  minSize,
                  maxSize,
                );
                if (newWidth != size.width || newHeight != size.height) {
                  _update(position, Size(newWidth, newHeight));
                }
              },
            ),

            if (widget.shape.type != ShapeType.text &&
                widget.shape.type != ShapeType.empty &&
                widget.shape.type != ShapeType.drawing)
              Container(
                alignment: Alignment.topRight,
                margin: EdgeInsets.only(left: size.width, top: handleSize / 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Icon(
                    Icons.delete_outline_outlined,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle({
    required double left,
    required double top,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    return Visibility(
      visible:
          widget.shape.type != ShapeType.text &&
          widget.shape.type != ShapeType.empty,
      child: Positioned(
        left: left - (36 - handleSize) / 2,
        top: top - (36 - handleSize) / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: onPanUpdate,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final ShapeType type;
  final Color color;

  _ShapePainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    switch (type) {
      case ShapeType.circle:
        canvas.drawOval(Offset.zero & size, paint);
        break;
      case ShapeType.rectangle:
        canvas.drawRect(Offset.zero & size, paint);
        break;
      case ShapeType.line:
        canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
        break;
      case ShapeType.text || ShapeType.empty || ShapeType.drawing:
        break;
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) => oldDelegate.type != type;
}
