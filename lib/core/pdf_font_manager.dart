import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

const _fontAsset = 'assets/fonts/NotoSansJP-Regular.otf';
const _fontLicenseAsset = 'assets/fonts/NotoSansJP-OFL.txt';

final inkfoldPdfFontManager = PdfFontManager(
  resolvers: <PdfFontResolver>[BundledJapanesePdfFontResolver()],
);

final class BundledJapanesePdfFontResolver implements PdfFontResolver {
  Future<Uint8List>? _fontData;

  @override
  FutureOr<PdfFontResolution?> resolve(
    PdfFontQuery query,
    PdfFontResolveContext context,
  ) {
    if (query.charset == PdfFontCharset.symbol) return null;
    return PdfFontResolution(
      loadData: _loadFont,
      resolvedFace: 'Noto Sans JP',
      source: Uri.parse('asset:///$_fontAsset'),
    );
  }

  Future<Uint8List> _loadFont({
    PdfFontDataLoadProgressCallback? onProgress,
  }) async {
    final source = await (_fontData ??= rootBundle.load(_fontAsset).then((data) {
      return data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }));
    // The web backend transfers this buffer to its PDFium worker, which
    // detaches it from Dart. Every target face therefore needs its own copy.
    final transferable = Uint8List.fromList(source);
    onProgress?.call(loaded: transferable.length, total: transferable.length);
    return transferable;
  }
}

void registerBundledPdfFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(_fontLicenseAsset);
    yield LicenseEntryWithLineBreaks(<String>['Noto Sans JP'], license);
  });
}
