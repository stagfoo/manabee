/// Putting photographed pages in the order they were taken.
///
/// A book photographed page by page is in order by time, not by name, and
/// a gallery hands picked photos over in whatever order it likes. The best
/// clock is the one the camera wrote into the photo (EXIF
/// DateTimeOriginal); failing that, the timestamp most phone cameras put in
/// the file name (IMG_20261014_093012.jpg, PXL_20261014_093012345.jpg);
/// failing that, the file's own date. Pure, so it's tested without photos.
library;

/// "2026:10:14 09:30:12", as EXIF writes it.
DateTime? parseExifDate(String? s) {
  if (s == null) return null;
  final m = RegExp(r'(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
      .firstMatch(s.trim());
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
  if (parts[0] < 1990 || parts[1] == 0 || parts[2] == 0) return null;
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}

/// The timestamp in a camera's file name: an 8-digit date then a 6-digit
/// time, with or without separators, and any fraction of a second after —
/// IMG_20261014_093012.jpg, PXL_20261014_093012345.jpg,
/// 20261014_093012.jpg, Screenshot_2026-10-14-09-30-12.png.
DateTime? dateFromFilename(String name) {
  final m = RegExp(
    r'(\d{4})-?(\d{2})-?(\d{2})[_\- ]?(\d{2})[-:.]?(\d{2})[-:.]?(\d{2})(\d{0,3})',
  ).firstMatch(name);
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final h = int.parse(m[4]!);
  final mi = int.parse(m[5]!);
  final s = int.parse(m[6]!);
  if (y < 1990 ||
      mo < 1 ||
      mo > 12 ||
      d < 1 ||
      d > 31 ||
      h > 23 ||
      mi > 59 ||
      s > 59) {
    return null;
  }
  final ms = (m[7] ?? '').isEmpty ? 0 : int.parse(m[7]!.padRight(3, '0'));
  return DateTime(y, mo, d, h, mi, s, ms);
}

class PhotoInfo {
  const PhotoInfo(this.name, {this.exifDate, this.fileDate});

  final String name;
  final DateTime? exifDate;
  final DateTime? fileDate;

  /// When it was taken, from the best clock available.
  DateTime? get taken => exifDate ?? dateFromFilename(name) ?? fileDate;
}

/// [photos] in the order they were taken: by [PhotoInfo.taken], ties and
/// undated photos by name (naturally — 2 before 10), undated last.
List<T> inTakenOrder<T>(List<T> photos, PhotoInfo Function(T) info) {
  final keyed = [for (final p in photos) (p, info(p))];
  keyed.sort((a, b) {
    final ta = a.$2.taken;
    final tb = b.$2.taken;
    if (ta != null && tb != null) {
      final c = ta.compareTo(tb);
      if (c != 0) return c;
    } else if (ta != null) {
      return -1;
    } else if (tb != null) {
      return 1;
    }
    return _natural(a.$2.name, b.$2.name);
  });
  return [for (final k in keyed) k.$1];
}

int _natural(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final ca = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final cb = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final na = int.tryParse(ca[i]);
    final nb = int.tryParse(cb[i]);
    final c = na != null && nb != null
        ? na.compareTo(nb)
        : ca[i].compareTo(cb[i]);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}
