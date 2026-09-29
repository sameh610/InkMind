import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';

void paintStroke(
  Canvas canvas,
  InkStroke s, {
  Color? overrideColor,
  double opacity = 1,
}) {
  if (s.points.isEmpty) return;
  final base = overrideColor ?? Color(s.color);
  final alpha =
      (s.tool == InkTool.highlighter
          ? 0.28
          : s.tool == InkTool.pencil
          ? 0.72
          : 1.0) *
      opacity;
  final p = Paint()
    ..color = base.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (s.points.length == 1) {
    canvas.drawCircle(
      s.points.first.position,
      s.width / 2,
      p..style = PaintingStyle.fill,
    );
    return;
  }
  for (var i = 1; i < s.points.length; i++) {
    final start = i == 1
        ? s.points.first.position
        : Offset.lerp(s.points[i - 1].position, s.points[i].position, .5)!;
    final end = i == s.points.length - 1
        ? s.points[i].position
        : Offset.lerp(s.points[i].position, s.points[i + 1].position, .5)!;
    p.strokeWidth =
        s.width *
        (s.tool == InkTool.highlighter
            ? 5
            : s.tool == InkTool.pencil
            ? 0.7 + s.points[i].pressure * .6
            : .65 + s.points[i].pressure * .7);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          s.points[i].position.dx,
          s.points[i].position.dy,
          end.dx,
          end.dy,
        ),
      p,
    );
    if (s.tool == InkTool.pencil && i % 2 == 0) {
      canvas.drawCircle(
        s.points[i].position + Offset(.6, -.4),
        .4,
        Paint()..color = base.withValues(alpha: .3),
      );
    }
  }
}

class PaperPainter extends CustomPainter {
  final PaperKind kind;
  final bool dark;
  PaperPainter(this.kind, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xff222428) : const Color(0xfffffdf9),
    );
    final p = Paint()
      ..color = (dark ? Colors.white : const Color(0xff8a847a)).withValues(
        alpha: dark ? 0.08 : .10,
      )
      ..strokeWidth = .7;
    switch (kind) {
      case PaperKind.blank:
        break;
      case PaperKind.lined:
        for (double y = 96; y < size.height; y += 32) {
          canvas.drawLine(Offset(45, y), Offset(size.width - 45, y), p);
        }
        break;
      case PaperKind.grid:
        for (double y = 0; y < size.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        for (double x = 0; x < size.width; x += 24) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        break;
      case PaperKind.dotted:
        for (double y = 24; y < size.height; y += 24) {
          for (double x = 24; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), .85, p);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(PaperPainter old) => old.kind != kind || old.dark != dark;
}

class StrokePainter extends CustomPainter {
  final List<InkStroke> strokes;
  final Set<String> selected;
  final bool dark;
  StrokePainter(this.strokes, {this.selected = const {}, this.dark = false});
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      paintStroke(
        canvas,
        s,
        overrideColor: dark && s.color == 0xff303c38 ? Color(0xffe1e8df) : null,
      );
      if (selected.contains(s.id)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(s.bounds.inflate(6), Radius.circular(5)),
          Paint()..color = Color(0xff7fa990).withValues(alpha: .2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StrokePainter old) => true;
}

class ActiveStrokePainter extends CustomPainter {
  final ValueNotifier<List<InkPoint>> points;
  final InkTool tool;
  final int color;
  final double width;
  final bool dark;
  ActiveStrokePainter(this.points, this.tool, this.color, this.width, this.dark)
    : super(repaint: points);
  @override
  void paint(Canvas canvas, Size size) {
    if (tool == InkTool.lasso) {
      if (points.value.isEmpty) return;
      final path = Path()
        ..moveTo(
          points.value.first.position.dx,
          points.value.first.position.dy,
        );
      for (final p in points.value.skip(1)) {
        path.lineTo(p.position.dx, p.position.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Color(0xff75a38c).withValues(alpha: .12),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Color(0xff75a38c)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      paintStroke(
        canvas,
        InkStroke(
          id: 'active',
          points: points.value,
          tool: tool,
          color: color,
          width: width,
        ),
        overrideColor: dark && color == 0xff303c38 ? Color(0xffe1e8df) : null,
      );
    }
  }

  @override
  bool shouldRepaint(ActiveStrokePainter old) =>
      old.tool != tool ||
      old.color != color ||
      old.width != width ||
      old.dark != dark;
}

class CoverPainter extends CustomPainter {
  final Color color;
  final bool playground;
  CoverPainter(this.color, {this.playground = false});
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (playground) {
      for (var k = 0; k < 5; k++) {
        final path = Path();
        for (var i = 0; i <= 100; i++) {
          final x = s.width * i / 100,
              y = s.height * .55 + math.sin(i / 16 + k * .35) * (35 + k * 9);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        c.drawPath(path, p);
      }
    } else {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * .65, s.height * .5),
          width: s.width * .7,
          height: s.height * .55,
        ),
        p,
      );
      c.drawLine(
        Offset(s.width * .2, s.height * .8),
        Offset(s.width * .85, s.height * .15),
        p,
      );
    }
    c.drawLine(
      Offset(9, 0),
      Offset(9, s.height),
      Paint()
        ..color = Colors.black.withValues(alpha: .17)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CoverPainter old) =>
      old.color != color || old.playground != playground;
}
