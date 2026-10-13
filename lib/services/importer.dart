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
import 'package:image/image.dart' as img;

import '../core/pages.dart';
import '../core/photo_order.dart';
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

  /// One chapter from photographs of pages — from the gallery (put in the
  /// order they were taken) or straight from the in-app camera (already in
  /// order: [sortByTaken] false).
  ///
  /// Phone photos are stored sideways with a rotation tag, and at twelve
  /// megapixels. Every page is turned upright and scaled to
  /// [kPhotoLongSide] on its long side as it's copied in, so the reader,
  /// its geometry and OCR all see a plain upright image.
  Future<Chapter> importPhotos(
    String mangaId, {
    List<PlatformFile> files = const [],
    List<String> paths = const [],
    required String title,
    bool sortByTaken = true,
  }) async {
    final tmpDir = await Directory('$root/tmp').create(recursive: true);
    final staged = <(String, String)>[]; // (path, original name)
    for (final f in files.where((f) => isImagePath(f.name))) {
      final tmp = '${tmpDir.path}/${newId()}.${extensionOf(f.name)}';
      await _copy(f, tmp);
      staged.add((tmp, f.name));
    }
    for (final p in paths) {
      staged.add((p, basename(p)));
    }
    final chapterId = newId();
    final dir = _chapterDir(mangaId, chapterId);
    await Directory('$root/$dir').create(recursive: true);
    try {
      final pages = await Isolate.run(
        () => _normalizePhotos(staged, root, dir, sortByTaken),
      );
      return Chapter(id: chapterId, title: title, pages: pages);
    } finally {
      for (final (path, _) in staged) {
        if (path.startsWith(tmpDir.path)) {
          await File(path).delete().catchError((_) => File(path));
        }
      }
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

/// The longest side a photographed page is kept at: plenty for reading and
/// for OCR, a fraction of a twelve-megapixel original.
const int kPhotoLongSide = 2400;

/// Orders [photos] by when they were taken (if [sortByTaken]), then writes
/// each upright and scaled down as a page. Runs in an isolate.
List<String> _normalizePhotos(
  List<(String, String)> photos,
  String root,
  String dir,
  bool sortByTaken,
) {
  final infos = <(String, String, PhotoInfo)>[];
  for (final (path, name) in photos) {
    DateTime? exif;
    try {
      final data = img.decodeJpgExif(File(path).readAsBytesSync());
      final tag =
          data?.exifIfd['DateTimeOriginal'] ?? data?.imageIfd['DateTime'];
      exif = parseExifDate(tag?.toString());
    } catch (_) {
      // Not a JPEG, or no EXIF: the name or the file date will do.
    }
    final fileDate = File(path).lastModifiedSync();
    infos.add((
      path,
      name,
      PhotoInfo(name, exifDate: exif, fileDate: fileDate),
    ));
  }
  final ordered = sortByTaken ? inTakenOrder(infos, (x) => x.$3) : infos;

  final pages = <String>[];
  for (final (path, _, _) in ordered) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) continue;
    var page = img.bakeOrientation(decoded);
    final long = page.width > page.height ? page.width : page.height;
    if (long > kPhotoLongSide) {
      page = page.width >= page.height
          ? img.copyResize(
              page,
              width: kPhotoLongSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              page,
              height: kPhotoLongSide,
              interpolation: img.Interpolation.average,
            );
    }
    final rel = '$dir/${Importer._pageName(pages.length, 'jpg')}';
    File('$root/$rel').writeAsBytesSync(img.encodeJpg(page, quality: 88));
    pages.add(rel);
  }
  return pages;
}
