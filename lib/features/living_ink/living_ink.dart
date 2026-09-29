import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../canvas/painters.dart';
import '../inkmatter/matter.dart';

class LivingInk extends StatefulWidget {
  final PageObject object;
  final VoidCallback onChanged;
  const LivingInk({super.key, required this.object, required this.onChanged});
  @override
  State<LivingInk> createState() => _LivingInkState();
}

class _LivingInkState extends State<LivingInk>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  bool running = false;
  double phase = 0;
  int previous = 0;
  late List<InkStroke> strokes;
  double get gravity =>
      (widget.object.data['gravity'] as num? ?? 9.81).toDouble();
  @override
  void initState() {
    super.initState();
    clock = AnimationController(vsync: this, duration: Duration(seconds: 100))
      ..addListener(tick);
    strokes = (widget.object.data['strokes'] as List? ?? [])
        .map(
          (s) => StrokeCodec.decode(
            s['id'],
            Uint8List.fromList((s['bytes'] as List).cast<int>()),
          ),
        )
        .toList();
  }

  void tick() {
    final ms = clock.lastElapsedDuration?.inMilliseconds ?? 0;
    final dt = ((ms - previous) / 1000).clamp(0, .05);
    previous = ms;
    phase +=
        dt * math.sqrt(gravity / (widget.object.data['length'] as num? ?? 2));
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moon = (gravity - 1.62).abs() < .01;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) =>
          parseModifier(d.data, 'living', widget.object.data) != null,
      onAcceptWithDetails: (d) {
        final command = parseModifier(d.data, 'living', widget.object.data)!;
        widget.object.data[command.property] = command.value;
        widget.onChanged();
        setState(() {});
      },
      builder: (context, candidates, rejected) {
        final scheme = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: candidates.isNotEmpty
                ? scheme.primary.withValues(alpha: .06)
                : Colors.transparent,
            border: Border.all(
              color: candidates.isNotEmpty
                  ? scheme.primary.withValues(alpha: .45)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    Text(
                      running ? '▶ Living' : 'Living Ink',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      moon ? 'gravity 1.62 m/s²' : 'gravity 9.81 m/s²',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: clock,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: LivingPainter(
                      strokes,
                      phase,
                      Theme.of(context).brightness == Brightness.dark,
                      widget.object.data['system']?.toString() ?? 'pendulum',
                    ),
                  ),
                ),
              ),
            SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    key: const ValueKey('living-play'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        running = !running;
                        if (running) {
                          previous = 0;
                          clock.repeat();
                        } else {
                          clock.stop();
                        }
                      });
                    },
                    icon: Icon(
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(running ? 'Pause ink' : 'Run ink'),
                  ),
                  if (moon) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        widget.object.data['gravity'] = 9.81;
                        widget.onChanged();
                        setState(() {});
                      },
                      child: const Text('Moon ×'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

class LivingPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final double phase;
  final bool dark;
  final String system;
  LivingPainter(this.strokes, this.phase, this.dark, this.system);
  @override
  void paint(Canvas canvas, Size size) {
    final color = dark ? Color(0xffe0e7dc) : Color(0xff384a40);
    final scale = math.min(size.width / 470, size.height / 290);
    canvas.save();
    canvas.translate((size.width - 470 * scale) / 2, 8);
    canvas.scale(scale);
    final p = Paint()
      ..color = color.withValues(alpha: .3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(155, 40), Offset(285, 40), p);
    for (var i = 0; i < 9; i++) {
      canvas.drawLine(Offset(160 + i * 15, 40), Offset(167 + i * 15, 30), p);
    }
    canvas.save();
    if (system == 'pendulum') {
      canvas.translate(220, 40);
      canvas.rotate(math.sin(phase) * .48);
      canvas.translate(-220, -40);
    } else if (system == 'ball' || system == 'ramp') {
      canvas.translate(math.sin(phase) * 65, (1 - math.cos(phase * 2)) * 35);
    } else if (system == 'spring') {
      canvas.translate(0, math.sin(phase) * 35);
    } else {
      canvas.translate(math.sin(phase) * 12, 0);
    }
    for (final s in strokes) {
      paintStroke(canvas, s, overrideColor: color);
    }
    canvas.restore();
    canvas.drawCircle(Offset(220, 40), 4, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LivingPainter old) =>
      old.phase != phase || old.dark != dark;
}
