import 'dart:math' as math;
import '../../core/models/ink.dart';

enum InkAction {
  explain,
  hint,
  check,
  summarize,
  continueIdea,
  quiz,
  flashcards,
  makeAlive,
  animateInk,
  createVisual,
  debug,
  prerequisite,
  rewrite,
}

class InkRequest {
  final String text;
  final InkAction action;
  final Map<String, dynamic>? selection;
  const InkRequest(this.text, this.action, {this.selection});
}

class InkResponse {
  final String text;
  final CellSpec? cell;
  final DebugResult? debug;
  final VisualSpec? visual;
  final String? animationSystem;
  final Map<String, dynamic>? motion;
  final String engine;
  const InkResponse(
    this.text, {
    this.cell,
    this.debug,
    this.visual,
    this.animationSystem,
    this.motion,
    this.engine = 'Demo Engine',
  });
}

/// A deliberately small, declarative visual contract. AI can choose the
/// composition, but it cannot inject executable code into the notebook.
class VisualSpec {
  final String style;
  final String title;
  final String caption;
  final int seed;
  final String? code;
  final String? script;
  final Map<String, dynamic>? ir;
  const VisualSpec({
    required this.style,
    required this.title,
    required this.caption,
    this.seed = 7,
    this.code,
    this.script,
    this.ir,
  });

  static const styles = {'wave', 'orbit', 'network', 'flow', 'timeline'};
  bool get valid =>
      (styles.contains(style) ||
          (style == 'code' && code != null && code!.length <= 60000) ||
          (style == 'ir' && ir?['mode'] == 'visual')) &&
      title.trim().isNotEmpty &&
      title.length <= 120 &&
      caption.length <= 300;

  Map<String, dynamic> toJson() => {
    'style': style,
    'title': title,
    'caption': caption,
    'seed': seed,
    if (code != null) 'code': code,
    if (script != null) 'script': script,
    if (ir != null) 'ir': ir,
  };

  static VisualSpec? fromJson(Map<String, dynamic> json) {
    final style = json['style']?.toString().toLowerCase();
    if (style == null ||
        (!styles.contains(style) && style != 'code' && style != 'ir')) {
      return null;
    }
    final spec = VisualSpec(
      style: style,
      title: json['title']?.toString().trim() ?? 'AI visual',
      caption: json['caption']?.toString().trim() ?? '',
      seed: (json['seed'] as num?)?.toInt() ?? 7,
      code: json['code']?.toString(),
      script: json['script']?.toString(),
      ir: json['ir'] is Map
          ? Map<String, dynamic>.from(json['ir'] as Map)
          : null,
    );
    return spec.valid ? spec : null;
  }

  static VisualSpec fromLooseText(String text, {String? title}) {
    final lower = text.toLowerCase();
    final style = lower.contains('network') || lower.contains('neural')
        ? 'network'
        : lower.contains('orbit') || lower.contains('planet')
        ? 'orbit'
        : lower.contains('flow') || lower.contains('process')
        ? 'flow'
        : lower.contains('timeline') || lower.contains('history')
        ? 'timeline'
        : 'wave';
    return VisualSpec(
      style: style,
      title: title ?? 'A new way to see this idea',
      caption: text.trim().substring(0, math.min(text.trim().length, 300)),
    );
  }
}

String animationSystemFromText(String text) {
  final lower = text.toLowerCase();
  for (final system in [
    'pendulum',
    'ball',
    'ramp',
    'spring',
    'array',
    'nodes',
    'network',
  ]) {
    if (lower.contains(system)) return system;
  }
  return 'pendulum';
}

class CellSpec {
  final String type, title;
  final Map<String, dynamic> parameters;
  const CellSpec(this.type, this.title, this.parameters);
  static const types = {
    'graph',
    'quiz',
    'projectile',
    'pendulum',
    'spring',
    'ramp',
    'ball',
    'algorithm',
    'neural',
    'calculator',
    'flow',
    'circuit',
  };
  bool get valid =>
      types.contains(type) &&
      title.length <= 120 &&
      parameters.values.every((v) => v is! num || v.isFinite);
  PageObject toObject({double y = 290}) {
    if (!valid) throw FormatException('Invalid InkCell specification');
    return PageObject(kind: type, text: title, y: y, data: Map.of(parameters));
  }
}

abstract class LocalModelEngine {
  String get name;
  bool get available;
  Future<InkResponse> infer(InkRequest request);
}

