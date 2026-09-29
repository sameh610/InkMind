import 'code_view_stub.dart' if (dart.library.js_interop) 'code_view_web.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ai/engine.dart';
import '../../core/models/ink.dart';
import '../../core/theme/tokens.dart';
import 'ink_ir_view.dart';

/// Renders saved visuals. Browser-generated code runs in a sandboxed iframe;
/// older declarative visuals are drawn by Flutter.
class AiVisualView extends StatefulWidget {
  final PageObject object;
  const AiVisualView({super.key, required this.object});
  @override
  State<AiVisualView> createState() => _AiVisualViewState();
}

class _AiVisualViewState extends State<AiVisualView>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  bool code = false;
  VisualSpec get spec =>
      VisualSpec.fromJson(widget.object.data) ??
      VisualSpec.fromLooseText(widget.object.text);

  @override
  void initState() {
    super.initState();
    clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.object.data['style'] != 'code' &&
        widget.object.data['style'] != 'ir')
      clock.repeat();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = spec;
    final colors = InkColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: .97 + .03 * progress,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(InkTokens.r16),
          border: Border.all(color: colors.borderStrong),
          boxShadow: InkTokens.lift(.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, size: 17, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  s.style == 'ir' ? 'INTERACTIVE VISUAL' : 'LIVING VISUAL',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => code = !code),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                  child: Text(
                    code ? 'BACK TO VISUAL' : 'VIEW SOURCE',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (s.style != 'ir') ...[
              Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'Lora',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: code
                  ? SingleChildScrollView(
                      child: SelectableText(
                        s.script ??
                            s.code ??
                            'InkMind visual schema\nstyle: ${s.style}\nseed: ${s.seed}\n\nRendered by Flutter\nNo eval, scripts, or arbitrary code.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    )
                  : s.style == 'ir' && s.ir != null
                  ? InkIrView(ir: s.ir!)
                  : s.style == 'code'
                  ? generatedVisual(s.code!)
                  : AnimatedBuilder(
                      animation: clock,
                      builder: (context, _) => CustomPaint(
                        painter: _VisualPainter(
                          s.style,
                          clock.value,
                          s.seed,
                          colors,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualPainter extends CustomPainter {
  final String style;
  final double t;
  final int seed;
  final InkColors colors;
  _VisualPainter(this.style, this.t, this.seed, this.colors);
  Color get aqua => colors.success;
  Color get coral => colors.accent;
  Color get lilac => colors.textSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      center,
      math.min(size.width, size.height) * .42,
      p..color = colors.border,
    );
    switch (style) {
      case 'network':
        _network(canvas, size, p);
      case 'orbit':
        _orbit(canvas, size, p);
      case 'flow':
        _flow(canvas, size, p);
      case 'timeline':
        _timeline(canvas, size, p);
      default:
        _wave(canvas, size, p);
    }
  }

  void _wave(Canvas canvas, Size size, Paint p) {
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final x = size.width * i / 80;
      final y =
          size.height * .5 +
          math.sin(i / 9 + t * math.pi * 2) * size.height * .2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p..color = aqua);
    canvas.drawCircle(
      Offset(size.width * .68, size.height * .5),
      6,
      Paint()..color = coral,
    );
  }

  void _orbit(Canvas canvas, Size size, Paint p) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 24, Paint()..color = coral);
    for (var i = 0; i < 3; i++) {
      final r = 42.0 + i * 27;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2.4, height: r * 1.2),
        p..color = i.isEven ? aqua : lilac,
      );
      final a = t * math.pi * 2 * (i.isEven ? 1 : -1) + i;
      canvas.drawCircle(
        c + Offset(math.cos(a) * r * 1.2, math.sin(a) * r * .6),
        5,
        Paint()..color = colors.paper,
      );
    }
  }

  void _network(Canvas canvas, Size size, Paint p) {
    final nodes = [
      Offset(size.width * .18, size.height * .5),
      Offset(size.width * .45, size.height * .25),
      Offset(size.width * .45, size.height * .75),
      Offset(size.width * .78, size.height * .5),
    ];
    for (final a in nodes.take(3)) {
      canvas.drawLine(a, nodes.last, p..color = colors.borderStrong);
    }
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(
        nodes[i],
        12 + (i == 3 ? math.sin(t * math.pi * 2) * 2 : 0),
        Paint()..color = [aqua, lilac, lilac, coral][i],
      );
    }
  }

  void _flow(Canvas canvas, Size size, Paint p) {
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.2 + i * .2);
      final path = Path()..moveTo(20, y);
      path.cubicTo(
        size.width * .35,
        y - 25,
        size.width * .6,
        y + 25,
        size.width - 24,
        y,
      );
      canvas.drawPath(path, p..color = i.isEven ? aqua : lilac);
      canvas.drawCircle(
        Offset(size.width * (.25 + i * .15), y),
        4,
        Paint()..color = coral,
      );
    }
  }

  void _timeline(Canvas canvas, Size size, Paint p) {
    final y = size.height * .58;
    canvas.drawLine(
      Offset(20, y),
      Offset(size.width - 20, y),
      p..color = colors.textTertiary,
    );
    for (var i = 0; i < 5; i++) {
      final x = 28 + i * (size.width - 56) / 4;
      canvas.drawLine(Offset(x, y - 12), Offset(x, y + 12), p..color = aqua);
      canvas.drawCircle(
        Offset(x, y - math.sin(t * math.pi * 2 + i) * 18),
        6,
        Paint()..color = i.isEven ? coral : lilac,
      );
    }
  }

  @override
  bool shouldRepaint(_VisualPainter old) =>
      old.t != t || old.style != style || old.seed != seed;
}
