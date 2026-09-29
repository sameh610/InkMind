import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../../core/theme/tokens.dart';
import '../ai/engine.dart';
import 'history_canvas.dart';
import 'stroke_history.dart';

class DebugView extends StatefulWidget {
  final PageObject object;
  const DebugView({super.key, required this.object});
  @override
  State<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends State<DebugView>
    with SingleTickerProviderStateMixin {
  late final AnimationController replay;
  late DebugResult result;
  late List<InkStroke> history;

  @override
  void initState() {
    super.initState();
    final data = widget.object.data;
    history = readStrokeHistory(data['strokeHistory']);
    result = data['steps'] is List
        ? DebugResult(
            (data['steps'] as List).cast<String>(),
            data['firstError'] as int?,
            data['explanation'] as String,
            (data['corrected'] as List).cast<String>(),
          )
        : debugMath(data['source'] ?? widget.object.text);
    replay = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      replay.value = 1;
    } else {
      replay.forward();
    }
  }

  @override
  void dispose() {
    replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return AnimatedBuilder(
      animation: replay,
      builder: (context, _) {
        final progress = replay.value;
        final error = result.firstError;
        final found = error != null && progress >= .42;
        final status = error == null
            ? 'CHECKING REASONING'
            : progress < .42
            ? 'REWINDING YOUR PATH'
            : progress < .58
            ? 'FIRST DIVERGENCE · STEP ${error + 1}'
            : progress < .96
            ? 'BRANCHING FROM STEP ${error + 1}'
            : 'CORRECTED PATH';
        double phase(double start, double end) =>
            ((progress - start) / (end - start)).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          decoration: BoxDecoration(
            color: colors.paper.withValues(alpha: .7),
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(InkTokens.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'InkDebug',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Replay reasoning',
                    onPressed: () => replay.forward(from: 0),
                    icon: Icon(
                      Icons.replay,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: found ? colors.danger : colors.textTertiary,
                ),
              ),
              Expanded(
                child: history.isNotEmpty
                    ? Semantics(
                        label:
                            'Recorded pen history, ${history.length} strokes. Corrected branch: ${result.corrected.join(', ')}',
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: HistoryCanvas(
                            strokes: history,
                            firstError: error,
                            progress: progress,
                            color: colors.textPrimary,
                            accent: colors.accent,
                            corrected: result.corrected,
                          ),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: history.isNotEmpty
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RECORDED PEN HISTORY · ${history.length} STROKES',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: HistoryCanvas(
                                          strokes: history,
                                          firstError: error,
                                          progress: progress,
                                          color: colors.textPrimary,
                                          accent: colors.danger,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your path',
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: .5,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...result.steps.asMap().entries.map(
                                        (e) => Opacity(
                                          opacity:
                                              error != null && e.key > error
                                              ? 1 -
                                                    phase(
                                                      .07 +
                                                          (result.steps.length -
                                                                  1 -
                                                                  e.key) *
                                                              .09,
                                                      .20 +
                                                          (result.steps.length -
                                                                  1 -
                                                                  e.key) *
                                                              .09,
                                                    )
                                              : 1,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: _stepText(
                                              e.value,
                                              isError: e.key == error,
                                              highlight: phase(.36, .48),
                                              textColor: colors.textPrimary,
                                              errorColor: colors.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Opacity(
                                  opacity: phase(.57, .68),
                                  child: Text(
                                    'Corrected branch',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: .5,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...result.corrected.asMap().entries.map(
                                  (entry) => Opacity(
                                    opacity: phase(
                                      .60 + entry.key * .13,
                                      .72 + entry.key * .13,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontFamily: 'Caveat',
                                          fontSize: 22,
                                          color: colors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              Opacity(
                opacity: phase(.83, .96),
                child: Text(
                  result.explanation,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  semanticFormatterCallback: (v) =>
                      'Reasoning replay ${(v * 100).round()} percent',
                  value: replay.value,
                  onChanged: (v) {
                    replay.stop();
                    replay.value = v;
                  },
                ),
              ),
              Text(
                result.firstError == null
                    ? '${result.supported ? 'Verified' : 'Not verified'} · ${result.steps.length} steps'
                    : progress >= .58
                    ? 'Step ${result.firstError! + 1} changed the solution · correction starts here'
                    : 'Step 1 → Step 2 → ✕ Step ${result.firstError! + 1}',
                style: TextStyle(fontSize: 10, color: colors.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepText(
    String value, {
    required bool isError,
    required double highlight,
    required Color textColor,
    required Color errorColor,
  }) {
    final equals = value.lastIndexOf('=');
    if (!isError || equals < 0) {
      return Text(
        value,
        style: TextStyle(fontFamily: 'Caveat', fontSize: 22, color: textColor),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.substring(0, equals + 1),
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 22,
            color: textColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: .14 * highlight),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: errorColor.withValues(alpha: .75 * highlight),
            ),
          ),
          child: Text(
            value.substring(equals + 1).trim(),
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color.lerp(textColor, errorColor, highlight),
            ),
          ),
        ),
      ],
    );
  }
}
