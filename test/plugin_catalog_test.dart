import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold/domain/plugin_catalog.dart';
import 'package:inkfold_fb2_plugin/inkfold_fb2_plugin.dart';
import 'package:inkfold_pdf_plugin/inkfold_pdf_plugin.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';
import 'package:inkfold_text_plugin/inkfold_text_plugin.dart';

void main() {
  test('resolves the built-in text plugin', () async {
    final catalog = PluginCatalog(const <BookFormatPlugin>[TextFormatPlugin()]);
    final plugin = await catalog.resolve(
      SourceDescriptor(name: 'book.txt', bytes: Uint8List(0)),
    );

    expect(plugin.manifest.id, 'app.inkfold.text');
  });

  test('rejects duplicate plugin ids', () {
    expect(
      () => PluginCatalog(const <BookFormatPlugin>[
        TextFormatPlugin(),
        TextFormatPlugin(),
      ]),
      throwsStateError,
    );
  });

  test('rejects unsupported file types', () async {
    final catalog = PluginCatalog(const <BookFormatPlugin>[TextFormatPlugin()]);

    expect(
      () => catalog.resolve(SourceDescriptor(name: 'book.pdf', bytes: Uint8List(0))),
      throwsA(isA<UnsupportedBookFormatException>()),
    );
  });

  test('resolves the built-in PDF plugin from its signature', () async {
    final catalog = PluginCatalog(const <BookFormatPlugin>[
      TextFormatPlugin(),
      PdfFormatPlugin(),
    ]);
    final plugin = await catalog.resolve(
      SourceDescriptor(
        name: 'book.pdf',
        bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2d]),
      ),
    );

    expect(plugin.manifest.id, 'app.inkfold.pdf');
  });

  test('resolves the built-in FB2 plugin from its XML root', () async {
    final catalog = PluginCatalog(const <BookFormatPlugin>[
      TextFormatPlugin(),
      Fb2FormatPlugin(),
    ]);
    final plugin = await catalog.resolve(
      SourceDescriptor(
        name: 'book.fb2',
        bytes: Uint8List.fromList(
          '<FictionBook><body><section><p>Text</p></section></body></FictionBook>'
              .codeUnits,
        ),
      ),
    );

    expect(plugin.manifest.id, 'app.inkfold.fb2');
  });
}
