import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/app/app.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/core/storage/repository.dart';
import 'package:inkmind/features/visuals/visual_view.dart';
import 'package:inkmind/features/inkdebug/debug_view.dart';
import 'package:inkmind/features/living_ink/living_ink.dart';
import 'package:inkmind/features/notebook/controller.dart';
import 'package:inkmind/features/notebook/playground.dart';
import 'package:inkmind/features/settings/settings.dart';

Future<InkMindController> start(
  WidgetTester tester, {
  bool playground = false,
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = MemoryRepository();
  repo.prefs = {'onboarding': true};
  final c = InkMindController(repo);
  await tester.pumpWidget(InkMindApp(controller: c));
  await tester.pumpAndSettle();
  if (playground) {
    c.openPlayground();
    await tester.pumpAndSettle();
  }
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('create notebook, draw, pen change, undo, add page and reopen', (
    tester,
  ) async {
    final c = await start(tester);
    await tester.tap(find.text('New notebook'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Field notes');
    await tester.tap(find.text('Create notebook'));
    await tester.pumpAndSettle();
    expect(c.book!.title, 'Field notes');
    final gesture = await tester.startGesture(Offset(350, 280));
    await gesture.moveTo(Offset(430, 350));
    await gesture.moveTo(Offset(540, 320));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.page.strokes.length, 1);
    await tester.tap(find.byTooltip('Pencil'));
    await tester.pump();
    expect(c.tool, InkTool.pencil);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(c.page.strokes, isEmpty);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(c.page.strokes.length, 1);
    await tester.tap(find.byTooltip('Add page'));
    await tester.pumpAndSettle();
    expect(c.book!.pages.length, 2);
    await tester.tap(find.byTooltip('Back to library'));
    await tester.pumpAndSettle();
    expect(find.text('Field notes'), findsWidgets);
    await tester.tap(find.text('Field notes').first);
    await tester.pumpAndSettle();
    expect(c.book!.pages.first.strokes.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Make Alive offers a new visual for selected notes', (
    tester,
  ) async {
    final c = await start(tester, playground: true);
    c.goTo(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3x^2 - 1 = y'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make Alive'));
    await tester.pumpAndSettle();
    expect(find.text('Animate my ink'), findsOneWidget);
    await tester.tap(find.text('Create a new visual'));
    await tester.pumpAndSettle();
    expect(find.text('What should this become?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Make it a graph');
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AiVisualView), findsOneWidget);
    expect(c.page.objects.last.kind, 'visual');
    await tester.pump(Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Living Ink runs and Moon drop changes gravity, removal restores',
    (tester) async {
      final c = await start(tester, playground: true);
      final pendulumStrokesForTest = pendulumStrokes();
      final data = pendulumStrokesForTest
          .map(
            (stroke) => {
              'id': stroke.id,
              'bytes': StrokeCodec.encode(stroke).toList(),
            },
          )
          .toList();
      c.open(
        Notebook(
          title: 'Physics test',
          pages: [
            InkPage(
              objects: [
                PageObject(
                  kind: 'living',
                  text: 'pendulum',
                  x: 65,
                  y: 180,
                  width: 560,
                  height: 430,
                  data: {'strokes': data, 'gravity': 9.81, 'length': 2.0},
                ),
                PageObject(kind: 'modifier', text: 'Moon', x: 105, y: 650),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LivingInk), findsOneWidget);
      await tester.tap(find.text('Run ink').first);
      await tester.pump(Duration(milliseconds: 400));
      expect(find.text('Pause ink'), findsOneWidget);
      final moon = find.text('Moon'), target = find.byType(LivingInk);
      await tester.dragFrom(
        tester.getCenter(moon),
        tester.getCenter(target) - tester.getCenter(moon),
      );
      await tester.pump(Duration(milliseconds: 350));
      final pendulum = c.page.objects.firstWhere((o) => o.kind == 'living');
      expect(pendulum.data['gravity'], 1.62);
      await tester.tap(find.text('Moon ×'));
      await tester.pump(Duration(milliseconds: 350));
      expect(pendulum.data['gravity'], 9.81);
      await tester.tap(find.text('Pause ink'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('debug identifies first error and renders correction branch', (
    tester,
  ) async {
    final c = await start(tester, playground: true);
    c.goTo(1);
    await tester.pumpAndSettle();
    // The example is real handwriting painted on the canvas, so select its
    // recorded strokes and attach the transcription used by this offline test.
    c.selectRect(const Rect.fromLTRB(80, 180, 650, 390));
    c.associateLabel('3x + 5 = 20\n3x = 25\nx = 8.33');
    await tester.pump();
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(find.byType(DebugView), findsOneWidget);
    expect(c.page.objects.last.data['corrected'], contains('x = 5'));
    expect(
      find.bySemanticsLabel(RegExp(r'Recorded pen history, .*Corrected branch:.*x = 5')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('quiz generation answers all questions and retries', (
    tester,
  ) async {
    final c = await start(tester, playground: true);
    final notesNotebook = c.create('Quiz test');
    notesNotebook.pages.first.objects.add(
      PageObject(
        kind: 'text',
        text:
            'A pendulum moves because gravity pulls its bob. The Moon has lower gravity.',
        data: {'style': 'notes'},
        height: 180,
      ),
    );
    c.open(notesNotebook);
    await tester.pumpAndSettle();
    c.selectObject(c.page.objects.first);
    await tester.pump();
    await tester.tap(find.text('Create quiz'));
    await tester.pumpAndSettle();
    final cell = c.page.objects.last;
    expect(cell.kind, 'quiz');
    final questions = cell.data['questions'] as List;
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i] as Map;
      final answer = q['answer'] as int;
      final label =
          '${String.fromCharCode(65 + answer)}   ${(q['choices'] as List)[answer]}';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(i == questions.length - 1 ? 'See score' : 'Next question →'),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.text('${questions.length} / ${questions.length}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QUESTION 1 OF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('model settings and explicit demo paywall entitlement', (
    tester,
  ) async {
    final c = await start(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('AI Engine: Demo Engine'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qwen 2.5 Coder 0.5B'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Use model').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use model').first);
    await tester.pumpAndSettle();
    expect(c.preferences['aiModel'], 'qwen-2.5-coder-0.5b');
    expect(tester.takeException(), isNull, reason: 'after selecting a model');
    await tester.scrollUntilVisible(
      find.text('Gemma 4 E2B'),
      260,
      scrollable: find
          .descendant(
            of: find.byType(SettingsDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Gemma 4 E2B'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'after browsing model list');
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after closing settings');
    showPaywall(tester.element(find.text('New notebook').first), c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'when opening paywall');
    expect(find.text('Make your\npaper think.'), findsOneWidget);
    await tester.tap(find.text('Continue with Annual'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'after tapping annual plan');
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.pro, true);
    expect(find.textContaining('No payment was taken'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'after enabling demo Pro');
  });
  testWidgets(
    'phone library notebook settings paywall have no layout exceptions',
    (tester) async {
      final c = await start(tester, size: Size(390, 844));
      expect(tester.takeException(), isNull);
      c.openPlayground();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      c.goTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      showSettings(tester.element(find.byTooltip('Notebook settings')), c);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
