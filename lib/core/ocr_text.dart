/// Turning OCR output into a sentence a person would read.
///
/// ML Kit hands back blocks of lines in roughly left-to-right, top-to-bottom
/// order, which is wrong for manga: speech bubbles are usually set
/// vertically, in columns read right to left. This orders the pieces the
/// way the page is read and joins them without the spaces and newlines the
/// recogniser inserts between columns, which Japanese doesn't use.
library;

import 'dart:ui';

import 'kana.dart';

class OcrPiece {
  const OcrPiece(this.text, this.box);

  final String text;

  /// Pixel or normalised — only relative positions matter here.
  final Rect box;

  bool get isVertical => box.height > box.width * 1.2;
}

/// Whether the pieces read as vertical text: most of them, weighted by how
/// much text they hold, are taller than wide.
bool isVerticalLayout(List<OcrPiece> pieces) {
  var vertical = 0;
  var horizontal = 0;
  for (final p in pieces) {
    final weight = p.text.runes.length;
    // Single characters are square either way and tell us nothing.
    if (weight < 2) continue;
    if (p.isVertical) {
      vertical += weight;
    } else {
      horizontal += weight;
    }
  }
  return vertical > horizontal;
}

/// [pieces] in reading order: columns right to left for vertical text,
/// lines top to bottom (then left to right) for horizontal.
List<OcrPiece> readingOrder(List<OcrPiece> pieces) {
  final sorted = [...pieces];
  if (isVerticalLayout(pieces)) {
    sorted.sort((a, b) {
      final byX = b.box.center.dx.compareTo(a.box.center.dx);
      return byX != 0 ? byX : a.box.top.compareTo(b.box.top);
    });
  } else {
    sorted.sort((a, b) {
      // Lines whose vertical centres are within half a line of each other
      // are the same line, and go left to right.
      final tolerance = (a.box.height + b.box.height) / 4;
      final dy = a.box.center.dy - b.box.center.dy;
      if (dy.abs() > tolerance) return dy < 0 ? -1 : 1;
      return a.box.left.compareTo(b.box.left);
    });
  }
  return sorted;
}

