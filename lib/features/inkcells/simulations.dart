import 'dart:math' as math;
import 'dart:ui';

Offset projectile(double t, double velocity, double angle, double gravity) {
  final theta = angle * math.pi / 180;
  return Offset(
    velocity * math.cos(theta) * t,
    velocity * math.sin(theta) * t - .5 * gravity * t * t,
  );
}

double pendulumPeriod(double length, double gravity) =>
    2 * math.pi * math.sqrt(length / gravity);

class AlgorithmFrame {
  final List<int> values, active;
  final String caption;
  const AlgorithmFrame(this.values, this.active, this.caption);
}

List<AlgorithmFrame> algorithmFrames(
  String type,
  List<int> source, {
  bool descending = false,
  int target = 6,
}) {
  final values = List<int>.of(source), frames = <AlgorithmFrame>[];
  void record(String message, List<int> active) {
    frames.add(AlgorithmFrame(List.of(values), active, message));
  }

  record('Start with ${values.length} values.', []);
  if (type == 'binary search') {
    values.sort();
    record('Binary search requires a sorted array.', []);
    var low = 0, high = values.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      record('Compare $target with ${values[mid]} at index $mid.', [mid]);
      if (values[mid] == target) {
        record('Found $target at index $mid.', [mid]);
        break;
      }
      if (values[mid] < target) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (low > high) record('$target is not in the array.', []);
  } else if (type == 'graph traversal') {
    for (var i = 0; i < values.length; i++) {
      record(
        'Breadth-first visit: node ${values[i]}.',
        List.generate(i + 1, (j) => j),
      );
    }
  } else if (type == 'insertion sort') {
    for (var i = 1; i < values.length; i++) {
      var j = i;
      while (j > 0 &&
          (descending
              ? values[j] > values[j - 1]
              : values[j] < values[j - 1])) {
        final v = values[j];
        values[j] = values[j - 1];
        values[j - 1] = v;
        record('Insert $v into the sorted prefix.', [j, j - 1]);
        j--;
      }
    }
    record('Sorted ${descending ? 'descending' : 'ascending'}.', []);
  } else {
    for (var i = 0; i < values.length; i++) {
      for (var j = 0; j < values.length - i - 1; j++) {
        record('Compare neighbors ${values[j]} and ${values[j + 1]}.', [
          j,
          j + 1,
        ]);
        if (descending
            ? values[j] < values[j + 1]
            : values[j] > values[j + 1]) {
          final v = values[j];
          values[j] = values[j + 1];
          values[j + 1] = v;
          record('Swap this pair.', [j, j + 1]);
        }
      }
    }
    record('Sorted ${descending ? 'descending' : 'ascending'}.', []);
  }
  return frames;
}

/// Real, deterministic 2–4–1 sigmoid network, trained with backpropagation.
class XorNetwork {
  late List<List<double>> weights;
  late List<double> bias, out;
  double outBias = 0, loss = 1, accuracy = 0;
  int epoch = 0;
  XorNetwork() {
    final r = math.Random(42);
    weights = List.generate(
      4,
      (_) => List.generate(2, (_) => r.nextDouble() * 2 - 1),
    );
    bias = List.generate(4, (_) => r.nextDouble() - .5);
    out = List.generate(4, (_) => r.nextDouble() * 2 - 1);
  }
  double sigmoid(double x) => 1 / (1 + math.exp(-x.clamp(-30, 30)));
  List<double> hidden(double x, double y) => List.generate(
    4,
    (i) => sigmoid(weights[i][0] * x + weights[i][1] * y + bias[i]),
  );
  double predict(double x, double y) {
    final h = hidden(x, y);
    return sigmoid(
      outBias + List.generate(4, (i) => h[i] * out[i]).reduce((a, b) => a + b),
    );
  }

  void train([int count = 50]) {
    const data = [
      [0.0, 0.0, 0.0],
      [0.0, 1.0, 1.0],
      [1.0, 0.0, 1.0],
      [1.0, 1.0, 0.0],
    ];
    for (var n = 0; n < count; n++) {
      for (final row in data) {
        final h = hidden(row[0], row[1]), prediction = predict(row[0], row[1]);
        final delta = prediction - row[2];
        for (var i = 0; i < 4; i++) {
          final dh = delta * out[i] * h[i] * (1 - h[i]);
          weights[i][0] -= .35 * dh * row[0];
          weights[i][1] -= .35 * dh * row[1];
          bias[i] -= .35 * dh;
          out[i] -= .35 * delta * h[i];
        }
        outBias -= .35 * delta;
      }
      epoch++;
    }
    loss = 0;
    accuracy = 0;
    for (final row in data) {
      final p = predict(row[0], row[1]).clamp(.00001, .99999);
      loss -= row[2] * math.log(p) + (1 - row[2]) * math.log(1 - p);
      if ((p >= .5 ? 1 : 0) == row[2]) accuracy += .25;
    }
    loss /= 4;
  }
}
