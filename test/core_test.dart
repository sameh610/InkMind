import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/core/storage/repository.dart';
import 'package:inkmind/features/ai/engine.dart';
import 'package:inkmind/features/ai/response_parser.dart';
import 'package:inkmind/features/canvas/gestures.dart';
import 'package:inkmind/features/inkcells/simulations.dart';
import 'package:inkmind/features/inkmatter/matter.dart';
import 'package:inkmind/features/notebook/controller.dart';
import 'package:inkmind/features/notebook/notebook_screen.dart';
import 'package:inkmind/features/notebook/playground.dart';
import 'package:inkmind/features/subscriptions/subscriptions.dart';
import 'package:inkmind/features/settings/settings.dart';

void main() {
  test(
    'pointed bird parts stay in motion while a detached arrow is removable',
    () {
      final bird = birdStrokes();
      expect(isDirectionArrowOverlay(bird[2], bird), isFalse); // beak
      expect(isDirectionArrowOverlay(bird[3], bird), isFalse); // tail
      final arrow = InkStroke(
        id: 'direction-hint',
        points: [
          const Offset(520, 240),
          const Offset(550, 240),
          const Offset(580, 240),
          const Offset(562, 224),
        ].map((point) => InkPoint(point)).toList(),
        width: 3,
      );
      expect(isDirectionArrowOverlay(arrow, [...bird, arrow]), isTrue);
    },
  );

  test('mobile QAT quantization is exposed only for Gemma', () {
    expect(quantizationsFor('gemma-4-e2b'), contains('QAT / mobile-optimized'));
    expect(quantizationsFor('gemma-4-e4b'), contains('QAT / mobile-optimized'));
    expect(
      quantizationsFor('qwen-2.5-coder-0.5b'),
      isNot(contains('QAT / mobile-optimized')),
    );
    expect(
      quantizationsFor('spark-x2.5-1.7b'),
      isNot(contains('QAT / mobile-optimized')),
    );
    expect(
      quantizationsFor('ternary-bonsai-2-27b'),
      isNot(contains('QAT / mobile-optimized')),
    );
  });
  test('simplification preserves endpoints and geometric error bound', () {
    final raw = List.generate(
      400,
      (i) =>
          InkPoint(Offset(i.toDouble(), math.sin(i / 30) * 40), i / 400, i * 7),
    );
    final simple = simplifyStroke(raw, .6);
    expect(simple.length, lessThan(raw.length ~/ 3));
    expect(simple.first, same(raw.first));
    expect(simple.last, same(raw.last));
    for (final p in raw) {
      final error = List.generate(
        simple.length - 1,
        (i) => distanceToSegment(
          p.position,
          simple[i].position,
          simple[i + 1].position,
        ),
      ).reduce(math.min);
      expect(error, lessThanOrEqualTo(.61));
    }
  });
  test(
    'binary strokes round trip tool color time pressure and negative deltas',
    () {
      final s = InkStroke(
        id: 's',
        tool: InkTool.pencil,
        color: 0xffaabbcc,
        width: 3.5,
        created: 100000,
        points: [
          InkPoint(Offset(30.17, 40.09), .2, 0),
          InkPoint(Offset(-24.4, 96.2), .9, 53),
        ],
      );
      final bytes = StrokeCodec.encode(s),
          copy = StrokeCodec.decode('s', StrokeCodec.encode(s));
      expect(bytes.length, 54);
      expect(copy.tool, s.tool);
      expect(copy.created, s.created);
      expect(copy.color, s.color);
      for (var i = 0; i < 2; i++) {
        expect(
          (copy.points[i].position - s.points[i].position).distance,
          lessThan(.05),
        );
        expect(copy.points[i].pressure, closeTo(s.points[i].pressure, 1 / 255));
        expect(copy.points[i].time, s.points[i].time);
      }
      expect(
        () => StrokeCodec.decode('x', Uint8List(3)),
        throwsFormatException,
      );
    },
  );
  test('undo redo preserve objects and ink independently', () async {
    final c = InkMindController(MemoryRepository());
    await c.initialize();
    c.open(c.create('test'));
    c.addStroke(InkStroke(id: 'a', points: [InkPoint(Offset(1, 1))]));
    c.checkpoint();
    c.page.objects.add(PageObject(kind: 'text', text: 'thought'));
    c.changed();
    c.undo();
    expect(c.page.objects, isEmpty);
    expect(c.page.strokes.length, 1);
    c.undo();
    expect(c.page.strokes, isEmpty);
    c.redo();
    expect(c.page.strokes.length, 1);
    c.redo();
    expect(c.page.objects.single.text, 'thought');
    await c.flush();
    c.dispose();
  });
  test(
    'autosave flush and notebook reopen survive repository serialization',
    () async {
      final repo = MemoryRepository(),
          c = InkMindController(MemoryRepository());
      c.dispose();
      final first = InkMindController(repo);
      await first.initialize();
      final n = first.create('Persist me');
      first.open(n);
      first.addPage();
      first.addStroke(InkStroke(id: 'a', points: [InkPoint(Offset(3, 7))]));
      await first.flush();
      first.dispose();
      final second = InkMindController(repo);
      await second.initialize();
      final reopened = second.notebooks.singleWhere(
        (notebook) => notebook.title == 'Persist me',
      );
      expect(reopened.pages.length, 2);
      expect(reopened.pages.last.strokes.single.id, 'a');
      second.dispose();
    },
  );
  test('circle box check and custom shape recognition', () {
    final circle = List.generate(
      65,
      (i) => InkPoint(
        Offset(
          100 + 50 * math.cos(i * math.pi / 32),
          100 + 50 * math.sin(i * math.pi / 32),
        ),
      ),
    );
    expect(recognizeGesture(circle), InkGesture.circle);
    final box = [
      Offset(0, 0),
      Offset(80, 0),
      Offset(80, 80),
      Offset(0, 80),
      Offset(0, 0),
    ].map((p) => InkPoint(p)).toList();
    expect(recognizeGesture(box), InkGesture.box);
    final check = [
      Offset(10, 30),
      Offset(30, 50),
      Offset(70, 0),
    ].map((p) => InkPoint(p)).toList();
    expect(recognizeGesture(check), InkGesture.check);
    final directionArrow = [
      Offset(0, 20),
      Offset(30, 20),
      Offset(60, 20),
      Offset(42, 4),
    ].map((p) => InkPoint(p)).toList();
    expect(recognizeGesture(directionArrow), InkGesture.arrow);
    expect(
      shapeSimilarity(
        normalizeShape(circle),
        normalizeShape(
          circle
              .map((p) => InkPoint(p.position * 2 + Offset(400, 20)))
              .toList(),
        ),
      ),
      greaterThan(.98),
    );
  });
  test('InkMatter validates target and modifier values', () {
    expect(parseModifier('Moon', 'living', {})!.value, 1.62);
    expect(parseModifier('Moon', 'quiz', {}), isNull);
    expect(parseModifier('3x velocity', 'ball', {'velocity': 20})!.value, 60);
    expect(parseModifier('900x velocity', 'ball', {}), isNull);
    expect(parseModifier('no friction', 'ramp', {})!.value, 0);
    expect(parseModifier('9V', 'circuit', {})!.value, 9);
    expect(parseModifier('conversion = 8%', 'calculator', {})!.value, .08);
    expect(parseModifier('API fails', 'flow', {})!.value, true);
    expect(parseModifier('sort descending', 'algorithm', {})!.value, true);
  });
  test('InkDebug stops at first incorrect transformation', () {
    final r = debugMath('3x + 5 = 20\n3x = 25\nx = 8.33');
    expect(r.firstError, 1);
    expect(r.explanation, contains('20 - 5 = 15, not 25'));
    expect(r.corrected.last, 'x = 5');
    expect(debugMath('3x + 5 = 20\n3x = 15\nx = 5').firstError, isNull);
    expect(debugMath('2x - 4 = 10\n2x = 6\nx = 3').firstError, 1);
    expect(debugMath('2 + 3 = 6').firstError, 0);
    expect(debugMath('physics proves everything').supported, false);
  });
  test('model router falls back from unavailable native engine', () async {
    final router = ModelRouter(smart: MiniCPMEngine());
    final r = await router.run(
      InkRequest('y = x² + 3x - 2', InkAction.makeAlive),
    );
    expect(r.cell!.type, 'graph');
    expect(r.cell!.parameters['b'], 3);
    expect(r.cell!.parameters['c'], -2);
    expect(r.cell!.valid, true);
    expect(
      (await router.run(
        InkRequest('projectile 30 m/s 60°', InkAction.makeAlive),
      )).cell!.parameters['velocity'],
      30,
    );
    expect(
      (await router.run(
        InkRequest('neural network XOR', InkAction.makeAlive),
      )).cell!.type,
      'neural',
    );
  });
  test('browser AI path never substitutes a demo result', () async {
    final router = ModelRouter(requireAi: true, smart: MiniCPMEngine());
    await expectLater(
      router.run(InkRequest('explain gravity', InkAction.explain)),
      throwsStateError,
    );
  });
  test('model output requires complete visual, motion and quiz artifacts', () {
    final visual = decodeAiResponse(
      InkAction.createVisual,
      'TITLE|Quadratic curve\nAXES\nPLOT|1|3|-2|teal\nTEXT|310|45|y = x² + 3x - 2',
      'Browser AI',
    );
    expect(visual.visual!.style, 'code');
    expect(visual.visual!.code, contains('<path'));
    expect(visual.visual!.script, contains('PLOT|1|3|-2'));
    final streamed = decodeAiResponse(
      InkAction.createVisual,
      'AXES\nPLOT\nTITLE\nQuadratic curve\nTEXT\n310\n45\ny = x² + 3x - 2',
      'Browser AI',
      context: 'y = x² + 3x - 2',
    );
    expect(streamed.visual!.title, 'Quadratic curve');
    expect(streamed.visual!.code, contains('<path'));
    expect(
      () => decodeAiResponse(InkAction.createVisual, 'a pretty chart', 'AI'),
      throwsFormatException,
    );
    final motion = decodeAiResponse(
      InkAction.animateInk,
      'WHY|The pendulum swings\nMOVE|s1|100|100|0|0|0.3|2',
      'Browser AI',
    );
    expect((motion.motion!['tracks'] as List).single['ids'], ['s1']);
    final splitMotion = decodeAiResponse(
      InkAction.animateInk,
      'WHY\nThe bob swings\nMOVE\ns1\n100\n100\n0\n0\n0.3\n2',
      'Browser AI',
    );
    expect((splitMotion.motion!['tracks'] as List).single['pivotX'], 100);
    final markdownMotion = decodeAiResponse(
      InkAction.animateInk,
      '**WHY:** The bob swings\n**MOVE:** s1;360;100;0;0;0.35;2',
      'Browser AI',
    );
    expect((markdownMotion.motion!['tracks'] as List).single['ids'], ['s1']);
    final liveMotion = decodeAiResponse(
      InkAction.animateInk,
      'WHY:The pendulum bob swings around its supportnewline MOVE;s1;360;100;0;0;0.35;2.0;coordinatesOnA720x1080page',
      'Browser AI',
    );
    expect((liveMotion.motion!['tracks'] as List).single['ids'], ['s1']);
    expect(liveMotion.text, 'The pendulum bob swings around its support');
    final compactMotion = decodeAiResponse(
      InkAction.animateInk,
      'WHY|The chosen part swings in a gentle arc.|MOVE|stroke_abc|360|100|0|0|0.3|2',
      'Browser AI',
    );
    expect((compactMotion.motion!['tracks'] as List).single['ids'], [
      'stroke_abc',
    ]);
    expect(compactMotion.text, 'The chosen part swings in a gentle arc.');
    expect(
      () => decodeAiResponse(
        InkAction.animateInk,
        'WHY|Move\nMOVE|s1|100|100|0|0|0.3|0',
        'AI',
      ),
      throwsFormatException,
    );
    expect(
      () => decodeAiResponse(
        InkAction.quiz,
        '{"title":"Quiz","questions":[{"prompt":"Q","choices":["A","B"],"answer":2,"explanation":"A"}]}',
        'AI',
      ),
      throwsFormatException,
    );
  });
  test('quiz derives answers from supplied notes', () {
    final q = makeQuiz(
      'Gravity attracts massive objects. Lower gravity slows a pendulum.',
    );
    expect(q.length, 3);
    for (final item in q) {
      expect(
        item['explanation'],
        contains((item['choices'] as List)[item['answer']]),
      );
    }
  });
  test('demo entitlement enables only through explicit purchase', () async {
    final s = DemoSubscriptionService();
    await s.initialize();
    expect(s.pro, false);
    await s.restore();
    expect(s.pro, false);
    await s.purchase(annual: true);
    expect(s.pro, true);
    expect(s.isDemo, true);
  });
  test(
    'free action quota enforced while ordinary pages remain unlimited',
    () async {
      final c = InkMindController(MemoryRepository());
      await c.initialize();
      c.open(c.create('free'));
      c.preferences['aiActions'] = 25;
      expect(
        () => c.action(InkAction.explain, text: 'x = 2'),
        throwsStateError,
      );
      for (var i = 0; i < 30; i++) {
        c.addPage();
      }
      expect(c.book!.pages.length, 31);
      await c.flush();
      c.dispose();
    },
  );
  test('physics responds to gravity and projectile returns to ground', () {
    expect(pendulumPeriod(2, 1.62), greaterThan(pendulumPeriod(2, 9.81)));
    final flight = 2 * 20 * math.sin(math.pi / 4) / 9.81;
    expect(projectile(flight, 20, 45, 9.81).dy, closeTo(0, .000001));
  });
  test('algorithm traces sort correctly and binary search reports index', () {
    expect(algorithmFrames('bubble sort', [5, 2, 1]).last.values, [1, 2, 5]);
    expect(
      algorithmFrames('insertion sort', [
        5,
        2,
        1,
      ], descending: true).last.values,
      [5, 2, 1],
    );
    expect(
      algorithmFrames('binary search', [5, 2, 1], target: 2).last.caption,
      contains('Found 2'),
    );
  });
  test('deterministic neural network actually learns XOR', () {
    final n = XorNetwork();
    n.train(5000);
    expect(n.accuracy, 1);
    expect(n.loss, lessThan(.05));
    expect(n.predict(0, 1), greaterThan(.9));
    expect(n.predict(1, 1), lessThan(.1));
  });
  test('InkMind Demo has six editable fixtures and original vector ink', () {
    final n = buildPlayground();
    expect(n.title, 'InkMind Demo');
    expect(n.pages.length, 6);
    expect(n.pages[0].strokes.length, 3);
    expect(n.pages[0].objects.any((o) => o.text == 'Moon'), true);
    expect(n.pages[1].strokes.length, greaterThan(20));
    expect(n.pages[2].objects.any((o) => o.text == '3x^2 - 1 = y'), true);
    expect(n.pages[3].strokes.length, greaterThanOrEqualTo(5));
  });
  test(
    'AI visual contract is validated and animation keeps a known system',
    () async {
      expect(
        VisualSpec.fromJson({
          'style': 'network',
          'title': 'XOR',
          'caption': 'A small network',
        })!.valid,
        true,
      );
      expect(
        VisualSpec.fromJson({
          'style': 'run arbitrary javascript',
          'title': 'x',
        }),
        isNull,
      );
      expect(
        animationSystemFromText('a soft spring with hand drawn loops'),
        'spring',
      );
      final response = await ModelRouter(
        smart: DemoModelEngine(),
      ).run(InkRequest('a calm orbit around a planet', InkAction.createVisual));
      expect(response.visual, isNotNull);
      expect(response.visual!.valid, true);
    },
  );
}
