/// Importing a manga, or editing one: cover, title, and chapters.
///
/// Chapters are copied into storage the moment they're picked (with a
/// spinner), not at Save — copying hundreds of pages is the slow part, and
/// doing it up front means Save is instant and a failure is reported next
/// to the thing that failed. Leaving without saving deletes what was
/// copied, so an abandoned import leaves nothing behind.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/pages.dart';
import '../models.dart';
import '../services/importer.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.mangaId});

  /// Null for a new manga.
  final String? mangaId;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late final String _id;
  late final TextEditingController _title;
  late final Importer _importer;
  String? _cover;
  String? _originalCover;
  final List<Chapter> _chapters = [];
  final List<Chapter> _added = [];
  final List<Chapter> _removed = [];
  final List<String> _newCovers = [];
  bool _busy = false;
  bool _saved = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    final lib = AppScope.read(context);
    _importer = Importer(lib.storage.root);
    final existing = widget.mangaId == null
        ? null
        : lib.mangaById(widget.mangaId!);
    _id = existing?.id ?? newId();
    _title = TextEditingController(text: existing?.title ?? '');
    _cover = existing?.cover;
    _originalCover = existing?.cover;
    // Copies, so a rename here doesn't reach the library unless saved.
    if (existing != null) {
      _chapters.addAll([
        for (final c in existing.chapters)
          Chapter(
            id: c.id,
            title: c.title,
            pages: c.pages,
            readUpTo: c.readUpTo,
          ),
      ]);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    if (!_saved) _discard();
    super.dispose();
  }

  void _discard() {
    for (final c in _added) {
      _importer.deleteChapterFiles(_id, c);
    }
    for (final c in _newCovers) {
      _importer.deleteFile(c);
    }
  }

  Future<void> _run(String status, Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) toast(context, 'Import failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _pickCover() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Pick a cover',
    );
    if (files.isEmpty) return;
    await _run('Copying cover…', () async {
      final rel = await _importer.importCover(_id, files.first);
      _newCovers.add(rel);
      setState(() => _cover = rel);
    });
  }

  Future<void> _addImages() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Pick the pages of one chapter',
    );
    if (files.isEmpty) return;
    final n = _chapters.length + 1;
    await _run('Copying ${files.length} pages…', () async {
      final c = await _importer.importImages(
        _id,
        files,
        title: '${n.toString().padLeft(2, '0')}# Chapter',
      );
      if (c.pages.isEmpty) {
        if (mounted) toast(context, 'None of those were images.');
        return;
      }
      setState(() {
        _chapters.add(c);
        _added.add(c);
      });
    });
  }

  Future<void> _addArchives() async {
    // FileType.any rather than custom ['cbz','zip']: Android has no MIME
    // type for .cbz, so a custom filter greys every comic archive out.
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Pick .cbz or .zip chapters',
    );
    final archives = files.where((f) => isArchivePath(f.name)).toList()
      ..sort((a, b) => naturalCompare(a.name, b.name));
    if (files.isNotEmpty && archives.isEmpty) {
      if (mounted) toast(context, 'Pick .cbz or .zip files.');
      return;
    }
    for (final a in archives) {
      await _run('Unpacking ${a.name}…', () async {
        final chapters = await _importer.importArchive(_id, a);
        if (chapters.isEmpty && mounted) {
          toast(context, 'No images inside ${a.name}.');
        }
        setState(() {
          _chapters.addAll(chapters);
          _added.addAll(chapters);
        });
      });
    }
    if (_title.text.trim().isEmpty && archives.isNotEmpty) {
      _title.text = withoutExtension(archives.first.name);
    }
  }

  void _addMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuRow(
                icon: Icons.photo_library_outlined,
                title: 'Page images',
                subtitle: 'Pick every page of one chapter',
                onTap: () {
                  Navigator.pop(context);
                  _addImages();
                },
              ),
              _MenuRow(
                icon: Icons.folder_zip_outlined,
                title: 'Archive (.cbz / .zip)',
                subtitle: 'One chapter per archive, or per folder inside it',
                onTap: () {
                  Navigator.pop(context);
                  _addArchives();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(Chapter c) async {
    final name = await promptText(
      context,
      title: 'Chapter name',
      initial: c.title,
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() => c.title = name.trim());
    }
  }

  void _remove(Chapter c) {
    setState(() {
      _chapters.remove(c);
      if (_added.remove(c)) {
        _importer.deleteChapterFiles(_id, c);
      } else {
        _removed.add(c);
      }
    });
  }

  Future<void> _save() async {
    final lib = AppScope.read(context);
    if (_chapters.isEmpty) {
      toast(context, 'Add at least one chapter.');
      return;
    }
    final title = _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim();
    final existing = lib.mangaById(_id);
    final m = existing ?? Manga(id: _id, title: title);
    m.title = title;
    m.cover = _cover;
    m.chapters = [..._chapters];
    final keep = {for (final c in _chapters) c.id};
    m.bubbles.removeWhere((b) => !keep.contains(b.chapterId));
    if (m.lastChapter >= m.chapters.length) {
      m.lastChapter = 0;
      m.lastPage = 0;
    }
    lib.upsertManga(m);
    await lib.save();
    for (final c in _removed) {
      await _importer.deleteChapterFiles(_id, c);
    }
    // Covers picked and then replaced, and the one this edit replaced.
    for (final c in _newCovers.where((c) => c != _cover)) {
      await _importer.deleteFile(c);
    }
    if (_originalCover != null && _originalCover != _cover) {
      await _importer.deleteFile(_originalCover!);
    }
    _saved = true;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return GridScaffold(
      onBack: () => Navigator.maybePop(context),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _pickCover,
                  child: SizedBox(
                    width: w * 0.5,
                    height: w * 0.5 * 1.5,
                    child: _cover != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LibraryImage(_cover, cacheWidth: 600),
                          )
                        : Container(
                            color: C.violet,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  size: 80,
                                  color: Color(0xFF3A3A44),
                                ),
                                Text(
                                  'cover\nimage',
                                  textAlign: TextAlign.center,
                                  style: T.headlineLg.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _title,
                style: T.bodyLg,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 16),
              for (final c in _chapters)
                _ChapterRow(
                  chapter: c,
                  onTap: () => _rename(c),
                  onRemove: _busy ? null : () => _remove(c),
                ),
              const SizedBox(height: 4),
              LimeButton(
                label: '+ add new page/folder',
                onPressed: _busy ? null : _addMenu,
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: widget.mangaId == null
                    ? 'Save to library'
                    : 'Save changes',
                icon: Icons.check_rounded,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xAA000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_status ?? '', style: T.bodyMd),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.onTap,
    this.onRemove,
  });

  final Chapter chapter;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                const Text('📁', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: T.bodyMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('${chapter.pages.length} pages', style: T.monoSm),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, color: C.inactive),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: C.lime),
    title: Text(title, style: T.bodyLg),
    subtitle: Text(subtitle, style: T.bodyMd.copyWith(color: C.textDim)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
