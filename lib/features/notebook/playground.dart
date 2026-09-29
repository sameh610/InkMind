import 'dart:math' as math;
import 'dart:ui';
import '../../core/models/ink.dart';
import 'demo_ink.dart';

List<InkPoint> _points(Iterable<Offset> points, [double pressure = .65]) =>
    points
        .toList()
        .asMap()
        .entries
        .map((e) => InkPoint(e.value, pressure, e.key * 12))
        .toList();

InkStroke _stroke(Iterable<Offset> points, {double width = 3}) =>
    InkStroke(id: newId(), points: _points(points), width: width);

List<InkStroke> pendulumStrokes() {
  final pivot = const Offset(340, 235), end = const Offset(390, 465);
  final rod = List.generate(
    36,
    (i) => InkPoint(
      Offset.lerp(pivot, end, i / 35)! + Offset(math.sin(i * 1.2) * .6, 0),
      .55,
      i * 8,
    ),
  );
  final bob = List.generate(65, (i) {
    final a = i / 64 * 2 * math.pi;
    return InkPoint(
      end + Offset(math.cos(a) * 28 + math.sin(i) * .7, math.sin(a) * 28),
      .6,
      300 + i * 6,
    );
  });
  final pivotMark = List.generate(25, (i) {
    final a = i / 24 * 2 * math.pi;
    return InkPoint(
      pivot + Offset(math.cos(a) * 5, math.sin(a) * 5),
      .7,
      900 + i * 5,
    );
  });
  return [
    InkStroke(id: newId(), points: rod, width: 3),
    InkStroke(id: newId(), points: bob, width: 3),
    InkStroke(id: newId(), points: pivotMark, width: 2.5),
  ];
}

List<InkStroke> birdStrokes() {
  // A raised head, lifted wing and forked tail read as a bird even without
  // labels. Each piece remains a separate, editable original ink stroke.
  List<Offset> curve(Offset a, Offset b, Offset c, Offset d) => [
    for (var i = 0; i <= 12; i++)
      Offset(
        (1 - i / 12) * (1 - i / 12) * (1 - i / 12) * a.dx +
            3 * (1 - i / 12) * (1 - i / 12) * (i / 12) * b.dx +
            3 * (1 - i / 12) * (i / 12) * (i / 12) * c.dx +
            (i / 12) * (i / 12) * (i / 12) * d.dx,
        (1 - i / 12) * (1 - i / 12) * (1 - i / 12) * a.dy +
            3 * (1 - i / 12) * (1 - i / 12) * (i / 12) * b.dy +
            3 * (1 - i / 12) * (i / 12) * (i / 12) * c.dy +
            (i / 12) * (i / 12) * (i / 12) * d.dy,
      ),
  ];
  final body = [
    ...curve(
      const Offset(269, 394),
      const Offset(291, 360),
      const Offset(329, 365),
      const Offset(360, 349),
    ),
    ...curve(
      const Offset(360, 349),
      const Offset(378, 317),
      const Offset(410, 328),
      const Offset(423, 351),
    ),
    ...curve(
      const Offset(423, 351),
      const Offset(438, 375),
      const Offset(412, 397),
      const Offset(385, 407),
    ),
    ...curve(
      const Offset(385, 407),
      const Offset(345, 432),
      const Offset(291, 428),
      const Offset(269, 394),
    ),
  ];
  final wing = [
    ...curve(
      const Offset(341, 382),
      const Offset(330, 352),
      const Offset(306, 320),
      const Offset(314, 297),
    ),
    ...curve(
      const Offset(314, 297),
      const Offset(344, 301),
      const Offset(371, 341),
      const Offset(365, 376),
    ),
  ];
  final beak = [
    const Offset(421, 352),
    const Offset(450, 362),
    const Offset(423, 370),
  ];
  final tail = [
    const Offset(272, 388),
    const Offset(226, 356),
    const Offset(244, 391),
    const Offset(217, 405),
    const Offset(277, 404),
  ];
  final eye = List.generate(17, (i) {
    final a = i / 16 * 2 * math.pi;
    return Offset(402 + math.cos(a) * 3.2, 348 + math.sin(a) * 3.2);
  });
  final feather = [
    const Offset(358, 414),
    const Offset(344, 434),
    const Offset(356, 428),
  ];
  return [
    _stroke(body),
    _stroke(wing),
    _stroke(beak),
    _stroke(tail),
    _stroke(eye, width: 3.2),
    _stroke(feather),
  ];
}

