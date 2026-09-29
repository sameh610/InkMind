import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

enum InkTool { pen, pencil, highlighter, eraser, lasso, hand }

enum PaperKind { blank, lined, grid, dotted }

class InkPoint {
  final Offset position;
  final double pressure;
  final int time;
  const InkPoint(this.position, [this.pressure = .5, this.time = 0]);
}

class InkStroke {
  final String id;
  final InkTool tool;
  final int color;
  final double width;
  final List<InkPoint> points;
  final int created;
  InkStroke({
    required this.id,
    required this.points,
    this.tool = InkTool.pen,
    this.color = 0xff303c38,
    this.width = 2.5,
    int? created,
  }) : created = created ?? DateTime.now().millisecondsSinceEpoch;
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.position.dx, right = left;
    var top = points.first.position.dy, bottom = top;
    for (final p in points) {
      left = math.min(left, p.position.dx);
      right = math.max(right, p.position.dx);
      top = math.min(top, p.position.dy);
      bottom = math.max(bottom, p.position.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(width / 2);
  }

  InkStroke transformed(
    Offset delta, {
    double scale = 1,
    Offset origin = Offset.zero,
  }) => InkStroke(
    id: id,
    tool: tool,
    color: color,
    width: width * scale,
    created: created,
    points: points
        .map(
          (p) => InkPoint(
            origin + (p.position - origin) * scale + delta,
            p.pressure,
            p.time,
          ),
        )
        .toList(),
  );
}

/// Ramer–Douglas–Peucker, retaining timing and pressure on chosen samples.
List<InkPoint> simplifyStroke(List<InkPoint> points, [double tolerance = .65]) {
  if (points.length < 3) return List.of(points);
  final keep = <int>{0, points.length - 1};
  final work = <(int, int)>[(0, points.length - 1)];
  while (work.isNotEmpty) {
    final (start, end) = work.removeLast();
    var maxDistance = tolerance, farthest = -1;
    for (var i = start + 1; i < end; i++) {
      final distance = distanceToSegment(
        points[i].position,
        points[start].position,
        points[end].position,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        farthest = i;
      }
    }
    if (farthest != -1) {
      keep.add(farthest);
      work.add((start, farthest));
      work.add((farthest, end));
    }
  }
  return (keep.toList()..sort()).map((i) => points[i]).toList();
}

double distanceToSegment(Offset p, Offset a, Offset b) {
  final v = b - a;
  if (v.distanceSquared == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * v.dx + (p.dy - a.dy) * v.dy) / v.distanceSquared)
      .clamp(0.0, 1.0);
  return (p - (a + v * t)).distance;
}

/// IMK1: little endian. 1/16px signed coordinate deltas, uint8 pressure,
/// uint32 relative milliseconds. No JSON objects per persisted point.
class StrokeCodec {
  static Uint8List encode(InkStroke s) {
    final bytes = ByteData(28 + s.points.length * 13);
    bytes.setUint32(0, 0x494d4b31);
    bytes.setUint8(4, s.tool.index);
    bytes.setUint32(5, s.color, Endian.little);
    bytes.setFloat32(9, s.width, Endian.little);
    bytes.setFloat64(13, s.created.toDouble(), Endian.little);
    bytes.setUint32(21, s.points.length, Endian.little);
    var x = 0, y = 0, offset = 28;
    for (final p in s.points) {
      final nx = (p.position.dx * 16).round(),
          ny = (p.position.dy * 16).round();
      bytes.setInt32(offset, nx - x, Endian.little);
      bytes.setInt32(offset + 4, ny - y, Endian.little);
      bytes.setUint8(offset + 8, (p.pressure.clamp(0, 1) * 255).round());
      bytes.setUint32(offset + 9, p.time.clamp(0, 0xffffffff), Endian.little);
      x = nx;
      y = ny;
      offset += 13;
    }
    return bytes.buffer.asUint8List();
  }

