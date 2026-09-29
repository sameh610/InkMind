import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../ai/ink_ir.dart';
import 'code_view_stub.dart' if (dart.library.js_interop) 'code_view_web.dart';

/// Pure Flutter renderer for validated InkIR. It never evaluates TSX source.
class InkIrView extends StatefulWidget {
  final Map<String, dynamic> ir;
  const InkIrView({super.key, required this.ir});
  @override
  State<InkIrView> createState() => _InkIrViewState();
}

class _InkIrViewState extends State<InkIrView> with TickerProviderStateMixin {
  InkColors get colors => InkColors.of(context);
  late final AnimationController clock;
  late final AnimationController reveal;
  late Map<String, dynamic> values;
  InkIrEvaluator get evaluator => InkIrEvaluator(values);

  void refreshComputed() {
    for (final raw in (widget.ir['state'] as List? ?? []).whereType<Map>()) {
      if (raw['reactive'] == false &&
          raw['expression'] != null &&
          raw['name'] is String) {
        values[raw['name'] as String] = InkIrEvaluator(
          values,
        ).eval(raw['expression']);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    values = {
      for (final raw in (widget.ir['state'] as List? ?? []).whereType<Map>())
        if (raw['name'] is String) raw['name'] as String: raw['value'],
    };
    clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..forward();
    if (_hasMotion(widget.ir['root'])) clock.repeat();
  }

  bool _hasMotion(Object? value) {
    if (value is Map) {
      if (value['kind'] == 'ref' && value['name'] == 'time') return true;
      if (const {
        'Wave',
        'Pendulum',
        'Projectile',
        'Orbit',
        'ParticleField',
        'NeuralNetwork',
        'SortingVisualizer',
      }.contains(value['type'])) {
        return true;
      }
      return value.values.any(_hasMotion);
    }
    if (value is List) return value.any(_hasMotion);
    return false;
  }

  @override
  void dispose() {
    clock.dispose();
    reveal.dispose();
    super.dispose();
  }

  dynamic prop(Map node, String key) =>
      evaluator.eval((node['props'] as Map?)?[key]);
  String label(Map node, [String key = 'label']) =>
      (prop(node, key) ?? '').toString();
  double number(Map node, String key, double fallback) {
    final v = prop(node, key);
    return v is num && v.isFinite ? v.toDouble() : fallback;
  }

  List<Map> children(Map node) =>
      (node['children'] as List? ?? []).whereType<Map>().toList();
  String textOf(Map node) {
    final direct = prop(node, 'text') ?? prop(node, 'value');
    if (direct != null) return direct.toString();
    return children(node).map(textOf).where((x) => x.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    refreshComputed();
    if (widget.ir['mode'] != 'visual' || widget.ir['root'] is! Map) {
      return const Center(child: Text('Invalid InkScript visual'));
    }
    return AnimatedBuilder(
      animation: Listenable.merge([clock, reveal]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildNode(widget.ir['root'] as Map, clock.value),
      ),
    );
  }

  Widget _buildNode(Map node, double t) {
    final type = node['type']?.toString() ?? '';
    final kids = children(node);
    final built = kids.map((n) => _buildNode(n, t)).toList();
    switch (type) {
      case 'App':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label(node, 'title').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  label(node, 'title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontFamily: 'Lora',
                    fontSize: 20,
                  ),
                ),
              ),
            ...built,
          ],
        );
      case 'Column':
      case 'Section':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced(built, 8),
        );
      case 'Row':
      case 'Grid':
        return LayoutBuilder(
          builder: (_, constraints) {
            final width = math.max(130.0, (constraints.maxWidth - 10) / 2);
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final child in built) SizedBox(width: width, child: child),
              ],
            );
          },
        );
      case 'Stack':
        return Stack(children: built);
      case 'Panel':
      case 'Controls':
        final root = widget.ir['root'];
        final rootTitle = root is Map ? label(root, 'title') : '';
        final contents = type == 'Panel'
            ? kids
                  .where(
                    (child) =>
                        !(child['type'] == 'Heading' &&
                            textOf(child) == rootTitle),
                  )
                  .map((child) => _buildNode(child, t))
                  .toList()
            : built;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: type == 'Controls' ? colors.surface : colors.paper,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(InkTokens.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(contents, 8),
          ),
        );
      case 'Spacer':
        return const SizedBox(height: 12);
      case 'Divider':
        return Divider(color: colors.border);
      case 'Title':
      case 'Heading':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            textOf(node),
            style: TextStyle(
              color: colors.textPrimary,
              fontFamily: 'Lora',
              fontSize: type == 'Title' ? 22 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'Text':
      case 'Label':
      case 'Note':
      case 'Hint':
      case 'Success':
      case 'Warning':
      case 'ErrorText':
      case 'Equation':
      case 'Number':
        final color = switch (type) {
          'Success' => colors.success,
          'Warning' => colors.accent,
          'ErrorText' => colors.danger,
          'Hint' => colors.textTertiary,
          _ => colors.textSecondary,
        };
        return Text(
          textOf(node),
          style: TextStyle(
            color: color,
            fontFamily: type == 'Equation' ? 'monospace' : null,
            fontSize: type == 'Number'
                ? 24
                : type == 'Label'
                ? 12
                : 14,
            fontWeight: type == 'Number' ? FontWeight.bold : FontWeight.normal,
            height: 1.3,
          ),
        );
      case 'Slider':
        return _slider(node);
      case 'Toggle':
        return _toggle(node);
      case 'Button':
        return FilledButton(
          onPressed: () => setState(() {
            clock.reset();
            clock.repeat();
          }),
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.paper,
          ),
          child: Text(label(node).isEmpty ? 'Replay' : label(node)),
        );
      case 'Select':
      case 'Tabs':
      case 'SegmentedControl':
        return _select(node);
      case 'Input':
      case 'NumberInput':
        final inputRef = (node['props'] as Map?)?['value'];
        final inputName = inputRef is Map && inputRef['kind'] == 'ref'
            ? inputRef['name']?.toString()
            : null;
        return TextFormField(
          key: ValueKey(inputName),
          initialValue: prop(node, 'value')?.toString() ?? '',
          decoration: InputDecoration(
            labelText: label(node),
            border: const OutlineInputBorder(),
          ),
          keyboardType: type == 'NumberInput'
              ? TextInputType.number
              : TextInputType.text,
          style: TextStyle(color: colors.textPrimary),
          onChanged: inputName == null
              ? null
              : (text) => setState(
                  () => values[inputName] = type == 'NumberInput'
                      ? (double.tryParse(text) ?? values[inputName])
                      : text,
                ),
        );
      case 'Scene':
        return SizedBox(
          height: number(node, 'height', 190).clamp(80, 500),
          width: double.infinity,
          child: CustomPaint(painter: _ScenePainter(kids, evaluator, colors)),
        );
      case 'NativeWeb':
        return SizedBox(
          height: number(node, 'height', 240).clamp(100, 500),
          child: generatedVisual(label(node, 'html')),
        );
      default:
        if (_diagrams.contains(type)) {
          return Container(
            height: number(node, 'height', 188).clamp(90, 440),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: colors.paper,
              borderRadius: BorderRadius.circular(InkTokens.r12),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _DiagramPainter(
                type,
                {
                  for (final key in (node['props'] as Map? ?? {}).keys)
                    key.toString(): prop(node, key.toString()),
                },
                t,
                colors,
                reveal.value,
              ),
            ),
          );
        }
        return Text(
          'InkScript component <$type> is not available.',
          style: TextStyle(color: colors.accent),
        );
    }
  }

  List<Widget> _spaced(List<Widget> widgets, double gap) => [
    for (var i = 0; i < widgets.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      widgets[i],
    ],
  ];
  Widget _slider(Map node) {
    final min = number(node, 'min', 0), max = number(node, 'max', 100);
    final lo = math.min(min, max), hi = math.max(min + .001, max);
    final value = number(node, 'value', lo).clamp(lo, hi);
    final unit = label(node, 'unit');
    final ref = (node['props'] as Map?)?['value'];
    final stateName = ref is Map && ref['kind'] == 'ref'
        ? ref['name']?.toString()
        : null;
    final step = number(node, 'step', 0);
    final divisions = step > 0
        ? ((hi - lo) / step).round().clamp(1, 1000)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label(node).isEmpty ? 'Value' : label(node),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(value.abs() < 10 ? 1 : 0)}${unit.isEmpty ? '' : ' $unit'}',
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.accent,
            inactiveTrackColor: colors.borderStrong,
            thumbColor: colors.accent,
            overlayColor: colors.accent.withValues(alpha: .12),
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: lo,
            max: hi,
            divisions: divisions,
            onChanged: stateName == null
                ? null
                : (v) => setState(() => values[stateName] = v),
          ),
        ),
      ],
    );
  }

  Widget _toggle(Map node) {
    final ref = (node['props'] as Map?)?['value'];
    final stateName = ref is Map && ref['kind'] == 'ref'
        ? ref['name']?.toString()
        : null;
    return SwitchListTile(
      dense: true,
      title: Text(label(node), style: TextStyle(color: colors.textPrimary)),
      activeThumbColor: colors.accent,
      value: prop(node, 'value') == true,
      onChanged: stateName == null
          ? null
          : (v) => setState(() => values[stateName] = v),
    );
  }

  Widget _select(Map node) {
    final options = prop(node, 'options');
    final choices = options is List
        ? options.map((x) => x.toString()).toList()
        : children(node).map(textOf).toList();
    final ref = (node['props'] as Map?)?['value'];
    final stateName = ref is Map && ref['kind'] == 'ref'
        ? ref['name']?.toString()
        : null;
    final current = prop(node, 'value')?.toString();
    return Wrap(
      spacing: 6,
      children: [
        for (final option in choices.take(12))
          ChoiceChip(
            label: Text(option),
            selected: current == option,
            onSelected: stateName == null
                ? null
                : (_) => setState(() => values[stateName] = option),
          ),
      ],
    );
  }
}

