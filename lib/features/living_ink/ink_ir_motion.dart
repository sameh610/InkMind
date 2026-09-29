import '../../core/models/ink.dart';
import '../ai/ink_ir.dart';
import 'dart:ui';

/// Resolve compiled selectors against real, selected vector stroke IDs.
Map<String, List<String>> bindInkAnimation(
  Map<String, dynamic> ir,
  InkPage page,
  Set<String> selectedIds,
) {
  if (ir['mode'] != 'animateInk')
    throw const FormatException('Expected Animate Ink InkIR.');
  final available = page.strokes
      .where((s) => selectedIds.contains(s.id))
      .map((s) => s.id)
      .toList();
  if (available.isEmpty)
    throw const FormatException('No selected ink to animate.');
  if (ir['rig'] is Map) {
    final rig = Map<String, dynamic>.from(ir['rig'] as Map);
    const kinds = {
      'pendulum',
      'patrol',
      'reveal',
      'wave',
      'float',
      'slide',
      'bounce',
      'pulse',
      'rotate',
    };
    const roles = {'rod', 'bob', 'ink', 'static', 'anchor'};
    final parts = (rig['parts'] as List? ?? []).whereType<Map>().toList();
    final ids = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      final id = part['id']?.toString() ?? '';
      final role = part['role']?.toString() ?? '';
      if (!available.contains(id) || !seen.add(id) || !roles.contains(role)) {
        throw const FormatException(
          'Ink rig references an invalid selected stroke.',
        );
      }
      if (role != 'static' && role != 'anchor') ids.add(id);
    }
    final speed = rig['speed'], amount = rig['amount'];
    final controls = rig['controls'];
    final controlsValid =
        controls == null ||
        (controls is List &&
            controls.length <= 8 &&
            controls.every((raw) {
              if (raw is! Map) return false;
              final name = raw['name'];
              final min = raw['min'], max = raw['max'], value = raw['value'];
              return name is String &&
                  name.isNotEmpty &&
                  name.length < 32 &&
                  min is num &&
                  max is num &&
                  value is num &&
                  min.isFinite &&
                  max.isFinite &&
                  value.isFinite &&
                  min < max &&
                  value >= min &&
                  value <= max &&
                  (raw['unit'] == null || raw['unit'] is String);
            }));
    if (!kinds.contains(rig['kind']) ||
        ids.isEmpty ||
        parts.length > 256 ||
        speed is! num ||
        !speed.isFinite ||
        speed <= 0 ||
        speed > 12 ||
        amount is! num ||
        !amount.isFinite ||
        amount.abs() > 1000 ||
        !controlsValid ||
        rig['pivotX'] is! num ||
        !(rig['pivotX'] as num).isFinite ||
        rig['pivotY'] is! num ||
        !(rig['pivotY'] as num).isFinite) {
      throw const FormatException('Ink rig is incomplete or unsafe.');
    }
    return {'rig': ids};
  }
  final resolved = <String, List<String>>{};
  final drawings = (ir['drawings'] as List? ?? []).whereType<Map>().toList();
  final seenDrawings = <String>{};
  for (final drawing in drawings) {
    final id = drawing['id']?.toString() ?? '';
    final points = drawing['points'];
    if (!available.contains(id) ||
        !seenDrawings.add(id) ||
        points is! List ||
        points.length > 512) {
      throw const FormatException(
        'InkScript draw references an invalid selected stroke.',
      );
    }
  }
  final states = (ir['state'] as List? ?? []).whereType<Map>().toList();
  final stateNames = <String>{};
  for (final state in states) {
    final name = state['name']?.toString() ?? '';
    final value = state['value'];
    if (name.isEmpty ||
        name.length > 48 ||
        !stateNames.add(name) ||
        value is! num ||
        !value.isFinite) {
      throw const FormatException('InkScript animation state is invalid.');
    }
  }
  for (final raw in (ir['bindings'] as List? ?? []).whereType<Map>()) {
    for (final key in ['pivotX', 'pivotY']) {
      final value = raw[key];
      if (value != null &&
          (value is! num || !value.isFinite || value.abs() > 100000)) {
        throw const FormatException(
          'Ink pivot must be a finite page coordinate.',
        );
      }
    }
    final name = raw['name']?.toString() ?? '';
    final selector = raw['selector']?.toString();
    final arg = raw['arg']?.toString().toLowerCase();
    List<String> ids;
    switch (selector) {
      case 'selection':
      case 'page':
        ids = available;
      case 'stroke':
        ids = available.where((id) => id == raw['arg']).toList();
      case 'find':
        ids = available
            .where(
              (id) => (page.labels[id] ?? '').toLowerCase().contains(arg ?? ''),
            )
            .toList();
      case 'group':
        final parent = resolved[raw['parent']?.toString()] ?? [];
        ids = parent
            .where(
              (id) => (page.labels[id] ?? '').toLowerCase().contains(arg ?? ''),
            )
            .toList();
      default:
        throw FormatException('Unknown ink selector $selector.');
    }
    if (name.isEmpty || ids.isEmpty) {
      throw FormatException(
        'Ink binding "$name" matched no selected strokes. Label those strokes or use ink.selection().',
      );
    }
    resolved[name] = ids;
  }
  if (resolved.isEmpty) throw const FormatException('No ink bindings found.');
  for (final raw in (ir['animations'] as List? ?? []).whereType<Map>()) {
    if (!resolved.containsKey(raw['target']))
      throw const FormatException('Animation has an unknown target.');
  }
  final values = <String, dynamic>{'time': 0.0};
  for (final state in states) {
    values[state['name'].toString()] = state['value'];
  }
  for (final entry in resolved.entries) {
    Rect? bounds;
    for (final stroke in page.strokes.where(
      (s) => entry.value.contains(s.id),
    )) {
      bounds = bounds == null
          ? stroke.bounds
          : bounds.expandToInclude(stroke.bounds);
    }
    final center = bounds?.center ?? Offset.zero;
    values[entry.key] = {
      'baseX': center.dx,
      'baseY': center.dy,
      'x': center.dx,
      'y': center.dy,
      'rotation': 0.0,
      'bend': 0.0,
      'scaleX': 1.0,
      'scaleY': 1.0,
      'opacity': 1.0,
      'visible': true,
    };
  }
  final evaluator = InkIrEvaluator(values);
  for (final raw in (ir['animations'] as List? ?? []).whereType<Map>()) {
    final target = values[raw['target']] as Map;
    final property = raw['property']?.toString();
    final expected = target[property];
    final actual = evaluator.eval(raw['value']);
    final matches = expected is num && actual is num
        ? (expected - actual).abs() < .001
        : expected == actual;
    if (!matches)
      throw FormatException(
        'Animation changes original ink at time 0: $property.',
      );
  }
  return resolved;
}
