import 'package:flutter/material.dart';

/// Draws a dashed line from [a] to [b] — shared by every schematic/top-view
/// painter so the dash pattern reads consistently across diagrams.
void drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
    {double dashWidth = 5.0, double dashSpace = 4.0}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final direction = (b - a) / total;
  double drawn = 0;
  while (drawn < total) {
    final start = a + direction * drawn;
    final end = a + direction * (drawn + dashWidth).clamp(0, total);
    canvas.drawLine(start, end, paint);
    drawn += dashWidth + dashSpace;
  }
}
