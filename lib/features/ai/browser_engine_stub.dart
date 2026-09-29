import 'engine.dart';

String browserAiStatus() => 'Available on Flutter Web';

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
  String get name => 'Browser AI';
  @override
  bool get available => false;
  @override
  Future<InkResponse> infer(InkRequest request) async =>
      throw UnsupportedError('Browser model unavailable on this platform');
}

String browserAiSelection(String model, String quant) => '$model · $quant';

void cancelBrowserAi() {}
