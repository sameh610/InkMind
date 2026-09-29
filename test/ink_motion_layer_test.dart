import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/features/living_ink/ink_motion_layer.dart';
import 'package:inkmind/features/living_ink/stroke_rig.dart';

void main() {
  test(
    'patrol moves the original subject across and back as a rigid group',
    () {
      final source = InkStroke(
        id: 'bee',
        points: const [InkPoint(Offset(20, 40)), InkPoint(Offset(40, 60))],
      );
      final rig = {
        'kind': 'patrol',
        'speed': 1.0,
        'amount': 240.0,
        'gravity': 9.8,
        'pivotX': 20.0,
        'pivotY': 40.0,
      };
      final atFarSide = riggedStroke(source, rig, 'ink', .5);
      final returning = riggedStroke(source, rig, 'ink', 1.5);
      final atHome = riggedStroke(source, rig, 'ink', 2.0);
      expect(atFarSide.points.first.position.dx, closeTo(140, .001));
      expect(returning.points.first.position.dx, closeTo(140, .001));
      expect(atHome.points.first.position.dx, closeTo(20, .001));
      expect(
        returning.points[1].position.dx - returning.points.first.position.dx,
        closeTo(20, .001),
      );
    },
  );

  test('matter updates both legacy state and current rig controls', () {
    final legacy = <String, dynamic>{
      'state': [
        {'name': 'gravity', 'value': 9.81, 'reactive': true},
      ],
    };
    final current = <String, dynamic>{
      'rig': {
        'controls': [
          {'name': 'gravity', 'min': 0, 'max': 20, 'value': 9.81},
        ],
      },
    };

    expect(motionIrHasControl(legacy, 'gravity'), isTrue);
    expect(motionIrHasControl(current, 'gravity'), isTrue);
    final legacyAfter = updateMotionIrControl(legacy, 'gravity', 1.62);
    final currentAfter = updateMotionIrControl(current, 'gravity', 1.62);
    expect((legacyAfter['state'] as List).single['value'], 1.62);
    expect(
      ((currentAfter['rig'] as Map)['controls'] as List).single['value'],
      1.62,
    );
    expect((legacy['state'] as List).single['value'], 9.81);
    expect(
      (((current['rig'] as Map)['controls'] as List).single)['value'],
      9.81,
    );
  });

  test('motion overlay hides static guide strokes from the base canvas', () {
    final page = InkPage(
      strokes: [
        InkStroke(
          id: 'rod',
          points: const [InkPoint(Offset(100, 20)), InkPoint(Offset(100, 140))],
        ),
        InkStroke(
          id: 'arrow',
          points: const [
            InkPoint(Offset(150, 150)),
            InkPoint(Offset(220, 150)),
          ],
        ),
      ],
      objects: [
        PageObject(
          kind: 'inkMotion',
          data: {
            'bindings': {
              'rig': ['rod'],
            },
            'ir': {
              'mode': 'animateInk',
              'rig': {
                'parts': [
                  {'id': 'rod', 'role': 'rod'},
                  {'id': 'arrow', 'role': 'static'},
                ],
              },
            },
          },
        ),
      ],
    );
    expect(movingStrokeIds(page), {'rod'});
    expect(motionStrokeIds(page), {'rod', 'arrow'});
  });

  testWidgets(
    'source-first InkScript exposes state controls under normal motion',
    (tester) async {
      final page = InkPage(
        strokes: [
          InkStroke(
            id: 'bee',
            points: const [InkPoint(Offset(20, 40)), InkPoint(Offset(40, 60))],
          ),
        ],
        objects: [
          PageObject(
            kind: 'inkMotion',
            data: {
              'bindings': {
                'part': ['bee'],
              },
              'ir': {
                'mode': 'animateInk',
                'drawings': [
                  {
                    'id': 'bee',
                    'points': [
                      [20, 40],
                      [40, 60],
                    ],
                  },
                ],
                'state': [
                  {'name': 'speed', 'value': 1.4, 'reactive': true},
                  {'name': 'gravity', 'value': 9.8, 'reactive': true},
                ],
                'bindings': [
                  {'name': 'part', 'selector': 'stroke', 'arg': 'bee'},
                ],
                'animations': [
                  {
                    'target': 'part',
                    'property': 'x',
                    'value': {
                      'kind': 'member',
                      'object': 'part',
                      'property': 'baseX',
                    },
                  },
                ],
              },
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 500,
            height: 400,
            child: InkMotionLayer(page: page, dark: true),
          ),
        ),
      );
      expect(find.text('LIVE CONTROLS'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('Gravity'), findsOneWidget);
    },
  );

  testWidgets('dropping Moon onto the pendulum ink updates its live state', (
    tester,
  ) async {
    final strokes = [
      InkStroke(
        id: 'rod',
        points: const [InkPoint(Offset(150, 80)), InkPoint(Offset(160, 220))],
      ),
      InkStroke(
        id: 'bob',
        points: const [
          InkPoint(Offset(135, 235)),
          InkPoint(Offset(165, 265)),
          InkPoint(Offset(135, 295)),
          InkPoint(Offset(105, 265)),
          InkPoint(Offset(135, 235)),
        ],
      ),
    ];
    final motion = PageObject(
      kind: 'inkMotion',
      text: 'Recognized pendulum · original ink animation',
      data: {
        'source':
            'const gravity = state(9.81); part.rotation = Math.sin(time * Math.sqrt(gravity / 9.81));',
        'bindings': {
          'part': ['rod', 'bob'],
        },
        'ir': {
          'mode': 'animateInk',
          'rig': {
            'kind': 'pendulum',
            'speed': 1.4,
            'amount': 0.95,
            'pivotX': 155.0,
            'pivotY': 80.0,
            'parts': [
              {'id': 'rod', 'role': 'rod'},
              {'id': 'bob', 'role': 'bob'},
            ],
            'controls': [
              {
                'name': 'gravity',
                'min': 0.0,
                'max': 20.0,
                'value': 9.81,
                'unit': 'm/s²',
              },
            ],
          },
        },
      },
    );
    final page = InkPage(strokes: strokes, objects: [motion]);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 500,
          height: 400,
          child: Stack(
            children: [
              Positioned.fill(
                child: InkMotionLayer(
                  page: page,
                  beforeEdit: () {},
                  onEdited: () {},
                ),
              ),
              const Positioned(
                left: 24,
                top: 335,
                child: Draggable<String>(
                  data: 'Moon',
                  feedback: Material(child: Text('Moon')),
                  child: Text('Moon'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final start = tester.getCenter(find.text('Moon'));
    final target =
        tester.getTopLeft(find.byType(InkMotionLayer)) + const Offset(135, 265);
    await tester.dragFrom(start, target - start);
    await tester.pumpAndSettle();
    final updatedIr = motion.data['ir'] as Map;
    final rig = updatedIr['rig'] as Map;
    expect((rig['controls'] as List).single['value'], 1.62);
    expect(find.text('Moon · gravity 1.62 m/s²'), findsOneWidget);
  });

  testWidgets('animated default ink remains visible on dark paper', (
    tester,
  ) async {
    final page = InkPage(
      strokes: [
        InkStroke(
          id: 'rod',
          color: 0xff303c38,
          width: 5,
          points: const [InkPoint(Offset(100, 20)), InkPoint(Offset(100, 140))],
        ),
      ],
      objects: [
        PageObject(
          kind: 'inkMotion',
          data: {
            'bindings': {
              'rig': ['rod'],
            },
            'ir': {
              'mode': 'animateInk',
              'rig': {
                'kind': 'pendulum',
                'speed': 2,
                'amount': .3,
                'pivotX': 100,
                'pivotY': 20,
                'parts': [
                  {'id': 'rod', 'role': 'rod'},
                ],
              },
            },
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: RepaintBoundary(
              key: const Key('motion'),
              child: InkMotionLayer(page: page, dark: true),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('motion')),
    );
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final rgba = bytes!.buffer.asUint8List();
    final i = (60 * image!.width + 100) * 4;
    expect(rgba[i], greaterThan(190));
    expect(rgba[i + 1], greaterThan(190));
    expect(rgba[i + 2], greaterThan(190));
  });
}
