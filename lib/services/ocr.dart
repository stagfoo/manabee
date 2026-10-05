/// Reading Japanese out of a page, on-device, with ML Kit.
///
/// Two ways in: a region the reader dragged over one speech balloon
/// ([readRegion]), and a whole-page scan that finds every block of text it
/// can ([scanPage]). The region path crops first: on a whole page the art
/// competes with the lettering, and a crop of one balloon, upscaled and
/// padded with white, recognises markedly better.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/geometry.dart';
import '../core/ocr_text.dart';

class ScannedBlock {
  const ScannedBlock(this.text, this.region);

  final String text;

  /// Normalised to the page.
  final Rect region;
}

class Ocr {
  Ocr._();
  static final Ocr instance = Ocr._();

  TextRecognizer? _recognizer;

  TextRecognizer get _r =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.japanese);

  /// The text inside [region] (normalised) of the page at [imagePath].
  Future<String> readRegion(String imagePath, Rect region) async {
    final tmpDir = await getTemporaryDirectory();
    final out = '${tmpDir.path}/ocr_crop.png';
    final ok = await Isolate.run(() => _cropForOcr(imagePath, region, out));
    if (!ok) return '';
    final result = await _r.processImage(InputImage.fromFilePath(out));
    final pieces = [
      for (final block in result.blocks)
        for (final line in block.lines) OcrPiece(line.text, line.boundingBox),
    ];
    return joinPieces(pieces);
  }

  /// Every block of text on the page, normalised to the page.
  Future<List<ScannedBlock>> scanPage(String imagePath, Size imageSize) async {
    final result = await _r.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in result.blocks)
        if (block.text.trim().isNotEmpty)
          ScannedBlock(
            joinPieces([
              for (final line in block.lines)
                OcrPiece(line.text, line.boundingBox),
            ]),
            normalizePixelRect(block.boundingBox, imageSize),
          ),
    ];
  }

  Future<void> close() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// Crops, upscales small crops, and pads with white. Runs in an isolate:
/// decoding a full manga page in Dart takes long enough to drop frames.
bool _cropForOcr(String imagePath, Rect region, String outPath) {
  final decoded = img.decodeImage(File(imagePath).readAsBytesSync());
  if (decoded == null) return false;
  final c = pixelCrop(region, decoded.width, decoded.height);
  var crop = img.copyCrop(
    decoded,
    x: c.x,
    y: c.y,
    width: c.width,
    height: c.height,
  );

  // ML Kit wants glyphs a few dozen pixels tall. Balloon lettering on a
  // phone-resolution scan is often half that.
  final shortSide = crop.width < crop.height ? crop.width : crop.height;
  if (shortSide < 400) {
    final factor = (400 / shortSide).clamp(1.0, 4.0);
    crop = img.copyResize(
      crop,
      width: (crop.width * factor).round(),
      height: (crop.height * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
  }
  crop = img.grayscale(crop);
  crop = img.copyExpandCanvas(
    crop,
    padding: 32,
    backgroundColor: img.ColorRgb8(255, 255, 255),
  );
  File(outPath).writeAsBytesSync(img.encodePng(crop));
  return true;
}