const _diagrams = {
  'Graph',
  'Chart',
  'Table',
  'Timeline',
  'Flowchart',
  'Diagram',
  'Planet',
  'Orbit',
  'Star',
  'ParticleField',
  'Wave',
  'Vector',
  'ForceArrow',
  'Field',
  'Flow',
  'Pendulum',
  'Projectile',
  'Spring',
  'Ramp',
  'Ball',
  'Collision',
  'NeuralNetwork',
  'SortingVisualizer',
  'SearchVisualizer',
  'TreeVisualizer',
  'GraphNetwork',
};

class _DiagramPainter extends CustomPainter {
  final String type;
  final Map<String, dynamic> props;
  final double time;
  final InkColors colors;
  final double reveal;
  _DiagramPainter(this.type, this.props, this.time, this.colors, this.reveal);
  Color get _inkAqua => colors.accent;
  Color get _inkCoral => colors.success;
  Color get _inkLilac => colors.textTertiary;
  double n(String key, double fallback) {
    final v = props[key];
    return v is num && v.isFinite ? v.toDouble() : fallback;
  }

  List<double>? graphCoefficients() {
    final supplied = props['coefficients'];
    if (supplied is List && supplied.isNotEmpty && supplied.length <= 6) {
      final parsed = supplied
          .map(
            (value) => value is num && value.isFinite ? value.toDouble() : null,
          )
          .toList();
      if (parsed.every((value) => value != null)) {
        return parsed.cast<double>();
      }
      return null;
    }
    final functions = props['functions'];
    if (functions is! List || functions.isEmpty) return null;
    final formula = functions.first
        .toString()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('x*x', 'x^2');
    final byPower = <int, double>{};
    var degree = 0;
    for (final match in RegExp(r'[+-]?[^+-]+').allMatches(formula)) {
      final term = match.group(0)!;
      final powerMatch = RegExp(r'x(?:\^([0-9]+))?').firstMatch(term);
      final power = powerMatch == null
          ? 0
          : int.tryParse(powerMatch.group(1) ?? '1');
      if (power == null || power < 0 || power > 5) return null;
      final raw = term
          .replaceFirst(RegExp(r'x(?:\^[0-9]+)?'), '')
          .replaceAll('*', '');
      final value = raw == '' || raw == '+'
          ? 1.0
          : raw == '-'
          ? -1.0
          : double.tryParse(raw);
      if (value == null) return null;
      byPower[power] = (byPower[power] ?? 0) + value;
      degree = math.max(degree, power);
    }
    return [for (var power = degree; power >= 0; power--) byPower[power] ?? 0];
  }