class ModelRouter {
  final LocalModelEngine fast, smart, fallback;
  final bool requireAi;
  ModelRouter({
    this.requireAi = false,
    LocalModelEngine? fast,
    LocalModelEngine? smart,
    LocalModelEngine? fallback,
  }) : fast = fast ?? DemoModelEngine(),
       smart = smart ?? DemoModelEngine(),
       fallback = fallback ?? DemoModelEngine();
  Future<InkResponse> run(InkRequest r) async {
    if (requireAi) {
      if (!smart.available) {
        throw StateError('Enable Browser AI in Settings to use AI actions.');
      }
      return smart.infer(r);
    }
    // Every action gets an AI attempt. The fast engine remains the validated
    // offline fallback for malformed model output or unavailable runtimes.
    final engine = smart.available ? smart : fast;
    try {
      return await (engine.available ? engine : fallback).infer(r);
    } catch (_) {
      if (identical(engine, fallback)) rethrow;
      return fallback.infer(r);
    }
  }
}

abstract class NativeModelEngine implements LocalModelEngine {
  @override
  bool get available => false;
  @override
  Future<InkResponse> infer(InkRequest request) async =>
      throw UnsupportedError('$name requires a native runtime adapter');
}

class AppleFoundationModelEngine extends NativeModelEngine {
  @override
  String get name => 'Apple Foundation Model';
}

class MiniCPMEngine extends NativeModelEngine {
  @override
  String get name => 'MiniCPM';
}

class LFMEngine extends NativeModelEngine {
  @override
  String get name => 'LFM';
}

class FutureQwenEngine extends NativeModelEngine {
  @override
  String get name => 'Qwen';
}

abstract class RecognitionEngine {
  String recognize(InkPage page, Set<String> strokeIds, Set<String> objectIds);
}

class DemoRecognitionEngine implements RecognitionEngine {
  @override
  String recognize(
    InkPage page,
    Set<String> strokeIds,
    Set<String> objectIds,
  ) => [
    ...strokeIds.map((id) => page.labels[id] ?? ''),
    ...page.objects
        .where((o) => objectIds.contains(o.id))
        .map((o) => o.data['recognizedText']?.toString() ?? o.text),
  ].where((s) => s.isNotEmpty).toSet().join('\n');
}

