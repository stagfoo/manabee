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
