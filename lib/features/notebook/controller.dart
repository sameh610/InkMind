import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide InkResponse;
import '../../core/models/ink.dart';
import '../../core/storage/repository.dart';
import '../ai/engine.dart';
import '../ai/browser_engine_stub.dart'
    if (dart.library.js_interop) '../ai/browser_engine_web.dart';
import '../subscriptions/subscriptions.dart';
import 'playground.dart';

class InkMindController extends ChangeNotifier {
  final NotebookRepository repository;
  late final ModelRouter router;
  final SubscriptionService subscription;
  InkMindController(
    this.repository, {
    ModelRouter? router,
    SubscriptionService? subscription,
  }) : subscription = subscription ?? DemoSubscriptionService() {
    this.router =
        router ??
        ModelRouter(
          requireAi: kIsWeb,
          smart: BrowserModelEngine(
            () => preferences['browserAi'] != false,
            selectedModel: () =>
                preferences['aiModel']?.toString() ?? 'Automatic',
            selectedQuant: () => preferences['aiQuant']?.toString() ?? 'Auto',
            performance: () =>
                preferences['aiPerformance']?.toString() ?? 'balanced',
          ),
        );
  }
  List<Notebook> notebooks = [];
  Map<String, dynamic> preferences = {};
  bool loading = true;
  String? error;
  String saveStatus = 'Saved on this device';
  Notebook? book;
  int pageIndex = 0;
  InkTool tool = InkTool.pen;
  int inkColor = 0xff303c38;
  double inkWidth = 2.5;
  final Set<String> selectedStrokes = {}, selectedObjects = {};
  final ValueNotifier<List<InkPoint>> activeInk = ValueNotifier([]);
  List<InkPage> _undo = [], _redo = [];
  final Map<String, Timer> _saveTimers = {};
  Future<void> _writeQueue = Future.value();
  bool get dark => preferences['dark'] == true;
  bool get onboardingDone => preferences['onboarding'] == true;
  bool get pro => subscription.pro;
  bool get developer => preferences['developer'] == true;
  InkPage get page => book!.pages[pageIndex];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  Future<void> initialize() async {
    var hadNotebooks = false;
    try {
      notebooks = await repository.load();
      preferences = await repository.settings();
      hadNotebooks = notebooks.isNotEmpty;
      if (!notebooks.any((n) => n.playground && n.title == 'InkMind Demo')) {
        // Seed a separate, editable demo notebook without replacing or
        // changing any notebooks that were already on this device.
        final demo = buildPlayground();
        notebooks.insert(0, demo);
        await repository.save(demo);
      }
      // The browser demo should be immediately explorable. Native builds keep
      // the gentle onboarding gate; web opens the real Playground on first run.
      if (kIsWeb && preferences['onboarding'] != true) {
        preferences['onboarding'] = true;
        preferences['browserAi'] = true;
        await repository.saveSettings(preferences);
      }
      await subscription.initialize();
    } catch (e) {
      error =
          'Local storage could not be opened. Retry or use a browser with IndexedDB enabled. $e';
    }
    loading = false;
    if (kIsWeb && book == null && !hadNotebooks) {
      openPlayground();
    }
    notifyListeners();
  }

  void updatePreferences(String key, dynamic value) {
    preferences[key] = value;
    repository.saveSettings(preferences).catchError((Object e) {
      error = 'Preferences could not be saved: $e';
      notifyListeners();
    });
    notifyListeners();
  }

  void open(Notebook notebook) {
    book = notebook;
    pageIndex = 0;
    _undo = [];
    _redo = [];
    clearSelection(notify: false);
    notifyListeners();
  }

  void close() {
    flush();
    book = null;
    notifyListeners();
  }

  Notebook create(String title) {
    final n = Notebook(
      title: title.trim().isEmpty ? 'Untitled notebook' : title.trim(),
      color: [
        0xff416d5b,
        0xffc49a66,
        0xff757c98,
        0xffa36e61,
      ][notebooks.length % 4],
    );
    notebooks.insert(0, n);
    persist(n);
    notifyListeners();
    return n;
  }

  void openPlayground() {
    final existing = notebooks
        .where((n) => n.playground && n.title == 'InkMind Demo')
        .firstOrNull;
    final n = existing ?? buildPlayground();
    if (existing == null) {
      notebooks.insert(0, n);
      persist(n);
    }
    open(n);
  }

  void rename(Notebook n, String title) {
    if (title.trim().isEmpty) return;
    n.title = title.trim();
    persist(n);
    notifyListeners();
  }

  void duplicate(Notebook n) {
    final data = n.toJson();
    data['id'] = newId();
    data['title'] = '${n.title} — copy';
    data['playground'] = false;
    final copy = Notebook.fromJson(data);
    notebooks.insert(0, copy);
    persist(copy);
    notifyListeners();
  }

  Future<void> delete(Notebook n) async {
    _saveTimers.remove(n.id)?.cancel();
    await _writeQueue;
    try {
      await repository.delete(n.id);
      notebooks.remove(n);
      if (book == n) book = null;
      notifyListeners();
    } catch (e) {
      error = 'Could not delete notebook: $e';
      notifyListeners();
    }
  }

  void persist(Notebook n) {
    n.edited = DateTime.now();
    saveStatus = 'Saving…';
    _saveTimers.remove(n.id)?.cancel();
    _saveTimers[n.id] = Timer(Duration(milliseconds: 450), () => _save(n));
  }

