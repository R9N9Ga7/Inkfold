import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold_fb2_plugin/inkfold_fb2_plugin.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';

void main() {
  const plugin = Fb2FormatPlugin();

  test('imports FB2 metadata and structured readable text', () async {
    final source = SourceDescriptor(
      name: 'fallback.fb2',
      bytes: Uint8List.fromList(utf8.encode(_sampleFb2)),
    );

    expect(await plugin.probe(source), 1);
    final imported = await plugin.importBook(source);
    final document = await plugin.openDocument(
      'book-1',
      imported.metadata.title,
      imported.payload,
    );

    expect(imported.metadata.title, 'The Example Book');
    expect(imported.metadata.author, 'Ada M. Reader');
    expect(document.sections, hasLength(2));
    expect(document.sections.first.title, 'Chapter One');
    expect(document.sections.first.blocks.first.text, 'First emphasized line.');
    expect(document.sections.last.title, 'A Poem');
    expect(document.sections.last.blocks.single.text, 'Line one\nLine two');
  });

  test('reads Windows-1251 FB2 files', () async {
    const prefix = '<?xml version="1.0" encoding="windows-1251"?>'
        '<FictionBook><description><title-info><book-title>';
    const suffix = '</book-title></title-info></description>'
        '<body><section><p>Text</p></section></body></FictionBook>';
    final bytes = Uint8List.fromList(<int>[
      ...ascii.encode(prefix),
      0xca, 0xed, 0xe8, 0xe3, 0xe0,
      ...ascii.encode(suffix),
    ]);

    final imported = await plugin.importBook(
      SourceDescriptor(name: 'book.fb2', bytes: bytes),
    );

    expect(imported.metadata.title, '\u041a\u043d\u0438\u0433\u0430');
  });

  test('rejects malformed or non-FB2 XML', () async {
    final source = SourceDescriptor(
      name: 'broken.fb2',
      bytes: Uint8List.fromList(utf8.encode('<book><p>Text</p></book>')),
    );

    expect(await plugin.probe(source), 0);
    await expectLater(plugin.importBook(source), throwsFormatException);
  });

  test('rejects corrupted stored FB2 payloads', () async {
    const payload = PluginBookPayload(
      format: 'fb2',
      version: 1,
      data: <String, Object?>{
        'sections': <Object?>[
          <String, Object?>{'id': 'body', 'blocks': 'not a list'},
        ],
      },
    );

    await expectLater(
      plugin.openDocument('book-1', 'Broken', payload),
      throwsFormatException,
    );
  });
}

const _sampleFb2 = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>The Example Book</book-title>
      <author>
        <first-name>Ada</first-name>
        <middle-name>M.</middle-name>
        <last-name>Reader</last-name>
      </author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Chapter One</p></title>
      <p>First <emphasis>emphasized</emphasis> line.</p>
      <section>
        <title><p>A Poem</p></title>
        <poem><stanza><v>Line one</v><v>Line two</v></stanza></poem>
      </section>
    </section>
  </body>
</FictionBook>
''';
