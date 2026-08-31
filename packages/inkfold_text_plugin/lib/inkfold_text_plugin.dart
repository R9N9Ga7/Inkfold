library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:inkfold_reader_api/inkfold_reader_api.dart';

final class TextFormatPlugin implements BookFormatPlugin {
  const TextFormatPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'app.inkfold.text',
    name: 'Plain text',
    version: '0.1.0',
    apiVersion: inkfoldPluginApiVersion,
    extensions: <String>{'txt', 'text'},
    mimeTypes: <String>{'text/plain'},
    capabilities: <PluginCapability>{
      PluginCapability.reflowableText,
      PluginCapability.search,
    },
  );

  @override
  Future<double> probe(SourceDescriptor source) async {
    if (manifest.extensions.contains(source.extension)) return 1;
    if (source.mimeType != null && manifest.mimeTypes.contains(source.mimeType)) {
      return 0.9;
    }
    return 0;
  }

  @override
  Future<ImportedBook> importBook(SourceDescriptor source) async {
    final normalized = _normalize(_decode(source.bytes));
    if (normalized.trim().isEmpty) {
      throw const FormatException('This text file is empty.');
    }
    final rawTitle = source.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final title = rawTitle.trim().isEmpty ? 'Untitled' : rawTitle.trim();
    return ImportedBook(
      metadata: BookMetadata(title: title),
      payload: PluginBookPayload(
        format: 'plainText',
        version: 1,
        data: <String, Object?>{'text': normalized},
      ),
    );
  }

  @override
  Future<ReflowableDocument> openDocument(
    String documentId,
    String title,
    PluginBookPayload payload,
  ) async {
    if (payload.format != 'plainText' || payload.version != 1) {
      throw const FormatException('Unsupported plain-text payload version.');
    }
    final text = payload.data['text'];
    if (text is! String) {
      throw const FormatException('The stored text document is invalid.');
    }
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return ReflowableDocument(
      id: documentId,
      title: title,
      sections: <ReaderSection>[
        ReaderSection(
          id: 'body',
          blocks: <ReaderBlock>[
            for (var index = 0; index < paragraphs.length; index++)
              ReaderBlock(id: 'p$index', text: paragraphs[index]),
          ],
        ),
      ],
    );
  }

  String _decode(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    final start = bytes.length >= 3 && bytes[0] == 0xef &&
            bytes[1] == 0xbb && bytes[2] == 0xbf ? 3 : 0;
    try {
      return utf8.decode(bytes.sublist(start), allowMalformed: false);
    } on FormatException {
      throw const FormatException(
        'Inkfold supports UTF-8 and BOM-marked UTF-16 text files.',
      );
    }
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    if (bytes.length.isOdd) {
      throw const FormatException('The UTF-16 text file is incomplete.');
    }
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      units.add(littleEndian
          ? bytes[index] | (bytes[index + 1] << 8)
          : (bytes[index] << 8) | bytes[index + 1]);
    }
    return String.fromCharCodes(units);
  }

  String _normalize(String source) {
    final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final paragraphs = <String>[];
    final current = <String>[];
    void commit() {
      if (current.isEmpty) return;
      paragraphs.add(current.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim());
      current.clear();
    }
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) {
        commit();
      } else {
        current.add(trimmed.trimLeft());
      }
    }
    commit();
    return paragraphs.join('\n\n');
  }
}
