import 'package:flutter/material.dart';
import '../../core/models/ink.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/haptics.dart';
import '../canvas/painters.dart';
import '../notebook/controller.dart';
import '../settings/settings.dart';

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = 'Name your notebook',
  int lines = 1,
}) async {
  final text = TextEditingController(text: initial);
  final result = await showInkSheet<String>(
    context: context,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: editorial(context, 22)),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: true,
              minLines: lines,
              maxLines: lines == 1 ? 1 : 8,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: lines == 1 ? (v) => Navigator.pop(context, v) : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                InkGhostButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                InkPrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context, text.text),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
          ],
        ),
      );
    },
  );
  Future<void>.delayed(const Duration(milliseconds: 350), text.dispose);
  return result;
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
) => showInkSheet<bool>(
  context: context,
  builder: (context) {
    final colors = InkColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Delete $title?', style: editorial(context, 22)),
          const SizedBox(height: 12),
          Text(
            'This removes it from this device. This action cannot be undone.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              InkGhostButton(
                label: 'Keep it',
                onPressed: () => Navigator.pop(context, false),
              ),
              const Spacer(),
              InkPrimaryButton(
                label: 'Delete',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
  },
).then((v) => v ?? false);

Future<CreateNotebookResult?> showCreateNotebook(BuildContext context) {
  return showInkSheet<CreateNotebookResult>(
    context: context,
    heightFactor: .78,
    builder: (context) => const _CreateNotebookSheet(),
  );
}

class CreateNotebookResult {
  final String title;
  final PaperKind paper;
  final int cover;
  const CreateNotebookResult(this.title, this.paper, this.cover);
}

class _CreateNotebookSheet extends StatefulWidget {
  const _CreateNotebookSheet();
  @override
  State<_CreateNotebookSheet> createState() => _CreateNotebookSheetState();
}

class _CreateNotebookSheetState extends State<_CreateNotebookSheet> {
  final name = TextEditingController();
  PaperKind paper = PaperKind.dotted;
  int cover = InkTokens.coverTones.first;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New notebook', style: editorial(context, 24)),
            const SizedBox(height: 6),
            Text(
              'A quiet place for the next idea.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Untitled notebook'),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 24),
            Text(
              'Paper',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: PaperKind.values.map((p) {
                final selected = paper == p;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: p == PaperKind.values.last ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        InkHaptics.selection();
                        setState(() => paper = p);
                      },
                      child: AnimatedContainer(
                        duration: InkTokens.quick,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.paper,
                          borderRadius: BorderRadius.circular(InkTokens.r8),
                          border: Border.all(
                            color: selected ? colors.accent : colors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                                child: CustomPaint(
                                  painter: PaperPainter(p, false),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                p.name[0].toUpperCase() + p.name.substring(1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? colors.accent
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Cover',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: InkTokens.coverTones.map((tone) {
                final selected = cover == tone;
                return GestureDetector(
                  onTap: () {
                    InkHaptics.selection();
                    setState(() => cover = tone);
                  },
                  child: AnimatedContainer(
                    duration: InkTokens.quick,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(tone),
                      borderRadius: BorderRadius.circular(InkTokens.r8),
                      border: Border.all(
                        color: selected ? colors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white70,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            InkPrimaryButton(
              label: 'Create notebook',
              expand: true,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }

  void _create() {
    final title = name.text.trim().isEmpty
        ? 'Untitled notebook'
        : name.text.trim();
    Navigator.pop(context, CreateNotebookResult(title, paper, cover));
  }
}

class LibraryScreen extends StatefulWidget {
  final InkMindController controller;
  const LibraryScreen({super.key, required this.controller});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '';
  InkMindController get c => widget.controller;

  Future<void> create() async {
    final result = await showCreateNotebook(context);
    if (result == null) return;
    final n = c.create(result.title);
    n.color = result.cover;
    if (n.pages.isNotEmpty) n.pages.first.paper = result.paper;
    c.persist(n);
    InkHaptics.success();
    c.open(n);
  }

  @override
  Widget build(BuildContext context) {
    return InkResponsive(
      builder: (context, layout) {
        final colors = InkColors.of(context);
        final books = c.notebooks
            .where((n) => n.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

        return Scaffold(
          backgroundColor: colors.workspace,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: layout.libraryPadding.copyWith(bottom: 8),
                        child: Row(
                          children: [
                            Text('InkMind', style: wordmark(context, 24)),
                            const Spacer(),
                            if (!layout.isPhone)
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Text(
                                  'Paper you can think with',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ),
                            InkIconBtn(
                              tooltip: 'Settings',
                              icon: Icons.tune_rounded,
                              onPressed: () => showSettings(context, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.libraryPadding.left,
                          layout.isPhone ? 24 : 40,
                          layout.libraryPadding.right,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              books.isEmpty
                                  ? 'Your shelf is empty.'
                                  : 'Notebooks',
                              style: editorial(
                                context,
                                layout.isPhone ? 28 : 34,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              books.isEmpty
                                  ? 'Your first idea starts here.'
                                  : '${books.length} ${books.length == 1 ? 'notebook' : 'notebooks'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                InkPrimaryButton(
                                  label: 'New notebook',
                                  icon: Icons.add,
                                  onPressed: create,
                                ),
                                const SizedBox(width: 12),
                                if (!layout.isPhone)
                                  InkGhostButton(
                                    label: 'Open InkMind Demo',
                                    onPressed: c.openPlayground,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (layout.isPhone)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.libraryPadding.left,
                            8,
                            layout.libraryPadding.right,
                            0,
                          ),
                          child: TextButton(
                            onPressed: c.openPlayground,
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Open InkMind Demo'),
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.libraryPadding.left,
                          28,
                          layout.libraryPadding.right,
                          16,
                        ),
                        child: _SearchField(
                          onChanged: (v) => setState(() => query = v),
                        ),
                      ),
                    ),
                    if (books.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.libraryPadding.left,
                            vertical: 48,
                          ),
                          child: const _EmptyShelf(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          layout.libraryPadding.left,
                          8,
                          layout.libraryPadding.right,
                          48,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: layout.notebookColumns(),
                                crossAxisSpacing: layout.isPhone ? 14 : 22,
                                mainAxisSpacing: layout.isPhone ? 20 : 28,
                                childAspectRatio: .72,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _NotebookCover(
                              notebook: books[i],
                              onOpen: () {
                                InkHaptics.light();
                                c.open(books[i]);
                              },
                              onRename: () async {
                                final title = await askText(
                                  context,
                                  'Rename notebook',
                                  initial: books[i].title,
                                );
                                if (title != null) c.rename(books[i], title);
                              },
                              onDuplicate: () => c.duplicate(books[i]),
                              onDelete: () async {
                                if (await confirmDelete(
                                  context,
                                  books[i].title,
                                )) {
                                  c.delete(books[i]);
                                }
                              },
                            ),
                            childCount: books.length,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Center(
                          child: Text(
                            'Local notes · stays on this device',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Find a notebook',
        prefixIcon: Icon(Icons.search, size: 18, color: colors.textTertiary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 150,
          child: CustomPaint(painter: _EmptyNotebookPainter(colors)),
        ),
        const SizedBox(height: 24),
        Text(
          'Your first idea starts here.',
          style: editorial(context, 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Open a blank page and begin.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyNotebookPainter extends CustomPainter {
  final InkColors colors;
  _EmptyNotebookPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 4, size.width - 16, size.height - 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(r, Paint()..color = colors.paper);
    canvas.drawRRect(
      r,
      Paint()
        ..color = colors.borderStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(20, size.height * .35),
      Offset(size.width - 20, size.height * .35),
      Paint()
        ..color = colors.border
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(20, size.height * .48),
      Offset(size.width - 28, size.height * .48),
      Paint()
        ..color = colors.border
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyNotebookPainter old) => false;
}

class _NotebookCover extends StatefulWidget {
  final Notebook notebook;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _NotebookCover({
    required this.notebook,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_NotebookCover> createState() => _NotebookCoverState();
}

class _NotebookCoverState extends State<_NotebookCover> {
  bool hover = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = InkColors.of(context);
    final n = widget.notebook;
    final days = DateTime.now().difference(n.edited).inDays;
    final edited = days == 0
        ? 'Edited today'
        : days == 1
        ? 'Edited yesterday'
        : '$days days ago';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label: 'Open ${n.title}',
            button: true,
            child: MouseRegion(
              onEnter: (_) => setState(() => hover = true),
              onExit: (_) => setState(() => hover = false),
              child: GestureDetector(
                onTapDown: (_) => setState(() => pressed = true),
                onTapUp: (_) => setState(() => pressed = false),
                onTapCancel: () => setState(() => pressed = false),
                onTap: widget.onOpen,
                child: AnimatedScale(
                  scale: pressed
                      ? .97
                      : hover
                      ? 1.015
                      : 1,
                  duration: InkTokens.quick,
                  curve: InkTokens.easeOut,
                  child: AnimatedContainer(
                    duration: InkTokens.quick,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(InkTokens.r8),
                      boxShadow: hover
                          ? InkTokens.lift(.1)
                          : InkTokens.lift(.04),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(InkTokens.r8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: Color(n.color)),
                          CustomPaint(
                            painter: CoverPainter(
                              Color(n.color),
                              playground: n.playground,
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 20,
                            right: 14,
                            child: Text(
                              n.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 18,
                                height: 1.25,
                                color: Color(0xFFF4F0E6),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            bottom: 16,
                            child: Text(
                              '${n.pages.length.toString().padLeft(2, '0')} pages',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: .8,
                                color: Colors.white.withValues(alpha: .55),
                              ),
                            ),
                          ),
                          // Spine
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 6,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: .18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                n.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                tooltip: 'Notebook options',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: colors.textTertiary,
                ),
                onSelected: (v) {
                  if (v == 'rename') widget.onRename();
                  if (v == 'duplicate') widget.onDuplicate();
                  if (v == 'delete') widget.onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ],
        ),
        Text(
          '${n.pages.length} ${n.pages.length == 1 ? 'page' : 'pages'} · $edited',
          style: TextStyle(fontSize: 11, color: colors.textTertiary),
        ),
      ],
    );
  }
}

class PlaygroundArt extends CustomPainter {
  final Color color;
  PlaygroundArt(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(25, 15), const Offset(130, 15), p);
    c.drawLine(const Offset(76, 15), const Offset(108, 89), p);
    c.drawCircle(const Offset(108, 89), 14, p);
    c.drawArc(
      Rect.fromCircle(center: const Offset(76, 15), radius: 88),
      .75,
      1.7,
      false,
      p..color = color.withValues(alpha: .28),
    );
  }

  @override
  bool shouldRepaint(PlaygroundArt old) => old.color != color;
}
