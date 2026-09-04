import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold/core/pdf_font_manager.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled PDF font resolver loads Japanese fallback font', () async {
    final resolver = BundledJapanesePdfFontResolver();
    final resolution = await resolver.resolve(
      const PdfFontQuery(
        face: 'IPAMincho',
        weight: 400,
        isItalic: false,
        charset: PdfFontCharset.shiftJis,
        pitchFamily: 16,
      ),
      const PdfFontResolveContext(),
    );

    expect(resolution, isNotNull);
    expect(resolution!.resolvedFace, 'Noto Sans JP');
    final firstLoad = await resolution.loadData!();
    final secondLoad = await resolution.loadData!();
    expect(firstLoad.length, greaterThan(4000000));
    expect(secondLoad, orderedEquals(firstLoad));
    expect(identical(firstLoad.buffer, secondLoad.buffer), isFalse);
  });

  test('bundled PDF font resolver leaves symbol fonts untouched', () async {
    final resolver = BundledJapanesePdfFontResolver();
    final resolution = await resolver.resolve(
      const PdfFontQuery(
        face: 'Symbol',
        weight: 400,
        isItalic: false,
        charset: PdfFontCharset.symbol,
        pitchFamily: 0,
      ),
      const PdfFontResolveContext(),
    );

    expect(resolution, isNull);
  });
}
