import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../notebook/controller.dart';

class Onboarding extends StatefulWidget {
  final InkMindController controller;
  const Onboarding({super.key, required this.controller});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding>
    with SingleTickerProviderStateMixin {
  int step = 0;
  late final AnimationController anim;

  static const titles = [
    'Write naturally.',
    'Ask the page.',
    'Make ideas interactive.',
    'Change reality with ink.',
  ];

  @override
  void initState() {
    super.initState();
    anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  void finish() => widget.controller.updatePreferences('onboarding', true);

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Scaffold(
      backgroundColor: colors.workspace,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('InkMind', style: wordmark(context, 22)),
                      const Spacer(),
                      InkGhostButton(label: 'Skip', onPressed: finish),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: AnimatedBuilder(
                            animation: anim,
                            builder: (context, _) => Container(
                              decoration: BoxDecoration(
                                color: colors.paper,
                                borderRadius:
                                    BorderRadius.circular(InkTokens.r12),
                                border: Border.all(color: colors.border),
                                boxShadow: InkTokens.paperShadow(),
                              ),
                              child: CustomPaint(
                                painter: _OnboardPainter(step, anim.value, colors),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          titles[step],
                          textAlign: TextAlign.center,
                          style: editorial(context, 28),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (i) => AnimatedContainer(
                        duration: InkTokens.quick,
                        width: i == step ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(
                            alpha: i == step ? 1 : .22,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkPrimaryButton(
                    label: step == 3 ? 'Start writing' : 'Continue',
                    expand: true,
                    onPressed: () {
                      if (step < 3) {
                        setState(() => step++);
                      } else {
                        finish();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardPainter extends CustomPainter {
  final int step;
  final double t;
  final InkColors colors;
  _OnboardPainter(this.step, this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = colors.textPrimary.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    switch (step) {
      case 0:
        final path = Path()
          ..moveTo(size.width * .18, size.height * .42)
          ..quadraticBezierTo(
            size.width * (.35 + t * .02),
            size.height * (.28 + t * .04),
            size.width * .55,
            size.height * .45,
          )
          ..quadraticBezierTo(
            size.width * .72,
            size.height * (.58 - t * .03),
            size.width * .82,
            size.height * .38,
          );
        canvas.drawPath(path, ink);
      case 1:
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * .42, size.height * .45),
            width: size.width * .42,
            height: size.height * .22,
          ),
          const Radius.circular(40),
        );
        canvas.drawRRect(r, accent..color = colors.accent.withValues(alpha: .5));
        _text(canvas, '3x + 5 = 20', Offset(size.width * .28, size.height * .42), ink.color);
        _text(canvas, '?', Offset(size.width * .68, size.height * .38), colors.accent, 28);
        if (t > .4) {
          _text(
            canvas,
            'x = 5',
            Offset(size.width * .55, size.height * .68),
            colors.accent.withValues(alpha: ((t - .4) / .6).clamp(0, 1)),
            18,
          );
        }
      case 2:
        _text(canvas, 'y = x²', Offset(size.width * .18, size.height * .22), ink.color, 20);
        final graph = Path();
        for (var i = 0; i <= 40; i++) {
          final x = size.width * (.2 + i / 40 * .55);
          final nx = (i / 40) * 2 - 1;
          final y = size.height * (.7 - nx * nx * .35 * (.3 + t * .7));
          if (i == 0) {
            graph.moveTo(x, y);
          } else {
            graph.lineTo(x, y);
          }
        }
        canvas.drawPath(graph, accent);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .15, size.height * .18, size.width * .7, size.height * .64),
            const Radius.circular(8),
          ),
          Paint()
            ..color = colors.border
            ..style = PaintingStyle.stroke,
        );
      default:
        final pivot = Offset(size.width * .45, size.height * .22);
        final angle = -.4 + t * .8;
        final bob = pivot + Offset(math.sin(angle) * 70, math.cos(angle) * 70);
        canvas.drawLine(pivot, bob, ink);
        canvas.drawCircle(bob, 12, ink);
        final moon = Offset(size.width * (.72 - t * .08), size.height * (.35 + t * .08));
        canvas.drawCircle(moon, 10, accent);
        _text(canvas, 'Moon', moon + const Offset(14, -6), colors.accent, 12);
    }
  }

  void _text(Canvas c, String s, Offset o, Color color, [double size = 16]) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'Caveat', fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _OnboardPainter old) =>
      old.step != step || old.t != t;
}
