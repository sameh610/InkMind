import 'dart:math' as math;
import 'dart:ui';
import '../../core/models/ink.dart';

// Editable pen fixtures. Every path keeps its own timestamp, sample times and
// pressure; InkDebug replays these samples instead of a font replacement.
List<InkStroke> reasoningInk() {
  const glyphs = <String,List<List<double>>>{
    '3': [[0,2,5,0,10,2,11,5,7,9,4,9,9,10,12,14,11,18,6,20,0,19]],
    'x': [[0,3,12,19],[11,2,0,20]],
    '+': [[0,10,12,10],[6,4,6,17]],
    '5': [[11,0,1,0,0,9,7,8,12,11,12,17,8,20,1,19]],
    '=': [[0,7,12,7],[0,13,12,13]],
    '2': [[0,3,3,0,8,0,12,4,11,8,0,20,13,20]],
    '0': [[6,0,1,3,0,11,2,18,7,20,12,16,13,7,10,1,6,0]],
    '8': [[6,9,1,5,3,1,8,0,12,4,9,8,3,12,0,16,3,20,9,20,13,16,10,11,6,9]],
    '.': [[6,19,7,20]],
  };
  final result = <InkStroke>[];
  var clock = 1700000000000;
  final lines = ['3x + 5 = 20','3x = 25','x = 8.33'];
  for (var row=0; row<lines.length; row++) {
    var x=100.0;
    for (final ch in lines[row].split('')) {
      if (ch == ' ') { x+=14; continue; }
      for (final path in glyphs[ch] ?? <List<double>>[]) {
        final points = <InkPoint>[];
        for(var i=0;i<path.length-2;i+=2) {
          final a=Offset(x+path[i]*1.65,200+row*62+path[i+1]*1.65);
          final b=Offset(x+path[i+2]*1.65,200+row*62+path[i+3]*1.65);
          for(var j=0;j<5;j++) { points.add(InkPoint(Offset.lerp(a,b,j/4)!,.6,points.length*12)); }
        }
        result.add(InkStroke(id:newId(),points:points,width:2.6,created:clock));
        clock+=points.length*12+80;
      }
      x+=29;
    }
    clock+=600;
  }
  return result;
}

List<InkStroke> flowerInk() {
  final paths=<List<Offset>>[
    List.generate(35,(i)=>Offset(340+math.sin(i/34*math.pi)*8,480-i/34*160)),
    [const Offset(344,407),const Offset(312,370),const Offset(284,370),const Offset(300,399),const Offset(344,407)],
    [const Offset(345,430),const Offset(379,394),const Offset(405,390),const Offset(387,421),const Offset(345,430)],
    List.generate(41,(i)=>Offset(340+math.cos(i/40*math.pi*2)*15,305+math.sin(i/40*math.pi*2)*15)),
    for(var p=0;p<6;p++) List.generate(31,(i) {
      final a=p*math.pi/3,t=i/30*math.pi*2;
      final along=27+math.cos(t)*18,across=math.sin(t)*13;
      return Offset(340+math.cos(a)*along-math.sin(a)*across,305+math.sin(a)*along+math.cos(a)*across);
    }),
  ];
  return paths.map((p)=>InkStroke(id:newId(),width:3,points:p.asMap().entries.map((e)=>InkPoint(e.value,.6,e.key*12)).toList())).toList();
}
