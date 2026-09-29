import 'dart:math' as math;

/// Evaluates the expression nodes emitted by the InkScript compiler. No Dart or
/// JavaScript source is executed at runtime.
class InkIrEvaluator {
  final Map<String, dynamic> values;
  const InkIrEvaluator(this.values);

  dynamic eval(dynamic raw, [int depth = 0]) {
    if (depth > 32 || raw is! Map) return null;
    final node = Map<String, dynamic>.from(raw);
    dynamic child(dynamic value) => eval(value, depth + 1);
    num number(dynamic v) => v is num && v.isFinite ? v : 0;
    bool truth(dynamic v) => v != null && v != false && v != 0 && v != '';
    switch (node['kind']) {
      case 'literal':
        return node['value'];
      case 'ref':
        return values[node['name']];
      case 'member':
        final object = values[node['object']];
        return object is Map ? object[node['property']] : null;
      case 'array':
        final items = node['items'];
        return items is List ? items.take(256).map(child).toList() : [];
      case 'object':
        final entries = node['entries'];
        if (entries is! List) return {};
        return {
          for (final entry in entries.take(256).whereType<Map>())
            entry['key'].toString(): child(entry['value']),
        };
      case 'unary':
        final v = child(node['arg']);
        switch (node['op']) {
          case '-':
            return -number(v);
          case '+':
            return number(v);
          case '!':
            return !truth(v);
        }
      case 'binary':
        final a = child(node['left']), b = child(node['right']);
        final x = number(a), y = number(b);
        dynamic result;
        switch (node['op']) {
          case '+':
            result = a is String || b is String ? '$a$b' : x + y;
            break;
          case '-':
            result = x - y;
            break;
          case '*':
            result = x * y;
            break;
          case '/':
            result = y == 0 ? 0 : x / y;
            break;
          case '%':
            result = y == 0 ? 0 : x % y;
            break;
          case '**':
            result = math.pow(x, y);
            break;
          case '>':
            return x > y;
          case '<':
            return x < y;
          case '>=':
            return x >= y;
          case '<=':
            return x <= y;
          case '==':
          case '===':
            return a == b;
          case '!=':
          case '!==':
            return a != b;
          case '&&':
            return truth(a) && truth(b);
          case '||':
            return truth(a) || truth(b);
        }
        return result is num && !result.isFinite ? 0 : result;
      case 'conditional':
        return truth(child(node['test']))
            ? child(node['yes'])
            : child(node['no']);
      case 'template':
        final parts = node['parts'] is List ? node['parts'] as List : [];
        final expressions = node['values'] is List
            ? node['values'] as List
            : [];
        final out = StringBuffer();
        for (var i = 0; i < parts.length && i < 64; i++) {
          out.write(parts[i]);
          if (i < expressions.length) out.write(child(expressions[i]));
        }
        return out.toString();
      case 'math':
        final args = node['args'] is List
            ? (node['args'] as List)
                  .take(8)
                  .map((v) => number(child(v)).toDouble())
                  .toList()
            : <double>[];
        final a = args.isEmpty ? 0.0 : args.first;
        final b = args.length < 2 ? 0.0 : args[1];
        final value = switch (node['fn']) {
          'sin' => math.sin(a),
          'cos' => math.cos(a),
          'tan' => math.tan(a),
          'sqrt' => math.sqrt(math.max(0, a)),
          'abs' => a.abs(),
          'pow' => math.pow(a, b).toDouble(),
          'min' => args.isEmpty ? 0.0 : args.reduce(math.min),
          'max' => args.isEmpty ? 0.0 : args.reduce(math.max),
          _ => 0.0,
        };
        return value.isFinite ? value : 0;
      case 'quantity':
        return {'value': child(node['value']), 'unit': child(node['unit'])};
    }
    return null;
  }
}
