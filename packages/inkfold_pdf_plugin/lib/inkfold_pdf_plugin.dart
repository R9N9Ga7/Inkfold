library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:inkfold_reader_api/inkfold_reader_api.dart';

final class PdfFormatPlugin implements BookFormatPlugin {
  const PdfFormatPlugin();

  static const _signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2d];

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'app.inkfold.pdf',
    name: 'PDF',
    version: '0.1.0',
    apiVersion: inkfoldPluginApiVersion,
    extensions: <String>{'pdf'},
    mimeTypes: <String>{'application/pdf'},
    capabilities: <PluginCapability>{PluginCapability.fixedLayout},
  );

  @override
  Future<double> probe(SourceDescriptor source) async {
    if (!_hasPdfSignature(source.bytes)) return 0;
    if (manifest.extensions.contains(source.extension)) return 1;
    if (source.mimeType != null &&
        manifest.mimeTypes.contains(source.mimeType)) {
      return 0.95;
    }
    return 0.8;
  }

  @override
  Future<ImportedBook> importBook(SourceDescriptor source) async {
    if (!_hasPdfSignature(source.bytes)) {
      throw const FormatException('This file is not a valid PDF document.');
    }
    final rawTitle = source.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final title = rawTitle.trim().isEmpty ? 'Untitled' : rawTitle.trim();
    return ImportedBook(
      metadata: BookMetadata(title: title),
      payload: PluginBookPayload(
        format: 'pdf',
        version: 1,
        data: <String, Object?>{'bytes': base64Encode(source.bytes)},
      ),
    );
  }

  @override
  Future<FixedLayoutDocument> openDocument(
    String documentId,
    String title,
    PluginBookPayload payload,
  ) async {
    if (payload.format != 'pdf' || payload.version != 1) {
      throw const FormatException('Unsupported PDF payload version.');
    }
    final encoded = payload.data['bytes'];
    if (encoded is! String) {
      throw const FormatException('The stored PDF document is invalid.');
    }
    try {
      final bytes = base64Decode(encoded);
      if (!_hasPdfSignature(bytes)) {
        throw const FormatException('The stored PDF document is invalid.');
      }
      return FixedLayoutDocument(
        id: documentId,
        title: title,
        bytes: bytes,
        mediaType: 'application/pdf',
      );
    } on FormatException {
      throw const FormatException('The stored PDF document is invalid.');
    }
  }

  bool _hasPdfSignature(Uint8List bytes) {
    if (bytes.length < _signature.length) return false;
    for (var index = 0; index < _signature.length; index++) {
      if (bytes[index] != _signature[index]) return false;
    }
    return true;
  }
}
