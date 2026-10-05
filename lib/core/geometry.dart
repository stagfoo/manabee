/// Page geometry: where a page image sits on screen, and translating
/// between screen space and the image's own normalised 0..1 space.
///
/// Everything placed on a page — translation bubbles, OCR regions — is
/// stored normalised to the image, never in screen pixels. That's what lets
/// one bubble land on the same speech balloon on a phone, a tablet, in
/// either orientation and at any zoom.
///
/// Uses dart:ui value types only, no widgets, so it tests without a device.
library;

import 'dart:math' as math;
import 'dart:ui';

/// The rect an image of [image] size occupies when fitted inside [box] with
/// BoxFit.contain, centred.
Rect containRect(Size image, Size box) {
  if (image.isEmpty || box.isEmpty) return Rect.zero;
  final scale = math.min(box.width / image.width, box.height / image.height);
  final w = image.width * scale;
  final h = image.height * scale;
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}

/// [point] in [imageRect] as a 0..1 fraction of the image, or null when the
/// point is outside the image (on the letterbox bars).
Offset? toNormalized(Offset point, Rect imageRect) {
  if (imageRect.isEmpty || !imageRect.contains(point)) return null;
  return Offset(
    (point.dx - imageRect.left) / imageRect.width,
    (point.dy - imageRect.top) / imageRect.height,
  );
}

/// The inverse of [toNormalized].
Offset fromNormalized(Offset normalized, Rect imageRect) => Offset(
  imageRect.left + normalized.dx * imageRect.width,
  imageRect.top + normalized.dy * imageRect.height,
);

/// A screen-space drag from [a] to [b] as a normalised rect, clamped to the
/// image. A drag that starts on the letterbox still selects the part of
/// the image it covers.
Rect normalizedSelection(Offset a, Offset b, Rect imageRect) {
  if (imageRect.isEmpty) return Rect.zero;
  double nx(double x) =>
      ((x - imageRect.left) / imageRect.width).clamp(0.0, 1.0);
  double ny(double y) =>
      ((y - imageRect.top) / imageRect.height).clamp(0.0, 1.0);
  return Rect.fromLTRB(
    nx(math.min(a.dx, b.dx)),
    ny(math.min(a.dy, b.dy)),
    nx(math.max(a.dx, b.dx)),
    ny(math.max(a.dy, b.dy)),
  );
}

/// A normalised rect in screen space within [imageRect].
Rect denormalizeRect(Rect normalized, Rect imageRect) => Rect.fromLTRB(
  imageRect.left + normalized.left * imageRect.width,
  imageRect.top + normalized.top * imageRect.height,
  imageRect.left + normalized.right * imageRect.width,
  imageRect.top + normalized.bottom * imageRect.height,
);

/// Integer pixel bounds for cropping [normalized] out of an image of
/// [width]×[height], clamped to the image and never empty — a crop of zero
/// pixels would throw inside the image library rather than return nothing.
({int x, int y, int width, int height}) pixelCrop(
  Rect normalized,
  int width,
  int height,
) {
  final left = (normalized.left * width).floor().clamp(0, width - 1);
  final top = (normalized.top * height).floor().clamp(0, height - 1);
  final right = (normalized.right * width).ceil().clamp(left + 1, width);
  final bottom = (normalized.bottom * height).ceil().clamp(top + 1, height);
  return (x: left, y: top, width: right - left, height: bottom - top);
}

/// A pixel rect inside an image of [imageSize] as a normalised rect.
Rect normalizePixelRect(Rect pixels, Size imageSize) {
  if (imageSize.isEmpty) return Rect.zero;
  return Rect.fromLTRB(
    (pixels.left / imageSize.width).clamp(0.0, 1.0),
    (pixels.top / imageSize.height).clamp(0.0, 1.0),
    (pixels.right / imageSize.width).clamp(0.0, 1.0),
    (pixels.bottom / imageSize.height).clamp(0.0, 1.0),
  );
}

/// Whether a selection is big enough to be deliberate. A tap that wobbled
/// a few pixels shouldn't run OCR on a sliver.
bool isUsableSelection(Rect normalized, {double minSide = 0.02}) =>
    normalized.width >= minSide && normalized.height >= minSide;
