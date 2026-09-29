import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../ai/engine.dart';
import '../inkmatter/matter.dart';
import 'simulations.dart';

class InkCellView extends StatefulWidget {
  final PageObject object;
  final VoidCallback onChanged;
  const InkCellView({super.key, required this.object, required this.onChanged});
  @override
  State<InkCellView> createState() => _InkCellViewState();
}

class _InkCellViewState extends State<InkCellView>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  bool code = false, running = false;
  int question = 0, score = 0, step = 0;
  int? answer;
  bool complete = false;
  Timer? trainer;
  XorNetwork network = XorNetwork();
  Map<String, dynamic> get data => widget.object.data;
  double value(String key, double fallback) =>
      (data[key] as num? ?? fallback).toDouble();
  @override
  void initState() {
    super.initState();
    clock = AnimationController(vsync: this, duration: Duration(seconds: 6));
  }

  @override
  void dispose() {
    clock.dispose();
    trainer?.cancel();
    super.dispose();
  }

  void update(String key, dynamic v) {
    setState(() => data[key] = v);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) =>
          parseModifier(d.data, widget.object.kind, data) != null,
      onAcceptWithDetails: (d) {
        final command = parseModifier(d.data, widget.object.kind, data)!;
        update(command.property, command.value);
      },
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: candidates.isNotEmpty
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: .8),
            width: candidates.isNotEmpty ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.object.kind.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.object.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _seg('LIVE', !code, () => setState(() => code = false)),
                      _seg('CODE', code, () => setState(() => code = true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: code
                  ? SingleChildScrollView(
                      child: SelectableText(
                        'InkCell • validated specification\nNo eval, scripts, or network access.\n\n${JsonEncoder.withIndent('  ').convert({'type': widget.object.kind, 'parameters': data})}\n\n${sourceFor(widget.object.kind)}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    )
                  : live(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback tap) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: on
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: on
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

  Widget live(BuildContext context) {
    switch (widget.object.kind) {
      case 'graph':
        return graph();
      case 'quiz':
        return quiz();
      case 'algorithm':
        return algorithm();
      case 'neural':
        return neural();
      case 'calculator':
        return calculator();
      case 'flow':
        return flow();
      case 'circuit':
        return circuit();
      default:
        return simulation();
    }
  }

  Widget control(
    String name,
    String key,
    double min,
    double max,
    double fallback, {
    String unit = '',
  }) => SizedBox(
    height: 35,
    child: Row(
      children: [
        SizedBox(width: 68, child: Text(name, style: TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            semanticFormatterCallback: (v) => '$name ${fmt(v)} $unit',
            value: value(key, fallback).clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => update(key, v),
          ),
        ),
        SizedBox(
          width: 55,
          child: Text(
            '${fmt(value(key, fallback))}$unit',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  );
  Widget graph() => Column(
    children: [
      Expanded(
        child: CustomPaint(
          size: Size.infinite,
          painter: GraphPainter(
            value('a', 1),
            value('b', 0),
            value('c', 0),
            data['sin'] == true,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      control(data['sin'] == true ? 'amplitude' : 'a', 'a', -4, 4, 1),
      control('b', 'b', -8, 8, 0),
      control('c', 'c', -10, 10, 0),
    ],
  );
  Widget quiz() {
    final questions =
        (data['questions'] as List? ?? makeQuiz(widget.object.text));
    if (complete) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 14),
          Text(
            '$score / ${questions.length}',
            style: TextStyle(fontFamily: 'Lora', fontSize: 36),
          ),
          Text('A little better remembered.'),
          SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() {
              question = 0;
              score = 0;
              answer = null;
              complete = false;
            }),
            child: Text('Try again'),
          ),
        ],
      );
    }
    final q = questions[question] as Map;
    final choices = q['choices'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUESTION ${question + 1} OF ${questions.length}  ·  $score CORRECT',
          style: TextStyle(fontSize: 9, letterSpacing: 1.4),
        ),
        SizedBox(height: 10),
        Text(q['prompt'], style: TextStyle(fontSize: 14, height: 1.4)),
        SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: choices
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, 36),
                        alignment: Alignment.centerLeft,
                        backgroundColor: answer != null && e.key == q['answer']
                            ? Color(0xffabc7b2).withValues(alpha: .35)
                            : answer == e.key
                            ? Color(0xffd6a28c).withValues(alpha: .25)
                            : null,
                      ),
                      onPressed: answer != null
                          ? null
                          : () => setState(() {
                              answer = e.key;
                              if (e.key == q['answer']) score++;
                            }),
                      child: Text(
                        '${String.fromCharCode(65 + e.key)}   ${e.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (answer != null) ...[
          Text(
            answer == q['answer']
                ? 'Correct. ${q['explanation']}'
                : 'Review: ${q['explanation']}',
            style: TextStyle(fontSize: 11),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                if (question == questions.length - 1) {
                  complete = true;
                } else {
                  question++;
                  answer = null;
                }
              }),
              child: Text(
                question == questions.length - 1
                    ? 'See score'
                    : 'Next question →',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget simulation() {
    final type = widget.object.kind;
    final g = value('gravity', 9.81);
    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: clock,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: PhysicsPainter(
                type,
                clock.value * 6,
                data,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (type == 'projectile') ...[
          control('Velocity', 'velocity', 1, 60, 20, unit: ' m/s'),
          control('Angle', 'angle', 5, 85, 45, unit: '°'),
        ],
        if (type == 'pendulum' || type == 'spring')
          control('Length', 'length', .5, 5, 2, unit: ' m'),
        if (type == 'ramp') control('Friction', 'friction', 0, 1, .2),
        Row(
          children: [
            Text('g = ${fmt(g)} m/s²', style: TextStyle(fontSize: 11)),
            if (g == 1.62)
              IconButton(
                tooltip: 'Remove Moon modifier',
                icon: Icon(Icons.close, size: 14),
                onPressed: () => update('gravity', 9.81),
              ),
            Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  running = !running;
                  if (running) {
                    clock.repeat();
                  } else {
                    clock.stop();
                  }
                });
              },
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? 'Pause' : 'Run'),
            ),
          ],
        ),
      ],
    );
  }

  Widget algorithm() {
    final frames = algorithmFrames(
      data['algorithm'] ?? 'bubble sort',
      (data['values'] as List? ?? [7, 3, 9, 1, 6, 2, 8]).cast<int>(),
      descending: data['descending'] == true,
      target: (data['target'] as num? ?? 6).toInt(),
    );
    final current = frames[step.clamp(0, frames.length - 1)];
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: current.values
                .asMap()
                .entries
                .map(
                  (e) => Expanded(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      height: 30 + e.value * 12.0,
                      decoration: BoxDecoration(
                        color: current.active.contains(e.key)
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.bottomCenter,
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${e.value}',
                        style: TextStyle(
                          color: current.active.contains(e.key)
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: 16),
        Text(current.caption, style: TextStyle(fontSize: 12)),
        Slider(
          value: step.clamp(0, frames.length - 1).toDouble(),
          min: 0,
          max: (frames.length - 1).toDouble(),
          divisions: frames.length - 1,
          onChanged: (v) => setState(() => step = v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP ${step + 1} / ${frames.length}',
              style: TextStyle(fontSize: 10),
            ),
            IconButton(
              tooltip: 'Restart algorithm',
              onPressed: () => setState(() => step = 0),
              icon: Icon(Icons.replay),
            ),
            FilledButton.tonal(
              onPressed: step >= frames.length - 1
                  ? null
                  : () => setState(() => step++),
              child: Text('Next step'),
            ),
          ],
        ),
      ],
    );
  }

  Widget neural() => Column(
    children: [
      Expanded(
        child: CustomPaint(
          size: Size.infinite,
          painter: NetworkPainter(
            network,
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('EPOCH ${network.epoch}', style: TextStyle(fontSize: 10)),
          Text(
            'LOSS ${network.loss.toStringAsFixed(3)}',
            style: TextStyle(fontSize: 10),
          ),
          Text(
            'ACCURACY ${(network.accuracy * 100).round()}%',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
      SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              trainer?.cancel();
              setState(() {
                network = XorNetwork();
                running = false;
              });
            },
            child: Text('Reset'),
          ),
          FilledButton.tonal(
            onPressed: () {
              setState(() => running = !running);
              if (running) {
                trainer = Timer.periodic(Duration(milliseconds: 80), (_) {
                  if (mounted) setState(() => network.train(40));
                });
              } else {
                trainer?.cancel();
              }
            },
            child: Text(running ? 'Pause training' : 'Train XOR'),
          ),
        ],
      ),
    ],
  );
  Widget calculator() => Column(
    children: [
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '\$${fmt(value('visitors', 1000) * value('conversion', .04) * value('price', 25))}',
                style: TextStyle(fontFamily: 'Lora', fontSize: 40),
              ),
              Text(
                'visitors × conversion × order value',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      control('Visitors', 'visitors', 100, 10000, 1000),
      control('Conversion', 'conversion', 0, .25, .04),
      control('Order value', 'price', 1, 100, 25),
    ],
  );
  Widget flow() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: ['Client', '→', 'API', '→', 'Database']
            .map(
              (s) => Chip(
                label: Text(s),
                backgroundColor: data['failed'] == true && s != 'Client'
                    ? Color(0xffd39b85).withValues(alpha: .3)
                    : null,
              ),
            )
            .toList(),
      ),
      SizedBox(height: 20),
      Text(
        data['failed'] == true
            ? 'API unavailable → downstream request cannot complete.'
            : 'All stages responding.',
        style: TextStyle(fontSize: 12),
      ),
      TextButton(
        onPressed: () => update('failed', data['failed'] != true),
        child: Text(
          data['failed'] == true ? 'Recover API' : 'Simulate API failure',
        ),
      ),
    ],
  );
  Widget circuit() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.lightbulb_outline,
        size: 50,
        color: Theme.of(context).colorScheme.primary.withValues(
          alpha: (value('voltage', 5) / 12).clamp(.1, 1),
        ),
      ),
      Text(
        '${fmt(value('voltage', 5))} V / 100 Ω = ${fmt(value('voltage', 5) / 100 * 1000)} mA',
      ),
      SizedBox(height: 20),
      control('Voltage', 'voltage', 0, 12, 5, unit: ' V'),
      Text('Ideal resistor · Ohm’s law', style: TextStyle(fontSize: 11)),
    ],
  );
}

