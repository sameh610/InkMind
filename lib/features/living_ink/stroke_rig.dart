import 'dart:math' as math;
import 'dart:ui';
import '../../core/models/ink.dart';

/// Makes old single-transform pendulum sketches coherent on existing pages.
/// It runs only when a tall rod, a nearby round bob and a wide guide mark are
/// all present; unrelated old animations keep their original behavior.
Map<String, dynamic>? inferLegacyPendulumRig(InkPage page, Set<String> ids) {
  final strokes = page.strokes.where((s) => ids.contains(s.id)).toList();
  if (strokes.length < 3) return null;
  final rods = strokes.where((s) {
    final b = s.bounds;
    return b.height > 55 && b.height > b.width * 1.25;
  }).toList()..sort((a, b) => b.bounds.height.compareTo(a.bounds.height));
  if (rods.isEmpty) return null;
  final rod = rods.first;
  final lower = rod.points.isEmpty
      ? rod.bounds.bottomCenter
      : rod.points
            .reduce((a, b) => a.position.dy > b.position.dy ? a : b)
            .position;
  final bobs =
      strokes.where((s) {
        if (s.id == rod.id) return false;
        final b = s.bounds;
        return b.width > 10 &&
            b.height > 10 &&
            b.width / b.height > .45 &&
            b.width / b.height < 2 &&
            (b.center - lower).distance < 85;
      }).toList()..sort(
        (a, b) => (a.bounds.center - lower).distance.compareTo(
          (b.bounds.center - lower).distance,
        ),
      );
  if (bobs.isEmpty) return null;
  final bob = bobs.first;
  final guides = strokes.where((s) {
    if (s.id == rod.id || s.id == bob.id) return false;
    final b = s.bounds;
    return b.width > 45 && b.width > b.height * 2;
  }).toList();
  if (guides.isEmpty) return null;
  final upper = rod.points.isEmpty
      ? rod.bounds.topCenter
      : rod.points
            .reduce((a, b) => a.position.dy < b.position.dy ? a : b)
            .position;
  return {
    'kind': 'pendulum',
    'speed': 2.0,
    'amount': .28,
    'pivotX': upper.dx,
    'pivotY': upper.dy,
    'parts': [
      for (final s in strokes)
        {
          'id': s.id,
          'role': s.id == rod.id
              ? 'rod'
              : s.id == bob.id
              ? 'bob'
              : 'static',
        },
    ],
  };
}

/// Creates a display-only version of an original vector stroke. The saved
/// stroke, pressure samples, timestamps, color and identity are never changed.
InkStroke riggedStroke(
  InkStroke source,
  Map<String, dynamic> rig,
  String role,
  double seconds, {
  int order = 0,
  int movingCount = 1,
}) {
  if (seconds == 0 || role == 'static' || role == 'anchor') return source;
  final kind = rig['kind']?.toString() ?? 'reveal';
  final speed = ((rig['speed'] as num?)?.toDouble() ?? 2).clamp(.2, 12.0);
  final amount = ((rig['amount'] as num?)?.toDouble() ?? .3).clamp(0, 100.0);
  final pivot = Offset(
    (rig['pivotX'] as num?)?.toDouble() ?? source.bounds.center.dx,
    (rig['pivotY'] as num?)?.toDouble() ?? source.bounds.center.dy,
  );
  final phase = math.sin(seconds * speed);
  Offset rotate(Offset point, double radians) {
    final delta = point - pivot;
    final c = math.cos(radians), s = math.sin(radians);
    return pivot +
        Offset(delta.dx * c - delta.dy * s, delta.dx * s + delta.dy * c);
  }

  if (kind == 'reveal') {
    final count = math.max(1, movingCount);
    final progress = (seconds * speed) % (count + .6);
    return _partialStroke(source, (progress - order).clamp(0.0, 1.0));
  }
  if (kind == 'patrol') {
    // A patrol is a true ping-pong path: the whole selected drawing travels
    // to the far side, reverses at the edge, and returns to its start. This
    // keeps a bee (or any other subject) coherent instead of drawing a new
    // overlay or swinging around an arbitrary pivot.
    final cycle = (seconds * speed) % 2.0;
    final progress = cycle <= 1 ? cycle : 2 - cycle;
    final travel = ((rig['amount'] as num?)?.toDouble() ?? 240).clamp(40, 900);
    final gravity = ((rig['gravity'] as num?)?.toDouble() ?? 9.8).clamp(0, 20);
    final verticalSag = (gravity - 9.8) * 0.8 * math.sin(progress * math.pi);
    final offset = Offset(progress * travel, verticalSag);
    return _mapStroke(
      source,
      (point, _) => InkPoint(
        point.position + offset,
        point.pressure,
        point.time,
      ),
    );
  }
  final center = source.bounds.center;
  final angle = phase * amount;
  return _mapStroke(source, (point, index) {
    final position = point.position;
    Offset next;
    switch (kind) {
      case 'pendulum':
        // Every connected pendulum part uses the same rigid transform. Moving
        // the bob by only its center arc lets its attachment point separate
        // from the rod, especially for large hand-drawn bobs.
        next = rotate(position, angle);
      case 'rotate':
        next = rotate(position, angle);
      case 'float':
        next = position + Offset(0, phase * amount);
      case 'slide':
        next = position + Offset(phase * amount, 0);
      case 'bounce':
        next = position + Offset(0, -phase.abs() * amount);
      case 'pulse':
        final scale = 1 + phase * amount;
        next = center + (position - center) * scale;
      case 'wave':
        final along = source.points.length < 2
            ? 0.0
            : index / (source.points.length - 1);
        final bend = phase * amount * math.sin(along * math.pi);
        final vertical = source.bounds.height > source.bounds.width;
        next = position + (vertical ? Offset(bend, 0) : Offset(0, bend));
      default:
        next = position;
    }
    return InkPoint(next, point.pressure, point.time);
  });
}

InkStroke _mapStroke(InkStroke source, InkPoint Function(InkPoint, int) map) =>
    InkStroke(
      id: source.id,
      tool: source.tool,
      color: source.color,
      width: source.width,
      created: source.created,
      points: [
        for (var i = 0; i < source.points.length; i++) map(source.points[i], i),
      ],
    );

InkStroke _partialStroke(InkStroke source, double fraction) {
  if (fraction >= 1) return source;
  if (fraction <= 0 || source.points.isEmpty) {
    return InkStroke(
      id: source.id,
      tool: source.tool,
      color: source.color,
      width: source.width,
      created: source.created,
      points: [],
    );
  }
  if (source.points.length == 1) return source;
  final lengths = <double>[0];
  for (var i = 1; i < source.points.length; i++) {
    lengths.add(
      lengths.last +
          (source.points[i].position - source.points[i - 1].position).distance,
    );
  }
  final total = lengths.last;
  if (total <= .001) return source;
  final target = total * fraction;
  final points = <InkPoint>[source.points.first];
  for (var i = 1; i < source.points.length; i++) {
    if (lengths[i] <= target) {
      points.add(source.points[i]);
      continue;
    }
    final previous = source.points[i - 1], next = source.points[i];
    final t = ((target - lengths[i - 1]) / (lengths[i] - lengths[i - 1])).clamp(
      0.0,
      1.0,
    );
    points.add(
      InkPoint(
        Offset.lerp(previous.position, next.position, t)!,
        previous.pressure + (next.pressure - previous.pressure) * t,
        (previous.time + (next.time - previous.time) * t).round(),
      ),
    );
    break;
  }
  return InkStroke(
    id: source.id,
    tool: source.tool,
    color: source.color,
    width: source.width,
    created: source.created,
    points: points,
  );
}
