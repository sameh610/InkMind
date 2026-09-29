import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../inkscript/compile_stub.dart'
    if (dart.library.js_interop) '../inkscript/compile_web.dart';
import 'ink_ir_motion.dart';

/// Compile and bind before committing: invalid edits never replace live ink.
class MotionEditor extends StatefulWidget {
  final InkPage page;
  final PageObject motion;
  final void Function(
    Map<String, dynamic> ir,
    String source,
    Map<String, List<String>> bindings,
  )
  onApply;
  const MotionEditor({
    super.key,
    required this.page,
    required this.motion,
    required this.onApply,
  });
  @override
  State<MotionEditor> createState() => _MotionEditorState();
}

class _MotionEditorState extends State<MotionEditor> {
  late final editor = TextEditingController(
    text: widget.motion.data['source']?.toString() ?? '',
  );
  bool busy = false;
  String? error;
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await compileInkScriptInBrowser(editor.text);
      if (result['ok'] != true) {
        final errors = (result['errors'] as List? ?? []).whereType<Map>();
        throw FormatException(
          errors.firstOrNull?['message']?.toString() ??
              'InkScript could not be compiled.',
        );
      }
      final ir = Map<String, dynamic>.from(result['ir'] as Map);
      final previous = widget.motion.data['ir'] as Map?;
      final ids = <String>{
        for (final d in (previous?['drawings'] as List? ?? []).whereType<Map>())
          d['id'].toString(),
        for (final list in (widget.motion.data['bindings'] as Map).values)
          if (list is List) ...list.whereType<String>(),
      };
      final bindings = bindInkAnimation(ir, widget.page, ids);
      if (!mounted) return;
      widget.onApply(ir, result['source']?.toString() ?? editor.text, bindings);
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Could not compile this edit. Please retry.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit ink animation'),
    content: SizedBox(
      width: 720,
      height: 440,
      child: Column(
        children: [
          const Text(
            'Edit the motion, then apply. Your original strokes are preserved; notebook Undo restores the previous script.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: editor,
              expands: true,
              maxLines: null,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'InkScript',
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : apply,
        child: Text(busy ? 'Validating…' : 'Apply animation'),
      ),
    ],
  );
}