  void _save(Notebook n) {
    final snapshot = Notebook.fromJson(n.toJson());
    _writeQueue = _writeQueue.then((_) async {
      try {
        await repository.save(snapshot);
        saveStatus = 'Saved on this device';
      } catch (e) {
        saveStatus = 'Not saved — storage error';
        error =
            'Your latest edits could not be saved. Free browser storage and retry. $e';
      }
      notifyListeners();
    });
  }

  Future<void> flush() async {
    for (final entry in _saveTimers.entries) {
      if (entry.value.isActive) {
        entry.value.cancel();
        final n = notebooks.where((n) => n.id == entry.key).firstOrNull;
        if (n != null) _save(n);
      }
    }
    await _writeQueue;
  }

  void changed() {
    if (book != null) persist(book!);
    notifyListeners();
  }

  void checkpoint() {
    _undo.add(page.copy());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(page.copy());
    book!.pages[pageIndex] = _undo.removeLast();
    clearSelection(notify: false);
    changed();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(page.copy());
    book!.pages[pageIndex] = _redo.removeLast();
    clearSelection(notify: false);
    changed();
  }

  void addStroke(InkStroke stroke) {
    checkpoint();
    page.strokes.add(stroke);
    changed();
  }

  void erase(Offset p) {
    final hits = page.strokes
        .where(
          (s) =>
              s.bounds.inflate(12).contains(p) &&
              s.points.asMap().entries.any(
                (e) => e.key == 0
                    ? (e.value.position - p).distance < 14
                    : distanceToSegment(
                            p,
                            s.points[e.key - 1].position,
                            e.value.position,
                          ) <
                          14,
              ),
        )
        .toList();
    if (hits.isNotEmpty) {
      page.strokes.removeWhere(hits.contains);
      changed();
    }
  }

  void selectRect(Rect rect) {
    selectedStrokes.clear();
    selectedObjects.clear();
    selectedStrokes.addAll(
      page.strokes.where((s) => rect.overlaps(s.bounds)).map((s) => s.id),
    );
    selectedObjects.addAll(
      page.objects
          .where(
            (o) => rect.overlaps(Rect.fromLTWH(o.x, o.y, o.width, o.height)),
          )
          .map((o) => o.id),
    );
    notifyListeners();
  }

  void selectObject(PageObject o) {
    clearSelection(notify: false);
    selectedObjects.add(o.id);
    notifyListeners();
  }

  void clearSelection({bool notify = true}) {
    selectedStrokes.clear();
    selectedObjects.clear();
    if (notify) notifyListeners();
  }

  void moveSelection(Offset delta) {
    page.strokes = page.strokes
        .map((s) => selectedStrokes.contains(s.id) ? s.transformed(delta) : s)
        .toList();
    for (final o in page.objects.where((o) => selectedObjects.contains(o.id))) {
      o.x += delta.dx;
      o.y += delta.dy;
    }
    changed();
  }

  void deleteSelection() {
    checkpoint();
    page.strokes.removeWhere((s) => selectedStrokes.contains(s.id));
    page.objects.removeWhere((o) => selectedObjects.contains(o.id));
    clearSelection(notify: false);
    changed();
  }

  String get recognizedText =>
      DemoRecognitionEngine().recognize(page, selectedStrokes, selectedObjects);
  void associateLabel(String text) {
    checkpoint();
    for (final id in selectedStrokes) {
      page.labels[id] = text;
    }
    changed();
  }

  void setTool(InkTool value) {
    tool = value;
    notifyListeners();
  }

  void addPage() {
    book!.pages.add(InkPage(title: 'Page ${book!.pages.length + 1}'));
    goTo(book!.pages.length - 1);
    changed();
  }

  void goTo(int index) {
    if (index < 0 || index >= book!.pages.length) return;
    pageIndex = index;
    _undo = [];
    _redo = [];
    clearSelection(notify: false);
    notifyListeners();
  }

  void duplicatePage(int index) {
    book!.pages.insert(index + 1, book!.pages[index].copy(newIdentity: true));
    goTo(index + 1);
    changed();
  }

  void deletePage(int index) {
    if (book!.pages.length == 1) return;
    book!.pages.removeAt(index);
    goTo(pageIndex.clamp(0, book!.pages.length - 1));
    changed();
  }

  void reorderPage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final current = page.id;
    final p = book!.pages.removeAt(oldIndex);
    book!.pages.insert(newIndex, p);
    goTo(book!.pages.indexWhere((p) => p.id == current));
    changed();
  }

  Future<InkResponse> action(
    InkAction action, {
    String? text,
    Map<String, dynamic>? selection,
  }) async {
    if ((!kIsWeb || !subscription.isDemo) && !pro && (preferences['aiActions'] as int? ?? 0) >= 25) {
      throw StateError(
        'Your 25 free actions are used. Open InkMind Pro for unlimited AI actions.',
      );
    }
    final response = await router.run(
      InkRequest(text ?? recognizedText, action, selection: selection),
    );
    updatePreferences('aiActions', (preferences['aiActions'] as int? ?? 0) + 1);
    return response;
  }

  int get storageBytes =>
      book == null ? 0 : utf8.encode(jsonEncode(book!.toJson())).length;
  @override
  void dispose() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    activeInk.dispose();
    super.dispose();
  }
}
