import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import '../ai/browser_engine_stub.dart'
    if (dart.library.js_interop) '../ai/browser_engine_web.dart';
import '../living_ink/ink_motion_layer.dart';
import '../living_ink/ink_ir_motion.dart';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/models/ink.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/ink_toolbar.dart';
import '../ai/engine.dart';
import '../canvas/gestures.dart';
import '../canvas/painters.dart';
import '../inkcells/cell_view.dart';
import '../inkdebug/debug_view.dart';
import '../inkdebug/stroke_history.dart';
import '../inkscript/playground.dart';
import '../library/library.dart';
import '../living_ink/living_ink.dart';
import '../settings/settings.dart';
import '../visuals/visual_view.dart';
import 'controller.dart';

/// A direction hint is removable only when it is detached from the selected
/// drawing. Beaks, tails, wings, and other pointed parts can resemble arrows.
bool isDirectionArrowOverlay(InkStroke stroke, Iterable<InkStroke> selection) {
  final bounds = stroke.bounds;
  var arrowLike = recognizeGesture(stroke.points) == InkGesture.arrow;
  if (!arrowLike &&
      stroke.points.length >= 5 &&
      bounds.width >= 24 &&
      bounds.width > bounds.height * 1.2) {
    var reversals = 0;
    double? previousDx;
    var path = 0.0;
    for (var i = 1; i < stroke.points.length; i++) {
      final delta = stroke.points[i].position - stroke.points[i - 1].position;
      path += delta.distance;
      if (delta.dx.abs() > 2) {
        if (previousDx != null && previousDx * delta.dx < 0) reversals++;
        previousDx = delta.dx;
      }
    }
    final chord =
        (stroke.points.last.position - stroke.points.first.position).distance;
    arrowLike = reversals > 0 && chord > 1 && path / chord > 1.12;
  }
  if (!arrowLike) return false;
  for (final other in selection) {
    if (other.id == stroke.id || !bounds.inflate(12).overlaps(other.bounds))
      continue;
    for (final point in stroke.points) {
      if (other.points.any(
        (neighbor) =>
            (point.position - neighbor.position).distanceSquared <= 144,
      )) {
        return false;
      }
    }
  }
  return true;
}

class NotebookScreen extends StatefulWidget {
  final InkMindController controller;
  const NotebookScreen({super.key, required this.controller});
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final transform = TransformationController();
  final canvasKey = GlobalKey();
  final pageCaptureKey = GlobalKey();
  InkMindController get c => widget.controller;
  int? drawingPointer;
  final Set<int> pointers = {};
  int started = 0;
  bool gestureMode = false, working = false, moving = false;
  Offset? lastMove;
  String? fittedPage;
  double? viewportWidth;
  double viewportHeight = 800;
  List<InkPoint> raw = [];
  String status = 'A quiet place for a thought.';

  @override
  void dispose() {
    aiProgress?.cancel();
    if (working) cancelBrowserAi();
    transform.dispose();
    super.dispose();
  }

  void fit(double width) {
    final scale = math.min(
      (width - 32) / 720,
      math.min(1.08, (viewportHeight - 40) / 900),
    );
    transform.value = Matrix4.identity()
      ..translate((width - 720 * scale) / 2, 20.0)
      ..scale(scale);
    final ids = movingStrokeIds(c.page);
    if (ids.isNotEmpty) {
      final strokes = c.page.strokes.where((s) => ids.contains(s.id)).toList();
      if (strokes.isNotEmpty)
        focusInk(
          strokes.map((s) => s.bounds).reduce((a, b) => a.expandToInclude(b)),
          width: width,
        );
    }
  }

  void focusInk(Rect bounds, {double? width}) {
    final viewWidth = width ?? viewportWidth ?? 720;
    if (bounds.isEmpty || bounds.width > 500 || bounds.height > 700) return;
    final scale = math
        .min(
          2.4,
          math.min(
            viewWidth * .60 / (bounds.width + 80),
            viewportHeight * .62 / (bounds.height + 120),
          ),
        )
        .clamp(.8, 2.4);
    transform.value = Matrix4.identity()
      ..translate(
        viewWidth / 2 - bounds.center.dx * scale,
        viewportHeight / 2 - bounds.center.dy * scale,
      )
      ..scale(scale);
  }

