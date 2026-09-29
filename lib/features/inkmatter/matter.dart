class MatterCommand {
  final String property, unit;
  final dynamic value;
  const MatterCommand(this.property, this.value, [this.unit = '']);
}

MatterCommand? parseModifier(
  String text,
  String target,
  Map<String, dynamic> current,
) {
  final s = text.trim().toLowerCase();
  if (s == 'moon' &&
      {
        'pendulum',
        'projectile',
        'ball',
        'spring',
        'ramp',
        'living',
      }.contains(target)) {
    return MatterCommand('gravity', 1.62, 'm/s²');
  }
  if (s == 'earth' &&
      {
        'pendulum',
        'projectile',
        'ball',
        'spring',
        'ramp',
        'living',
      }.contains(target)) {
    return MatterCommand('gravity', 9.81, 'm/s²');
  }
  final speed = RegExp(r'^(\d+(?:\.\d+)?)x\s+velocity$').firstMatch(s);
  if (speed != null &&
      {'ball', 'projectile', 'ramp', 'living'}.contains(target)) {
    final value =
        (current['velocity'] as num? ?? 20) * double.parse(speed.group(1)!);
    if (value > 0 && value <= 200) {
      return MatterCommand('velocity', value.toDouble(), 'm/s');
    }
  }
  if (s == 'no friction' && target == 'ramp') {
    return MatterCommand('friction', 0.0);
  }
  final volts = RegExp(r'^(\d+(?:\.\d+)?)v$').firstMatch(s);
  if (volts != null && target == 'circuit') {
    return MatterCommand(
      'voltage',
      double.parse(volts.group(1)!).clamp(0, 100),
      'V',
    );
  }
  if (s == 'sort descending' && target == 'algorithm') {
    return MatterCommand('descending', true);
  }
  if (s == 'api fails' && target == 'flow') {
    return MatterCommand('failed', true);
  }
  final conversion = RegExp(
    r'^conversion\s*=\s*(\d+(?:\.\d+)?)%$',
  ).firstMatch(s);
  if (conversion != null && target == 'calculator') {
    return MatterCommand(
      'conversion',
      (double.parse(conversion.group(1)!) / 100).clamp(0, 1),
    );
  }
  return null;
}
