import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/features/ai/ink_ir.dart';
import 'package:inkmind/features/ai/engine.dart';
import 'package:inkmind/features/ai/response_parser.dart';
import 'package:inkmind/features/living_ink/ink_ir_motion.dart';
import 'package:inkmind/features/living_ink/stroke_rig.dart';
import 'package:inkmind/features/visuals/ink_ir_view.dart';

Map<String, dynamic> lit(dynamic value) => {'kind': 'literal', 'value': value};
Map<String, dynamic> ref(String name) => {'kind': 'ref', 'name': name};

void main() {
  test('bend binds at zero and preserves original stroke identity', () {
    final page = InkPage(strokes: [InkStroke(id:'stem',points: const [InkPoint(Offset(0,100)),InkPoint(Offset(0,0))])]);
    final ir = <String,dynamic>{'mode':'animateInk','bindings':[{'name':'plant','selector':'stroke','arg':'stem','pivotX':0,'pivotY':100}], 'animations':[{'target':'plant','property':'bend','value':ref('time')}]};
    expect(bindInkAnimation(ir,page,{'stem'}), {'plant':['stem']});
    (ir['animations'] as List).first['value'] = lit(20);
    expect(() => bindInkAnimation(ir,page,{'stem'}),throwsFormatException);
  });
  test(
    'safe expression evaluation handles arithmetic, state and bounded division',
    () {
      final evaluator = InkIrEvaluator({'a': 3});
      expect(
        evaluator.eval({
          'kind': 'binary',
          'op': '*',
          'left': ref('a'),
          'right': lit(4),
        }),
        12,
      );
      expect(
        evaluator.eval({
          'kind': 'binary',
          'op': '/',
          'left': lit(1),
          'right': lit(0),
        }),
        0,
      );
      expect(
        evaluator.eval({
          'kind': 'math',
          'fn': 'sin',
          'args': [lit(0)],
        }),
        0,
      );
    },
  );

  test('compiled visual response preserves TSX and IR', () {
    final ir = {
      'version': 1,
      'mode': 'visual',
      'state': [],
      'root': {
        'type': 'App',
        'props': {'title': lit('Lab')},
        'children': [],
      },
    };
    final response = decodeAiResponse(
      InkAction.createVisual,
      jsonEncode({'source': 'export default function Visual() {}', 'ir': ir}),
      'Browser AI',
    );
    expect(response.visual?.style, 'ir');
    expect(response.visual?.title, 'Lab');
    expect(
      VisualSpec.fromJson(response.visual!.toJson())?.ir?['mode'],
      'visual',
    );
  });

  test('Animate Ink binding resolves only selected original stroke IDs', () {
    InkStroke stroke(String id) => InkStroke(
      id: id,
      points: [const InkPoint(Offset(1, 2)), const InkPoint(Offset(3, 4))],
    );
    final page = InkPage(
      strokes: [stroke('wing'), stroke('body')],
      labels: {'wing': 'leftWing'},
    );
    final ir = {
      'mode': 'animateInk',
      'bindings': [
        {'name': 'bird', 'selector': 'selection', 'arg': null},
        {
          'name': 'left',
          'selector': 'group',
          'parent': 'bird',
          'arg': 'leftWing',
        },
      ],
      'animations': [
        {'target': 'left', 'property': 'rotation', 'value': lit(0)},
      ],
    };
    final before = jsonEncode(page.toJson());
    expect(bindInkAnimation(ir, page, {'wing', 'body'})['left'], ['wing']);
    expect(() => bindInkAnimation(ir, page, {'body'}), throwsFormatException);
    final shifted = {
      ...ir,
      'animations': [
        {'target': 'left', 'property': 'rotation', 'value': lit(1)},
      ],
    };
    expect(
      () => bindInkAnimation(shifted, page, {'wing', 'body'}),
      throwsFormatException,
    );
    expect(jsonEncode(page.toJson()), before);
  });

  test('pendulum rig joins rod and bob while guide ink stays fixed', () {
    InkStroke stroke(String id, List<Offset> points) =>
        InkStroke(id: id, points: [for (final p in points) InkPoint(p)]);
    final rod = stroke('rod', [const Offset(100, 20), const Offset(100, 140)]);
    final bob = stroke('bob', [
      const Offset(100, 140),
      const Offset(110, 155),
      const Offset(100, 165),
      const Offset(90, 155),
      const Offset(100, 140),
    ]);
    final guide = stroke('guide', [
      const Offset(120, 160),
      const Offset(220, 170),
    ]);
    final page = InkPage(strokes: [rod, bob, guide]);
    final before = jsonEncode(page.toJson());
    final migrated = inferLegacyPendulumRig(page, {'rod', 'bob', 'guide'});
    expect(migrated, isNotNull);
    expect((migrated!['parts'] as List).last['role'], 'static');
    final rig = <String, dynamic>{
      'kind': 'pendulum',
      'speed': 2,
      'amount': .3,
      'pivotX': 100,
      'pivotY': 20,
      'parts': [
        {'id': 'rod', 'role': 'rod'},
        {'id': 'bob', 'role': 'bob'},
        {'id': 'guide', 'role': 'static'},
      ],
    };
    final bindings = bindInkAnimation(
      {'mode': 'animateInk', 'rig': rig},
      page,
      {'rod', 'bob', 'guide'},
    );
    expect(bindings['rig'], ['rod', 'bob']);
    final time = 3.141592653589793 / 4;
    final movedRod = riggedStroke(rod, rig, 'rod', time);
    final movedBob = riggedStroke(bob, rig, 'bob', time);
    expect(movedRod.points.first.position, rod.points.first.position);
    expect(movedRod.points.last.position.dx, lessThan(100));
    expect(movedBob.bounds.center.dx, lessThan(bob.bounds.center.dx));
    expect(
      (movedRod.points.last.position - movedBob.points.first.position).distance,
      lessThan(.001),
    );
    expect(riggedStroke(guide, rig, 'static', time), same(guide));
    expect(jsonEncode(page.toJson()), before);
    expect(
      () => bindInkAnimation(
        {
          'mode': 'animateInk',
          'rig': {
            ...rig,
            'parts': [
              {'id': 'outside', 'role': 'rod'},
            ],
          },
        },
        page,
        {'rod', 'bob'},
      ),
      throwsFormatException,
    );
  });

  test('handwriting reveal uses original sampled path without changing it', () {
    final stroke = InkStroke(
      id: 'word',
      points: [
        const InkPoint(Offset(0, 0), .3, 0),
        const InkPoint(Offset(20, 0), .7, 20),
        const InkPoint(Offset(40, 20), .5, 40),
      ],
    );
    final before = StrokeCodec.encode(stroke);
    final rig = <String, dynamic>{
      'kind': 'reveal',
      'speed': 1,
      'amount': 0,
      'pivotX': 0,
      'pivotY': 0,
    };
    final partial = riggedStroke(stroke, rig, 'ink', .4);
    expect(partial.points.length, greaterThan(1));
    expect(partial.points.last.position.dx, lessThan(40));
    expect(StrokeCodec.encode(stroke), before);
    expect(riggedStroke(stroke, rig, 'ink', 0), same(stroke));
  });

  testWidgets('InkIR slider updates reactive state and visual', (tester) async {
    final ir = <String, dynamic>{
      'version': 1,
      'mode': 'visual',
      'state': [
        {'name': 'g', 'value': 5, 'reactive': true},
      ],
      'root': {
        'type': 'App',
        'props': {'title': lit('Test')},
        'children': [
          {
            'type': 'Number',
            'props': {'value': ref('g')},
            'children': [],
          },
          {
            'type': 'Slider',
            'props': {
              'label': lit('Gravity'),
              'value': ref('g'),
              'min': lit(0),
              'max': lit(10),
            },
            'children': [],
          },
        ],
      },
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 400, width: 500, child: InkIrView(ir: ir)),
        ),
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(find.text('5'), findsNothing);
  });

  testWidgets('cubic graph renders all exact polynomial coefficients', (
    tester,
  ) async {
    final ir = <String, dynamic>{
      'version': 1,
      'mode': 'visual',
      'state': [
        for (final entry in {'p3': 1, 'p2': -1, 'p1': 0, 'p0': 1}.entries)
          {'name': entry.key, 'value': entry.value, 'reactive': true},
      ],
      'root': {
        'type': 'App',
        'props': {'title': lit('y = x³ − x² + 1')},
        'children': [
          {
            'type': 'Graph',
            'props': {
              'coefficients': {
                'kind': 'array',
                'items': [ref('p3'), ref('p2'), ref('p1'), ref('p0')],
              },
            },
            'children': [],
          },
        ],
      },
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 600, height: 500, child: InkIrView(ir: ir)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('y = x³ − x² + 1'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