  double graphY(List<double> coefficients, double x) =>
      coefficients.fold(0.0, (value, coefficient) => value * x + coefficient);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, t = time * math.pi * 2;
    final line = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    final aqua = Paint()
      ..color = _inkAqua
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = _inkAqua;
    if (type == 'Graph' || type == 'Wave' || type == 'Chart') {
      for (var i = 1; i < 5; i++) {
        canvas.drawLine(Offset(w * i / 5, 12), Offset(w * i / 5, h - 12), line);
        canvas.drawLine(Offset(12, h * i / 5), Offset(w - 12, h * i / 5), line);
      }
      if (type != 'Graph') {
        canvas.drawLine(
          Offset(w / 2, 10),
          Offset(w / 2, h - 10),
          Paint()..color = colors.textTertiary,
        );
        canvas.drawLine(
          Offset(10, h / 2),
          Offset(w - 10, h / 2),
          Paint()..color = colors.textTertiary,
        );
      }
      if (type == 'Chart') {
        final data = props['values'] is List
            ? props['values'] as List
            : [2, 4, 3, 6, 5];
        final nums = data
            .take(16)
            .map((x) => x is num ? x.toDouble() : 0.0)
            .toList();
        final peak = math.max(
          1.0,
          nums.fold<double>(0, (a, b) => math.max(a, b.abs())),
        );
        for (var i = 0; i < nums.length; i++) {
          final bw = (w - 40) / nums.length * .6;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                20 + (w - 40) * i / nums.length,
                h - 20 - (h - 40) * nums[i] / peak,
                bw,
                (h - 40) * nums[i] / peak,
              ),
              const Radius.circular(4),
            ),
            Paint()..color = i.isEven ? _inkAqua : _inkLilac,
          );
        }
      } else {
        final path = Path();
        final coefficients = graphCoefficients();
        if (type == 'Graph' &&
            props['functions'] is List &&
            coefficients == null) {
          _caption(canvas, 'Unsupported graph formula', const Offset(18, 16));
          return;
        }
        final graph = coefficients ?? [n('a', 1), n('b', 0), n('c', 0)],
            amp = n('amplitude', 1),
            freq = n('frequency', 2);
        final xr = props['x'] is List ? props['x'] as List : [-3, 3];
        final yr = props['y'] is List ? props['y'] as List : null;
        final xMin = xr.length > 1 && xr[0] is num
            ? (xr[0] as num).toDouble()
            : -3.0;
        final xMax = xr.length > 1 && xr[1] is num
            ? (xr[1] as num).toDouble()
            : 3.0;
        final samples = [
          for (var i = 0; i <= 120; i++)
            graphY(graph, xMin + (xMax - xMin) * i / 120),
          0.0,
        ];
        final low = samples.reduce(math.min), high = samples.reduce(math.max);
        final padding = math.max(1.0, (high - low) * .12);
        final yMin = yr != null && yr.length > 1 && yr[0] is num
            ? (yr[0] as num).toDouble()
            : low - padding;
        final yMax = yr != null && yr.length > 1 && yr[1] is num
            ? (yr[1] as num).toDouble()
            : high + padding;
        if (type == 'Graph') {
          final axis = Paint()
            ..color = colors.textTertiary.withValues(alpha: .7)
            ..strokeWidth = 1.1;
          final zeroX = ((-xMin) / (xMax - xMin) * w).clamp(12.0, w - 12);
          final zeroY = (h - 12 - (-yMin) / (yMax - yMin) * (h - 24)).clamp(
            12.0,
            h - 12,
          );
          canvas.drawLine(Offset(zeroX, 12), Offset(zeroX, h - 12), axis);
          canvas.drawLine(Offset(12, zeroY), Offset(w - 12, zeroY), axis);
        }
        final visibleSamples = type == 'Graph'
            ? (180 * Curves.easeOutCubic.transform(reveal)).ceil().clamp(0, 180)
            : 180;
        for (var i = 0; i <= visibleSamples; i++) {
          final x = w * i / 180, xv = xMin + (xMax - xMin) * i / 180;
          final y = type == 'Graph'
              ? h -
                    12 -
                    ((graphY(graph, xv) - yMin) /
                            math.max(0.001, yMax - yMin)) *
                        (h - 24)
              : h / 2 -
                    math.sin(i / 180 * math.pi * 2 * freq + t) * amp * h * .23;
          if (i == 0)
            path.moveTo(x, y.clamp(-h, h * 2).toDouble());
          else
            path.lineTo(x, y.clamp(-h, h * 2).toDouble());
        }
        canvas.drawPath(path, aqua);
      }
      return;
    }
    if (type == 'Pendulum') {
      final length = n('length', 2).clamp(.2, 6),
          gravity = n('gravity', 9.81).clamp(.1, 40);
      final angle = math.sin(t * math.sqrt(gravity / length) * .55) * .47;
      final origin = Offset(w / 2, 24),
          radius = math.min(h * .64, 56 + length * 18).toDouble();
      final bob =
          origin + Offset(math.sin(angle) * radius, math.cos(angle) * radius);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        math.pi * .29,
        math.pi * .42,
        false,
        line,
      );
      canvas.drawLine(
        origin,
        bob,
        Paint()
          ..color = colors.textSecondary
          ..strokeWidth = 2,
      );
      canvas.drawCircle(origin, 5, fill);
      canvas.drawCircle(bob, 16, Paint()..color = _inkCoral);
      canvas.drawCircle(bob, 6, Paint()..color = colors.paper);
      return;
    }
    if (type == 'Projectile') {
      final v = n('velocity', 20).clamp(1, 100),
          angle = n('angle', 45) * math.pi / 180,
          g = n('gravity', 9.81).clamp(.1, 40);
      final range = v * v * math.sin(2 * angle) / g;
      final flight = 2 * v * math.sin(angle) / g;
      final peak = v * v * math.sin(angle) * math.sin(angle) / (2 * g);
      final path = Path();
      Offset point(double f) => Offset(
        24 + (w - 48) * f,
        h -
            24 -
            (h - 50) *
                (peak <= 0
                    ? 0
                    : (v * math.sin(angle) * flight * f -
                              .5 * g * math.pow(flight * f, 2)) /
                          math.max(peak * 1.12, 1)),
      );
      for (var i = 0; i <= 80; i++) {
        final p = point(i / 80);
        if (i == 0)
          path.moveTo(p.dx, p.dy);
        else
          path.lineTo(p.dx, p.dy);
      }
      canvas.drawLine(Offset(12, h - 24), Offset(w - 12, h - 24), line);
      canvas.drawPath(path, aqua);
      canvas.drawCircle(point(time), 8, Paint()..color = _inkCoral);
      _caption(canvas, 'Range ${range.toStringAsFixed(1)} m', Offset(18, 13));
      return;
    }
    if (type == 'Orbit' || type == 'Planet' || type == 'Star') {
      final center = Offset(w / 2, h / 2), r = math.min(w * .31, h * .38);
      canvas.drawCircle(center, r, line);
      canvas.drawCircle(center, r * .62, line);
      canvas.drawCircle(center, 17, Paint()..color = _inkCoral);
      final speed = n('speed', 1);
      final p =
          center + Offset(math.cos(t * speed) * r, math.sin(t * speed) * r);
      canvas.drawCircle(p, 7, fill);
      canvas.drawCircle(
        center +
            Offset(math.cos(-t * .7) * r * .62, math.sin(-t * .7) * r * .62),
        5,
        Paint()..color = _inkLilac,
      );
      return;
    }
    if (type == 'NeuralNetwork' ||
        type == 'GraphNetwork' ||
        type == 'TreeVisualizer' ||
        type == 'Flowchart' ||
        type == 'Diagram') {
      final layers = [
        [Offset(w * .17, h * .5)],
        [
          Offset(w * .43, h * .25),
          Offset(w * .43, h * .5),
          Offset(w * .43, h * .75),
        ],
        [Offset(w * .76, h * .36), Offset(w * .76, h * .64)],
      ];
      for (var i = 0; i < layers.length - 1; i++)
        for (final a in layers[i])
          for (final b in layers[i + 1]) canvas.drawLine(a, b, line);
      for (var i = 0; i < layers.length; i++)
        for (final p in layers[i]) {
          canvas.drawCircle(
            p,
            10,
            Paint()..color = i == 2 ? _inkCoral : _inkAqua,
          );
          canvas.drawCircle(p, 4, Paint()..color = colors.paper);
        }
      return;
    }
    if (type == 'SortingVisualizer' ||
        type == 'SearchVisualizer' ||
        type == 'Table') {
      final items = props['values'] is List
          ? props['values'] as List
          : [5, 2, 7, 3, 8, 4, 6];
      final nums = items
          .take(18)
          .map((x) => x is num ? x.toDouble() : 1.0)
          .toList();
      final peak = math.max(
        1.0,
        nums.fold<double>(0, (a, b) => math.max(a, b.abs())),
      );
      for (var i = 0; i < nums.length; i++) {
        final bw = (w - 34) / nums.length * .72,
            x = 18 + (w - 34) * i / nums.length;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x,
              h - 20 - (h - 45) * nums[i] / peak,
              bw,
              (h - 45) * nums[i] / peak,
            ),
            const Radius.circular(5),
          ),
          Paint()
            ..color = i == (time * nums.length).floor() ? _inkCoral : _inkAqua,
        );
      }
      return;
    }
    if (type == 'Timeline' || type == 'Flow') {
      canvas.drawLine(Offset(24, h / 2), Offset(w - 24, h / 2), aqua);
      for (var i = 0; i < 4; i++) {
        final x = 28 + (w - 56) * i / 3;
        canvas.drawCircle(
          Offset(x, h / 2),
          10,
          Paint()..color = i == (time * 4).floor() ? _inkCoral : _inkLilac,
        );
      }
      return;
    }
    // General physical/vector components share a calibrated grid and vector marks.
    canvas.drawLine(Offset(20, h * .78), Offset(w - 20, h * .78), line);
    final x = 25 + (w - 50) * time;
    canvas.drawCircle(
      Offset(x, h * .56 + math.sin(t) * h * .16),
      12,
      Paint()..color = _inkCoral,
    );
    canvas.drawLine(Offset(x, h * .56), Offset(x + 38, h * .56 - 22), aqua);
    canvas.drawLine(
      Offset(x + 38, h * .56 - 22),
      Offset(x + 29, h * .56 - 20),
      aqua,
    );
  }

  void _caption(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colors.textSecondary, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_DiagramPainter old) =>
      old.time != time ||
      old.reveal != reveal ||
      old.props.toString() != props.toString() ||
      old.type != type;
}