List<InkStroke> bouncingBallStrokes() {
  const center = Offset(340, 390);
  final outline = List.generate(73, (i) {
    final a = i / 72 * 2 * math.pi;
    return center + Offset(math.cos(a) * 50, math.sin(a) * 50);
  });
  final seam = List.generate(37, (i) {
    final t = i / 36;
    return Offset(340 + math.sin(t * math.pi) * 17, 342 + t * 96);
  });
  final crossSeam = List.generate(39, (i) {
    final t = i / 38;
    return Offset(292 + t * 96, 390 + math.sin(t * math.pi * 2) * 11);
  });
  return [
    _stroke(outline, width: 3.4),
    _stroke(seam, width: 2.2),
    _stroke(crossSeam, width: 2.2),
    _stroke([const Offset(190, 510), const Offset(510, 510)], width: 2),
  ];
}

PageObject textObject(
  String text, {
  double x = 90,
  double y = 150,
  double height = 80,
  double width = 530,
  String style = 'ink',
}) => PageObject(
  kind: 'text',
  text: text,
  x: x,
  y: y,
  width: width,
  height: height,
  data: {'style': style},
);

Notebook buildPlayground() {
  final pages = <InkPage>[];
  void add(
    String title,
    String subtitle,
    List<PageObject> objects, {
    List<InkStroke> strokes = const [],
  }) {
    pages.add(
      InkPage(
        title: title,
        strokes: strokes,
        objects: [
          textObject(subtitle, y: 100, height: 42, style: 'caption'),
          ...objects,
        ],
      ),
    );
  }

  final pendulum = pendulumStrokes();
  add(
    'Pendulum',
    '01 / ANIMATE INK  ·  Select the pendulum, then Make Alive.',
    [
      PageObject(
        kind: 'modifier',
        text: 'Moon',
        x: 120,
        y: 545,
        width: 130,
        height: 58,
      ),
      textObject(
        'Your original ink, in motion.',
        y: 710,
        height: 48,
        style: 'caption',
      ),
    ],
    strokes: pendulum,
  );
  add('InkDebug', '02 / REASONING  ·  Select the work, then tap Debug.', [], strokes: reasoningInk());
  add(
    'New Visual',
    '03 / INTERACTIVE MATH  ·  Select the equation, then New Visual.',
    [
      textObject('3x^2 - 1 = y', y: 205, height: 105),
      textObject(
        'Keep the coefficient and constant. Explore the curve.',
        y: 360,
        height: 70,
        style: 'caption',
      ),
    ],
  );
  add(
    'The same ink can fly',
    '04 / GENERALITY  ·  Select the bird, then Animate Ink: “make it fly”.',
    [
      textObject(
        'A drawing stays a drawing. Only its strokes move.',
        y: 610,
        height: 65,
        style: 'caption',
      ),
    ],
    strokes: birdStrokes(),
  );
  add('Wind in your ink', '05 / ORIGINAL STROKES · Select the flower. Animate Ink: “blow in the wind”.', [], strokes: flowerInk());
  add('Projectile lab', '06 / NEW VISUAL · Select the note, then New Visual.', [textObject('Projectile: 20 m/s, 45°', y:205, height:95)]);
  return Notebook(
    title: 'InkMind Demo',
    playground: true,
    color: 0xff3b6151,
    pages: pages,
  );
}
