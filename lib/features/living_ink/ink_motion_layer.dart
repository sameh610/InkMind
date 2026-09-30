import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../canvas/painters.dart';
import '../ai/ink_ir.dart';
import '../inkmatter/matter.dart';
import 'stroke_rig.dart';
import 'motion_editor.dart';

List<Map<String, dynamic>> motionControlEntries(Map<String, dynamic> ir) {
  final rig = ir['rig'];
  final rigControls = rig is Map ? rig['controls'] : null;
  final raw = rigControls is List ? rigControls : ir['state'];
  return (raw as List? ?? [])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}

bool motionIrHasControl(Map<String, dynamic> ir, String name) =>
    motionControlEntries(ir).any(
      (entry) => entry['name']?.toString().toLowerCase() == name.toLowerCase(),
    );

Map<String, dynamic> updateMotionIrControl(
  Map<String, dynamic> ir,
  String name,
  num value,
) {
  final updated = Map<String, dynamic>.from(ir);
  final states = updated['state'];
  if (states is List) {
    updated['state'] = states.map((entry) {
      if (entry is! Map ||
          entry['name']?.toString().toLowerCase() != name.toLowerCase()) {
        return entry;
      }
      return {...Map<String, dynamic>.from(entry), 'value': value};
    }).toList();
  }
  final rawRig = updated['rig'];
  if (rawRig is Map) {
    final rig = Map<String, dynamic>.from(rawRig);
    final controls = rig['controls'];
    if (controls is List) {
      rig['controls'] = controls.map((entry) {
        if (entry is! Map ||
            entry['name']?.toString().toLowerCase() != name.toLowerCase()) {
          return entry;
        }
        return {...Map<String, dynamic>.from(entry), 'value': value};
      }).toList();
    }
    updated['rig'] = rig;
  }
  return updated;
}

Set<String> movingStrokeIds(InkPage page) => page.objects
    .where((o) => o.kind == 'inkMotion')
    .expand(movingIdsForMotion)
    .toSet();

/// IDs covered by a motion overlay, including static context strokes. Static
/// context is intentionally omitted from the base canvas while an animation
/// owns it; otherwise direction arrows and guide marks remain stranded beside
/// the moving ink.
Set<String> motionStrokeIds(InkPage page) => page.objects
    .where((o) => o.kind == 'inkMotion')
    .expand(allIdsForMotion)
    .toSet();

Iterable<String> allIdsForMotion(PageObject motion) sync* {
  final ir = motion.data['ir'];
  final rig = ir is Map ? ir['rig'] : null;
  if (rig is Map && rig['parts'] is List) {
    for (final part in (rig['parts'] as List).whereType<Map>()) {
      final id = part['id']?.toString();
      if (id != null && id.isNotEmpty) yield id;
    }
    return;
  }
  yield* movingIdsForMotion(motion);
}

Iterable<String> movingIdsForMotion(PageObject motion) sync* {
  final bindings = motion.data['bindings'];
  if (bindings is Map) {
    for (final ids in bindings.values) {
      if (ids is List) yield* ids.whereType<String>();
    }
  } else {
    for (final track
        in (motion.data['tracks'] as List? ?? []).whereType<Map>()) {
      yield* (track['ids'] as List? ?? []).whereType<String>();
    }
  }
}

/// Motion is an extra page object. Original stroke bytes, IDs, colors, pressure,
/// positions and thickness remain untouched and are restored by undo.
class InkMotionLayer extends StatefulWidget {
  final InkPage page;
  final bool dark;
  final VoidCallback? beforeEdit;
  final VoidCallback? onEdited;
  const InkMotionLayer({
    super.key,
    required this.page,
    this.dark = false,
    this.beforeEdit,
    this.onEdited,
  });
  @override
  State<InkMotionLayer> createState() => _InkMotionLayerState();
}

