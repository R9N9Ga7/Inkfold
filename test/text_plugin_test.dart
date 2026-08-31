import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';
import 'package:inkfold_text_plugin/inkfold_text_plugin.dart';

void main() {
  const plugin = TextFormatPlugin();

  test('imports UTF-8 text into stable paragraph blocks', () async {
    final source = SourceDescriptor(
      name: 'The_Test.txt',
      bytes: Uint8List.fromList(utf8.encode('First line\nwraps here.\n\nSecond paragraph.')),
    );

    final imported = await plugin.importBook(source);
    final document = await plugin.openDocument('1', imported.metadata.title, imported.payload);

    expect(imported.metadata.title, 'The_Test');
    expect(document.sections.single.blocks, hasLength(2));
    expect(document.sections.single.blocks.first.text, 'First line wraps here.');
  });

  test('decodes BOM-marked UTF-16 little endian text', () async {
    final bytes = Uint8List.fromList(<int>[
      0xff, 0xfe,
      0x48, 0x00,
      0x69, 0x00,
    ]);
    final imported = await plugin.importBook(SourceDescriptor(name: 'hi.txt', bytes: bytes));

    expect(imported.payload.data['text'], 'Hi');
  });

  test('rejects malformed encodings with a useful message', () async {
    final source = SourceDescriptor(
      name: 'broken.txt',
      bytes: Uint8List.fromList(<int>[0xc3, 0x28]),
    );

    expect(
      () => plugin.importBook(source),
      throwsA(isA<FormatException>()),
    );
  });
}
