/// Copying picked pages and archives into the app's own storage.
///
/// Files are copied, never referenced in place: Android hands out picked
/// files as content URIs or cache copies that can vanish, and a manga that
/// stops opening because its source folder moved is a manga lost.
///
/// Layout: `manga/<mangaId>/<chapterId>/<NNN>.<ext>` under the storage
/// root, with the page number zero-padded so the directory listing reads
/// in order too.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';

import '../core/pages.dart';
import '../models.dart';

class Importer {
  Importer(this.root);

  /// The storage root (Library.storage.root).
  final String root;

  String _chapterDir(String mangaId, String chapterId) =>
      'manga/$mangaId/$chapterId';

  static String _pageName(int index, String ext) =>
      '${(index + 1).toString().padLeft(3, '0')}.${ext.isEmpty ? 'jpg' : ext}';

  /// One chapter from picked image files, ordered by name.
  Future<Chapter> importImages(
    String mangaId,
    List<PlatformFile> files, {
    required String title,
  }) async {
    final images = files.where((f) => isImagePath(f.name)).toList()
      ..sort((a, b) => naturalCompare(a.name, b.name));
    final chapterId = newId();
    final dir = _chapterDir(mangaId, chapterId);
    await Directory('$root/$dir').create(recursive: true);
    final pages = <String>[];
    for (var i = 0; i < images.length; i++) {
      final rel = '$dir/${_pageName(i, extensionOf(images[i].name))}';
      await _copy(images[i], '$root/$rel');
      pages.add(rel);
    }
    return Chapter(id: chapterId, title: title, pages: pages);
  }

  /// One chapter per folder inside a .cbz/.zip.
  Future<List<Chapter>> importArchive(String mangaId, PlatformFile file) async {
    final tmpDir = await Directory('$root/tmp').create(recursive: true);
    final tmp = '${tmpDir.path}/${newId()}.zip';
    await _copy(file, tmp);
    final fallbackTitle = withoutExtension(file.name);
    try {
      // Off the UI isolate: a 200-page archive takes seconds to inflate and
      // the import spinner should keep spinning meanwhile.
      final plan = await Isolate.run(
        () => _extract(
          archivePath: tmp,
          root: root,
          mangaDir: 'manga/$mangaId',
          fallbackTitle: fallbackTitle,
          idSeed: newId(),
        ),
      );
      return [
        for (final c in plan) Chapter(id: c.id, title: c.title, pages: c.pages),
      ];
    } finally {
      await File(tmp).delete().catchError((_) => File(tmp));
    }
  }

  Future<String> importCover(String mangaId, PlatformFile file) async {
    final ext = extensionOf(file.name);
    // A new name each time, so the image cache never shows the old cover.
    final rel = 'manga/$mangaId/cover_${newId()}.${ext.isEmpty ? 'jpg' : ext}';
    await Directory('$root/manga/$mangaId').create(recursive: true);
    await _copy(file, '$root/$rel');
    return rel;
  }

  Future<void> deleteChapterFiles(String mangaId, Chapter c) async {
    final dir = Directory('$root/${_chapterDir(mangaId, c.id)}');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> deleteFile(String relative) async {
    final f = File('$root/$relative');
    if (await f.exists()) await f.delete();
  }

  static Future<void> _copy(PlatformFile from, String to) async {
    final path = from.path;
    if (path != null && await File(path).exists()) {
      await File(path).copy(to);
      return;
    }
    final sink = File(to).openWrite();
    await sink.addStream(from.readAsByteStream());
    await sink.close();
  }
}

class _PlannedChapter {
  _PlannedChapter(this.id, this.title, this.pages);
  final String id;
  final String title;
  final List<String> pages;
}

List<_PlannedChapter> _extract({
  required String archivePath,
  required String root,
  required String mangaDir,
  required String fallbackTitle,
  required String idSeed,
}) {
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final byName = {
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };
    final groups = groupArchiveEntries(byName.keys, rootName: fallbackTitle);
    final out = <_PlannedChapter>[];
    var n = 0;
    for (final entry in groups.entries) {
      final id = '$idSeed${(n++).toRadixString(36)}';
      final dir = '$mangaDir/$id';
      Directory('$root/$dir').createSync(recursive: true);
      final pages = <String>[];
      for (var i = 0; i < entry.value.length; i++) {
        final name = entry.value[i];
        final file = byName[name] ?? byName[name.replaceAll('/', '\\')];
        final bytes = file?.readBytes();
        if (bytes == null || bytes.isEmpty) continue;
        final rel =
            '$dir/${Importer._pageName(pages.length, extensionOf(name))}';
        File('$root/$rel').writeAsBytesSync(bytes);
        pages.add(rel);
      }
      if (pages.isEmpty) continue;
      final title = groups.length == 1 ? fallbackTitle : basename(entry.key);
      out.add(_PlannedChapter(id, title, pages));
    }
    return out;
  } finally {
    input.closeSync();
  }
}
