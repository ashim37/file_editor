import 'package:flutter/material.dart';

class TextSticker extends StatefulWidget {
  final String text;
  final Color color;
  final double initialFontSize;
  final Offset initialPosition;
  final void Function(Offset position, double fontSize)? onChanged;
  final VoidCallback? onDelete;

  const TextSticker({
    super.key,
    required this.text,
    required this.color,
    this.initialFontSize = 20.0,
    this.initialPosition = const Offset(100, 100),
    this.onChanged,
    this.onDelete,
  });

  @override
  State<TextSticker> createState() => _TextStickerState();
}

class _TextStickerState extends State<TextSticker> {
  Offset position = Offset.zero;
  double fontSize = 20.0;

  Offset? startFocalPoint;
  Offset? startPosition;
  double? startFontSize;

  @override
  void initState() {
    super.initState();
    position = widget.initialPosition;
    fontSize = widget.initialFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          startFocalPoint = details.focalPoint;
          startPosition = position;
          startFontSize = fontSize;
        },
        onScaleUpdate: (details) {
          setState(() {
            final delta = details.focalPoint - (startFocalPoint ?? details.focalPoint);
            position = (startPosition ?? position) + delta;
            fontSize = (startFontSize! * details.scale).clamp(10.0, 100.0);
          });
          widget.onChanged?.call(position, fontSize);
        },
        child: Material(
          color: Colors.white.withValues(alpha: 0.85),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.17),
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                top: -20,
                right: -22,
                child: IconButton(
                  onPressed: widget.onDelete,
                  icon: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                  splashRadius: 16,
                  tooltip: 'Delete text',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
