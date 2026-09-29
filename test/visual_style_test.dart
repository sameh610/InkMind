import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkmind/core/models/ink.dart';
import 'package:inkmind/core/theme/theme.dart';
import 'package:inkmind/core/theme/tokens.dart';
import 'package:inkmind/features/visuals/visual_view.dart';

void main() {
  testWidgets('older generated graph adopts dark notebook styling', (
    tester,
  ) async {
    Map<String, dynamic> lit(Object value) => {
      'kind': 'literal',
      'value': value,
    };
    Map<String, dynamic> ref(String name) => {'kind': 'ref', 'name': name};
    Map<String, dynamic> node(
      String type, {
      Map<String, dynamic>? props,
      List<Map<String, dynamic>>? children,
    }) => {
      'type': type,
      'props': props ?? <String, dynamic>{},
      'children': children ?? <Map<String, dynamic>>[],
    };
    final ir = <String, dynamic>{
      'mode': 'visual',
      'state': [
        {'name': 'a', 'value': 3, 'reactive': true},
        {'name': 'b', 'value': 0, 'reactive': true},
        {'name': 'c', 'value': -1, 'reactive': true},
      ],
      'root': node(
        'App',
        props: {'title': lit('Quadratic Explorer')},
        children: [
          node(
            'Panel',
            children: [
              node(
                'Heading',
                children: [
                  node('Text', props: {'value': lit('Quadratic Explorer')}),
                ],
              ),
              node('Text', props: {'value': lit('Explore the selected idea.')}),
            ],
          ),
          node('Graph', props: {'a': ref('a'), 'b': ref('b'), 'c': ref('c')}),
          node(
            'Controls',
            children: [
              for (final name in ['a', 'b', 'c'])
                node(
                  'Slider',
                  props: {
                    'label': lit(name),
                    'value': ref(name),
                    'min': lit(-6),
                    'max': lit(6),
                  },
                ),
            ],
          ),
        ],
      ),
    };
    final object = PageObject(
      kind: 'visual',
      data: {
        'style': 'ir',
        'title': 'Quadratic Explorer',
        'caption': '',
        'ir': ir,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: inkTheme(false),
        darkTheme: inkTheme(true),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          backgroundColor: InkTokens.paperDark,
          body: Center(
            child: SizedBox(
              width: 560,
              height: 620,
          child: AiVisualView(object: object),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Quadratic Explorer'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    final card = tester.widget<Container>(
      find.descendant(
        of: find.byType(AiVisualView),
        matching: find.byType(Container),
      ).first,
    );
    expect((card.decoration as BoxDecoration).color, InkTokens.surfaceDark);
  });
}
