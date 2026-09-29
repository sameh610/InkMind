import 'dart:math' as math;
import 'engine.dart';

/// InkScript is a deliberately tiny, line-based drawing language. The model
/// chooses the commands; this interpreter owns geometry, escaping and output.
class InkScriptVisual {
  final String title;
  final String svg;
  const InkScriptVisual(this.title, this.svg);
}

List<String> _commands(String source) {
  final raw = source
      .replaceAll(RegExp(r'^```[^\n]*\n|\n?```\s*$'), '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(80)
      .toList();
  const arity = {
    'TITLE': 1,
    'TEXT': 3,
    'CIRCLE': 4,
    'RECT': 5,
    'LINE': 5,
    'ARROW': 5,
    'PLOT': 4,
    'AXES': 0,
    'WHY': 1,
    'MOVE': 7,
  };
  final result = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final line = raw[i];
    if (line.contains('|')) {
      result.add(line);
      continue;
    }
    final command = line.toUpperCase();
    if (!arity.containsKey(command)) continue;
    final parts = <String>[command];
    for (var j = 0; j < arity[command]! && i + 1 < raw.length; j++) {
      if (arity.containsKey(raw[i + 1].toUpperCase())) break;
      parts.add(raw[++i]);
    }
    result.add(parts.join('|'));
  }
  return result;
}

InkScriptVisual renderInkScript(String source, {String? context}) {
  final lines = _commands(source).take(32);
  final elements = <String>[];
  var title = 'AI visual';
  var drawCount = 0;
  var hasSubject = false;

  String xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String color(String value) => switch (value.toLowerCase().trim()) {
    'teal' => '#168b85',
    'coral' => '#df765e',
    'ivory' => '#fffbf2',
    'muted' => '#76818a',
    _ => '#172c3d',
  };
  double number(String value, double min, double max) {
    final n = double.tryParse(value.trim());
    if (n == null || !n.isFinite || n < min || n > max) {
      throw const FormatException('Invalid InkScript coordinate.');
    }
    return n;
  }

  String n(double v) => v.toStringAsFixed(1);

  for (final line in lines) {
    final p = line.split('|').map((s) => s.trim()).toList();
    final command = p.first.toUpperCase();
    if (command == 'TITLE' && p.length >= 2) {
      title = p.skip(1).join(' ').trim();
      if (title.length > 80) title = title.substring(0, 80);
    } else if (command == 'TEXT' && p.length >= 4) {
      final x = number(p[1], 0, 560), y = number(p[2], 0, 320);
      final label = p.sublist(3).join(' ').trim();
      if (label.isEmpty || label.length > 120) continue;
      elements.add(
        '<text x="${n(x)}" y="${n(y)}" fill="#172c3d" font-size="15" font-family="system-ui">${xml(label)}</text>',
      );
      drawCount++;
    } else if (command == 'CIRCLE' && p.length >= 4) {
      final x = number(p[1], 0, 560), y = number(p[2], 0, 320);
      final r = number(p[3], 1, 200);
      elements.add(
        '<circle cx="${n(x)}" cy="${n(y)}" r="${n(r)}" fill="${color(p.length > 4 ? p[4] : 'teal')}"/>',
      );
      drawCount++;
      hasSubject = true;
    } else if (command == 'RECT' && p.length >= 5) {
      final x = number(p[1], 0, 560), y = number(p[2], 0, 320);
      final w = number(p[3], 1, 560), h = number(p[4], 1, 320);
      elements.add(
        '<rect x="${n(x)}" y="${n(y)}" width="${n(w)}" height="${n(h)}" rx="12" fill="${color(p.length > 5 ? p[5] : 'teal')}"/>',
      );
      drawCount++;
      hasSubject = true;
    } else if ((command == 'LINE' || command == 'ARROW') && p.length >= 5) {
      final x1 = number(p[1], 0, 560), y1 = number(p[2], 0, 320);
      final x2 = number(p[3], 0, 560), y2 = number(p[4], 0, 320);
      final ink = color(p.length > 5 ? p[5] : 'navy');
      elements.add(
        '<line x1="${n(x1)}" y1="${n(y1)}" x2="${n(x2)}" y2="${n(y2)}" stroke="$ink" stroke-width="3" stroke-linecap="round"/>',
      );
      if (command == 'ARROW') {
        final angle = math.atan2(y2 - y1, x2 - x1);
        final left =
            '${n(x2 - 11 * math.cos(angle - .5))},${n(y2 - 11 * math.sin(angle - .5))}';
        final right =
            '${n(x2 - 11 * math.cos(angle + .5))},${n(y2 - 11 * math.sin(angle + .5))}';
        elements.add(
          '<polygon points="${n(x2)},${n(y2)} $left $right" fill="$ink"/>',
        );
      }
      drawCount++;
      hasSubject = true;
    } else if (command == 'AXES') {
      for (var x = 56; x <= 504; x += 56) {
        elements.add(
          '<line x1="$x" y1="38" x2="$x" y2="282" stroke="#dce9e5" stroke-width="1"/>',
        );
      }
      for (var y = 40; y <= 280; y += 40) {
        elements.add(
          '<line x1="56" y1="$y" x2="504" y2="$y" stroke="#dce9e5" stroke-width="1"/>',
        );
      }
      elements.add(
        '<line x1="55" y1="160" x2="510" y2="160" stroke="#76818a" stroke-width="2"/><line x1="280" y1="35" x2="280" y2="290" stroke="#76818a" stroke-width="2"/><text x="515" y="165" font-size="13" fill="#76818a">x</text><text x="286" y="28" font-size="13" fill="#76818a">y</text>',
      );
      drawCount++;
    } else if (command == 'PLOT') {
      final fromNote = Polynomial.tryParse(
        (context ?? '').replaceFirst(RegExp(r'^\s*y\s*='), '').trim(),
      );
      if (p.length < 4 && fromNote == null) continue;
      final a = p.length >= 4 ? number(p[1], -100, 100) : fromNote!.a;
      final b = p.length >= 4 ? number(p[2], -100, 100) : fromNote!.b;
      final c = p.length >= 4 ? number(p[3], -100, 100) : fromNote!.c;
      final points = <String>[];
      for (var i = 0; i <= 160; i++) {
        final x = -8 + i / 10;
        final y = a * x * x + b * x + c;
        if (y >= -10 && y <= 10) {
          points.add('${n(280 + x * 28)},${n(160 - y * 12)}');
        }
      }
      if (points.length >= 2) {
        final path = 'M${points.join(' L')}';
        elements.add(
          '<path d="$path" fill="none" stroke="${color(p.length > 4 ? p[4] : 'teal')}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
        );
        elements.add(
          '<circle r="7" fill="#df765e" stroke="#fff" stroke-width="2"><animateMotion dur="6s" repeatCount="indefinite" path="$path"/></circle>',
        );
        if (a != 0) {
          final vx = -b / (2 * a);
          final vy = a * vx * vx + b * vx + c;
          if (vx >= -8 && vx <= 8 && vy >= -10 && vy <= 10) {
            elements.add(
              '<circle cx="${n(280 + vx * 28)}" cy="${n(160 - vy * 12)}" r="6" fill="#172c3d" stroke="#fff" stroke-width="2"/>',
            );
          }
        }
        drawCount++;
        hasSubject = true;
      }
    }
  }
  if (drawCount == 0 || !hasSubject) {
    throw const FormatException(
      'AI did not return drawable InkScript commands.',
    );
  }
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 320" role="img" aria-label="${xml(title)}"><defs><linearGradient id="inkbg" x2="1" y2="1"><stop stop-color="#fffbf2"/><stop offset="1" stop-color="#e6f5f0"/></linearGradient></defs><rect width="560" height="320" fill="url(#inkbg)"/>${elements.join()}</svg>';
  return InkScriptVisual(title, svg);
}

