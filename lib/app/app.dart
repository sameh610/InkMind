import 'package:flutter/material.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../features/library/library.dart';
import '../features/notebook/controller.dart';
import '../features/notebook/notebook_screen.dart';
import '../features/onboarding/onboarding.dart';

class InkMindApp extends StatefulWidget {
  final InkMindController controller;
  const InkMindApp({super.key, required this.controller});
  @override
  State<InkMindApp> createState() => _InkMindAppState();
}

class _InkMindAppState extends State<InkMindApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.flush();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return MaterialApp(
        title: 'InkMind — Paper you can think with',
        debugShowCheckedModeBanner: false,
        theme: inkTheme(false),
        darkTheme: inkTheme(true),
        themeMode: c.dark ? ThemeMode.dark : ThemeMode.light,
        home: c.loading
            ? Scaffold(
                backgroundColor: InkTokens.workspaceLight,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'InkMind',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 28,
                          letterSpacing: -.6,
                          color: InkTokens.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: InkTokens.borderLight,
                          color: InkTokens.accentLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : c.error != null && c.notebooks.isEmpty
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            c.error = null;
                            c.initialize();
                          },
                          child: const Text('Retry local storage'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : !c.onboardingDone
            ? Onboarding(controller: c)
            : c.book == null
            ? LibraryScreen(controller: c)
            : NotebookScreen(key: ValueKey(c.book!.id), controller: c),
      );
    },
  );
}
