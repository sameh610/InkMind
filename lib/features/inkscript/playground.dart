import 'dart:convert';
import 'package:flutter/material.dart';
import 'compile_stub.dart' if (dart.library.js_interop) 'compile_web.dart';
import '../visuals/ink_ir_view.dart';

const inkScriptExample = '''export default function Visual() {
  const gravity = state(9.81);
  const length = state(2);

  return (
    <App title="Pendulum Lab">
      <Pendulum gravity={gravity} length={length} showTrail showEnergy />
      <Controls>
        <Slider label="Gravity" value={gravity} min={1} max={25} unit="m/s²" />
        <Slider label="Length" value={length} min={0.5} max={5} unit="m" />
      </Controls>
    </App>
  );
}''';

class InkScriptPlayground extends StatefulWidget {
  final void Function(Map<String, dynamic> ir, String source) onApply;
  const InkScriptPlayground({super.key, required this.onApply});
  @override
  State<InkScriptPlayground> createState() => _InkScriptPlaygroundState();
}

class _InkScriptPlaygroundState extends State<InkScriptPlayground> {
  final editor = TextEditingController(text: inkScriptExample);
  Map<String, dynamic>? result;
  bool compiling = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => compile());
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  Future<void> compile() async {
    setState(() {
      compiling = true;
      error = null;
    });
    try {
      final next = await compileInkScriptInBrowser(editor.text);
      if (mounted) setState(() => result = next);
    } catch (e) {
      if (mounted)
        setState(() {
          result = null;
          error = e.toString();
        });
    } finally {
      if (mounted) setState(() => compiling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok =
        result?['ok'] == true && (result?['ir'] as Map?)?['mode'] == 'visual';
    final diagnostics = result?['errors'] as List? ?? [];
    final warnings = result?['warnings'] as List? ?? [];
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: const Color(0xff122b3a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.code_rounded, color: Color(0xff65e4cc)),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'InkScript playground',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close playground',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit restricted TSX, compile it, and try the live controls.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 650;
                    final codePane = Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff0c202d),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: editor,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Write InkScript TSX here',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    );
                    final resultPane = Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff173343),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            ok ? 'LIVE PREVIEW' : 'COMPILER',
                            style: const TextStyle(
                              color: Color(0xff65e4cc),
                              letterSpacing: 1.5,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (compiling) const LinearProgressIndicator(),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(color: Color(0xffffb38f)),
                            ),
                          for (final d in diagnostics.whereType<Map>())
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${d['code']} at ${d['line']}:${d['column']} — ${d['message']}\n${d['repair']}',
                                style: const TextStyle(
                                  color: Color(0xffffb38f),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          for (final d in warnings.whereType<Map>())
                            Text(
                              '${d['code']}: ${d['message']}',
                              style: const TextStyle(
                                color: Color(0xffbca8ff),
                                fontSize: 11,
                              ),
                            ),
                          if (ok)
                            Expanded(
                              child: InkIrView(
                                key: ValueKey(editor.text),
                                ir: Map<String, dynamic>.from(
                                  result!['ir'] as Map,
                                ),
                              ),
                            ),
                          if (ok)
                            ExpansionTile(
                              title: const Text(
                                'Inspect InkIR',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              iconColor: Colors.white70,
                              collapsedIconColor: Colors.white70,
                              children: [
                                SizedBox(
                                  height: 100,
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      const JsonEncoder.withIndent(
                                        '  ',
                                      ).convert(result!['ir']),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                    if (wide)
                      return Row(
                        children: [
                          Expanded(child: codePane),
                          const SizedBox(width: 12),
                          Expanded(child: resultPane),
                        ],
                      );
                    return Column(
                      children: [
                        Expanded(child: codePane),
                        const SizedBox(height: 10),
                        Expanded(child: resultPane),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => editor.text = inkScriptExample),
                    child: const Text('Reset example'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: compiling ? null : compile,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Compile & preview'),
                  ),
                  const SizedBox(width: 9),
                  FilledButton.tonal(
                    onPressed: ok
                        ? () {
                            widget.onApply(
                              Map<String, dynamic>.from(result!['ir'] as Map),
                              editor.text,
                            );
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Add to page'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
