import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show TextAlign;

import '../domain/reading_preferences.dart';

part 'app_database.g.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get pluginId => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get sourceName => text()();
  TextColumn get contentHash => text().unique()();
  TextColumn get payloadJson => text()();
  IntColumn get coverColor => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  RealColumn get progress => real().withDefault(const Constant<double>(0))();
  IntColumn get position => integer().withDefault(const Constant<int>(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get excerpt => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class ReaderSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get palette => text().withDefault(const Constant<String>('paper'))();
  TextColumn get appAppearance => text().withDefault(const Constant<String>('system'))();
  RealColumn get fontSize => real().withDefault(const Constant<double>(19))();
  RealColumn get lineHeight => real().withDefault(const Constant<double>(1.65))();
  RealColumn get pageWidth => real().withDefault(const Constant<double>(720))();
  TextColumn get alignment => text().withDefault(const Constant<String>('left'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[Books, Bookmarks, ReaderSettings])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'inkfold',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(readerSettings).insertOnConflictUpdate(
        ReaderSettingsCompanion.insert(id: const Value<int>(1)),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<Book>> watchBooks() {
    return (select(books)..orderBy(<OrderingTerm Function(Books)>[
          (table) => OrderingTerm.desc(table.lastOpenedAt),
          (table) => OrderingTerm.desc(table.createdAt),
        ]))
        .watch();
  }

  Future<Book?> getBook(String id) =>
      (select(books)..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<Book?> findByHash(String hash) =>
      (select(books)..where((table) => table.contentHash.equals(hash))).getSingleOrNull();

  Future<void> addBook(BooksCompanion book) => into(books).insert(book);

  Future<void> saveProgress(
    String id, {
    required double progress,
    required int position,
  }) {
    return (update(books)..where((table) => table.id.equals(id))).write(
      BooksCompanion(
        progress: Value<double>(progress.clamp(0, 1)),
        position: Value<int>(position),
        lastOpenedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> deleteBook(String id) async {
    await transaction(() async {
      await (delete(bookmarks)..where((table) => table.bookId.equals(id))).go();
      await (delete(books)..where((table) => table.id.equals(id))).go();
    });
  }

  Stream<List<Bookmark>> watchBookmarks(String bookId) {
    return (select(bookmarks)
          ..where((table) => table.bookId.equals(bookId))
          ..orderBy(<OrderingTerm Function(Bookmarks)>[
            (table) => OrderingTerm.asc(table.position),
          ]))
        .watch();
  }

  Future<void> addBookmark({
    required String bookId,
    required int position,
    required String excerpt,
  }) => into(bookmarks).insert(
    BookmarksCompanion.insert(
      bookId: bookId,
      position: position,
      excerpt: excerpt,
      createdAt: DateTime.now(),
    ),
  );

  Future<void> removeBookmark(int id) =>
      (delete(bookmarks)..where((table) => table.id.equals(id))).go();

  Stream<ReadingPreferences> watchPreferences() {
    return (select(readerSettings)..where((table) => table.id.equals(1)))
        .watchSingle()
        .map(_mapPreferences);
  }

  Future<void> savePreferences(ReadingPreferences preferences) {
    return into(readerSettings).insertOnConflictUpdate(
      ReaderSettingsCompanion(
        id: const Value<int>(1),
        palette: Value<String>(preferences.palette.name),
        appAppearance: Value<String>(preferences.appAppearance.name),
        fontSize: Value<double>(preferences.fontSize),
        lineHeight: Value<double>(preferences.lineHeight),
        pageWidth: Value<double>(preferences.pageWidth),
        alignment: Value<String>(preferences.textAlign.name),
      ),
    );
  }

  ReadingPreferences _mapPreferences(ReaderSetting row) => ReadingPreferences(
    palette: ReaderPalette.values.byName(row.palette),
    appAppearance: AppAppearance.values.byName(row.appAppearance),
    fontSize: row.fontSize,
    lineHeight: row.lineHeight,
    pageWidth: row.pageWidth,
    textAlign: TextAlign.values.byName(row.alignment),
  );
}
