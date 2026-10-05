/// The pieces every screen shares: the grid ground, the manabee header,
/// covers, pills, progress bars, buttons, and the four-column word row.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/jisho.dart';
import '../services/store.dart';
import '../theme.dart';

/// The library and dictionary, reachable from any widget below the app.
class AppScope extends InheritedNotifier<Library> {
  const AppScope({
    super.key,
    required Library library,
    required this.jisho,
    required super.child,
  }) : super(notifier: library);

  final Jisho jisho;

  static AppScope _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Rebuilds the caller whenever the library changes.
  static Library library(BuildContext context) => _of(context).notifier!;

  /// Without subscribing — for event handlers.
  static Library read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static Jisho jishoOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.jisho;
}

class GridPainter extends CustomPainter {
  const GridPainter({this.spacing = 16});

  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.grid
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => old.spacing != spacing;
}

/// An opaque screen on the grid ground. Opaque, not transparent over a
/// shared grid: route transitions would otherwise show both screens at once.
class GridScaffold extends StatelessWidget {
  const GridScaffold({
    super.key,
    required this.body,
    this.header = true,
    this.floatingActionButton,
    this.onBack,
  });

  final Widget body;
  final bool header;
  final Widget? floatingActionButton;

  /// Shows a back arrow in the header when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.ground,
      floatingActionButton: floatingActionButton,
      body: CustomPaint(
        painter: const GridPainter(),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header) ManabeeHeader(onBack: onBack),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class ManabeeHeader extends StatelessWidget {
  const ManabeeHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: C.text),
            )
          else
            const SizedBox(width: 8),
          const Text('🐝', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Text('manabee', style: T.headlineMd.copyWith(fontSize: 22)),
          const Spacer(),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined, color: C.text, size: 28),
          ),
        ],
      ),
    );
  }
}

/// A page or cover image from the library, by relative path.
class LibraryImage extends StatelessWidget {
  const LibraryImage(
    this.relativePath, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
  });

  final String? relativePath;
  final BoxFit fit;
  final Alignment alignment;

  /// Decode width in physical pixels; set for thumbnails so a grid of
  /// covers doesn't hold a dozen full-resolution pages in memory.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final rel = relativePath;
    if (rel == null) return const _MissingImage();
    final lib = AppScope.read(context);
    return Image.file(
      File(lib.resolve(rel)),
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _MissingImage(),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) => Container(
    color: C.elevated,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined, color: C.inactive),
  );
}

class Cover extends StatelessWidget {
  const Cover(this.manga, {super.key, this.radius = 16, this.badge});

  final Manga manga;
  final double radius;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LibraryImage(manga.coverOrFirstPage, cacheWidth: 600),
          if (badge != null) Positioned(right: 8, bottom: 8, child: badge!),
        ],
      ),
    );
  }
}

/// The lime "50 💬" pill.
class CountPill extends StatelessWidget {
  const CountPill(this.count, {super.key, this.light = false});

  final int count;

  /// White instead of lime, as on the Bubbles title row.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: light ? Colors.white : C.lime,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: T.pill.copyWith(color: C.onLime)),
          const SizedBox(width: 6),
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 16,
            color: C.onLime,
          ),
        ],
      ),
    );
  }
}

/// The two-stage bar: lime for done, white for the rest.
class ProgressBar extends StatelessWidget {
  const ProgressBar(
    this.value, {
    super.key,
    this.color = C.lime,
    this.rest = Colors.white,
  });

  final double value;
  final Color color;
  final Color rest;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 4.0;
        final doneW = (box.maxWidth - gap) * v;
        return SizedBox(
          height: 4,
          child: Row(
            children: [
              if (v > 0)
                Container(
                  width: doneW,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (v > 0 && v < 1) const SizedBox(width: gap),
              if (v < 1)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: rest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class LimeButton extends StatelessWidget {
  const LimeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: C.lime,
        foregroundColor: C.onLime,
        disabledBackgroundColor: C.lime.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: T.pill.copyWith(fontSize: 15),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: C.onLime,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: C.surface,
        foregroundColor: C.text,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: C.ghostBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: T.pill.copyWith(fontSize: 15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// ENGLISH | ROMAJI | FURIGANA | KANJI, as four connected blocks.
class WordRow extends StatelessWidget {
  const WordRow(
    this.entry, {
    super.key,
    this.color = C.lime,
    this.onTap,
    this.trailing,
  });

  final Entry entry;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final onColor = color == C.lime ? C.onLime : C.text;
    final labelColor = onColor.withValues(alpha: 0.55);
    Widget cell(String label, String value, {bool jp = false}) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            bottom: BorderSide(color: Color(0x4D000000), width: 2),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: T.monoSm.copyWith(color: labelColor, fontSize: 9),
            ),
            const SizedBox(height: 8),
            Text(
              value.isEmpty ? '-' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  (jp
                          ? T.jp.copyWith(fontSize: 17)
                          : T.monoBold.copyWith(fontSize: 13))
                      .copyWith(
                        color: onColor,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell(
                'ENGLISH',
                entry.senses.isEmpty ? '' : entry.senses.first.glosses.first,
              ),
              cell('ROMAJI', entry.romaji),
              cell('FURIGANA', entry.reading, jp: true),
              cell('KANJI', entry.hasKanji ? entry.word : '', jp: true),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple centred message for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.body,
    this.action,
  });

  final String emoji;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title, style: T.headlineMd, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: T.bodyMd.copyWith(color: C.textDim),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A text-entry dialog. Returns null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String action = 'Save',
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        minLines: 1,
        style: T.jp,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: C.ghostBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: C.lime, width: 1.5),
          ),
        ),
        onSubmitted: maxLines == 1 ? (v) => Navigator.pop(context, v) : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: C.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String action = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: C.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action, style: const TextStyle(color: C.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
