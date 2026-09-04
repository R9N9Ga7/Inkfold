import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkfold_fb2_plugin/inkfold_fb2_plugin.dart';
import 'package:inkfold_pdf_plugin/inkfold_pdf_plugin.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';
import 'package:inkfold_text_plugin/inkfold_text_plugin.dart';

import 'data/app_database.dart';
import 'domain/plugin_catalog.dart';
import 'domain/reading_preferences.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final pluginCatalogProvider = Provider<PluginCatalog>((ref) {
  return PluginCatalog(const <BookFormatPlugin>[
    TextFormatPlugin(),
    PdfFormatPlugin(),
    Fb2FormatPlugin(),
  ]);
});

final booksProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(databaseProvider).watchBooks();
});

final bookProvider = FutureProvider.family<Book?, String>((ref, id) {
  return ref.watch(databaseProvider).getBook(id);
});

final bookmarksProvider = StreamProvider.family<List<Bookmark>, String>((ref, id) {
  return ref.watch(databaseProvider).watchBookmarks(id);
});

final readingPreferencesProvider = StreamProvider<ReadingPreferences>((ref) {
  return ref.watch(databaseProvider).watchPreferences();
});