class DemoModelEngine implements LocalModelEngine {
  @override
  String get name => 'Demo Engine';
  @override
  bool get available => true;
  @override
  Future<InkResponse> infer(InkRequest r) async {
    final text = r.text.trim(), lower = text.toLowerCase();
    if (text.isEmpty) {
      return InkResponse(
        "I couldn't confidently understand that. Select a text block, or associate a demo label with your ink, then choose an action.",
      );
    }
    if (r.action == InkAction.debug || r.action == InkAction.check) {
      final result = debugMath(text);
      return InkResponse(result.explanation, debug: result);
    }
    if (r.action == InkAction.quiz || r.action == InkAction.flashcards) {
      return InkResponse(
        'A study set from your notes.',
        cell: CellSpec(
          'quiz',
          r.action == InkAction.flashcards
              ? 'Recall cards'
              : 'A little retrieval practice',
          {
            'questions': makeQuiz(text),
            'flashcards': r.action == InkAction.flashcards,
          },
        ),
      );
    }
    if (r.action == InkAction.animateInk) {
      final system = animationSystemFromText(text);
      return InkResponse(
        'Offline example: $system animation.',
        animationSystem: system,
      );
    }
    if (r.action == InkAction.createVisual) {
      final visual = VisualSpec.fromLooseText(text, title: 'AI visual study');
      return InkResponse('Offline example visual.', visual: visual);
    }
    if (r.action == InkAction.makeAlive) {
      if (lower.contains('xor') || lower.contains('neural')) {
        return InkResponse(
          'Explore a 2–4–1 network.',
          cell: CellSpec('neural', 'Learning XOR', {'epoch': 0}),
        );
      }
      if (lower.contains('search') ||
          lower.contains('sort') ||
          lower.contains('traversal')) {
        return InkResponse(
          'Step through the algorithm.',
          cell: CellSpec('algorithm', text.split('\n').first, {
            'algorithm': lower.contains('binary')
                ? 'binary search'
                : lower.contains('insertion')
                ? 'insertion sort'
                : lower.contains('traversal')
                ? 'graph traversal'
                : 'bubble sort',
            'values': [7, 3, 9, 1, 6, 2, 8],
            'target': 6,
          }),
        );
      }
      for (final type in [
        'projectile',
        'pendulum',
        'spring',
        'ramp',
        'ball',
        'circuit',
        'flow',
      ]) {
        if (lower.contains(type)) {
          final velocity = RegExp(r'(\d+(?:\.\d+)?)\s*m/s').firstMatch(lower);
          final angle = RegExp(r'(\d+(?:\.\d+)?)\s*°').firstMatch(lower);
          return InkResponse(
            'The parameters are editable. Physics runs deterministically.',
            cell: CellSpec(
              type,
              '${type[0].toUpperCase()}${type.substring(1)} study',
              {
                'velocity': double.tryParse(velocity?.group(1) ?? '') ?? 20,
                'angle': double.tryParse(angle?.group(1) ?? '') ?? 45,
                'gravity': lower.contains('moon') ? 1.62 : 9.81,
                'length': 2.0,
                'friction': .2,
                'voltage': 5.0,
              },
            ),
          );
        }
      }
      if (lower.contains('conversion') || lower.contains('business')) {
        return InkResponse(
          'A small, transparent calculator.',
          cell: CellSpec('calculator', 'Conversion model', {
            'visitors': 1000.0,
            'conversion': .04,
            'price': 25.0,
          }),
        );
      }
      final polynomial = Polynomial.tryParse(
        text.replaceFirst(RegExp(r'^y\s*='), ''),
      );
      if (polynomial != null || lower.contains('sin(x)')) {
        return InkResponse(
          'Your equation, made explorable.',
          cell: CellSpec('graph', text, {
            'a': polynomial?.a ?? 1,
            'b': polynomial?.b ?? 0,
            'c': polynomial?.c ?? 0,
            'sin': lower.contains('sin(x)'),
          }),
        );
      }
      return InkResponse(
        'This concept has no interactive template yet. Try an equation, projectile, pendulum, sorting, XOR, or business calculator. Your original notes are unchanged.',
      );
    }
    final equation = LinearEquation.tryParse(text.split('\n').first);
    if (equation != null) {
      final x = equation.solution;
      if (r.action == InkAction.hint) {
        return InkResponse(
          'Keep both sides balanced. First remove the constant term from each side; then isolate x.',
        );
      }
      if (r.action == InkAction.prerequisite) {
        return InkResponse(
          'Prerequisite: inverse operations and equality. Whatever you do to one side, do to the other.',
        );
      }
      return InkResponse(
        'Keep the equation balanced. Collect x terms on one side and constants on the other: ${fmt(equation.coefficient)}x = ${fmt(equation.constant)}. Divide by ${fmt(equation.coefficient)} to get x = ${fmt(x)}.',
      );
    }
    if (lower.contains('pendulum')) {
      return InkResponse(
        'A pendulum trades potential energy for kinetic energy. For small swings, T = 2π√(L/g). At L = 2 m, Earth gives ${fmt(2 * math.pi * math.sqrt(2 / 9.81))} s per swing; Moon gives ${fmt(2 * math.pi * math.sqrt(2 / 1.62))} s.',
      );
    }
    if (r.action == InkAction.summarize) {
      final sentences = text
          .split(RegExp(r'[.!?\n]+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return InkResponse(
        'Key ideas\n${sentences.take(3).map((s) => '• ${s.trim()}').join('\n')}',
      );
    }
    if (r.action == InkAction.hint) {
      return InkResponse(
        'Start with the definitions in your selection. What is known, what is changing, and what do you need to find?',
      );
    }
    if (r.action == InkAction.prerequisite) {
      return InkResponse(
        'Identify the key terms in “${text.split('\n').first}”. Define each one, then work through a concrete example before combining them.',
      );
    }
    if (r.action == InkAction.rewrite) {
      return InkResponse(
        text
            .split(RegExp(r'\n+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => '• ${s[0].toUpperCase()}${s.substring(1)}')
            .join('\n'),
      );
    }
    if (r.action == InkAction.continueIdea) {
      return InkResponse(
        'Next in this line of thinking:\n1. State an assumption behind “${text.split('\n').first}”.\n2. Test it with a simple example.\n3. Record what would change your conclusion.',
      );
    }
    return InkResponse(
      'You selected: “$text”\n\nThis demo can summarize these notes or create recall questions. A full explanation of this topic needs a native model; no answer has been invented.',
    );
  }
}

String fmt(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

class Polynomial {
  final double a, b, c;
  const Polynomial(this.a, this.b, this.c);
  double at(double x) => a * x * x + b * x + c;
  static Polynomial? tryParse(String input) {
    var s = input
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('²', '^2')
        .replaceAll('−', '-')
        .replaceAll('*', '');
    if (s.isEmpty || !RegExp(r'^[\dx.\^+\-]+$').hasMatch(s)) return null;
    final tokens = RegExp(
      r'[+-]?[^+-]+',
    ).allMatches(s).map((m) => m.group(0)!).toList();
    var a = 0.0, b = 0.0, c = 0.0;
    for (final t in tokens) {
      String coefficient = t;
      int degree = 0;
      if (t.endsWith('x^2')) {
        coefficient = t.substring(0, t.length - 3);
        degree = 2;
      } else if (t.endsWith('x')) {
        coefficient = t.substring(0, t.length - 1);
        degree = 1;
      }
      final v = coefficient == '' || coefficient == '+'
          ? 1.0
          : coefficient == '-'
          ? -1.0
          : double.tryParse(coefficient);
      if (v == null || !v.isFinite) return null;
      if (degree == 2) {
        a += v;
      } else if (degree == 1) {
        b += v;
      } else {
        c += v;
      }
    }
    return Polynomial(a, b, c);
  }
}

class LinearEquation {
  final double coefficient, constant;
  const LinearEquation(this.coefficient, this.constant);
  double get solution => constant / coefficient;
  static LinearEquation? tryParse(String text) {
    final parts = text.replaceAll('≈', '=').split('=');
    if (parts.length != 2) return null;
    final l = Polynomial.tryParse(parts[0]), r = Polynomial.tryParse(parts[1]);
    if (l == null || r == null || l.a != 0 || r.a != 0 || l.b == r.b) {
      return null;
    }
    return LinearEquation(l.b - r.b, r.c - l.c);
  }
}

class DebugResult {
  final List<String> steps;
  final int? firstError;
  final String explanation;
  final List<String> corrected;
  final bool supported;
  const DebugResult(
    this.steps,
    this.firstError,
    this.explanation,
    this.corrected, {
    this.supported = true,
  });
}

DebugResult debugMath(String text) {
  final lines = text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return DebugResult(
      [],
      null,
      'Select a sequence of equations.',
      [],
      supported: false,
    );
  }
  final base = LinearEquation.tryParse(lines.first);
  if (base == null) {
    for (var i = 0; i < lines.length; i++) {
      final parts = lines[i].split('=');
      if (parts.length != 2) {
        return DebugResult(
          lines,
          null,
          'This demo verifies arithmetic and linear equations only.',
          [],
          supported: false,
        );
      }
      final l = Polynomial.tryParse(parts[0]),
          r = Polynomial.tryParse(parts[1]);
      if (l == null ||
          r == null ||
          l.a != 0 ||
          l.b != 0 ||
          r.a != 0 ||
          r.b != 0) {
        return DebugResult(
          lines,
          null,
          'This expression is outside the supported arithmetic checker.',
          [],
          supported: false,
        );
      }
      if ((l.c - r.c).abs() > .01) {
        return DebugResult(
          lines,
          i,
          '${parts[0].trim()} = ${fmt(l.c)}, not ${fmt(r.c)}.',
          ['${parts[0].trim()} = ${fmt(l.c)}'],
        );
      }
    }
    return DebugResult(lines, null, 'All arithmetic equalities check out.', []);
  }
  for (var i = 1; i < lines.length; i++) {
    final next = LinearEquation.tryParse(lines[i]);
    if (next == null) {
      return DebugResult(
        lines,
        null,
        'Step ${i + 1} is outside this linear-equation checker.',
        [],
        supported: false,
      );
    }
    if ((next.solution - base.solution).abs() > .015) {
      final p = Polynomial.tryParse(lines.first.split('=').first)!;
      final right = Polynomial.tryParse(lines.first.split('=').last)!;
      final explanation = right.b == 0 && p.c != 0
          ? '${fmt(right.c)} ${p.c >= 0 ? '-' : '+'} ${fmt(p.c.abs())} = ${fmt(base.constant)}, not ${fmt(next.constant)}. Apply the same operation to both sides.'
          : 'This step changes the solution from x = ${fmt(base.solution)} to x = ${fmt(next.solution)}.';
      return DebugResult(lines, i, explanation, [
        '${fmt(base.coefficient)}x = ${fmt(base.constant)}',
        'x = ${fmt(base.solution)}',
      ]);
    }
  }
  return DebugResult(
    lines,
    null,
    'Each step preserves the solution x = ${fmt(base.solution)}.',
    ['x = ${fmt(base.solution)}'],
  );
}

List<Map<String, dynamic>> makeQuiz(String text) {
  final facts = text
      .split(RegExp(r'[.!?\n]+'))
      .map((s) => s.trim())
      .where((s) => s.split(' ').length >= 3)
      .take(5)
      .toList();
  if (facts.isEmpty) facts.add('The selected topic is $text');
  return List.generate(math.max(3, facts.length), (i) {
    final fact = facts[i % facts.length];
    final words = fact.split(' ');
    final answer = words.removeLast();
    final alternatives = <String>{
      answer,
      ...facts.where((s) => s != fact).map((s) => s.split(' ').last),
      'unknown',
      'unchanged',
      'zero',
    }.take(4).toList();
    final shift = i % alternatives.length;
    final choices = [...alternatives.skip(shift), ...alternatives.take(shift)];
    return {
      'prompt': 'Complete your note: ${words.join(' ')} ____',
      'choices': choices,
      'answer': choices.indexOf(answer),
      'explanation': fact,
    };
  });
}
