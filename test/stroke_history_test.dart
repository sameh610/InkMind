import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/features/inkdebug/stroke_history.dart';
import 'package:inkmind/features/notebook/demo_ink.dart';

void main() {
  test('history round trip retains pen identity, pressure and timing', () {
    final s=InkStroke(id:'pen',created:100,points:[const InkPoint(Offset(1,2),.6,0),const InkPoint(Offset(3,4),.8,40)]);
    final history=readStrokeHistory(captureStrokeHistory([s]));
    expect(history.single.id,'pen');expect(history.single.created,100);
    expect(history.single.points.last.time,40);
    expect(strokeAtTime(history.single,120).points.length,1);
    expect(strokeAtTime(history.single,99).points,isEmpty);
  });
  test('reasoning fixture maps three rows with real ordered sample clocks', () {
    final ink=reasoningInk(), rows=historyRows(reasoningInk());
    expect(rows.length,3);expect(rows.every((r)=>r.isNotEmpty),isTrue);
    for(var i=1;i<ink.length;i++) { expect(ink[i].created,greaterThan(ink[i-1].created+ink[i-1].points.last.time)); }
  });
}