/// [raw] with whitespace between Japanese characters removed and other
/// runs of whitespace collapsed to one space. Latin text inside a bubble
/// (an English sound effect, a name) keeps its spaces.
String cleanOcrText(String raw) {
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final out = StringBuffer();
  final chars = collapsed.runes.toList();
  for (var i = 0; i < chars.length; i++) {
    final c = chars[i];
    if (c == 0x20) {
      final prev = i > 0 ? chars[i - 1] : 0;
      final next = i + 1 < chars.length ? chars[i + 1] : 0;
      if (_joinsJapanese(prev) || _joinsJapanese(next)) continue;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

bool _joinsJapanese(int c) =>
    isJapanese(c) ||
    // Japanese punctuation: 、。「」『』！？… and full-width forms.
    (c >= 0x3000 && c <= 0x303F) ||
    (c >= 0xFF01 && c <= 0xFF60) ||
    c == 0x2026;

/// The pieces joined into one sentence in reading order.
String joinPieces(List<OcrPiece> pieces) =>
    cleanOcrText(readingOrder(pieces).map((p) => p.text).join(' '));

/// One recognised character (ML Kit's TextSymbol) or, failing that, the
/// smallest piece the recogniser gave a box for.
typedef Glyph = OcrPiece;

/// Groups [glyphs] into lines along one axis: columns (by x) or rows
/// (by y). A glyph joins the current group when it overlaps the group's
/// span by at least half its own width (or height).
List<List<Glyph>> clusterGlyphs(List<Glyph> glyphs, {required bool columns}) {
  double lo(Glyph g) => columns ? g.box.left : g.box.top;
  double hi(Glyph g) => columns ? g.box.right : g.box.bottom;
  double mid(Glyph g) => columns ? g.box.center.dx : g.box.center.dy;
  final sorted = [...glyphs]..sort((a, b) => mid(a).compareTo(mid(b)));
  final groups = <List<Glyph>>[];
  double spanLo = 0, spanHi = 0;
  for (final g in sorted) {
    final size = hi(g) - lo(g);
    final overlap =
        (hi(g) < spanHi ? hi(g) : spanHi) - (lo(g) > spanLo ? lo(g) : spanLo);
    if (groups.isNotEmpty && overlap >= size * 0.5) {
      groups.last.add(g);
      if (lo(g) < spanLo) spanLo = lo(g);
      if (hi(g) > spanHi) spanHi = hi(g);
    } else {
      groups.add([g]);
      spanLo = lo(g);
      spanHi = hi(g);
    }
  }
  return groups;
}

/// Reads per-character boxes back into a sentence, without trusting the
/// recogniser's own ordering — which, on vertical manga lettering, can
/// join the columns left to right (きまーす + いって instead of いって +
/// きまーす).
///
/// The glyphs are grouped both into columns and into rows; whichever
/// grouping puts more characters in each line is the text's real
/// direction. Vertical: columns right to left, each top to bottom.
/// Horizontal: rows top to bottom, each left to right, with a space where
/// Latin words have a gap between them.
String joinGlyphs(List<Glyph> glyphs) {
  if (glyphs.isEmpty) return '';
  // Direction from full-size characters only: furigana runs alongside the
  // text and blurs both groupings.
  final median = _medianSize(glyphs);
  final main = [
    for (final g in glyphs)
      if (_size(g) >= median * 0.6) g,
  ];
  final basis = main.isEmpty ? glyphs : main;
  final vertical =
      basis.length / clusterGlyphs(basis, columns: true).length >
      basis.length / clusterGlyphs(basis, columns: false).length;

  // Then every glyph into lines along that axis, and furigana lines out.
  final lines = dropFurigana(clusterGlyphs(glyphs, columns: vertical));

  final out = StringBuffer();
  if (vertical) {
    lines.sort((a, b) => _centerX(b).compareTo(_centerX(a)));
    for (final col in lines) {
      col.sort((a, b) => a.box.top.compareTo(b.box.top));
      for (final g in col) {
        // Set vertically, ー is drawn as a vertical stroke and comes back
        // as a bar or 丨.
        out.write(_verticalBars.contains(g.text) ? 'ー' : g.text);
      }
    }
  } else {
    lines.sort((a, b) => _centerY(a).compareTo(_centerY(b)));
    for (var r = 0; r < lines.length; r++) {
      final row = lines[r]..sort((a, b) => a.box.left.compareTo(b.box.left));
      if (r > 0) out.write(' ');
      for (var i = 0; i < row.length; i++) {
        if (i > 0) {
          final gap = row[i].box.left - row[i - 1].box.right;
          final h = (row[i].box.height + row[i - 1].box.height) / 2;
          if (gap > h * 0.35) out.write(' ');
        }
        out.write(row[i].text);
      }
    }
  }
  // cleanOcrText drops any space that touches Japanese.
  return cleanOcrText(out.toString());
}

double _centerX(List<Glyph> g) =>
    g.fold(0.0, (s, x) => s + x.box.center.dx) / g.length;

double _centerY(List<Glyph> g) =>
    g.fold(0.0, (s, x) => s + x.box.center.dy) / g.length;

const Set<String> _verticalBars = {'|', '｜', '丨', 'l', 'I'};

double _size(Glyph g) =>
    g.box.width > g.box.height ? g.box.width : g.box.height;

double _medianSize(List<Glyph> glyphs) {
  final sizes = glyphs.map(_size).toList()..sort();
  return sizes[sizes.length ~/ 2];
}

/// [lines] without furigana: the reading aids printed beside kanji at
/// about half the size of the text. Left in, they come out as an extra
/// column of kana spliced into the sentence (朝ちょう食しょく…).
///
/// Judged per line, not per character, so a small っ or ゃ inside a
/// normal line stays — its line's characters are mostly full size.
List<List<Glyph>> dropFurigana(List<List<Glyph>> lines) {
  final all = [for (final l in lines) ...l];
  if (lines.length < 2 || all.length < 4) return lines;
  final median = _medianSize(all);
  return [
    for (final l in lines)
      if (_medianSize(l) >= median * 0.6) l,
  ];
}
