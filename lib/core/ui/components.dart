import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Primary action — restrained, not Material flashy.
class InkPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const InkPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  @override
  State<InkPrimaryButton> createState() => _InkPrimaryButtonState();
}

class _InkPrimaryButtonState extends State<InkPrimaryButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    final enabled = widget.onPressed != null;
    final child = AnimatedContainer(
      duration: InkTokens.instant,
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: widget.icon != null ? 18 : 22),
      decoration: BoxDecoration(
        color: enabled
            ? (_down
                ? Color.lerp(colors.accent, colors.textPrimary, .12)
                : _hover
                    ? Color.lerp(colors.accent, Colors.white, .06)
                    : colors.accent)
            : colors.border,
        borderRadius: BorderRadius.circular(InkTokens.r12),
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: -.1,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: widget.expand ? child : IntrinsicWidth(child: child),
      ),
    );
  }
}

class InkGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const InkGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class InkIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;

  const InkIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(InkTokens.r8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(InkTokens.r8),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? colors.accent
                  : onPressed == null
                      ? colors.textTertiary
                      : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet grouped settings section.
class InkSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const InkSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
                color: colors.textTertiary,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(InkTokens.r12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InkSettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const InkSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Subtle ink-line progress indicator.
class InkLineLoader extends StatelessWidget {
  final bool active;
  const InkLineLoader({super.key, this.active = true});

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    if (!active) return const SizedBox(height: 2);
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        backgroundColor: colors.border,
        color: colors.accent,
        minHeight: 2,
      ),
    );
  }
}

/// Compact sheet chrome used for create-notebook / pages / tool options.
Future<T?> showInkSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? heightFactor,
  bool dismissible = true,
}) {
  final layout = MediaQuery.sizeOf(context);
  final isPhone = layout.width < 600;
  if (isPhone) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = InkColors.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: layout.height * (heightFactor ?? .72),
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(InkTokens.r20),
              ),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        );
      },
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) {
      final colors = InkColors.of(ctx);
      return Dialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.r16),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: builder(ctx),
        ),
      );
    },
  );
}
