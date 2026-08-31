import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';

import '../core/inkfold_theme.dart';
import '../data/app_database.dart';
import '../providers.dart';
import 'app_scaffold.dart';

final class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

final class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _importing = false;
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['txt', 'text', 'pdf'],
    );
    if (result.isEmpty) return;
    await _importFiles(result.map((file) => file.xFile));
  }

  Future<void> _importFiles(Iterable<XFile> files) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await _importOne(file.name, file.mimeType, bytes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importOne(String name, String? mimeType, Uint8List bytes) async {
    final database = ref.read(databaseProvider);
    final hash = sha256.convert(bytes).toString();
    final duplicate = await database.findByHash(hash);
    if (duplicate != null) {
      if (mounted) context.go('/reader/${duplicate.id}');
      return;
    }

    final source = SourceDescriptor(name: name, mimeType: mimeType, bytes: bytes);
    final plugin = await ref.read(pluginCatalogProvider).resolve(source);
    final imported = await plugin.importBook(source);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${hash.substring(0, 8)}';
    const covers = <int>[
      0xff2f6f6a,
      0xff8f3b42,
      0xff3e526b,
      0xff8a6b35,
      0xff5d526d,
      0xff47634d,
    ];
    await database.addBook(
      BooksCompanion.insert(
        id: id,
        pluginId: plugin.manifest.id,
        title: imported.metadata.title,
        author: Value<String?>(imported.metadata.author),
        sourceName: name,
        contentHash: hash,
        payloadJson: jsonEncode(imported.payload.toJson()),
        coverColor: covers[hash.codeUnitAt(0) % covers.length],
        createdAt: DateTime.now(),
      ),
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('FormatException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    final importButton = Padding(
      padding: const EdgeInsets.only(right: 12),
      child: FilledButton.icon(
        onPressed: _importing ? null : _pickFiles,
        icon: _importing
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_importing ? 'Importing' : 'Import'),
      ),
    );
    return AppScaffold(
      selectedIndex: 0,
      title: 'Library',
      actions: <Widget>[importButton],
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          _importFiles(details.files);
        },
        child: books.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LibraryError(message: _friendlyError(error)),
          data: (items) => AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            color: _dragging
                ? InkfoldTheme.teal.withValues(alpha: 0.08)
                : Colors.transparent,
            child: items.isEmpty
                ? _EmptyLibrary(importing: _importing, onImport: _pickFiles)
                : _BookGrid(
                    books: items,
                    onDelete: (book) => _confirmDelete(book),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text('“${book.title}” and its reading progress will be deleted.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteBook(book.id);
    }
  }
}

final class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.importing, required this.onImport});

  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: <Widget>[
            Container(
              width: 112,
              height: 140,
              decoration: BoxDecoration(
                color: InkfoldTheme.oxblood,
                borderRadius: BorderRadius.circular(5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 9)),
                ],
              ),
              child: const Stack(
                children: <Widget>[
                  Positioned(left: 13, top: 0, bottom: 0, child: VerticalDivider(color: Color(0x55ffffff))),
                  Center(child: Icon(Icons.auto_stories_outlined, color: Colors.white, size: 34)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your shelf is ready',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'Literata',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose a text or PDF book, or drop one anywhere in this window.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: importing ? null : onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Choose book file'),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.onDelete});

  final List<Book> books;
  final ValueChanged<Book> onDelete;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 238,
            mainAxisExtent: 326,
            crossAxisSpacing: 22,
            mainAxisSpacing: 24,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _BookTile(book: books[index], onDelete: onDelete),
            childCount: books.length,
          ),
        ),
      ),
    ],
  );
}

final class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onDelete});

  final Book book;
  final ValueChanged<Book> onDelete;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${book.title}, ${(book.progress * 100).round()} percent read',
    child: InkWell(
      onTap: () => context.go('/reader/${book.id}'),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(book.coverColor),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 28, 18, 20),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      book.title,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Literata',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'INKFOLD',
                      style: TextStyle(color: Color(0xaaffffff), fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Book actions',
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'delete') onDelete(book);
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: book.progress,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 6),
          Text(
            book.progress == 0 ? 'Not started' : '${(book.progress * 100).round()}% read',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

final class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