String sourceFor(String type) => switch (type) {
  'projectile' => 'x = v cos(θ) t\ny = v sin(θ) t − ½gt²',
  'pendulum' => 'θ(t) = θ₀ sin(√(g/L) t)\nSmall-angle approximation',
  'graph' => 'y = a*x*x + b*x + c',
  'neural' =>
    '2 inputs → 4 sigmoid units → 1 output\nBinary cross entropy; SGD; seed 42',
  _ =>
    'Deterministic Dart template.\nParameters are validated before rendering.',
};

class GraphPainter extends CustomPainter {
  final double a, b, c;
  final bool sine;
  final Color color, ink;
  GraphPainter(this.a, this.b, this.c, this.sine, this.color, this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 16,
        sy = size.height / 16,
        origin = Offset(size.width / 2, size.height / 2);
    final grid = Paint()
      ..color = ink.withValues(alpha: .08)
      ..strokeWidth = .5;
    for (var i = -8; i <= 8; i++) {
      canvas.drawLine(
        Offset(origin.dx + i * sx, 0),
        Offset(origin.dx + i * sx, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, origin.dy + i * sy),
        Offset(size.width, origin.dy + i * sy),
        grid,
      );
    }
    final axis = Paint()
      ..color = ink.withValues(alpha: .35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), axis);
    canvas.drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), axis);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final path = Path();
    for (var i = 0; i <= 400; i++) {
      final x = -8 + 16 * i / 400,
          y = sine ? a * math.sin(x) + b * x + c : a * x * x + b * x + c;
      final point = Offset(origin.dx + x * sx, origin.dy - y * sy);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
    );
    canvas.restore();
    final text = TextPainter(
      text: TextSpan(
        text: sine
            ? 'y = ${fmt(a)} sin(x) + ${fmt(b)}x + ${fmt(c)}'
            : 'y = ${fmt(a)}x² + ${fmt(b)}x + ${fmt(c)}',
        style: TextStyle(color: ink, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(8, 6));
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}

class PhysicsPainter extends CustomPainter {
  final String type;
  final double t;
  final Map<String, dynamic> data;
  final Color color;
  PhysicsPainter(this.type, this.t, this.data, this.color);
  @override
  void paint(Canvas c, Size s) {
    double v(String k, double d) => (data[k] as num? ?? d).toDouble();
    final g = v('gravity', 9.81),
        velocity = v('velocity', 20),
        angle = v('angle', 45);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    c.drawLine(
      Offset(15, s.height - 15),
      Offset(s.width - 15, s.height - 15),
      Paint()
        ..color = color.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    Offset ball;
    if (type == 'projectile') {
      final flight = 2 * velocity * math.sin(angle * math.pi / 180) / g;
      final range = projectile(flight, velocity, angle, g).dx;
      final peak =
          math.pow(velocity * math.sin(angle * math.pi / 180), 2) / (2 * g);
      final scale = math.min(
        (s.width - 40) / math.max(range, 1),
        (s.height - 40) / math.max(peak, 1),
      );
      final path = Path();
      for (var i = 0; i <= 100; i++) {
        final point = projectile(flight * i / 100, velocity, angle, g),
            pos = Offset(
              20 + point.dx * scale,
              s.height - 15 - point.dy * scale,
            );
        if (i == 0) {
          path.moveTo(pos.dx, pos.dy);
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final point = projectile((t / 6) * flight, velocity, angle, g);
      ball = Offset(20 + point.dx * scale, s.height - 15 - point.dy * scale);
    } else if (type == 'pendulum') {
      final pivot = Offset(s.width / 2, 12),
          length = math.min(s.height - 40, 140.0),
          theta = .5 * math.sin(t * math.sqrt(g / v('length', 2)));
      ball = pivot + Offset(math.sin(theta) * length, math.cos(theta) * length);
      c.drawLine(pivot, ball, p);
    } else if (type == 'spring') {
      ball = Offset(
        s.width / 2,
        s.height / 2 + math.sin(t * math.sqrt(g)) * s.height * .22,
      );
      final path = Path()..moveTo(s.width / 2, 8);
      for (var i = 0; i < 18; i++) {
        path.lineTo(
          s.width / 2 + (i % 2 == 0 ? -12 : 12),
          10 + (ball.dy - 20) * i / 18,
        );
      }
      path.lineTo(ball.dx, ball.dy);
      c.drawPath(path, p..style = PaintingStyle.stroke);
    } else if (type == 'ramp') {
      c.drawLine(Offset(20, 20), Offset(s.width - 20, s.height - 20), p);
      final progress = (.5 * g * (1 - v('friction', .2)) * t * t / 100).clamp(
        0.0,
        1.0,
      );
      ball = Offset.lerp(
        Offset(25, 12),
        Offset(s.width - 25, s.height - 30),
        progress,
      )!;
    } else {
      ball = Offset(
        s.width / 2,
        s.height - 25 - (math.sin(t * math.sqrt(g)).abs()) * (s.height - 50),
      );
    }
    c.drawCircle(ball, 9, Paint()..color = color);
    c.drawCircle(ball, 15, Paint()..color = color.withValues(alpha: .09));
  }

  @override
  bool shouldRepaint(PhysicsPainter old) => true;
}

class NetworkPainter extends CustomPainter {
  final XorNetwork network;
  final Color color;
  NetworkPainter(this.network, this.color);
  @override
  void paint(Canvas c, Size s) {
    final input = [
      Offset(s.width * .15, s.height * .35),
      Offset(s.width * .15, s.height * .65),
    ];
    final hidden = List.generate(
          4,
          (i) => Offset(s.width * .5, s.height * (i + 1) / 5),
        ),
        output = Offset(s.width * .85, s.height * .5);
    for (var j = 0; j < 4; j++) {
      for (var i = 0; i < 2; i++) {
        c.drawLine(
          input[i],
          hidden[j],
          Paint()
            ..color = (network.weights[j][i] > 0 ? color : Color(0xffb37b63))
                .withValues(alpha: .45)
            ..strokeWidth = network.weights[j][i].abs().clamp(.5, 4),
        );
      }
    }
    for (var j = 0; j < 4; j++) {
      c.drawLine(
        hidden[j],
        output,
        Paint()
          ..color = (network.out[j] > 0 ? color : Color(0xffb37b63)).withValues(
            alpha: .6,
          )
          ..strokeWidth = network.out[j].abs().clamp(.5, 4),
      );
    }
    for (final p in [...input, ...hidden, output]) {
      c.drawCircle(p, 13, Paint()..color = color);
      c.drawCircle(p, 7, Paint()..color = Color(0xffecf3ea));
    }
  }

  @override
  bool shouldRepaint(NetworkPainter old) => true;
}
