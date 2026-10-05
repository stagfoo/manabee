/// Ordering and grouping imported page files.
///
/// Pages arrive as `1.jpg … 10.jpg` or `p001.png`, from a picker that
/// returns them in whatever order it likes, or inside a .cbz with one
/// folder per chapter. Plain string sorting puts `10.jpg` before `2.jpg`,
/// which reads a chapter out of order — hence a natural sort.
library;

const Set<String> kImageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
};

const Set<String> kArchiveExtensions = {'cbz', 'zip'};

String extensionOf(String path) {
  final name = basename(path);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash < 0 ? normalized : normalized.substring(slash + 1);
}

String withoutExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

bool isImagePath(String path) => kImageExtensions.contains(extensionOf(path));

bool isArchivePath(String path) =>
    kArchiveExtensions.contains(extensionOf(path));

final RegExp _chunks = RegExp(r'\d+|\D+');

/// Compares strings with digit runs compared as numbers, case-insensitive.
int naturalCompare(String a, String b) {
  final ca = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final cb = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final x = ca[i];
    final y = cb[i];
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    int c;
    if (nx != null && ny != null) {
      c = nx.compareTo(ny);
      // 01 and 1 are equal numerically; break the tie consistently.
      if (c == 0) c = x.length.compareTo(y.length);
    } else {
      c = x.compareTo(y);
    }
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}

List<String> naturalSorted(Iterable<String> items) =>
    [...items]..sort(naturalCompare);

/// The image entries of an archive grouped into chapters by their folder,
/// each chapter's pages naturally sorted, chapters naturally sorted by
/// name. Files at the archive's root form one chapter named [rootName].
/// Junk that archivers leave behind (__MACOSX, dotfiles) is skipped.
///
/// A single top-level folder wrapping everything (`Vol1/ch1/…`, or just
/// `Vol1/…`) is a wrapper, not a chapter, and is looked through.
Map<String, List<String>> groupArchiveEntries(
  Iterable<String> entryNames, {
  String rootName = 'Chapter',
}) {
  final images = entryNames
      .map((e) => e.replaceAll('\\', '/'))
      .where((e) => !e.endsWith('/'))
      .where(
        (e) => !e
            .split('/')
            .any((part) => part.startsWith('.') || part == '__MACOSX'),
      )
      .where(isImagePath)
      .toList();
  if (images.isEmpty) return {};

  // Strip shared leading wrapper folders.
  var prefix = '';
  while (true) {
    final firsts = images
        .map((e) => e.substring(prefix.length))
        .map((e) => e.contains('/') ? e.substring(0, e.indexOf('/')) : null)
        .toSet();
    if (firsts.length != 1 || firsts.first == null) break;
    final next = '$prefix${firsts.first}/';
    // Stop if stripping would leave any file with no folder of its own but
    // others with one — that's a real chapter split, not a wrapper.
    if (images.any((e) => !e.startsWith(next))) break;
    final rest = images.map((e) => e.substring(next.length));
    if (!rest.any((e) => e.contains('/'))) {
      // Everything sits directly in this one folder: it's the chapter.
      return {firsts.first!: naturalSorted(images)};
    }
    prefix = next;
  }

  final groups = <String, List<String>>{};
  for (final e in images) {
    final rel = e.substring(prefix.length);
    final slash = rel.lastIndexOf('/');
    final chapter = slash < 0 ? rootName : rel.substring(0, slash);
    groups.putIfAbsent(chapter, () => []).add(e);
  }
  return {
    for (final name in naturalSorted(groups.keys))
      name: naturalSorted(groups[name]!),
  };
}
