import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/haptics.dart';
import '../../features/ai/engine.dart';

/// Slim floating pencil-case toolbar.
class InkToolbar extends StatelessWidget {
  final InkTool tool;
  final bool gestureMode;
  final int inkColor;
  final double inkWidth;
  final bool phone;
  final ValueChanged<InkTool> onTool;
  final VoidCallback onToggleGesture;
  final ValueChanged<int> onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback onAddText;
  final VoidCallback onAddModifier;
  final Widget? trailing;

  const InkToolbar({
    super.key,
    required this.tool,
    required this.gestureMode,
    required this.inkColor,
    required this.inkWidth,
    required this.phone,
    required this.onTool,
    required this.onToggleGesture,
    required this.onColor,
    required this.onWidth,
    required this.onAddText,
    required this.onAddModifier,
    this.trailing,
  });

  static const _tools = [
    (InkTool.pen, Icons.edit_outlined, 'Pen'),
    (InkTool.pencil, Icons.draw_outlined, 'Pencil'),
    (InkTool.highlighter, Icons.highlight_outlined, 'Highlighter'),
    (InkTool.eraser, Icons.auto_fix_normal_outlined, 'Eraser'),
    (InkTool.lasso, Icons.gesture, 'Lasso / select'),
    (InkTool.hand, Icons.pan_tool_outlined, 'Pan'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._tools.map((item) {
          final selected = tool == item.$1 && !gestureMode;
          return _ToolSlot(
            tooltip: item.$3,
            selected: selected,
            icon: item.$2,
            onTap: () {
              InkHaptics.selection();
              onTool(item.$1);
            },
          );
        }),
        _Divider(colors),
        _ColorSlot(
          color: inkColor,
          onSelected: (v) {
            InkHaptics.selection();
            onColor(v);
          },
        ),
        _WidthSlot(
          width: inkWidth,
          onSelected: (v) {
            InkHaptics.selection();
            onWidth(v);
          },
        ),
        _Divider(colors),
        _ToolSlot(
          tooltip: 'Add text',
          icon: Icons.text_fields,
          onTap: onAddText,
        ),
        _ToolSlot(
          tooltip: 'Add InkMatter modifier',
          icon: Icons.scatter_plot_outlined,
          onTap: onAddModifier,
        ),
        _ToolSlot(
          tooltip: 'Gesture mode',
          icon: Icons.auto_awesome_motion_outlined,
          selected: gestureMode,
          onTap: () {
            InkHaptics.selection();
            onToggleGesture();
          },
        ),
        if (trailing != null) ...[_Divider(colors), trailing!],
      ],
    );

    return Material(
      color: colors.surface.withValues(alpha: .96),
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(
        phone ? InkTokens.r16 : InkTokens.r20,
      ),
      child: Container(
        height: phone ? 52 : 48,
        padding: EdgeInsets.symmetric(horizontal: phone ? 6 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            phone ? InkTokens.r16 : InkTokens.r20,
          ),
          border: Border.all(color: colors.border),
          boxShadow: InkTokens.toolShadow(),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        ),
      ),
    );
  }
}

class _ToolSlot extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolSlot({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(InkTokens.r8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(InkTokens.r8),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: selected ? colors.accent : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final InkColors colors;
  const _Divider(this.colors);
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: colors.border,
  );
}

class _ColorSlot extends StatelessWidget {
  final int color;
  final ValueChanged<int> onSelected;
  const _ColorSlot({required this.color, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Ink color',
      onSelected: onSelected,
      offset: const Offset(0, -8),
      itemBuilder: (_) => [
        for (var i = 0; i < InkTokens.inkPalette.length; i++)
          PopupMenuItem(
            value: InkTokens.inkPalette[i],
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(InkTokens.inkPalette[i]),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderStrong),
                  ),
                ),
                const SizedBox(width: 12),
                Text(InkTokens.inkPaletteNames[i]),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderStrong, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _WidthSlot extends StatelessWidget {
  final double width;
  final ValueChanged<double> onSelected;
  const _WidthSlot({required this.width, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return PopupMenuButton<double>(
      tooltip: 'Stroke width',
      onSelected: onSelected,
      itemBuilder: (_) => [1.5, 2.5, 4.0, 7.0]
          .map(
            (w) => PopupMenuItem(
              value: w,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: w,
                    decoration: BoxDecoration(
                      color: colors.textPrimary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    w == width ? '●' : '○',
                    style: TextStyle(color: colors.accent),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Container(
            width: 16,
            height: width.clamp(1.5, 7),
            decoration: BoxDecoration(
              color: colors.textPrimary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contextual AI actions — appears near selection, never dominates.
class InkContextActions extends StatelessWidget {
  final bool working;
  final bool compact;
  final VoidCallback onExplain;
  final VoidCallback onMakeAlive;
  final VoidCallback onAnimateInk;
  final VoidCallback onCreateVisual;
  final VoidCallback onRunInk;
  final VoidCallback onDebug;
  final VoidCallback onQuiz;
  final ValueChanged<InkAction> onMore;

  const InkContextActions({
    super.key,
    required this.working,
    required this.compact,
    required this.onExplain,
    required this.onMakeAlive,
    required this.onAnimateInk,
    required this.onCreateVisual,
    required this.onRunInk,
    required this.onDebug,
    required this.onQuiz,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    Widget chip(String label, IconData icon, VoidCallback onTap) =>
        TextButton.icon(
          onPressed: working ? null : onTap,
          style: TextButton.styleFrom(
            foregroundColor: working ? colors.textTertiary : colors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(icon, size: 14),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        );

    return Material(
      color: colors.surface.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(InkTokens.r16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InkTokens.r16),
          border: Border.all(color: colors.border),
          boxShadow: InkTokens.toolShadow(),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chip('Explain', Icons.question_mark, onExplain),

              PopupMenuButton<String>(
                tooltip: 'Choose how AI should make it alive',
                enabled: !working,
                onSelected: (v) {
                  if (v == 'ink') {
                    onAnimateInk();
                  } else {
                    onCreateVisual();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'ink', child: Text('Animate my ink')),
                  PopupMenuItem(
                    value: 'visual',
                    child: Text('Create a new visual'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 14,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 5),
                      const Text('Make Alive'),
                      Icon(Icons.expand_more, size: 16, color: colors.accent),
                    ],
                  ),
                ),
              ),

              chip('Debug', Icons.bug_report_outlined, onDebug),
              if (!compact) chip('Create quiz', Icons.style_outlined, onQuiz),
              PopupMenuButton<InkAction>(
                tooltip: 'More study actions',
                enabled: !working,
                onSelected: onMore,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: InkAction.quiz,
                    child: Text('Create quiz'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.hint,
                    child: Text('Hint'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.check,
                    child: Text('Check'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.summarize,
                    child: Text('Summarize'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.continueIdea,
                    child: Text('Continue idea'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.flashcards,
                    child: Text('Create flashcards'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.prerequisite,
                    child: Text('Find prerequisite'),
                  ),
                  const PopupMenuItem(
                    value: InkAction.rewrite,
                    child: Text('Rewrite'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.more_horiz, size: 16, color: colors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Study',
                        style: TextStyle(fontSize: 12, color: colors.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