class _InkMotionLayerState extends State<InkMotionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  bool playing = false;
  double seconds = 0;
  int previous = 0;
  final Map<String, double> controlValues = {};
  final GlobalKey _dropTargetKey = GlobalKey();
  Timer? _matterToastTimer;
  String? _matterToast;
  @override
  void initState() {
    super.initState();
    _syncControlValues();
    clock = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    );
    clock.addListener(() {
      final ms = clock.lastElapsedDuration?.inMilliseconds ?? 0;
      seconds += ((ms - previous) / 1000).clamp(0, .05);
      previous = ms;
    });
  }

  @override
  void didUpdateWidget(covariant InkMotionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControlValues();
  }

  List<Map<String, dynamic>> get motionControls {
    final result = <Map<String, dynamic>>[];
    for (final motion in widget.page.objects.where(
      (o) => o.kind == 'inkMotion',
    )) {
      final ir = motion.data['ir'];
      final rig = ir is Map ? ir['rig'] : null;
      if (rig is Map && rig['controls'] is List) {
        for (final raw in (rig['controls'] as List).whereType<Map>()) {
          final name = raw['name']?.toString() ?? '';
          if (name.isEmpty || result.any((c) => c['name'] == name)) continue;
          result.add(Map<String, dynamic>.from(raw));
        }
      } else if (ir is Map && ir['state'] is List) {
        for (final raw in (ir['state'] as List).whereType<Map>()) {
          final name = raw['name']?.toString() ?? '';
          final value = (raw['value'] as num?)?.toDouble();
          if (name.isEmpty ||
              value == null ||
              result.any((c) => c['name'] == name)) {
            continue;
          }
          final key = name.toLowerCase();
          final min = key == 'gravity'
              ? 0.0
              : key == 'speed'
              ? .2
              : key.contains('distance') || key.contains('amount')
              ? 0.0
              : math.min(0.0, value * 2);
          final max = key == 'gravity'
              ? 20.0
              : key == 'speed'
              ? 12.0
              : key.contains('distance') || key.contains('amount')
              ? 900.0
              : math.max(1.0, value.abs() * 3);
          final unit = key == 'gravity'
              ? 'm/s²'
              : key == 'speed'
              ? 'x'
              : '';
          result.add({
            'name': name,
            'min': min,
            'max': max,
            'value': value,
            'unit': unit,
          });
        }
      }
    }
    return result;
  }

  String? get motionSource {
    for (final motion in widget.page.objects.where(
      (o) => o.kind == 'inkMotion',
    )) {
      final source = motion.data['source']?.toString();
      if (source != null && source.trim().isNotEmpty) return source;
    }
    return null;
  }

  void _syncControlValues() {
    for (final control in motionControls) {
      final name = control['name']?.toString() ?? '';
      final initial = (control['value'] as num?)?.toDouble();
      if (name.isNotEmpty &&
          initial != null &&
          !controlValues.containsKey(name)) {
        controlValues[name] = initial;
      }
    }
  }

  @override
  void dispose() {
    _matterToastTimer?.cancel();
    clock.dispose();
    super.dispose();
  }

  PageObject? _gravityTargetAt(String text, Offset globalPosition) {
    if (parseModifier(text, 'pendulum', const {'gravity': 9.81}) == null) {
      return null;
    }
    final compatibleMotions = widget.page.objects
        .where(
          (motion) => motion.kind == 'inkMotion' && _isGravityPendulum(motion),
        )
        .toList();
    if (compatibleMotions.isEmpty) return null;
    // A page-level drop target can be transformed or temporarily lack a
    // render box during a drag. With one compatible pendulum on the page, the
    // drop itself identifies the target; do not silently discard the modifier
    // because a screen point failed to map back to ink coordinates.
    if (compatibleMotions.length == 1) return compatibleMotions.single;
    final renderBox =
        _dropTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return compatibleMotions.first;
    final position = renderBox.globalToLocal(globalPosition);
    final candidates = <({PageObject motion, double distance})>[];
    for (final motion in compatibleMotions) {
      final ids = allIdsForMotion(motion).toSet();
      final strokes = widget.page.strokes.where(
        (stroke) => ids.contains(stroke.id),
      );
      if (strokes.isEmpty) continue;
      final bounds = strokes
          .map((stroke) => stroke.bounds)
          .reduce((a, b) => a.expandToInclude(b))
          .inflate(56);
      candidates.add((
        motion: motion,
        distance: (bounds.center - position).distance,
      ));
    }
    if (candidates.isEmpty) return compatibleMotions.first;
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates.first.motion;
  }

  bool _isGravityPendulum(PageObject motion) {
    final rawIr = motion.data['ir'];
    if (rawIr is! Map) return false;
    final ir = Map<String, dynamic>.from(rawIr);
    if (!motionIrHasControl(ir, 'gravity')) return false;
    final rig = ir['rig'];
    if (rig is Map && rig['kind']?.toString().toLowerCase() == 'pendulum') {
      return true;
    }
    final source = motion.data['source']?.toString().toLowerCase() ?? '';
    return source.contains('rotation =') || source.contains('rotation=');
  }

  bool _hasGravityPendulum(String text) =>
      parseModifier(text, 'pendulum', const {'gravity': 9.81}) != null &&
      widget.page.objects
          .where((object) => object.kind == 'inkMotion')
          .any(_isGravityPendulum);

  void _applyMatter(String text, Offset globalPosition) {
    final target = _gravityTargetAt(text, globalPosition);
    if (target == null) return;
    final ir = Map<String, dynamic>.from(target.data['ir'] as Map);
    final command = parseModifier(text, 'pendulum', const {'gravity': 9.81})!;
    widget.beforeEdit?.call();
    target.data['ir'] = updateMotionIrControl(
      ir,
      command.property,
      command.value as num,
    );
    target.data['gravity'] = command.value;
    controlValues[command.property] = (command.value as num).toDouble();
    widget.onEdited?.call();
    setState(
      () => _matterToast =
          '$text · gravity ${(command.value as num).toStringAsFixed(2)} ${command.unit}',
    );
    _matterToastTimer?.cancel();
    _matterToastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _matterToast = null);
    });
  }

  Offset get controlsOffset {
    final ids = movingStrokeIds(widget.page);
    final strokes = widget.page.strokes.where((s) => ids.contains(s.id));
    if (strokes.isEmpty) return const Offset(500, 76);
    final bounds = strokes
        .map((s) => s.bounds)
        .reduce((a, b) => a.expandToInclude(b));
    return Offset(
      (bounds.center.dx - 74).clamp(20.0, 530.0),
      (bounds.bottom + 20).clamp(76.0, 830.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controls = motionControls;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(390.0, math.max(260.0, viewportWidth - 24));
    final cardLeft = controlsOffset.dx
        .clamp(12.0, math.max(12.0, viewportWidth - cardWidth - 12))
        .toDouble();
    final surface = widget.dark
        ? const Color(0xff1d1f21)
        : Theme.of(context).colorScheme.surface;
    final ink = widget.dark
        ? const Color(0xffe5e0d8)
        : Theme.of(context).colorScheme.onSurface;
    final accent = widget.dark
        ? const Color(0xffd77b58)
        : Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _hasGravityPendulum(details.data),
      onAcceptWithDetails: (details) =>
          _applyMatter(details.data, details.offset),
      builder: (context, candidates, rejected) => Stack(
        key: _dropTargetKey,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: clock,
                builder: (context, _) => CustomPaint(
                  painter: _InkMotionPainter(
                    widget.page,
                    seconds,
                    widget.dark,
                    controlValues,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: controlsOffset.dy,
            left: cardLeft,
            child: Material(
              color: surface.withValues(alpha: .96),
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 3, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 0,
                        runSpacing: 2,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: ink),
                            onPressed: () {
                              setState(() {
                                playing = !playing;
                                if (playing) {
                                  previous = 0;
                                  clock.repeat();
                                } else {
                                  clock.stop();
                                }
                              });
                            },
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              size: 16,
                            ),
                            label: Text(
                              playing ? 'Pause motion' : 'Play motion',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reset motion',
                            color: ink,
                            onPressed: () {
                              clock.stop();
                              setState(() {
                                playing = false;
                                seconds = 0;
                                previous = 0;
                              });
                            },
                            icon: const Icon(Icons.replay, size: 16),
                          ),
                          if (motionSource != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                              ),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => MotionEditor(
                                  page: widget.page,
                                  motion: widget.page.objects.firstWhere(
                                    (o) =>
                                        o.kind == 'inkMotion' &&
                                        o.data['source'] != null,
                                  ),
                                  onApply: (ir, source, bindings) {
                                    final motion = widget.page.objects
                                        .firstWhere(
                                          (o) =>
                                              o.kind == 'inkMotion' &&
                                              o.data['source'] != null,
                                        );
                                    widget.beforeEdit?.call();
                                    motion.data['ir'] = ir;
                                    motion.data['source'] = source;
                                    motion.data['bindings'] = bindings;
                                    clock.stop();
                                    setState(() {
                                      seconds = 0;
                                      previous = 0;
                                      playing = false;
                                      controlValues.clear();
                                      _syncControlValues();
                                    });
                                    widget.onEdited?.call();
                                  },
                                ),
                              ),
                              icon: const Icon(Icons.code_rounded, size: 15),
                              label: const Text('Edit InkScript'),
                            ),
                        ],
                      ),
                      if (controls.isNotEmpty) ...[
                        Divider(height: 1, color: ink.withValues(alpha: .12)),
                        Padding(
                          padding: const EdgeInsets.only(top: 7, left: 7),
                          child: Text(
                            'LIVE CONTROLS',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final control in controls)
                              _controlCard(control, ink, accent),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_matterToast != null)
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Material(
                    color: surface,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        _matterToast!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (candidates.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .035),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controlCard(Map<String, dynamic> control, Color ink, Color accent) {
    final name = control['name']?.toString() ?? 'control';
    final min = (control['min'] as num?)?.toDouble() ?? 0;
    final max = (control['max'] as num?)?.toDouble() ?? 1;
    final value =
        (controlValues[name] ?? (control['value'] as num?)?.toDouble() ?? min)
            .clamp(min, max)
            .toDouble();
    final unit = control['unit']?.toString() ?? '';
    final label = name.isEmpty
        ? 'Control'
        : '${name[0].toUpperCase()}${name.substring(1)}';
    return SizedBox(
      width: 174,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(value.abs() >= 10 ? 0 : 1)}$unit',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 22,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  inactiveTrackColor: ink.withValues(alpha: .18),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: (next) =>
                      setState(() => controlValues[name] = next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkMotionPainter extends CustomPainter {
  final InkPage page;
  final double seconds;
  final bool dark;
  final Map<String, double> controlValues;
  _InkMotionPainter(this.page, this.seconds, this.dark, this.controlValues);
  Color? inkColor(InkStroke stroke) =>
      dark && stroke.color == 0xff303c38 ? const Color(0xffe1e8df) : null;
  @override
  void paint(Canvas canvas, Size size) {
    final painted = <String>{};
    for (final motion in page.objects.where((o) => o.kind == 'inkMotion')) {
      if (motion.data['ir'] is Map && motion.data['bindings'] is Map) {
        _paintInkIr(canvas, motion, painted);
        continue;
      }
      for (final track in (motion.data['tracks'] as List).cast<Map>()) {
        final ids = (track['ids'] as List).cast<String>().toSet();
        final phase = math.sin(
          seconds * 2 * math.pi / (track['period'] as num),
        );
        final pivot = Offset(
          (track['pivotX'] as num).toDouble(),
          (track['pivotY'] as num).toDouble(),
        );
        canvas.save();
        canvas.translate(
          (track['dx'] as num) * phase,
          (track['dy'] as num) * phase,
        );
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate((track['angle'] as num) * phase);
        canvas.translate(-pivot.dx, -pivot.dy);
        for (final stroke in page.strokes.where((s) => ids.contains(s.id))) {
          if (painted.add(stroke.id)) {
            paintStroke(canvas, stroke, overrideColor: inkColor(stroke));
          }
        }
        canvas.restore();
      }
    }
  }

  void _paintInkIr(Canvas canvas, PageObject motion, Set<String> painted) {
    final ir = Map<String, dynamic>.from(motion.data['ir'] as Map);
    if (ir['rig'] is Map) {
      final rig = Map<String, dynamic>.from(ir['rig'] as Map);
      for (final entry in controlValues.entries) {
        if (entry.key == 'speed' || entry.key == 'gravity') {
          rig[entry.key] = entry.value;
        }
      }
      _paintRig(canvas, rig, painted);
      return;
    }
    final bindingIds = Map<String, dynamic>.from(
      motion.data['bindings'] as Map,
    );
    final oldBindings = (ir['bindings'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final oldAnimations = (ir['animations'] as List? ?? [])
        .whereType<Map>()
        .toList();
    if (oldBindings.length == 1 &&
        oldBindings.first['selector'] == 'selection' &&
        oldAnimations.length == 1 &&
        oldAnimations.first['property'] == 'rotation') {
      final ids = (bindingIds.values.first as List? ?? [])
          .whereType<String>()
          .toSet();
      final upgraded = inferLegacyPendulumRig(page, ids);
      if (upgraded != null) {
        _paintRig(canvas, upgraded, painted, paintStatic: true);
        return;
      }
    }
    final bindings = <String, Set<String>>{};
    final values = <String, dynamic>{'time': seconds};
    for (final raw in (ir['state'] as List? ?? []).whereType<Map>()) {
      final name = raw['name']?.toString();
      final value = raw['value'];
      if (name != null && value is num && value.isFinite) {
        values[name] = controlValues[name] ?? value;
      }
    }
    for (final entry in bindingIds.entries) {
      final ids = (entry.value as List? ?? []).whereType<String>().toSet();
      bindings[entry.key] = ids;
      Rect? bounds;
      for (final stroke in page.strokes.where((s) => ids.contains(s.id))) {
        bounds = bounds == null
            ? stroke.bounds
            : bounds.expandToInclude(stroke.bounds);
      }
      final center = bounds?.center ?? Offset.zero;
      final definition = oldBindings
          .where((b) => b['name'] == entry.key)
          .firstOrNull;
      values[entry.key] = {
        'pivotX': (definition?['pivotX'] as num?)?.toDouble() ?? center.dx,
        'pivotY': (definition?['pivotY'] as num?)?.toDouble() ?? center.dy,
        'baseX': center.dx,
        'baseY': center.dy,
        'x': center.dx,
        'y': center.dy,
        'rotation': 0,
        'scaleX': 1,
        'scaleY': 1,
        'opacity': 1,
        'visible': true,
      };
    }
    final evaluator = InkIrEvaluator(values);
    final assignments = (ir['animations'] as List? ?? [])
        .whereType<Map>()
        .toList();
    for (final stroke in page.strokes) {
      if (painted.contains(stroke.id) ||
          !bindings.values.any((ids) => ids.contains(stroke.id))) {
        continue;
      }
      var dx = 0.0,
          dy = 0.0,
          bend = 0.0,
          angle = 0.0,
          sx = 1.0,
          sy = 1.0,
          opacity = 1.0,
          visible = true;
      var pivot = stroke.bounds.center;
      for (final assignment in assignments) {
        final target = assignment['target']?.toString() ?? '';
        if (bindings[target]?.contains(stroke.id) != true) continue;
        final value = evaluator.eval(assignment['value']);
        final center = values[target] as Map;
        if (assignment['property'] == 'rotation' ||
            assignment['property'] == 'bend' ||
            assignment['property'] == 'scaleX' ||
            assignment['property'] == 'scaleY') {
          pivot = Offset(
            (center['pivotX'] as num).toDouble(),
            (center['pivotY'] as num).toDouble(),
          );
        }
        if (assignment['property'] == 'visible') {
          visible = value != false;
          continue;
        }
        if (value is! num || !value.isFinite) continue;
        final v = value.toDouble();
        switch (assignment['property']) {
          case 'bend':
            bend += v.clamp(-200, 200);
          case 'x':
            dx += (v - (center['baseX'] as num)).clamp(-500, 500);
          case 'y':
            dy += (v - (center['baseY'] as num)).clamp(-500, 500);
          case 'rotation':
            angle += v.clamp(-math.pi * 4, math.pi * 4);
          case 'scaleX':
            sx *= v.clamp(-5, 5);
          case 'scaleY':
            sy *= v.clamp(-5, 5);
          case 'opacity':
            opacity *= v.clamp(0, 1);
        }
      }
      painted.add(stroke.id);
      if (!visible || opacity <= 0) continue;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(angle);
      canvas.scale(sx, sy);
      canvas.translate(-pivot.dx, -pivot.dy);
      if (opacity < 1) {
        canvas.saveLayer(
          stroke.bounds.inflate(12),
          Paint()..color = Colors.white.withValues(alpha: opacity),
        );
      }
      final displayed = bend == 0 ? stroke : InkStroke(
        id: stroke.id, tool: stroke.tool, color: stroke.color, width: stroke.width, created: stroke.created,
        points: stroke.points.map((p) => InkPoint(
          p.position + Offset(bend * math.pow(math.max(0, pivot.dy - p.position.dy) / 200, 2), 0), p.pressure, p.time,
        )).toList(),
      );
      paintStroke(canvas, displayed, overrideColor: inkColor(stroke));
      if (opacity < 1) canvas.restore();
      canvas.restore();
    }
  }

  void _paintRig(
    Canvas canvas,
    Map<String, dynamic> rig,
    Set<String> painted, {
    bool paintStatic = false,
  }) {
    final allParts = (rig['parts'] as List? ?? []).whereType<Map>().toList();
    final moving = allParts
        .whereType<Map>()
        .where((part) => part['role'] != 'static' && part['role'] != 'anchor')
        .toList();
    for (final part in allParts) {
      final id = part['id']?.toString();
      final stroke = page.strokes.where((s) => s.id == id).firstOrNull;
      if (stroke == null) continue;
      if (part['role'] == 'static' || part['role'] == 'anchor') {
        if (paintStatic && painted.add(stroke.id)) {
          paintStroke(canvas, stroke, overrideColor: inkColor(stroke));
        }
        continue;
      }
      if (!painted.add(stroke.id)) continue;
      final order = moving.indexOf(part);
      final displayed = riggedStroke(
        stroke,
        rig,
        part['role']?.toString() ?? 'ink',
        seconds,
        order: order,
        movingCount: moving.length,
      );
      paintStroke(canvas, displayed, overrideColor: inkColor(stroke));
    }
  }

  @override
  bool shouldRepaint(_InkMotionPainter old) => true;
}
