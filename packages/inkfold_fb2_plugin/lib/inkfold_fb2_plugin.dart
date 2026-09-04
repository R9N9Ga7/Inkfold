library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:inkfold_reader_api/inkfold_reader_api.dart';
import 'package:xml/xml.dart';

final class Fb2FormatPlugin implements BookFormatPlugin {
  const Fb2FormatPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'app.inkfold.fb2',
    name: 'FictionBook 2',
    version: '0.1.0',
    apiVersion: inkfoldPluginApiVersion,
    extensions: <String>{'fb2'},
    mimeTypes: <String>{
      'application/x-fictionbook+xml',
      'application/fb2+xml',
    },
    capabilities: <PluginCapability>{
      PluginCapability.reflowableText,
      PluginCapability.tableOfContents,
      PluginCapability.search,
    },
  );

  @override
  Future<double> probe(SourceDescriptor source) async {
    if (!_looksLikeFb2(source.bytes)) return 0;
    if (manifest.extensions.contains(source.extension)) return 1;
    if (source.mimeType != null && manifest.mimeTypes.contains(source.mimeType)) {
      return 0.95;
    }
    return 0.8;
  }

  @override
  Future<ImportedBook> importBook(SourceDescriptor source) async {
    final xml = _decodeXml(source.bytes);
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlParserException {
      throw const FormatException('This file is not a valid FB2 document.');
    }
    if (_localName(document.rootElement) != 'fictionbook') {
      throw const FormatException('This file is not a valid FB2 document.');
    }

    final titleInfo = _firstDescendant(document.rootElement, 'title-info');
    final bookTitle = titleInfo == null
        ? null
        : _normalizedText(_firstChild(titleInfo, 'book-title'));
    final fallbackTitle = source.name.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
    final title = bookTitle?.isNotEmpty == true
        ? bookTitle!
        : fallbackTitle.isEmpty
        ? 'Untitled'
        : fallbackTitle;
    final authors = titleInfo == null
        ? const <String>[]
        : _children(titleInfo, 'author')
              .map(_authorName)
              .where((name) => name.isNotEmpty)
              .toList(growable: false);
    final sections = _extractSections(document.rootElement);
    if (sections.every((section) => section.blocks.isEmpty)) {
      throw const FormatException('This FB2 document does not contain readable text.');
    }

    return ImportedBook(
      metadata: BookMetadata(
        title: title,
        author: authors.isEmpty ? null : authors.join(', '),
      ),
      payload: PluginBookPayload(
        format: 'fb2',
        version: 1,
        data: <String, Object?>{
          'sections': <Map<String, Object?>>[
            for (final section in sections)
              <String, Object?>{
                'id': section.id,
                if (section.title != null) 'title': section.title,
                'blocks': <Map<String, Object?>>[
                  for (final block in section.blocks)
                    <String, Object?>{'id': block.id, 'text': block.text},
                ],
              },
          ],
        },
      ),
    );
  }

  @override
  Future<ReflowableDocument> openDocument(
    String documentId,
    String title,
    PluginBookPayload payload,
  ) async {
    if (payload.format != 'fb2' || payload.version != 1) {
      throw const FormatException('Unsupported FB2 payload version.');
    }
    final storedSections = payload.data['sections'];
    if (storedSections is! List) {
      throw const FormatException('The stored FB2 document is invalid.');
    }
    try {
      final sections = <ReaderSection>[];
      for (final storedSection in storedSections) {
        if (storedSection is! Map) throw const FormatException();
        final section = Map<String, Object?>.from(storedSection);
        final id = section['id'];
        final sectionTitle = section['title'];
        final storedBlocks = section['blocks'];
        if (id is! String ||
            (sectionTitle != null && sectionTitle is! String) ||
            storedBlocks is! List) {
          throw const FormatException();
        }
        final blocks = <ReaderBlock>[];
        for (final storedBlock in storedBlocks) {
          if (storedBlock is! Map) throw const FormatException();
          final block = Map<String, Object?>.from(storedBlock);
          final blockId = block['id'];
          final text = block['text'];
          if (blockId is! String || text is! String || text.trim().isEmpty) {
            throw const FormatException();
          }
          blocks.add(ReaderBlock(id: blockId, text: text));
        }
        sections.add(
          ReaderSection(id: id, title: sectionTitle as String?, blocks: blocks),
        );
      }
      if (sections.isEmpty || sections.every((section) => section.blocks.isEmpty)) {
        throw const FormatException();
      }
      return ReflowableDocument(
        id: documentId,
        title: title,
        sections: sections,
      );
    } on FormatException {
      throw const FormatException('The stored FB2 document is invalid.');
    }
  }

  bool _looksLikeFb2(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    try {
      final source = _decodeXml(bytes);
      final prefix = source.substring(0, source.length.clamp(0, 4096));
      return RegExp(
        r'<(?:[A-Za-z_][\w.-]*:)?FictionBook(?:\s|>)',
        caseSensitive: false,
      ).hasMatch(prefix);
    } on FormatException {
      return false;
    }
  }

  String _decodeXml(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    final start = bytes.length >= 3 &&
            bytes[0] == 0xef &&
            bytes[1] == 0xbb &&
            bytes[2] == 0xbf
        ? 3
        : 0;
    final declaration = latin1.decode(
      bytes.sublist(start, bytes.length.clamp(start, start + 256)),
    );
    final encoding = RegExp(
      r'''encoding\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(declaration)?.group(1)?.toLowerCase();
    if (encoding == 'windows-1251' || encoding == 'cp1251') {
      return _decodeWindows1251(bytes.sublist(start));
    }
    if (encoding == 'iso-8859-1' || encoding == 'latin1') {
      return latin1.decode(bytes.sublist(start));
    }
    if (encoding != null &&
        encoding != 'utf-8' &&
        encoding != 'utf8' &&
        encoding != 'us-ascii') {
      throw FormatException('FB2 encoding "$encoding" is not supported.');
    }
    try {
      return utf8.decode(bytes.sublist(start), allowMalformed: false);
    } on FormatException {
      throw const FormatException(
        'Inkfold supports UTF-8, UTF-16, and Windows-1251 FB2 files.',
      );
    }
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    if (bytes.length.isOdd) {
      throw const FormatException('The UTF-16 FB2 file is incomplete.');
    }
    final units = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      units.add(
        littleEndian
            ? bytes[index] | (bytes[index + 1] << 8)
            : (bytes[index] << 8) | bytes[index + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  String _decodeWindows1251(Uint8List bytes) {
    const special = <int>[
      0x0402, 0x0403, 0x201a, 0x0453, 0x201e, 0x2026, 0x2020, 0x2021,
      0x20ac, 0x2030, 0x0409, 0x2039, 0x040a, 0x040c, 0x040b, 0x040f,
      0x0452, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014,
      0xfffd, 0x2122, 0x0459, 0x203a, 0x045a, 0x045c, 0x045b, 0x045f,
      0x00a0, 0x040e, 0x045e, 0x0408, 0x00a4, 0x0490, 0x00a6, 0x00a7,
      0x0401, 0x00a9, 0x0404, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x0407,
      0x00b0, 0x00b1, 0x0406, 0x0456, 0x0491, 0x00b5, 0x00b6, 0x00b7,
      0x0451, 0x2116, 0x0454, 0x00bb, 0x0458, 0x0405, 0x0455, 0x0457,
    ];
    return String.fromCharCodes(<int>[
      for (final byte in bytes)
        if (byte < 0x80)
          byte
        else if (byte < 0xc0)
          special[byte - 0x80]
        else
          0x0410 + byte - 0xc0,
    ]);
  }

  List<ReaderSection> _extractSections(XmlElement root) {
    final result = <ReaderSection>[];
    var blockIndex = 0;
    final bodies = _children(root, 'body').toList(growable: false);

    List<ReaderBlock> directBlocks(XmlElement container) {
      final blocks = <ReaderBlock>[];
      void visit(XmlElement element) {
        final name = _localName(element);
        if (name == 'section' || name == 'title' || name == 'image' || name == 'empty-line') {
          return;
        }
        if (name == 'p' || name == 'subtitle' || name == 'text-author' || name == 'date') {
          final text = _normalizedText(element);
          if (text != null && text.isNotEmpty) {
            blocks.add(ReaderBlock(id: 'b${blockIndex++}', text: text));
          }
          return;
        }
        if (name == 'stanza') {
          final lines = _children(element, 'v')
              .map(_normalizedText)
              .whereType<String>()
              .where((line) => line.isNotEmpty)
              .toList(growable: false);
          if (lines.isNotEmpty) {
            blocks.add(ReaderBlock(id: 'b${blockIndex++}', text: lines.join('\n')));
          }
          return;
        }
        for (final child in element.childElements) {
          visit(child);
        }
      }

      for (final child in container.childElements) {
        visit(child);
      }
      return blocks;
    }

    void addSection(XmlElement section, String id) {
      final title = _sectionTitle(section);
      final blocks = directBlocks(section);
      if (title != null || blocks.isNotEmpty) {
        result.add(ReaderSection(id: id, title: title, blocks: blocks));
      }
      var childIndex = 0;
      for (final child in _children(section, 'section')) {
        addSection(child, '$id-${childIndex++}');
      }
    }

    for (var bodyIndex = 0; bodyIndex < bodies.length; bodyIndex++) {
      final body = bodies[bodyIndex];
      final bodyId = 'body-$bodyIndex';
      final title = _sectionTitle(body);
      final blocks = directBlocks(body);
      if (title != null || blocks.isNotEmpty) {
        result.add(ReaderSection(id: bodyId, title: title, blocks: blocks));
      }
      var sectionIndex = 0;
      for (final section in _children(body, 'section')) {
        addSection(section, '$bodyId-${sectionIndex++}');
      }
    }
    return result;
  }

  String _authorName(XmlElement author) {
    final nickname = _normalizedText(_firstChild(author, 'nickname'));
    final parts = <String?>[
      _normalizedText(_firstChild(author, 'first-name')),
      _normalizedText(_firstChild(author, 'middle-name')),
      _normalizedText(_firstChild(author, 'last-name')),
    ].whereType<String>().where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : nickname ?? '';
  }

  String? _sectionTitle(XmlElement element) {
    final title = _firstChild(element, 'title');
    if (title == null) return null;
    final lines = _children(title, 'p')
        .map(_normalizedText)
        .whereType<String>()
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines.isEmpty ? _normalizedText(title) : lines.join(' ');
  }

  String? _normalizedText(XmlElement? element) {
    if (element == null) return null;
    return element.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  XmlElement? _firstDescendant(XmlElement element, String name) {
    for (final descendant in element.descendants.whereType<XmlElement>()) {
      if (_localName(descendant) == name) return descendant;
    }
    return null;
  }

  XmlElement? _firstChild(XmlElement element, String name) {
    for (final child in element.childElements) {
      if (_localName(child) == name) return child;
    }
    return null;
  }

  Iterable<XmlElement> _children(XmlElement element, String name) {
    return element.childElements.where((child) => _localName(child) == name);
  }

  String _localName(XmlElement element) => element.name.local.toLowerCase();
}
