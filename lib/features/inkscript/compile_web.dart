import 'dart:convert';
import 'dart:js_interop';

@JS('InkMindBrowserAI.compile')
external JSPromise<JSString> _compile(JSString source, JSString capability);

Future<Map<String, dynamic>> compileInkScriptInBrowser(String source) async {
  final response = await _compile(source.toJS, 'BALANCED'.toJS).toDart;
  return Map<String, dynamic>.from(jsonDecode(response.toDart) as Map);
}
