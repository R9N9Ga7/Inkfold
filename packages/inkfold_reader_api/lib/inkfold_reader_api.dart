library;

import 'dart:typed_data';

const int inkfoldPluginApiVersion = 1;

enum PluginCapability { reflowableText, fixedLayout, tableOfContents, search }

final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.extensions,
    required this.mimeTypes,
    required this.capabilities,
  });

  final String id;
  final String name;
  final String version;
  final int apiVersion;
  final Set<String> extensions;
  final Set<String> mimeTypes;
  final Set<PluginCapability> capabilities;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'version': version,
    'apiVersion': apiVersion,
    'extensions': extensions.toList(growable: false),
    'mimeTypes': mimeTypes.toList(growable: false),
    'capabilities': capabilities.map((item) => item.name).toList(growable: false),
  };
}

final class SourceDescriptor {
  const SourceDescriptor({required this.name, required this.bytes, this.mimeType});

  final String name;
  final String? mimeType;
  final Uint8List bytes;

  String get extension {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }
}

final class BookMetadata {
  const BookMetadata({required this.title, this.author});

  final String title;
  final String? author;
}

final class PluginBookPayload {
  const PluginBookPayload({
    required this.format,
    required this.version,
    required this.data,
  });

  final String format;
  final int version;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format,
    'version': version,
    'data': data,
  };

  factory PluginBookPayload.fromJson(Map<String, Object?> json) {
    return PluginBookPayload(
      format: json['format']! as String,
      version: json['version']! as int,
      data: Map<String, Object?>.from(json['data']! as Map),
    );
  }
}

final class ImportedBook {
  const ImportedBook({required this.metadata, required this.payload});

  final BookMetadata metadata;
  final PluginBookPayload payload;
}

final class ReaderBlock {
  const ReaderBlock({required this.id, required this.text});

  final String id;
  final String text;
}

final class ReaderSection {
  const ReaderSection({required this.id, required this.blocks, this.title});

  final String id;
  final String? title;
  final List<ReaderBlock> blocks;
}

final class ReflowableDocument {
  const ReflowableDocument({
    required this.id,
    required this.title,
    required this.sections,
  });

  final String id;
  final String title;
  final List<ReaderSection> sections;

  String get plainText => sections
      .expand((section) => section.blocks)
      .map((block) => block.text)
      .join('\n\n');

  int get characterCount => plainText.length;
}

abstract interface class BookFormatPlugin {
  PluginManifest get manifest;
  Future<double> probe(SourceDescriptor source);
  Future<ImportedBook> importBook(SourceDescriptor source);
  Future<ReflowableDocument> openDocument(
    String documentId,
    String title,
    PluginBookPayload payload,
  );
}

final class UnsupportedBookFormatException implements Exception {
  const UnsupportedBookFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}
