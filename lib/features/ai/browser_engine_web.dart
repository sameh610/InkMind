import 'dart:convert';
import 'dart:js_interop';
import 'engine.dart';
import 'response_parser.dart';

@JS('InkMindBrowserAI.generate')
external JSPromise<JSString> _generate(
  JSString action,
  JSString text,
  JSString selection,
  JSString model,
  JSString quant,
  JSString performance,
);
@JS('InkMindBrowserAI.status')
external JSString _status();
@JS('InkMindBrowserAI.selection')
external JSString _selection(JSString model, JSString quant);
@JS('InkMindBrowserAI.usesNative')
external JSBoolean _usesNative();
@JS('InkMindBrowserAI.cancel')
external void cancelBrowserAi();
String browserAiStatus() => _status().toDart;
String browserAiSelection(String model, String quant) =>
    _selection(model.toJS, quant.toJS).toDart;
bool browserAiUsesNative() => _usesNative().toDart;

class BrowserModelEngine implements LocalModelEngine {
  final bool Function() enabled;
  final String Function() selectedModel;
  final String Function() selectedQuant;
  final String Function()? performance;
  BrowserModelEngine(
    this.enabled, {
    required this.selectedModel,
    required this.selectedQuant,
    this.performance,
  });
  @override
  String get name =>
      '${browserAiUsesNative() ? 'Local AI Companion' : 'Browser AI'} · ${browserAiSelection(selectedModel(), selectedQuant())}';
  @override
  bool get available => enabled();
  @override
  Future<InkResponse> infer(InkRequest request) async {
    final answer = await _generate(
      request.action.name.toJS,
      request.text.toJS,
      jsonEncode(request.selection ?? const <String, dynamic>{}).toJS,
      selectedModel().toJS,
      selectedQuant().toJS,
      (performance?.call() ?? 'balanced').toJS,
    ).toDart;
    return decodeAiResponse(
      request.action,
      answer.toDart,
      name,
      context: request.text,
    );
  }
}
