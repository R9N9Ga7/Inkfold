import 'package:inkfold_reader_api/inkfold_reader_api.dart';

final class PluginCatalog {
  PluginCatalog(List<BookFormatPlugin> plugins)
    : plugins = List<BookFormatPlugin>.unmodifiable(plugins) {
    final ids = <String>{};
    for (final plugin in plugins) {
      if (plugin.manifest.apiVersion != inkfoldPluginApiVersion) {
        throw StateError('${plugin.manifest.name} uses an incompatible plugin API.');
      }
      if (!ids.add(plugin.manifest.id)) {
        throw StateError('Duplicate plugin id: ${plugin.manifest.id}');
      }
    }
  }

  final List<BookFormatPlugin> plugins;

  BookFormatPlugin byId(String id) => plugins.firstWhere(
    (plugin) => plugin.manifest.id == id,
    orElse: () => throw const UnsupportedBookFormatException(
      'The plugin used by this book is not installed.',
    ),
  );

  Future<BookFormatPlugin> resolve(SourceDescriptor source) async {
    BookFormatPlugin? best;
    var bestScore = 0.0;
    for (final plugin in plugins) {
      final score = await plugin.probe(source);
      if (score > bestScore) {
        best = plugin;
        bestScore = score;
      }
    }
    if (best == null || bestScore < 0.5) {
      throw const UnsupportedBookFormatException('No installed plugin can open this file.');
    }
    return best;
  }
}