  static InkStroke decode(String id, Uint8List data) {
    final b = ByteData.sublistView(data);
    if (data.length < 28 || b.getUint32(0) != 0x494d4b31) {
      throw FormatException('Invalid ink data');
    }
    final n = b.getUint32(21, Endian.little);
    if (data.length != 28 + n * 13 || b.getUint8(4) >= InkTool.values.length) {
      throw FormatException('Corrupt ink');
    }
    var x = 0, y = 0;
    final points = <InkPoint>[];
    for (var i = 0; i < n; i++) {
      final o = 28 + i * 13;
      x += b.getInt32(o, Endian.little);
      y += b.getInt32(o + 4, Endian.little);
      points.add(
        InkPoint(
          Offset(x / 16, y / 16),
          b.getUint8(o + 8) / 255,
          b.getUint32(o + 9, Endian.little),
        ),
      );
    }
    return InkStroke(
      id: id,
      points: points,
      tool: InkTool.values[b.getUint8(4)],
      color: b.getUint32(5, Endian.little),
      width: b.getFloat32(9, Endian.little),
      created: b.getFloat64(13, Endian.little).round(),
    );
  }
}

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(0xffffff)}';

class PageObject {
  final String id;
  String kind, text;
  double x, y, width, height;
  Map<String, dynamic> data;
  PageObject({
    String? id,
    required this.kind,
    this.text = '',
    this.x = 70,
    this.y = 160,
    this.width = 520,
    this.height = 350,
    Map<String, dynamic>? data,
  }) : id = id ?? newId(),
       data = data ?? {};
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'text': text,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'data': data,
  };
  factory PageObject.fromJson(Map<String, dynamic> j) => PageObject(
    id: j['id'],
    kind: j['kind'],
    text: j['text'] ?? '',
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width: (j['width'] as num).toDouble(),
    height: (j['height'] as num).toDouble(),
    data: Map<String, dynamic>.from(j['data'] ?? {}),
  );
}

class InkPage {
  final String id;
  String title;
  PaperKind paper;
  List<InkStroke> strokes;
  List<PageObject> objects;
  Map<String, String> labels;
  InkPage({
    String? id,
    this.title = 'Untitled page',
    this.paper = PaperKind.dotted,
    List<InkStroke>? strokes,
    List<PageObject>? objects,
    Map<String, String>? labels,
  }) : id = id ?? newId(),
       strokes = strokes ?? [],
       objects = objects ?? [],
       labels = labels ?? {};
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'paper': paper.index,
    'strokes': strokes
        .map((s) => {'id': s.id, 'bytes': base64Encode(StrokeCodec.encode(s))})
        .toList(),
    'objects': objects.map((o) => o.toJson()).toList(),
    'labels': labels,
  };
  factory InkPage.fromJson(Map<String, dynamic> j) => InkPage(
    id: j['id'],
    title: j['title'],
    paper: PaperKind.values[j['paper']],
    strokes: (j['strokes'] as List)
        .map((s) => StrokeCodec.decode(s['id'], base64Decode(s['bytes'])))
        .toList(),
    objects: (j['objects'] as List)
        .map((o) => PageObject.fromJson(Map<String, dynamic>.from(o)))
        .toList(),
    labels: Map<String, String>.from(j['labels'] ?? {}),
  );
  InkPage copy({bool newIdentity = false}) {
    final j = toJson();
    if (newIdentity) j['id'] = newId();
    return InkPage.fromJson(j);
  }
}

class Notebook {
  final String id;
  String title;
  int color;
  DateTime edited;
  List<InkPage> pages;
  bool playground;
  Notebook({
    String? id,
    required this.title,
    this.color = 0xff416d5b,
    DateTime? edited,
    List<InkPage>? pages,
    this.playground = false,
  }) : id = id ?? newId(),
       edited = edited ?? DateTime.now(),
       pages = pages ?? [InkPage()];
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'color': color,
    'edited': edited.toIso8601String(),
    'playground': playground,
    'pages': pages.map((p) => p.toJson()).toList(),
  };
  factory Notebook.fromJson(Map<String, dynamic> j) => Notebook(
    id: j['id'],
    title: j['title'],
    color: j['color'],
    edited: DateTime.parse(j['edited']),
    playground: j['playground'] ?? false,
    pages: (j['pages'] as List)
        .map((p) => InkPage.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}
