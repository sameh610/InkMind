import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import 'stroke_history.dart';

class HistoryCanvas extends StatelessWidget {
  final List<InkStroke> strokes;
  final int? firstError;
  final double progress;
  final Color color, accent;
  final List<String> corrected;
  const HistoryCanvas({
    super.key,
    required this.strokes,
    required this.firstError,
    required this.progress,
    required this.color,
    required this.accent,
    this.corrected = const [],
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Original pen history, ${strokes.length} strokes, ${progress < .42 ? 'rewinding' : 'stopped at step ${(firstError ?? 0) + 1}'}',
    child: CustomPaint(
      painter: _HistoryPainter(
        strokes,
        firstError,
        progress,
        color,
        accent,
        corrected,
      ),
      size: Size.infinite,
    ),
  );
}

class _HistoryPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final int? error;
  final double progress;
  final Color color, accent;
  final List<String> corrected;
  _HistoryPainter(
    this.strokes,
    this.error,
    this.progress,
    this.color,
    this.accent,
    this.corrected,
  );
  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final bounds = strokes
        .map((s) => s.bounds)
        .reduce((a, b) => a.expandToInclude(b));
    final rows = historyRows(strokes);
    final rowIndex = (error ?? rows.length - 1).clamp(0, rows.length - 1);
    final stopIds = rows
        .take(rowIndex + 1)
        .expand((r) => r)
        .map((s) => s.id)
        .toSet();
    double endOf(InkStroke s) =>
        s.created + (s.points.isEmpty ? 0 : s.points.last.time).toDouble();
    final end = strokes.map(endOf).reduce(math.max);
    final stop = strokes
        .where((s) => stopIds.contains(s.id))
        .map(endOf)
        .reduce(math.max);
    final rewind = (progress / .42).clamp(0.0, 1.0);
    final clock = end + (stop - end) * rewind;
    final scale = math.min(
      (size.width * (corrected.isEmpty ? 1 : .56) - 12) /
          math.max(1, bounds.width),
      (size.height - 12) / math.max(1, bounds.height),
    );
    canvas.save();
    canvas.translate(6, 6);
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);
    for (final original in strokes) {
      if (rewind >= 1 && !stopIds.contains(original.id)) continue;
      final s = strokeAtTime(original, clock);
      if (s.points.isEmpty) continue;
      final pen = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var i = 1; i < s.points.length; i++) {
        pen.strokeWidth = s.width * (.65 + s.points[i].pressure * .65);
        canvas.drawLine(s.points[i - 1].position, s.points[i].position, pen);
      }
    }
    if (error != null && progress >= .42) {
      final row = rows[rowIndex];
      final r = row.map((s) => s.bounds).reduce((a, b) => a.expandToInclude(b));
      // Emphasize the right-hand value, retaining its real pen samples.
      final value = Rect.fromLTRB(
        r.left + r.width * .60,
        r.top - 5,
        r.right + 5,
        r.bottom + 5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(value, const Radius.circular(5)),
        Paint()..color = accent.withValues(alpha: .12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(value, const Radius.circular(5)),
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }
    canvas.restore();
    if (error != null && corrected.isNotEmpty && progress > .56) {
      final row = rows[rowIndex];
      final r = row.map((s) => s.bounds).reduce((a, b) => a.expandToInclude(b));
      final start = Offset(
        6 + (r.right - bounds.left) * scale,
        6 + (r.center.dy - bounds.top) * scale,
      );
      final target = Offset(size.width * .62, start.dy + 34);
      final branch = Path()
        ..moveTo(start.dx + 8, start.dy)
        ..cubicTo(
          start.dx + 36,
          start.dy,
          target.dx - 24,
          target.dy,
          target.dx - 8,
          target.dy,
        );
      final metric = branch.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(
          0,
          metric.length * ((progress - .56) / .15).clamp(0.0, 1.0),
        ),
        Paint()
          ..color = accent
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < corrected.length; i++) {
        final reveal = ((progress - .68 - i * .11) / .12).clamp(0.0, 1.0);
        final text = TextPainter(
          text: TextSpan(
            text: corrected[i],
            style: TextStyle(fontFamily: 'Caveat', fontSize: 26, color: accent),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width * .38);
        final point = target + Offset(0, i * 46.0 - 17);
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(point.dx, point.dy, text.width * reveal, text.height),
        );
        text.paint(canvas, point);
        canvas.restore();
        if (i > 0 && reveal > 0) {
          final x = target.dx + 18;
          final y = point.dy - 5;
          canvas.drawLine(
            Offset(x, y - 9),
            Offset(x, y),
            Paint()
              ..color = accent
              ..strokeWidth = 1.2,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x - 3, y - 3)
              ..lineTo(x, y)
              ..lineTo(x + 3, y - 3),
            Paint()
              ..color = accent
              ..strokeWidth = 1.2
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter old) =>
      old.progress != progress || old.strokes != strokes || old.color != color;
}
