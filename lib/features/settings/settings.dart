import '../ai/model_catalog.g.dart';
export '../ai/model_catalog.g.dart' show quantizationsFor;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../ai/engine.dart';
import '../ai/browser_engine_stub.dart'
    if (dart.library.js_interop) '../ai/browser_engine_web.dart';
import '../canvas/gestures.dart';
import '../canvas/painters.dart';
import '../library/library.dart';
import '../notebook/controller.dart';

Future<void> showSettings(BuildContext context, InkMindController c) =>
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(controller: c),
    );

Future<void> showPaywall(BuildContext context, InkMindController c) =>
    showDialog(
      context: context,
      builder: (context) => Paywall(controller: c),
    );

class SettingsDialog extends StatelessWidget {
  final InkMindController controller;
  const SettingsDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final colors = InkColors.of(context);
      final selectedModel = c.preferences['aiModel']?.toString() ?? 'Automatic';
      final selectedQuant = c.preferences['aiQuant']?.toString() ?? 'Auto';
      final availableQuants = quantizationsFor(selectedModel);
      final shownQuant = availableQuants.contains(selectedQuant)
          ? selectedQuant
          : 'Auto';
      final resolvedAi = kIsWeb
          ? browserAiSelection(selectedModel, shownQuant)
          : '$selectedModel · $shownQuant';
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Settings', style: editorial(context, 24)),
                    ),
                    IconButton(
                      tooltip: 'Close settings',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    InkSettingsSection(
                      title: 'AI performance',
                      children: [
                        InkSettingsRow(
                          title: 'Automatic model preference',
                          subtitle:
                              'Fast and Balanced favor the small planner. Quality selects a larger compatible model within an estimated memory budget. An explicit model choice takes priority.',
                          trailing: DropdownButton<String>(
                            value:
                                c.preferences['aiPerformance']?.toString() ??
                                'balanced',
                            items: const [
                              DropdownMenuItem(
                                value: 'fast',
                                child: Text('Fast'),
                              ),
                              DropdownMenuItem(
                                value: 'balanced',
                                child: Text('Balanced'),
                              ),
                              DropdownMenuItem(
                                value: 'quality',
                                child: Text('Quality'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                c.updatePreferences('aiPerformance', value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    InkSettingsSection(
                      title: 'General',
                      children: [
                        InkSettingsRow(
                          title: 'Dark paper',
                          subtitle: 'A quieter canvas after hours.',
                          trailing: Switch(
                            value: c.dark,
                            onChanged: (v) => c.updatePreferences('dark', v),
                          ),
                        ),
                        InkSettingsRow(
                          title: 'Finger navigation',
                          subtitle:
                              'Pen draws; one finger pans. Off to draw with touch.',
                          trailing: Switch(
                            value: c.preferences['fingerNavigation'] == true,
                            onChanged: (v) =>
                                c.updatePreferences('fingerNavigation', v),
                          ),
                        ),
                        InkSettingsRow(
                          title: 'Developer overlay',
                          subtitle: 'Stroke count, points, storage.',
                          trailing: Switch(
                            value: c.developer,
                            onChanged: (v) =>
                                c.updatePreferences('developer', v),
                          ),
                        ),
                      ],
                    ),
                    InkSettingsSection(
                      title: 'AI',
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kIsWeb && c.preferences['browserAi'] != false
                                    ? 'AI Engine: $resolvedAi'
                                    : 'AI Engine: Demo Engine',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                kIsWeb
                                    ? 'Browser actions use the local model. First use downloads weights; errors are shown without substituting demo answers.'
                                    : 'Native model adapters are previews in this build.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (kIsWeb)
                          InkSettingsRow(
                            title: 'Browser AI',
                            subtitle:
                                'Selected: $resolvedAi. ${browserAiStatus()}',
                            trailing: Switch(
                              value: c.preferences['browserAi'] != false,
                              onChanged: (v) =>
                                  c.updatePreferences('browserAi', v),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Models',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    _ModelRow(
                      title: 'Automatic',
                      detail: 'Resolved now: $resolvedAi',
                      size: '',
                      selected: selectedModel == 'Automatic',
                      installed: true,
                      onInstall: null,
                      onSelect: () =>
                          c.updatePreferences('aiModel', 'Automatic'),
                      selectLabel: 'Use Auto',
                    ),
                    const SizedBox(height: 8),
                    ...modelMetadata.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ModelCard(metadata: m, controller: c),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkSettingsSection(
                      title: 'Quantization',
                      children: [
                        InkSettingsRow(
                          title: shownQuant == 'Auto'
                              ? 'Auto · ${resolvedAi.split(' · ').skip(1).firstOrNull ?? 'device best'}'
                              : shownQuant,
                          subtitle:
                              'Auto chooses the best supported quant for this device. Manual choices apply when the selected runtime provides that quant.',
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Choose quantization',
                            initialValue: shownQuant,
                            onSelected: (value) =>
                                c.updatePreferences('aiQuant', value),
                            itemBuilder: (_) => availableQuants
                                .map(
                                  (value) => PopupMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            child: const Icon(Icons.tune, size: 18),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      child: Text(
                        'Spark models are registered for LiteRT-LM and Bonsai for a ternary GGUF runtime. Their cards show runtime availability honestly; Automatic only chooses a model this browser can execute.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    InkSettingsSection(
                      title: 'Notebook',
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Teach a continuous symbol, then use Gesture mode.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        ...(c.preferences['commands'] as List? ?? [])
                            .asMap()
                            .entries
                            .map((entry) {
                              final command = entry.value as Map;
                              return InkSettingsRow(
                                title: '${command['name']}',
                                subtitle: '${command['action']}',
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    final commands = List<dynamic>.from(
                                      c.preferences['commands'],
                                    );
                                    if (v == 'delete') {
                                      commands.removeAt(entry.key);
                                      c.updatePreferences('commands', commands);
                                    } else if (v == 'rename') {
                                      final name = await askText(
                                        context,
                                        'Rename command',
                                        initial: command['name'],
                                      );
                                      if (name != null) {
                                        commands[entry.key] = {
                                          ...command,
                                          'name': name,
                                        };
                                        c.updatePreferences(
                                          'commands',
                                          commands,
                                        );
                                      }
                                    } else {
                                      await trainCommand(
                                        context,
                                        c,
                                        index: entry.key,
                                      );
                                    }
                                  },
                                  itemBuilder: (_) =>
                                      ['rename', 'retrain', 'delete']
                                          .map(
                                            (v) => PopupMenuItem(
                                              value: v,
                                              child: Text(v),
                                            ),
                                          )
                                          .toList(),
                                ),
                              );
                            }),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: () => trainCommand(context, c),
                            icon: const Icon(Icons.gesture, size: 16),
                            label: const Text('Teach a symbol'),
                          ),
                        ),
                      ],
                    ),
                    InkSettingsSection(
                      title: 'Subscription',
                      children: [
                        InkSettingsRow(
                          title: 'InkMind Pro',
                          subtitle: c.pro
                              ? (c.subscription.isDemo ? 'Pro entitlement active · demo session' : 'Pro entitlement active · unlimited AI actions')
                              : 'More room for your thinking.',
                          trailing: Icon(
                            Icons.chevron_right,
                            color: colors.textTertiary,
                          ),
                          onTap: () => showPaywall(context, c),
                        ),
                      ],
                    ),
                    InkSettingsSection(
                      title: 'Privacy',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Notes stay in this browser’s IndexedDB. Clearing site data deletes them. No note content is sent to an AI provider in this preview.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'About · InkMind 0.1',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ModelCard extends StatelessWidget {
  final Map<String, Object> metadata;
  final InkMindController controller;
  const ModelCard({
    super.key,
    required this.metadata,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final id = metadata['id']! as String;
    final available = metadata['web'] == true;
    final selected = c.preferences['aiModel'] == id;
    return _ModelRow(
      title: metadata['model']! as String,
      detail:
          '${metadata['detail']! as String} · Quant: ${metadata['quants']! as String}',
      size: metadata['size']! as String,
      badge: metadata['tier']! as String,
      selected: selected,
      installed: available,
      onInstall: null,
      onSelect: available
          ? () {
              c.updatePreferences('aiQuant', 'Auto');
              c.updatePreferences('aiModel', selected ? 'Automatic' : id);
            }
          : null,
      selectLabel: selected ? 'Selected' : 'Use model',
    );
  }
}

class _ModelRow extends StatelessWidget {
  final String title;
  final String detail;
  final String size;
  final String? badge;
  final bool selected;
  final bool installed;
  final VoidCallback? onInstall;
  final VoidCallback? onSelect;
  final String installLabel;
  final String selectLabel;

  const _ModelRow({
    required this.title,
    required this.detail,
    required this.size,
    this.badge,
    required this.selected,
    required this.installed,
    this.onInstall,
    this.onSelect,
    this.selectLabel = 'Select',
  }) : installLabel = 'Download';

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(InkTokens.r12),
        border: Border.all(
          color: selected
              ? colors.accent.withValues(alpha: .45)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check, size: 14, color: colors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    ?badge,
                    detail,
                    if (size.isNotEmpty) size,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (onInstall != null)
            TextButton(
              onPressed: onInstall,
              child: Text(installLabel, style: const TextStyle(fontSize: 11)),
            ),
          if (onSelect != null)
            TextButton(
              onPressed: onSelect,
              child: Text(selectLabel, style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class Paywall extends StatefulWidget {
  final InkMindController controller;
  const Paywall({super.key, required this.controller});
  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> with SingleTickerProviderStateMixin {
  bool busy = false;
  bool annual = true;
  String? message;
  late final AnimationController hero;

  @override
  void initState() {
    super.initState();
    hero = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    hero.dispose();
    super.dispose();
  }

  Future<void> purchase(bool annual) async {
    setState(() => busy = true);
    try {
      await widget.controller.subscription.purchase(annual: annual);
      if (mounted) {
        setState(
          () => message = widget.controller.subscription.isDemo
              ? 'Demo Pro enabled for this session. No payment was taken.'
              : 'InkMind Pro is active.',
        );
        widget.controller.changed();
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Purchase could not complete: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'InkMind Pro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close paywall',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Text('Make your\npaper think.', style: editorial(context, 36)),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: hero,
                builder: (context, _) => Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: colors.paper,
                    borderRadius: BorderRadius.circular(InkTokens.r12),
                    border: Border.all(color: colors.border),
                  ),
                  child: CustomPaint(
                    painter: _PaywallHeroPainter(hero.value, colors),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...[
                'InkCells',
                'Living Ink',
                'InkMatter',
                'InkDebug',
                'Advanced local AI',
              ].map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 16, color: colors.accent),
                      const SizedBox(width: 12),
                      Text(s, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PlanOption(
                title: 'Annual',
                subtitle: 'Recommended',
                price: widget.controller.subscription.annualPrice ?? 'See checkout',
                selected: annual,
                onTap: busy ? null : () => setState(() => annual = true),
              ),
              const SizedBox(height: 10),
              _PlanOption(
                title: 'Monthly',
                subtitle: 'Flexible',
                price: widget.controller.subscription.monthlyPrice ?? 'See checkout',
                selected: !annual,
                onTap: busy ? null : () => setState(() => annual = false),
              ),
              const SizedBox(height: 14),
              InkPrimaryButton(
                label: widget.controller.pro ? 'Pro unlocked · return to notebook' : 'Continue with ${annual ? 'Annual' : 'Monthly'}',
                expand: true,
                onPressed: busy ? null : widget.controller.pro ? () => Navigator.pop(context) : () => purchase(annual),
              ),
              TextButton(
                onPressed: busy ? null : () => purchase(false),
                child: Text('Monthly · ${widget.controller.subscription.monthlyPrice ?? 'See checkout'}'),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              Text(
                widget.controller.subscription.isDemo
                    ? 'DEMO PURCHASES · NO CHARGE\nPreview prices. No billing or auto-renewal in this build.'
                    : widget.controller.subscription.isTestStore
                    ? 'REVENUECAT TEST STORE · NO REAL CHARGE\nA test purchase activates the Pro entitlement.'
                    : 'Subscriptions renew automatically. Manage or cancel through your store account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.55,
                  color: colors.textTertiary,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              await widget.controller.subscription.restore();
                              if (mounted) {
                                setState(
                                  () => message = widget.controller.pro
                                      ? 'Pro entitlement restored.'
                                      : widget.controller.subscription.isDemo
                                      ? 'No store purchases in demo mode. Enable Demo Pro with a plan above.'
                                      : 'No active Pro entitlement was found.',
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() => message = 'Restore failed.');
                              }
                            }
                          },
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkTokens.r12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InkTokens.r12),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.4 : 1,
          ),
          color: selected ? colors.accentSoft.withValues(alpha: .5) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallHeroPainter extends CustomPainter {
  final double t;
  final InkColors colors;
  _PaywallHeroPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = colors.textPrimary.withValues(alpha: .7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = colors.accent
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final tp = TextPainter(
      text: TextSpan(
        text: 'y = x²',
        style: TextStyle(
          fontFamily: 'Caveat',
          fontSize: 22,
          color: colors.textPrimary.withValues(alpha: .8 - t * .35),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * .12, size.height * .28));
    final path = Path();
    for (var i = 0; i <= 36; i++) {
      final x = size.width * (.42 + i / 36 * .45);
      final nx = (i / 36) * 2 - 1;
      final y = size.height * (.75 - nx * nx * .45 * (.2 + t * .8));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, accent);
    canvas.drawLine(
      Offset(size.width * .42, size.height * .78),
      Offset(size.width * .88, size.height * .78),
      ink..color = colors.borderStrong,
    );
  }

  @override
  bool shouldRepaint(covariant _PaywallHeroPainter old) => old.t != t;
}

Future<void> trainCommand(
  BuildContext context,
  InkMindController c, {
  int? index,
}) => showDialog(
  context: context,
  builder: (_) => TrainCommand(controller: c, index: index),
);

class TrainCommand extends StatefulWidget {
  final InkMindController controller;
  final int? index;
  const TrainCommand({super.key, required this.controller, this.index});
  @override
  State<TrainCommand> createState() => _TrainCommandState();
}

class _TrainCommandState extends State<TrainCommand> {
  final points = ValueNotifier<List<InkPoint>>([]);
  final name = TextEditingController();
  InkAction action = InkAction.makeAlive;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.index != null) {
      final command =
          (widget.controller.preferences['commands'] as List)[widget.index!];
      name.text = command['name'];
      action = InkAction.values.byName(command['action']);
    }
  }

  @override
  void dispose() {
    points.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return AlertDialog(
      title: Text(
        widget.index == null ? 'Teach a symbol' : 'Retrain your symbol',
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Command name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InkAction>(
                initialValue: action,
                items:
                    [
                          InkAction.makeAlive,
                          InkAction.explain,
                          InkAction.quiz,
                          InkAction.debug,
                          InkAction.summarize,
                        ]
                        .map(
                          (a) =>
                              DropdownMenuItem(value: a, child: Text(a.name)),
                        )
                        .toList(),
                onChanged: (v) => action = v!,
              ),
              const SizedBox(height: 12),
              Text(
                'Draw one continuous symbol below.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: colors.chrome,
                  borderRadius: BorderRadius.circular(InkTokens.r12),
                  border: Border.all(color: colors.border),
                ),
                child: Listener(
                  onPointerDown: (e) =>
                      points.value = [InkPoint(e.localPosition)],
                  onPointerMove: (e) => points.value = [
                    ...points.value,
                    InkPoint(e.localPosition),
                  ],
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: ActiveStrokePainter(
                      points,
                      InkTool.pen,
                      InkTokens.inkPalette.first,
                      3,
                      false,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Text(error!, style: TextStyle(color: colors.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final shape = normalizeShape(points.value);
            if (shape.isEmpty || name.text.trim().isEmpty) {
              setState(
                () => error = 'Name the command and draw a symbol first.',
              );
              return;
            }
            final commands = List<dynamic>.from(
              widget.controller.preferences['commands'] ?? [],
            );
            final command = {
              'name': name.text.trim(),
              'action': action.name,
              'shape': shape.map((p) => [p.dx, p.dy]).toList(),
            };
            if (widget.index == null) {
              commands.add(command);
            } else {
              commands[widget.index!] = command;
            }
            widget.controller.updatePreferences('commands', commands);
            Navigator.pop(context);
          },
          child: const Text('Remember symbol'),
        ),
      ],
    );
  }
}
