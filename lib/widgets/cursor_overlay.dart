import 'package:flutter/material.dart';

/// A virtual mouse pointer, drawn where the D-pad moves it.
class CursorOverlay extends StatelessWidget {
  const CursorOverlay({super.key, required this.position});

  final Offset position;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CursorPainter(position),
        size: Size.infinite,
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.position);

  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final center = position;

    // Soft halo so the pointer stands out over bright content.
    final halo = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, halo);

    final fill = Paint()
      ..color = const Color(0xFFFFD740)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, fill);

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 12, ring);
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) =>
      oldDelegate.position != position;
}
