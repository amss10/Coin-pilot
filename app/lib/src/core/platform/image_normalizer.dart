import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Prepares a receipt photo for the AI (contract §1.5): JPEG only (Claude does
/// not accept HEIC), EXIF metadata removed (location, device), long edge at
/// most [maxEdge] px, at most [maxBytes].
///
/// Callers should already have limited the size when picking
/// (`image_picker` `maxWidth`/`maxHeight` = [maxEdge]); this never upscales.
abstract interface class ImageNormalizer {
  static const int maxEdge = 2000;
  static const int maxBytes = 2 * 1024 * 1024;

  Future<Uint8List> toReceiptJpeg(Uint8List input);
}

final class NativeImageNormalizer implements ImageNormalizer {
  const NativeImageNormalizer();

  @override
  Future<Uint8List> toReceiptJpeg(Uint8List input) async {
    var quality = 85;
    var output = await _compress(input, quality);
    while (output.lengthInBytes > ImageNormalizer.maxBytes && quality > 40) {
      quality -= 15;
      output = await _compress(input, quality);
    }
    return output;
  }

  Future<Uint8List> _compress(Uint8List input, int quality) => FlutterImageCompress.compressWithList(
    input,
    minWidth: ImageNormalizer.maxEdge,
    minHeight: ImageNormalizer.maxEdge,
    quality: quality,
    // ignore: avoid_redundant_argument_values, being explicit about privacy-relevant defaults.
    keepExif: false,
  );
}
