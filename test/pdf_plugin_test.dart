import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold_pdf_plugin/inkfold_pdf_plugin.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';

void main() {
  const plugin = PdfFormatPlugin();
  final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nmock document'));

  test('imports and opens PDF bytes as a fixed-layout document', () async {
    final source = SourceDescriptor(name: 'A Quiet Book.pdf', bytes: pdfBytes);

    expect(await plugin.probe(source), 1);
    final imported = await plugin.importBook(source);
    final document = await plugin.openDocument(
      'book-1',
      imported.metadata.title,
      imported.payload,
    );

    expect(imported.metadata.title, 'A Quiet Book');
    expect(document.mediaType, 'application/pdf');
    expect(document.bytes, orderedEquals(pdfBytes));
  });

  test('rejects a renamed non-PDF file', () async {
    final source = SourceDescriptor(
      name: 'not-a-book.pdf',
      bytes: Uint8List.fromList(utf8.encode('plain text')),
    );

    expect(await plugin.probe(source), 0);
    await expectLater(plugin.importBook(source), throwsFormatException);
  });

  test('rejects corrupted stored PDF payloads', () async {
    const payload = PluginBookPayload(
      format: 'pdf',
      version: 1,
      data: <String, Object?>{'bytes': 'not base64'},
    );

    await expectLater(
      plugin.openDocument('book-1', 'Broken', payload),
      throwsFormatException,
    );
  });
}
