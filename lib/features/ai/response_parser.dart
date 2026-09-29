import 'dart:convert';
import 'engine.dart';
import 'ink_script.dart';

/// Reject incomplete model artifacts rather than inventing an unrelated result.
InkResponse decodeAiResponse(
  InkAction action,
  String output,
  String engine, {
  String? context,
}) {
  final text = output.trim();
  if (text.isEmpty)
    throw const FormatException('AI returned an empty answer. Retry.');
  if (action == InkAction.createVisual || action == InkAction.makeAlive) {
    final payload = _compiledInkScript(text, 'visual');
    if (payload != null) {
      final ir = Map<String, dynamic>.from(payload['ir'] as Map);
      final root = Map<String, dynamic>.from(ir['root'] as Map);
      final props = Map<String, dynamic>.from(root['props'] as Map);
      final titleNode = props['title'];
      final title = titleNode is Map ? titleNode['value']?.toString() : null;
      return InkResponse(
        'AI-generated interactive visual',
        engine: engine,
        visual: VisualSpec(
          style: 'ir',
          title: title?.isNotEmpty == true ? title! : 'Interactive visual',
          caption: 'Move the controls to explore',
          script: payload['source']?.toString(),
          ir: ir,
        ),
      );
    }
    final visual = renderInkScript(text, context: context);
    return InkResponse(
      'AI-generated visual',
      engine: engine,
      visual: VisualSpec(
        style: 'code',
        title: visual.title,
        caption: 'Generated from your notes',
        code: visual.svg,
        script: text,
      ),
    );
  }
  if (action == InkAction.animateInk) {
    final payload = _compiledInkScript(text, 'animateInk');
    if (payload != null) {
      final ir = Map<String, dynamic>.from(payload['ir'] as Map);
      final rawRig = ir['rig'];
      final subject = rawRig is Map
          ? rawRig['subject']?.toString().trim()
          : null;
      return InkResponse(
        subject?.isNotEmpty == true
            ? 'Recognized $subject · original ink animation'
            : 'Original ink animation',
        engine: engine,
        motion: {
          'ir': ir,
          'source': payload['source'],
          'tracks': <dynamic>[],
          'engine': engine,
        },
      );
    }
    final motion = parseInkMotion(text);
    return InkResponse(
      motion['explanation'] as String,
      engine: engine,
      motion: {'tracks': motion['tracks'], 'engine': engine},
    );
  }
  if (![
    InkAction.quiz,
    InkAction.flashcards,
    InkAction.debug,
    InkAction.check,
  ].contains(action)) {
    return InkResponse(text, engine: engine);
  }
  final raw = text
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>)
    throw const FormatException('Expected a structured AI response.');
  final j = decoded;
  String str(dynamic v, [int max = 2000]) {
    if (v is! String || v.trim().isEmpty || v.length > max)
      throw const FormatException('Incomplete AI response.');
    return v;
  }

  List<String> strings(dynamic v) {
    if (v is! List || v.length > 32)
      throw const FormatException('Invalid AI list.');
    return v.map((s) => str(s)).toList();
  }

  if (action == InkAction.quiz || action == InkAction.flashcards) {
    final rawQuestions = j['questions'];
    if (rawQuestions is! List ||
        rawQuestions.isEmpty ||
        rawQuestions.length > 10)
      throw const FormatException('AI returned no valid questions.');
    final questions = <Map<String, dynamic>>[];
    for (final q in rawQuestions) {
      if (q is! Map) throw const FormatException('Invalid question.');
      final choices = strings(q['choices']);
      final answer = q['answer'];
      if (choices.length < 2 ||
          choices.length > 6 ||
          answer is! int ||
          answer < 0 ||
          answer >= choices.length)
        throw const FormatException('Invalid quiz answer.');
      questions.add({
        'prompt': str(q['prompt']),
        'choices': choices,
        'answer': answer,
        'explanation': str(q['explanation']),
      });
    }
    return InkResponse(
      'AI study set',
      engine: engine,
      cell: CellSpec('quiz', str(j['title'], 120), {
        'questions': questions,
        'flashcards': action == InkAction.flashcards,
      }),
    );
  }
  final steps = strings(j['steps']);
  final first = j['firstError'];
  if (steps.isEmpty ||
      (first != null && (first is! int || first < 0 || first >= steps.length)))
    throw const FormatException('Invalid reasoning review.');
  return InkResponse(
    str(j['explanation']),
    engine: engine,
    debug: DebugResult(
      steps,
      first as int?,
      str(j['explanation']),
      strings(j['corrected']),
    ),
  );
}

Map<String, dynamic>? _compiledInkScript(String text, String mode) {
  try {
    final payload = jsonDecode(text);
    if (payload is! Map ||
        payload['ir'] is! Map ||
        payload['source'] is! String)
      return null;
    final ir = payload['ir'] as Map;
    if (ir['version'] != 1 || ir['mode'] != mode)
      throw const FormatException('Invalid InkScript mode.');
    return Map<String, dynamic>.from(payload);
  } on FormatException {
    return null;
  }
}