Map<String, dynamic> parseInkMotion(String source) {
  final tracks = <Map<String, dynamic>>[];
  var explanation = 'Motion generated for your original ink.';
  double num(String raw, double min, double max) {
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < min || value > max) {
      throw const FormatException('Invalid InkScript motion value.');
    }
    return value;
  }

  for (final line in _commands(source)) {
    final p = line.trim().split('|').map((s) => s.trim()).toList();
    if (p.isEmpty) continue;
    if (p.first.toUpperCase() == 'WHY' && p.length >= 2) {
      explanation = p.skip(1).join(' ').trim();
    } else if (p.first.toUpperCase() == 'MOVE' && p.length == 8) {
      final id = p[1];
      if (id.isEmpty || id.length > 200) continue;
      tracks.add({
        'ids': [id],
        'pivotX': num(p[2], 0, 720),
        'pivotY': num(p[3], 0, 1080),
        'dx': num(p[4], -600, 600),
        'dy': num(p[5], -900, 900),
        'angle': num(p[6], -6.3, 6.3),
        'period': num(p[7], .2, 60),
      });
    }
  }
  if (tracks.isEmpty) {
    final compactWhy = RegExp(
      r'\bWHY\s*[:|]\s*(.+?)(?:newline\s*MOVE|[|;\s]+MOVE\s*[:;|]|$)',
      caseSensitive: false,
    ).firstMatch(source);
    if (compactWhy != null) explanation = compactWhy.group(1)!.trim();
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.replaceAll('*', '').trim();
      final move = RegExp(r'\bMOVE\s*[:;|]?\s*(.+)$', caseSensitive: false)
          .firstMatch(line);
      if (move == null) continue;
      final values = move.group(1)!.split(RegExp(r'[;|,\s]+'));
      if (values.length < 7) continue;
      final id = values[0];
      if (id.isEmpty || id.length > 200) continue;
      tracks.add({
        'ids': [id],
        'pivotX': num(values[1], 0, 720),
        'pivotY': num(values[2], 0, 1080),
        'dx': num(values[3], -600, 600),
        'dy': num(values[4], -900, 900),
        'angle': num(values[5], -6.3, 6.3),
        'period': num(values[6], .2, 60),
      });
    }
  }
  if (tracks.isEmpty || tracks.length > 100) {
    throw const FormatException('AI did not return usable MOVE commands.');
  }
  return {'explanation': explanation, 'tracks': tracks};
}