class _ScenePainter extends CustomPainter {
  final List<Map> shapes;
  final InkIrEvaluator evaluator;
  final InkColors colors;
  _ScenePainter(this.shapes, this.evaluator, this.colors);
  Color get _inkAqua => colors.accent;
  Color get _inkCoral => colors.success;
  Color get _inkLilac => colors.textTertiary;
  double n(Map node, String key, double fallback) {
    final raw = (node['props'] as Map?)?[key], value = evaluator.eval(raw);
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in shapes.take(256)) {
      final type = node['type'];
      final color = type == 'Circle' || type == 'Arrow'
          ? _inkAqua
          : type == 'Rect'
          ? _inkCoral
          : _inkLilac;
      final stroke = Paint()
        ..color = color
        ..strokeWidth = n(node, 'strokeWidth', 2).clamp(.5, 16)
        ..style = PaintingStyle.stroke;
      final fill = Paint()..color = color.withValues(alpha: .6);
      final x = n(node, 'x', 0), y = n(node, 'y', 0);
      if (type == 'Circle')
        canvas.drawCircle(
          Offset(x, y),
          n(node, 'radius', 12).clamp(0, 500),
          fill,
        );
      if (type == 'Rect')
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, n(node, 'width', 40), n(node, 'height', 30)),
            const Radius.circular(5),
          ),
          fill,
        );
      if (type == 'Line' || type == 'Arrow') {
        final a = Offset(n(node, 'x1', x), n(node, 'y1', y)),
            b = Offset(n(node, 'x2', x + 40), n(node, 'y2', y));
        canvas.drawLine(a, b, stroke);
        if (type == 'Arrow') {
          final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
          canvas.drawLine(
            b,
            b + Offset(math.cos(angle + 2.5) * 10, math.sin(angle + 2.5) * 10),
            stroke,
          );
          canvas.drawLine(
            b,
            b + Offset(math.cos(angle - 2.5) * 10, math.sin(angle - 2.5) * 10),
            stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
