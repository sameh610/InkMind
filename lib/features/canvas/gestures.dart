import 'dart:math' as math;
import 'dart:ui';
import '../../core/models/ink.dart';

enum InkGesture { circle, box, arrow, check, crossOut, question, none }

InkGesture recognizeGesture(List<InkPoint> points) {
  if (points.length < 3) return InkGesture.none;
  final s = InkStroke(id: 'gesture', points: points), b = s.bounds;
  if (b.longestSide < 12) return InkGesture.none;
  final p = points.map((p) => p.position).toList();
  final closed = (p.first - p.last).distance < b.longestSide * .27;
  if (closed && b.width > 18 && b.height > 18) {
    final edgeFraction =
        p
            .where(
              (p) =>
                  math.min(
                    math.min((p.dx - b.left).abs(), (p.dx - b.right).abs()),
                    math.min((p.dy - b.top).abs(), (p.dy - b.bottom).abs()),
                  ) <
                  b.shortestSide * .05,
            )
            .length /
        p.length;
    return edgeFraction > .75 ? InkGesture.box : InkGesture.circle;
  }
  final low = p.reduce((a, b) => a.dy > b.dy ? a : b);
  if (low != p.first &&
      low != p.last &&
      p.last.dx > low.dx &&
      p.last.dy < low.dy - b.height * .6 &&
      p.first.dx < low.dx &&
      p.first.dy < low.dy - b.height * .2) {
    return InkGesture.check;
  }
  var changes = 0;
  double? previous;
  for (var i = 1; i < p.length; i++) {
    final dx = p[i].dx - p[i - 1].dx;
    if (dx.abs() > 2) {
      if (previous != null && previous * dx < 0) changes++;
      previous = dx;
    }
  }
  if (changes >= 3 && b.width > b.height * 1.5) return InkGesture.crossOut;
  if (changes >= 1 && b.width > b.height * 1.5) return InkGesture.arrow;
  if (b.height > b.width * 1.25 &&
      p.first.dy < b.center.dy &&
      p.last.dy > b.center.dy &&
      changes >= 1) {
    return InkGesture.question;
  }
  return InkGesture.none;
}

List<Offset> normalizeShape(List<InkPoint> input) {
  if (input.length < 2) return [];
  final positions = input.map((p) => p.position).toList();
  final cumulative = <double>[0];
  for (var i = 1; i < positions.length; i++) {
    cumulative.add(
      cumulative.last + (positions[i] - positions[i - 1]).distance,
    );
  }
  if (cumulative.last == 0) return [];
  final sampled = <Offset>[];
  var cursor = 1;
  for (var i = 0; i < 32; i++) {
    final d = cumulative.last * i / 31;
    while (cursor < cumulative.length - 1 && cumulative[cursor] < d) {
      cursor++;
    }
    final length = cumulative[cursor] - cumulative[cursor - 1];
    sampled.add(
      Offset.lerp(
        positions[cursor - 1],
        positions[cursor],
        length == 0 ? 0 : (d - cumulative[cursor - 1]) / length,
      )!,
    );
  }
  final b = InkStroke(
    id: 'shape',
    points: sampled.map((p) => InkPoint(p)).toList(),
  ).bounds;
  return sampled.map((p) => (p - b.center) / b.longestSide).toList();
}

double shapeSimilarity(List<Offset> a, List<Offset> b) {
  if (a.length != 32 || b.length != 32) return 0;
  var distance = 0.0;
  for (var i = 0; i < 32; i++) {
    distance += (a[i] - b[i]).distance;
  }
  return (1 - distance / 32).clamp(0, 1);
}