  Offset local(PointerEvent e) =>
      (canvasKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(
        e.position,
      );
  bool objectAt(Offset p) => c.page.objects.any(
    (o) => Rect.fromLTWH(o.x, o.y, o.width, o.height).contains(p),
  );
  void down(PointerDownEvent e) {
    pointers.add(e.pointer);
    if (pointers.length > 1) {
      drawingPointer = null;
      raw = [];
      c.activeInk.value = [];
      return;
    }
    if (c.tool == InkTool.hand ||
        e.buttons == kMiddleMouseButton ||
        (e.kind == PointerDeviceKind.touch &&
            c.preferences['fingerNavigation'] == true)) {
      return;
    }
    final p = local(e);
    if (objectAt(p) && c.tool != InkTool.lasso && !gestureMode) return;
    drawingPointer = e.pointer;
    started = DateTime.now().millisecondsSinceEpoch;
    raw = [InkPoint(p, pressure(e), 0)];
    if (c.tool == InkTool.eraser) {
      c.checkpoint();
      c.erase(p);
      return;
    }
    if (c.tool == InkTool.lasso &&
        c.selectedStrokes.any(
          (id) => c.page.strokes.any(
            (s) => s.id == id && s.bounds.inflate(12).contains(p),
          ),
        )) {
      moving = true;
      lastMove = p;
      c.checkpoint();
      return;
    }
    c.activeInk.value = raw;
  }

  double pressure(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus && e.pressureMax > e.pressureMin
      ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(
          .05,
          1,
        )
      : .5;
  void move(PointerMoveEvent e) {
    if (drawingPointer != e.pointer) return;
    final p = local(e);
    if (moving) {
      c.moveSelection(p - lastMove!);
      lastMove = p;
      return;
    }
    if (c.tool == InkTool.eraser) {
      c.erase(p);
      return;
    }
    if (raw.isNotEmpty && (p - raw.last.position).distance < .5) return;
    raw.add(
      InkPoint(p, pressure(e), DateTime.now().millisecondsSinceEpoch - started),
    );
    c.activeInk.value = List.of(raw);
  }

  void up(PointerEvent e) {
    pointers.remove(e.pointer);
    if (drawingPointer != e.pointer) return;
    drawingPointer = null;
    if (moving) {
      moving = false;
      raw = [];
      return;
    }
    if (c.tool == InkTool.eraser) return;
    final points = simplifyStroke(raw);
    raw = [];
    c.activeInk.value = [];
    if (points.isEmpty) return;
    if (gestureMode) {
      handleGesture(points);
      return;
    }
    if (c.tool == InkTool.lasso) {
      c.selectRect(InkStroke(id: 'selection', points: points).bounds);
      setState(
        () => status =
            '${c.selectedStrokes.length} strokes / ${c.selectedObjects.length} objects selected',
      );
      return;
    }
    c.addStroke(
      InkStroke(
        id: newId(),
        points: points,
        tool: c.tool,
        color: c.inkColor,
        width: c.inkWidth,
        created: started,
      ),
    );
  }

  void handleGesture(List<InkPoint> points) {
    final normalized = normalizeShape(points);
    for (final command in c.preferences['commands'] as List? ?? []) {
      final shape = (command['shape'] as List)
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
          .toList();
      if (shapeSimilarity(normalized, shape) > .89) {
        runAction(InkAction.values.byName(command['action']));
        return;
      }
    }
    final gesture = recognizeGesture(points);
    if (gesture == InkGesture.circle || gesture == InkGesture.box) {
      c.selectRect(InkStroke(id: 'gesture', points: points).bounds);
      setState(
        () =>
            status = 'Selection ready. Draw ? or a check, or choose an action.',
      );
      return;
    }
    final action = switch (gesture) {
      InkGesture.question => InkAction.explain,
      InkGesture.arrow => InkAction.continueIdea,
      InkGesture.check => InkAction.check,
      InkGesture.crossOut => InkAction.rewrite,
      _ => null,
    };
    if (action != null) {
      runAction(action);
    } else {
      setState(
        () => status =
            'Symbol not recognized. Choose an action below, or teach it in Settings.',
      );
    }
  }

  Future<void> runAction(InkAction action) async {
    if (action == InkAction.animateInk) {
      await animateInk();
      return;
    }
    if (working) return;
    var source = c.recognizedText;
    if (source.isEmpty && c.selectedStrokes.isEmpty) {
      // Playground pages are deliberately ready to use: a single tap on an AI
      // action should work even before the user learns selection mechanics.
      final demo = c.page.objects
          .where(
            (o) =>
                o.kind == 'text' &&
                o.data['style'] != 'caption' &&
                o.text.trim().isNotEmpty,
          )
          .firstOrNull;
      if (demo != null) {
        c.selectObject(demo);
        source = demo.text;
      }
    }
    if (source.isEmpty && c.selectedStrokes.isNotEmpty && kIsWeb) {
      source = 'Read the selected handwriting exactly from the image.';
    }
    if (source.isEmpty) {
      final label = await askText(
        context,
        'What does this ink say?',
        hint: 'Type the selected content if handwriting was not recognized',
        lines: 3,
      );
      if (label == null || label.trim().isEmpty) return;
      source = label;
      c.associateLabel(label);
    }
    if (!mounted) return;
    var requestText = source;
    if (action == InkAction.createVisual || action == InkAction.makeAlive) {
      final equation = RegExp(
        r'\by\s*=|=\s*y\b',
        caseSensitive: false,
      ).hasMatch(source);
      final instruction = await askText(
        context,
        'What should this become?',
        initial: equation ? 'Make a graph of this exact equation' : '',
        hint: 'Describe the visual you want from the selection',
        lines: 2,
      );
      if (instruction == null || !mounted) return;
      requestText =
          'Selected content: $source\nInstruction: '
          '${instruction.trim().isEmpty ? 'Create an interactive visual from this selection' : instruction.trim()}';
    }
    startWorking();
    final pageId = c.page.id;
    try {
      final selection = await selectionSnapshot(
        c.page.strokes.where((s) => c.selectedStrokes.contains(s.id)).toList(),
        c.page.objects.where((o) => c.selectedObjects.contains(o.id)).toList(),
      );
      final response = await c.action(
        action,
        text: requestText,
        selection: selection,
      );
      if (!mounted || c.book == null || c.page.id != pageId) return;
      c.checkpoint();
      final selected = c.page.objects
          .where((o) => c.selectedObjects.contains(o.id))
          .toList();
      final bottoms = [
        ...selected.map((o) => o.y + o.height),
        ...c.page.strokes
            .where((s) => c.selectedStrokes.contains(s.id))
            .map((s) => s.bounds.bottom),
      ];
      final bottom = bottoms.isEmpty ? 240.0 : bottoms.reduce(math.max);
      final y = (bottom + 34).clamp(180.0, 650.0);
      PageObject object;
      if (action == InkAction.debug &&
          response.debug != null &&
          response.debug!.supported) {
        object = PageObject(
          kind: 'debug',
          text: 'Reasoning replay',
          y: y,
          height: 430,
          data: {
            'source': source,
            'steps': response.debug!.steps,
            'firstError': response.debug!.firstError,
            'explanation': response.debug!.explanation,
            'corrected': response.debug!.corrected,
            'engine': response.engine,
            'strokeHistory': captureStrokeHistory(
              c.page.strokes.where((s) => c.selectedStrokes.contains(s.id)),
            ),
          },
        );
      } else if (response.visual != null) {
        object = PageObject(
          kind: 'visual',
          text: response.visual!.title,
          y: y,
          width: 560,
          height: response.visual!.style == 'ir' ? 620 : 365,
          data: {
            ...response.visual!.toJson(),
            if (response.visual!.style == 'code')
              'title': source.length > 58
                  ? '${source.substring(0, 58)}…'
                  : source,
            'engine': response.engine,
          },
        );
      } else if (response.cell != null) {
        object = response.cell!.toObject(y: y);
        object.height = response.cell!.type == 'quiz' ? 390 : 365;
      } else {
        object = PageObject(
          kind: 'annotation',
          text: response.text,
          y: y,
          height: 185,
          data: {'engine': response.engine},
        );
      }
      c.page.objects.add(object);
      c.selectObject(object);
      c.changed();
      final scale = transform.value.getMaxScaleOnAxis();
      final bottomOnScreen =
          (object.y + object.height) * scale + transform.value.storage[13];
      if (bottomOnScreen > viewportHeight - 20) {
        final matrix = transform.value.clone();
        matrix.setTranslationRaw(
          matrix.storage[12],
          viewportHeight - 25 - (object.y + object.height) * scale,
          0,
        );
        transform.value = matrix;
      }
      setState(
        () => status = response.cell != null
            ? 'An idea, made interactive.'
            : response.visual != null
            ? 'A new visual, composed from your idea.'
            : response.debug != null
            ? 'Follow the reasoning, one step at a time.'
            : 'A note beside your thinking.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => status = e.toString().replaceFirst('Bad state: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => runAction(action),
            ),
          ),
        );
      }
    } finally {
      finishWorking();
    }
  }

  Future<void> addText({bool modifier = false}) async {
    final text = await askText(
      context,
      modifier ? 'A word that changes things' : 'Add a thought',
      hint: modifier
          ? 'Moon, 3x velocity, no friction...'
          : 'An equation, some notes, an idea...',
      lines: modifier ? 1 : 3,
    );
    if (text == null || text.trim().isEmpty) return;
    c.checkpoint();
    final o = PageObject(
      kind: modifier ? 'modifier' : 'text',
      text: text,
      y: 170 + c.page.objects.length * 45.0,
      width: modifier ? 170 : 520,
      height: modifier ? 65 : math.max(75, text.split('\n').length * 34.0),
    );
    c.page.objects.add(o);
    c.selectObject(o);
    c.changed();
  }

  Future<void> living() => animateInk();

  Future<Map<String, dynamic>> selectionSnapshot(
    List<InkStroke> strokes,
    List<PageObject> objects,
  ) async {
    final content = <ui.Rect>[
      for (final stroke in strokes) stroke.bounds,
      for (final object in objects)
        ui.Rect.fromLTWH(object.x, object.y, object.width, object.height),
    ];
    final result = <String, dynamic>{
      // Full visual content, without IDs/timestamps or transient selection UI.
      // A recognition cache must invalidate on every actual drawing change.
      if (objects.isEmpty)
        'visionContent': [
          c.dark,
          for (final s in strokes)
            [
              s.tool.index,
              s.color,
              s.width,
              for (final p in s.points)
                [p.position.dx, p.position.dy, p.pressure],
            ],
        ],
      'strokes': [
        for (final s in strokes)
          {
            'id': s.id,
            if (c.page.labels[s.id] != null) 'label': c.page.labels[s.id],
            'bounds': [
              s.bounds.left.round(),
              s.bounds.top.round(),
              s.bounds.right.round(),
              s.bounds.bottom.round(),
            ],
            'points': [
              for (
                var i = 0;
                i < s.points.length;
                i += math.max(1, (s.points.length / 32).ceil())
              )
                [
                  s.points[i].position.dx.round(),
                  s.points[i].position.dy.round(),
                ],
            ],
          },
      ],
      'objects': [
        for (final o in objects)
          {
            'id': o.id,
            'kind': o.kind,
            'text': o.text,
            'bounds': [
              o.x.round(),
              o.y.round(),
              (o.x + o.width).round(),
              (o.y + o.height).round(),
            ],
            if (o.data['script'] is String) 'script': o.data['script'],
            if (o.data['source'] is String) 'source': o.data['source'],
          },
      ],
    };
    if (content.isEmpty || !kIsWeb) return result;
    final boundary = pageCaptureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return result;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      var crop = content.reduce((a, b) => a.expandToInclude(b)).inflate(20);
      crop = crop.intersect(
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
      if (crop.isEmpty) return result;
      final scale = math.min(1.0, 512 / math.max(crop.width, crop.height));
      final width = math.max(1, (crop.width * scale).round());
      final height = math.max(1, (crop.height * scale).round());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        crop,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint(),
      );
      final clipped = await recorder.endRecording().toImage(width, height);
      try {
        final png = await clipped.toByteData(format: ui.ImageByteFormat.png);
        if (png != null)
          result['image'] =
              'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
      } finally {
        clipped.dispose();
      }
    } finally {
      image.dispose();
    }
    return result;
  }

  Future<void> animateInk() async {
    if (working) return;
    final picked = c.selectedStrokes.isEmpty
        ? c.page.strokes.toList()
        : c.page.strokes
              .where((s) => c.selectedStrokes.contains(s.id))
              .toList();
    if (picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw or write something on this page first.'),
        ),
      );
      return;
    }
    // A hand-drawn direction arrow is an instruction overlay, not part of the
    // object being animated. Keep it out of the vision prompt and remove it
    // after the motion is accepted so it cannot remain as a floating static
    // stroke beside the animation.
    final arrowIds = picked
        .where((s) => isDirectionArrowOverlay(s, picked))
        .map((s) => s.id)
        .toSet();
    final chosen = picked.where((s) => !arrowIds.contains(s.id)).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the ink you want to animate.')),
      );
      return;
    }
    final intent = await askText(
      context,
      'How should your ink move?',
      initial: c.recognizedText,
      hint: 'For example: swing the bob, keeping the support fixed',
      lines: 3,
    );
    if (intent == null || intent.trim().isEmpty || !mounted) return;
    final pageId = c.page.id;
    final bookId = c.book!.id;
    final originals = {
      for (final s in chosen) s.id: base64Encode(StrokeCodec.encode(s)),
    };
    startWorking();
    try {
      final selection = await selectionSnapshot(
        chosen,
        c.page.objects.where((o) => c.selectedObjects.contains(o.id)).toList(),
      );
      final response = await c.action(
        InkAction.animateInk,
        text: intent,
        selection: selection,
      );
      if (!mounted || c.book?.id != bookId || c.page.id != pageId) return;
      if (response.motion == null)
        throw StateError('The model returned no motion plan.');
      final ir = response.motion!['ir'];
      final bindings = ir is Map
          ? bindInkAnimation(
              Map<String, dynamic>.from(ir),
              c.page,
              originals.keys.toSet(),
            )
          : <String, List<String>>{};
      if (ir is Map) response.motion!['bindings'] = bindings;
      final ids = ir is Map
          ? bindings.values.expand((x) => x).toSet().toList()
          : (response.motion!['tracks'] as List)
                .expand((t) => (t['ids'] as List).cast<String>())
                .toList();
      if (ids.isEmpty || ids.any((id) => !originals.containsKey(id)))
        throw StateError('The motion plan references invalid strokes. Retry.');
      for (final id in originals.keys) {
        final current = c.page.strokes.where((s) => s.id == id).firstOrNull;
        if (current == null ||
            base64Encode(StrokeCodec.encode(current)) != originals[id])
          throw StateError(
            'Your ink changed during generation. Select it again.',
          );
      }
      c.checkpoint();
      if (arrowIds.isNotEmpty) {
        c.page.strokes.removeWhere((s) => arrowIds.contains(s.id));
      }
      c.page.objects.removeWhere(
        (o) =>
            o.kind == 'inkMotion' &&
            movingIdsForMotion(o).any(originals.containsKey),
      );
      c.page.objects.add(
        PageObject(
          kind: 'inkMotion',
          text: response.text,
          data: response.motion!,
        ),
      );
      c.clearSelection(notify: false);
      c.changed();
      final bounds = chosen
          .map((s) => s.bounds)
          .reduce((a, b) => a.expandToInclude(b));
      focusInk(bounds);
      final arrowNote = arrowIds.isEmpty ? '' : ' · direction arrow removed';
      setState(() => status = '${response.engine}: ${response.text}$arrowNote');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      finishWorking();
    }
  }

  Timer? aiProgress;
  void startWorking() {
    setState(() {
      working = true;
      status = 'Starting AI…';
    });
    aiProgress?.cancel();
    aiProgress = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && working) setState(() => status = browserAiStatus());
    });
  }

  void finishWorking() {
    aiProgress?.cancel();
    if (mounted) setState(() => working = false);
  }

  @override
  Widget build(BuildContext context) {
    final layout = InkLayout.of(context);
    final colors = InkColors.of(context);
    final hasSelection =
        c.selectedObjects.isNotEmpty || c.selectedStrokes.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            c.redo,
        SingleActivator(LogicalKeyboardKey.delete): c.deleteSelection,
        SingleActivator(LogicalKeyboardKey.escape): c.clearSelection,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.workspace,
          body: SafeArea(
            child: Column(
              children: [
                _topBar(layout, colors),
                if (working) ...[
                  const InkLineLoader(),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            status,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => cancelBrowserAi(),
                        child: const Text('Cancel AI'),
                      ),
                    ],
                  ),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      viewportHeight = constraints.maxHeight;
                      if (fittedPage != c.page.id ||
                          viewportWidth != constraints.maxWidth) {
                        fittedPage = c.page.id;
                        viewportWidth = constraints.maxWidth;
                        fit(constraints.maxWidth);
                      }
                      return Stack(
                        children: [
                          Positioned.fill(child: _canvas(colors)),
                          if (!layout.isPhone)
                            Positioned(
                              left: 16,
                              bottom: hasSelection ? 72 : 20,
                              child: InkToolbar(
                                tool: c.tool,
                                gestureMode: gestureMode,
                                inkColor: c.inkColor,
                                inkWidth: c.inkWidth,
                                phone: false,
                                onTool: (t) {
                                  setState(() => gestureMode = false);
                                  c.setTool(t);
                                },
                                onToggleGesture: () =>
                                    setState(() => gestureMode = !gestureMode),
                                onColor: (v) {
                                  c.inkColor = v;
                                  c.changed();
                                },
                                onWidth: (v) {
                                  c.inkWidth = v;
                                  c.changed();
                                },
                                onAddText: () => addText(),
                                onAddModifier: () => addText(modifier: true),
                                trailing: hasSelection
                                    ? _selectionMenu(colors)
                                    : null,
                              ),
                            ),
                          Positioned(
                            right: 14,
                            bottom: layout.isPhone
                                ? (hasSelection ? 8 : 12)
                                : 20,
                            child: _zoomControls(colors, constraints.maxWidth),
                          ),
                          if (hasSelection || c.book!.playground || working)
                            Positioned(
                              left: layout.isPhone ? 10 : null,
                              right: layout.isPhone ? 10 : 14,
                              bottom: layout.isPhone ? 8 : 20,
                              child: InkContextActions(
                                working: working,
                                compact: layout.isPhone,
                                onExplain: () => runAction(InkAction.explain),
                                onMakeAlive: () =>
                                    runAction(InkAction.makeAlive),
                                onAnimateInk: animateInk,
                                onCreateVisual: () =>
                                    runAction(InkAction.createVisual),
                                onRunInk: living,
                                onDebug: () => runAction(InkAction.debug),
                                onQuiz: () => runAction(InkAction.quiz),
                                onMore: runAction,
                              ),
                            ),
                          if (c.developer)
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: .94),
                                  borderRadius: BorderRadius.circular(
                                    InkTokens.r8,
                                  ),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  '${c.page.strokes.length} strokes / ${c.page.strokes.fold<int>(0, (n, s) => n + s.points.length)} points\n${(c.storageBytes / 1024).toStringAsFixed(1)} KB',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          if (!working && status.isNotEmpty && !layout.isPhone)
                            Positioned(
                              left: 20,
                              top: 12,
                              child: IgnorePointer(
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (layout.isPhone)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: InkToolbar(
                      tool: c.tool,
                      gestureMode: gestureMode,
                      inkColor: c.inkColor,
                      inkWidth: c.inkWidth,
                      phone: true,
                      onTool: (t) {
                        setState(() => gestureMode = false);
                        c.setTool(t);
                      },
                      onToggleGesture: () =>
                          setState(() => gestureMode = !gestureMode),
                      onColor: (v) {
                        c.inkColor = v;
                        c.changed();
                      },
                      onWidth: (v) {
                        c.inkWidth = v;
                        c.changed();
                      },
                      onAddText: () => addText(),
                      onAddModifier: () => addText(modifier: true),
                      trailing: hasSelection ? _selectionMenu(colors) : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(InkLayout layout, InkColors colors) {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: layout.isPhone ? 2 : 8),
      decoration: BoxDecoration(
        color: colors.workspace,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: .7)),
        ),
      ),
      child: Row(
        children: [
          InkIconBtn(
            tooltip: 'Back to library',
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: c.close,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.book!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: layout.isPhone ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '${(c.pageIndex + 1).toString().padLeft(2, '0')} / ${c.saveStatus}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          InkIconBtn(
            tooltip: 'Undo',
            icon: Icons.undo_rounded,
            onPressed: c.canUndo ? c.undo : null,
          ),
          InkIconBtn(
            tooltip: 'Redo',
            icon: Icons.redo_rounded,
            onPressed: c.canRedo ? c.redo : null,
          ),
          InkIconBtn(
            tooltip: 'Previous page',
            icon: Icons.chevron_left_rounded,
            onPressed: c.pageIndex > 0 ? () => c.goTo(c.pageIndex - 1) : null,
          ),
          InkIconBtn(
            tooltip: 'Next page',
            icon: Icons.chevron_right_rounded,
            onPressed: c.pageIndex < c.book!.pages.length - 1
                ? () => c.goTo(c.pageIndex + 1)
                : null,
          ),
          InkIconBtn(
            tooltip: 'Add page',
            icon: Icons.add_rounded,
            onPressed: c.addPage,
          ),
          InkIconBtn(
            tooltip: 'Page overview',
            icon: Icons.grid_view_rounded,
            onPressed: overview,
          ),
          PopupMenuButton<String>(
            tooltip: 'Notebook settings',
            onSelected: (v) {
              if (v == 'settings') {
                showSettings(context, c);
              } else if (v == 'inkscript') {
                showDialog<void>(
                  context: context,
                  builder: (_) => InkScriptPlayground(
                    onApply: (ir, source) {
                      final root = Map<String, dynamic>.from(ir['root'] as Map);
                      final titleNode = (root['props'] as Map?)?['title'];
                      final title = titleNode is Map
                          ? titleNode['value']?.toString()
                          : null;
                      final spec = VisualSpec(
                        style: 'ir',
                        title: title ?? 'InkScript visual',
                        caption: 'Interactive playground visual',
                        ir: ir,
                        script: source,
                      );
                      c.checkpoint();
                      c.page.objects.add(
                        PageObject(
                          kind: 'visual',
                          text: spec.title,
                          x: 76,
                          y: 260,
                          width: 560,
                          height: 500,
                          data: spec.toJson(),
                        ),
                      );
                      c.changed();
                    },
                  ),
                );
              } else if (v == 'pro') {
                showPaywall(context, c);
              } else if (v == 'title') {
                askText(context, 'Rename page', initial: c.page.title).then((
                  s,
                ) {
                  if (s != null) {
                    c.page.title = s;
                    c.changed();
                  }
                });
              } else {
                c.checkpoint();
                c.page.paper = PaperKind.values.byName(v);
                c.changed();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'inkscript',
                child: Text('InkScript playground'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings & AI models'),
              ),
              const PopupMenuItem(value: 'title', child: Text('Rename page')),
              const PopupMenuDivider(),
              ...PaperKind.values.map(
                (p) => PopupMenuItem(
                  value: p.name,
                  child: Text(
                    '${p == c.page.paper ? 'Selected: ' : ''}${p.name[0].toUpperCase()}${p.name.substring(1)} paper',
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'pro', child: Text('InkMind Pro')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.more_horiz,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas(InkColors colors) {
    return InteractiveViewer(
      transformationController: transform,
      constrained: false,
      minScale: .25,
      maxScale: 4,
      boundaryMargin: const EdgeInsets.all(600),
      panEnabled:
          c.tool == InkTool.hand || c.preferences['fingerNavigation'] == true,
      scaleEnabled: true,
      trackpadScrollCausesScale: true,
      child: Listener(
        key: canvasKey,
        onPointerDown: down,
        onPointerMove: move,
        onPointerUp: up,
        onPointerCancel: (e) {
          pointers.remove(e.pointer);
          drawingPointer = null;
          raw = [];
          c.activeInk.value = [];
        },
        child: RepaintBoundary(
          key: pageCaptureKey,
          child: Container(
            width: 720,
            height: 1080,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InkTokens.rPaper),
              boxShadow: InkTokens.paperShadow(c.dark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(InkTokens.rPaper),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: PaperPainter(c.page.paper, c.dark),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 65,
                    top: 40,
                    right: 60,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.page.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 22,
                                color: colors.textPrimary.withValues(
                                  alpha: .85,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'InkMind',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: StrokePainter(
                          c.page.strokes
                              .where(
                                (s) => !motionStrokeIds(c.page).contains(s.id),
                              )
                              .toList(),
                          selected: Set.of(c.selectedStrokes),
                          dark: c.dark,
                        ),
                      ),
                    ),
                  ),
                  if (c.page.objects.any((o) => o.kind == 'inkMotion'))
                    Positioned.fill(
                      child: InkMotionLayer(
                        key: ValueKey(
                          'motion-${c.page.id}-${c.page.objects.where((o) => o.kind == 'inkMotion').map((o) => o.id).join('-')}',
                        ),
                        page: c.page,
                        beforeEdit: c.checkpoint,
                        onEdited: c.changed,
                        dark: c.dark,
                      ),
                    ),
                  ...c.page.objects
                      .where((o) => o.kind != 'inkMotion')
                      .map(objectView),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: ActiveStrokePainter(
                            c.activeInk,
                            gestureMode ? InkTool.lasso : c.tool,
                            c.inkColor,
                            c.inkWidth,
                            c.dark,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 28,
                    left: 65,
                    child: IgnorePointer(
                      child: Text(
                        '${c.pageIndex + 1} / ${c.book!.pages.length}',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: .8,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _zoomControls(InkColors colors, double width) {
    return Material(
      color: colors.surface.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(InkTokens.r12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InkTokens.r12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkIconBtn(
              tooltip: 'Zoom out',
              icon: Icons.remove,
              size: 32,
              onPressed: () => zoom(.8),
            ),
            InkIconBtn(
              tooltip: 'Fit page width',
              icon: Icons.fit_screen,
              size: 32,
              onPressed: () => setState(() => fit(width)),
            ),
            InkIconBtn(
              tooltip: 'Zoom in',
              icon: Icons.add,
              size: 32,
              onPressed: () => zoom(1.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionMenu(InkColors colors) {
    return PopupMenuButton<String>(
      tooltip: 'Selection options',
      onSelected: (v) async {
        if (v == 'delete') {
          c.deleteSelection();
        } else if (v == 'clear') {
          c.clearSelection();
        } else if (v == 'scale') {
          c.checkpoint();
          c.page.strokes = c.page.strokes
              .map(
                (s) => c.selectedStrokes.contains(s.id)
                    ? s.transformed(
                        Offset.zero,
                        scale: 1.15,
                        origin: s.bounds.center,
                      )
                    : s,
              )
              .toList();
          c.changed();
        } else if (v == 'color') {
          c.checkpoint();
          c.page.strokes = c.page.strokes
              .map(
                (s) => c.selectedStrokes.contains(s.id)
                    ? InkStroke(
                        id: s.id,
                        points: s.points,
                        color: c.inkColor,
                        width: s.width,
                        tool: s.tool,
                        created: s.created,
                      )
                    : s,
              )
              .toList();
          c.changed();
        } else {
          final text = await askText(
            context,
            'Demo recognition label',
            initial: c.recognizedText,
            lines: 3,
          );
          if (text != null) c.associateLabel(text);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'label', child: Text('Associate recognized text')),
        PopupMenuItem(
          value: 'color',
          child: Text('Apply current color to ink'),
        ),
        PopupMenuItem(value: 'scale', child: Text('Enlarge selected ink')),
        PopupMenuItem(value: 'clear', child: Text('Clear selection')),
        PopupMenuItem(value: 'delete', child: Text('Delete selection')),
      ],
      child: Icon(Icons.more_vert, size: 18, color: colors.textSecondary),
    );
  }

  void zoom(double factor) {
    final next = transform.value.clone();
    final scale = next.getMaxScaleOnAxis();
    if (scale * factor < .25 || scale * factor > 4) return;
    next.scale(factor);
    transform.value = next;
  }

  Widget objectView(PageObject o) {
    final selected = c.selectedObjects.contains(o.id);
    final colors = InkColors.of(context);
    final visualHeight = o.kind == 'visual' && o.data['style'] == 'ir'
        ? math.max(o.height, 620.0)
        : o.height;
    Widget child;
    if (o.kind == 'living') {
      child = LivingInk(key: ValueKey(o.id), object: o, onChanged: c.changed);
    } else if (o.kind == 'visual') {
      child = AiVisualView(key: ValueKey(o.id), object: o);
    } else if (o.kind == 'debug') {
      child = DebugView(key: ValueKey(o.id), object: o);
    } else if (CellSpec.types.contains(o.kind)) {
      child = InkCellView(key: ValueKey(o.id), object: o, onChanged: c.changed);
    } else if (o.kind == 'modifier') {
      Widget chip({bool lifting = false}) => AnimatedContainer(
        duration: InkTokens.quick,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        transform: lifting
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: BorderRadius.circular(InkTokens.r8),
          border: Border.all(
            color: colors.accent.withValues(alpha: lifting ? .55 : .28),
          ),
          boxShadow: lifting ? InkTokens.lift(.12) : InkTokens.lift(.04),
        ),
        child: Text(
          o.text,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 24,
            color: colors.accent,
          ),
        ),
      );
      child = Draggable<String>(
        data: o.text,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: o.width,
            height: o.height,
            child: chip(lifting: true),
          ),
        ),
        childWhenDragging: Opacity(opacity: .2, child: chip()),
        onDragStarted: () => InkHaptics.medium(),
        onDragEnd: (details) {
          if (!details.wasAccepted) {
            final box =
                canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (box != null) {
              final p = box.globalToLocal(details.offset);
              c.checkpoint();
              o.x = p.dx.clamp(0, 720 - o.width);
              o.y = p.dy.clamp(80, 1080 - o.height);
              c.changed();
            }
          } else {
            InkHaptics.success();
          }
        },
        child: chip(),
      );
    } else if (o.kind == 'annotation') {
      child = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.accentSoft.withValues(alpha: c.dark ? .4 : .55),
          borderRadius: BorderRadius.circular(InkTokens.r8),
          border: Border(
            left: BorderSide(
              color: colors.accent.withValues(alpha: .45),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .6,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  o.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final caption = o.data['style'] == 'caption';
      final notes = o.data['style'] == 'notes';
      child = GestureDetector(
        onTap: () => c.selectObject(o),
        onLongPress: () async {
          final text = await askText(
            context,
            'Edit your thought',
            initial: o.text,
            lines: 3,
          );
          if (text != null) {
            c.checkpoint();
            o.text = text;
            c.changed();
          }
        },
        onPanStart: selected ? (_) => c.checkpoint() : null,
        onPanUpdate: selected
            ? (d) {
                final scale = transform.value.getMaxScaleOnAxis();
                o.x = (o.x + d.delta.dx / scale).clamp(0, 720 - o.width);
                o.y = (o.y + d.delta.dy / scale).clamp(80, 1080 - o.height);
                c.changed();
              }
            : null,
        child: Container(
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.transparent,
          child: Text(
            o.text,
            style: TextStyle(
              fontFamily: caption
                  ? 'Segoe UI'
                  : notes
                  ? 'Lora'
                  : 'Caveat',
              fontSize: caption
                  ? 13
                  : notes
                  ? 20
                  : 29,
              height: caption ? 1.8 : 1.7,
              letterSpacing: caption ? 0.5 : 0,
              color: caption ? colors.textSecondary : colors.textPrimary,
            ),
          ),
        ),
      );
    }
    return Positioned(
      key: ValueKey('position-${o.id}'),
      left: o.x,
      top: o.y,
      width: o.width,
      height: visualHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => c.selectObject(o),
              child: AnimatedContainer(
                duration: InkTokens.quick,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? colors.accent.withValues(alpha: .4)
                        : Colors.transparent,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(InkTokens.r12),
                ),
                child: child,
              ),
            ),
          ),
          if (selected) ...[
            Positioned(
              right: 4,
              top: -22,
              child: GestureDetector(
                onPanStart: (_) => c.checkpoint(),
                onPanUpdate: (d) {
                  final scale = transform.value.getMaxScaleOnAxis();
                  o.x = (o.x + d.delta.dx / scale).clamp(0, 720 - o.width);
                  o.y = (o.y + d.delta.dy / scale).clamp(80, 1080 - o.height);
                  c.changed();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(InkTokens.r8),
                  ),
                  child: const Text(
                    'Move',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: GestureDetector(
                onPanStart: (_) => c.checkpoint(),
                onPanUpdate: (d) {
                  final scale = transform.value.getMaxScaleOnAxis();
                  o.width = (o.width + d.delta.dx / scale).clamp(
                    o.kind == 'text' ? 180 : 300,
                    720 - o.x,
                  );
                  o.height = (o.height + d.delta.dy / scale).clamp(
                    o.kind == 'text' ? 60 : 250,
                    1080 - o.y,
                  );
                  c.changed();
                },
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.accent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> overview() {
    final layout = InkLayout.of(context);
    final colors = InkColors.of(context);
    if (layout.isPhone) {
      return showInkSheet(
        context: context,
        heightFactor: .82,
        builder: (context) => _pageNavigator(colors),
      );
    }
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Pages',
      barrierColor: Colors.black.withValues(alpha: .28),
      transitionDuration: InkTokens.settle,
      pageBuilder: (context, anim, secondary) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: colors.surface,
            child: Container(
              width: 320,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.border)),
              ),
              child: SafeArea(child: _pageNavigator(colors)),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secondary, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: InkTokens.easeOut)),
          child: child,
        );
      },
    );
  }

  Widget _pageNavigator(InkColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              Expanded(child: Text('Pages', style: editorial(context, 22))),
              InkIconBtn(
                tooltip: 'Add page',
                icon: Icons.add_rounded,
                onPressed: () {
                  c.addPage();
                  Navigator.pop(context);
                },
              ),
              InkIconBtn(
                tooltip: 'Close',
                icon: Icons.close,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: c.book!.pages.length,
            onReorder: (a, b) {
              c.reorderPage(a, b);
              Navigator.pop(context);
            },
            itemBuilder: (context, i) {
              final p = c.book!.pages[i];
              final current = i == c.pageIndex;
              return Padding(
                key: ValueKey(p.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: current ? colors.accentSoft : colors.chrome,
                  borderRadius: BorderRadius.circular(InkTokens.r12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(InkTokens.r12),
                    onTap: () {
                      c.goTo(i);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(InkTokens.r8),
                              border: Border.all(
                                color: current
                                    ? colors.accent
                                    : colors.borderStrong,
                                width: current ? 1.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: CustomPaint(
                                painter: ThumbnailPainter(p, c.dark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Page ${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'duplicate') {
                                c.duplicatePage(i);
                                Navigator.pop(context);
                              } else if (await confirmDelete(
                                context,
                                'this page',
                              )) {
                                c.deletePage(i);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              if (c.book!.pages.length > 1)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ThumbnailPainter extends CustomPainter {
  final InkPage page;
  final bool dark;
  ThumbnailPainter(this.page, this.dark);
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 720, s.height / 1080);
    PaperPainter(page.paper, dark).paint(c, const Size(720, 1080));
    StrokePainter(page.strokes, dark: dark).paint(c, const Size(720, 1080));
    for (final o in page.objects) {
      final p = Paint()..color = const Color(0xffb85a3e).withValues(alpha: .18);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.x, o.y, o.width, o.height),
          const Radius.circular(8),
        ),
        p,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(ThumbnailPainter old) => true;
}
