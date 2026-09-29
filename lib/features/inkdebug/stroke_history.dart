import 'dart:convert';
import 'dart:typed_data';
import '../../core/models/ink.dart';

/// A frozen copy of the selected pen samples, including their original clocks.
List<Map<String, dynamic>> captureStrokeHistory(Iterable<InkStroke> selection) {
  final strokes = selection.toList()
    ..sort((a, b) => a.created.compareTo(b.created));
  return strokes
      .map((s) => {'id': s.id, 'bytes': base64Encode(StrokeCodec.encode(s))})
      .toList();
}

List<InkStroke> readStrokeHistory(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map(
        (entry) => StrokeCodec.decode(
          entry['id'] as String,
          Uint8List.fromList(base64Decode(entry['bytes'] as String)),
        ),
      )
      .toList()
    ..sort((a, b) => a.created.compareTo(b.created));
}

/// Assign horizontal handwritten rows without reordering the stored strokes.
List<List<InkStroke>> historyRows(List<InkStroke> strokes) {
  final sorted = List<InkStroke>.of(strokes)
    ..sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));
  final rows = <List<InkStroke>>[];
  for (final stroke in sorted) {
    final row = rows.where((r) {
      final bounds = r
          .map((s) => s.bounds)
          .reduce((a, b) => a.expandToInclude(b));
      return stroke.bounds.center.dy >= bounds.top - 12 &&
          stroke.bounds.center.dy <= bounds.bottom + 12;
    }).firstOrNull;
    if (row == null) {
      rows.add([stroke]);
    } else {
      row.add(stroke);
    }
  }
  for (final row in rows) {
    row.sort((a, b) => a.created.compareTo(b.created));
  }
  return rows;
}

/// Reveal exactly a prefix of recorded samples, retaining pressure and timing.
InkStroke strokeAtTime(InkStroke stroke, double absoluteTime) => InkStroke(
  id: stroke.id,
  tool: stroke.tool,
  color: stroke.color,
  width: stroke.width,
  created: stroke.created,
  points: stroke.points
      .where((p) => stroke.created + p.time <= absoluteTime)
      .toList(),
);
