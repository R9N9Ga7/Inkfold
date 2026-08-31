import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inkfold_reader_api/inkfold_reader_api.dart';

import '../core/inkfold_theme.dart';
import '../data/app_database.dart';
import '../domain/reading_preferences.dart';
import '../providers.dart';

typedef _LoadedBook = ({Book book, ReflowableDocument document});

double? _readyMaxScrollExtent(ScrollController controller) {
  if (!controller.hasClients) return null;
  final position = controller.position;
  if (!position.hasContentDimensions) return null;
  return position.maxScrollExtent;
}

final class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});
  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

final class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final Future<_LoadedBook> _loadedFuture;
  _LoadedBook? _loaded;
  Timer? _saveTimer;
  bool _controlsVisible = true;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadedFuture = _loadBook();
  }

  Future<_LoadedBook> _loadBook() async {
    final book = await ref.read(databaseProvider).getBook(widget.bookId);
    if (book == null) throw StateError('This book is no longer in your library.');
    final plugin = ref.read(pluginCatalogProvider).byId(book.pluginId);
    final decoded = Map<String, Object?>.from(jsonDecode(book.payloadJson) as Map);
    final document = await plugin.openDocument(
      book.id,
      book.title,
      PluginBookPayload.fromJson(decoded),
    );
    final loaded = (book: book, document: document);
    _loaded = loaded;
    return loaded;
  }

  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveProgress);
  }

  Future<void> _saveProgress() async {
    final loaded = _loaded;
    final max = _readyMaxScrollExtent(_scrollController);
    if (loaded == null || max == null) return;
    final progress = max <= 0 ? 1.0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    final position = (loaded.document.characterCount * progress).round();
    await ref.read(databaseProvider).saveProgress(
      loaded.book.id,
      progress: progress,
      position: position,
    );
  }

  void _restoreProgress(Book book) {
    if (_restored || book.progress <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final max = _readyMaxScrollExtent(_scrollController);
      if (max == null) return;
      _restored = true;
      _scrollController.jumpTo(max * book.progress);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(readingPreferencesProvider).valueOrNull ??
        const ReadingPreferences();
    final colors = _ReaderColors.from(preferences.palette);
    return FutureBuilder<_LoadedBook>(
      future: _loadedFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString().replaceFirst('Bad state: ', '')),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(child: CircularProgressIndicator(color: colors.accent)),
          );
        }
        final loaded = snapshot.data!;
        _restoreProgress(loaded.book);
        return PopScope(
          onPopInvokedWithResult: (_, result) => _saveProgress(),
          child: Scaffold(
            backgroundColor: colors.background,
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _controlsVisible = !_controlsVisible),
                    child: SelectionArea(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.paddingOf(context).left + 24,
                          MediaQuery.paddingOf(context).top + 108,
                          MediaQuery.paddingOf(context).right + 24,
                          MediaQuery.paddingOf(context).bottom + 132,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: preferences.pageWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  loaded.book.title,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontFamily: 'Literata',
                                    fontSize: (preferences.fontSize * 1.75).clamp(28, 48),
                                    height: 1.16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 44),
                                for (final block in loaded.document.sections.expand((section) => section.blocks))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: Text(
                                      block.text,
                                      textAlign: preferences.textAlign,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontFamily: 'Literata',
                                        fontSize: preferences.fontSize,
                                        height: preferences.lineHeight,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _ReaderToolbar(
                  visible: _controlsVisible,
                  colors: colors,
                  title: loaded.book.title,
                  onBack: () {
                    _saveProgress();
                    context.go('/library');
                  },
                  onBookmark: () => _addBookmark(loaded),
                  onBookmarks: () => _showBookmarks(loaded),
                  onAppearance: () => _showAppearance(preferences),
                ),
                _ProgressBar(
                  visible: _controlsVisible,
                  colors: colors,
                  controller: _scrollController,
                  onSeek: (value) {
                    final max = _readyMaxScrollExtent(_scrollController);
                    if (max == null) return;
                    _scrollController.jumpTo(max * value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addBookmark(_LoadedBook loaded) async {
    final position = _currentPosition(loaded.document);
    final text = loaded.document.plainText;
    final start = (position - 30).clamp(0, text.length);
    final end = (position + 90).clamp(0, text.length);
    final excerpt = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    await ref.read(databaseProvider).addBookmark(
      bookId: loaded.book.id,
      position: position,
      excerpt: excerpt,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark added')),
      );
    }
  }

  int _currentPosition(ReflowableDocument document) {
    final max = _readyMaxScrollExtent(_scrollController);
    if (max == null || max <= 0) return 0;
    final ratio = (_scrollController.offset / max).clamp(0.0, 1.0);
    return (document.characterCount * ratio).round();
  }

  void _seekToPosition(int position, ReflowableDocument document) {
    final max = _readyMaxScrollExtent(_scrollController);
    if (max == null || document.characterCount == 0) return;
    final ratio = (position / document.characterCount).clamp(0.0, 1.0);
    _scrollController.animateTo(
      max * ratio,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showBookmarks(_LoadedBook loaded) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (context) => StreamBuilder<List<Bookmark>>(
        stream: ref.read(databaseProvider).watchBookmarks(loaded.book.id),
        builder: (context, snapshot) {
          final bookmarks = snapshot.data ?? const <Bookmark>[];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Bookmarks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: bookmarks.isEmpty
                        ? const Center(child: Text('No bookmarks in this book.'))
                        : ListView.separated(
                            itemCount: bookmarks.length,
                            separatorBuilder: (_, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final bookmark = bookmarks[index];
                              final percent = loaded.document.characterCount == 0
                                  ? 0
                                  : (bookmark.position / loaded.document.characterCount * 100).round();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bookmark, color: InkfoldTheme.oxblood),
                                title: Text(bookmark.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text('$percent%'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _seekToPosition(bookmark.position, loaded.document);
                                },
                                trailing: IconButton(
                                  tooltip: 'Remove bookmark',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => ref.read(databaseProvider).removeBookmark(bookmark.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAppearance(ReadingPreferences initial) async {
    var current = initial;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> update(ReadingPreferences value) async {
            setModalState(() => current = value);
            await ref.read(databaseProvider).savePreferences(value);
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Reading appearance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  SegmentedButton<ReaderPalette>(
                    segments: const <ButtonSegment<ReaderPalette>>[
                      ButtonSegment(value: ReaderPalette.day, icon: Icon(Icons.light_mode_outlined), label: Text('Day')),
                      ButtonSegment(value: ReaderPalette.paper, icon: Icon(Icons.menu_book_outlined), label: Text('Paper')),
                      ButtonSegment(value: ReaderPalette.night, icon: Icon(Icons.dark_mode_outlined), label: Text('Night')),
                    ],
                    selected: <ReaderPalette>{current.palette},
                    onSelectionChanged: (value) => update(current.copyWith(palette: value.first)),
                  ),
                  const SizedBox(height: 20),
                  _ReaderSlider(
                    label: 'Text size',
                    value: current.fontSize,
                    min: 15,
                    max: 30,
                    divisions: 15,
                    onChanged: (value) => update(current.copyWith(fontSize: value)),
                  ),
                  _ReaderSlider(
                    label: 'Line height',
                    value: current.lineHeight,
                    min: 1.25,
                    max: 2.1,
                    divisions: 17,
                    onChanged: (value) => update(current.copyWith(lineHeight: value)),
                  ),
                  _ReaderSlider(
                    label: 'Page width',
                    value: current.pageWidth,
                    min: 520,
                    max: 900,
                    divisions: 19,
                    onChanged: (value) => update(current.copyWith(pageWidth: value)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.visible,
    required this.colors,
    required this.title,
    required this.onBack,
    required this.onBookmark,
    required this.onBookmarks,
    required this.onAppearance,
  });

  final bool visible;
  final _ReaderColors colors;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onBookmarks;
  final VoidCallback onAppearance;

  @override
  Widget build(BuildContext context) => AnimatedPositioned(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    top: visible ? 0 : -104,
    left: 0,
    right: 0,
    child: Material(
      color: colors.chrome.withValues(alpha: 0.97),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: colors.text),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 8),
                IconButton(tooltip: 'Back to library', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(tooltip: 'Add bookmark', onPressed: onBookmark, icon: const Icon(Icons.bookmark_add_outlined)),
                IconButton(tooltip: 'Bookmarks', onPressed: onBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
                IconButton(tooltip: 'Reading appearance', onPressed: onAppearance, icon: const Icon(Icons.text_fields_rounded)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.visible,
    required this.colors,
    required this.controller,
    required this.onSeek,
  });
  final bool visible;
  final _ReaderColors colors;
  final ScrollController controller;
  final ValueChanged<double> onSeek;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

final class _ProgressBarState extends State<_ProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(covariant _ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _readyMaxScrollExtent(widget.controller) ?? 0.0;
    final value = max <= 0 ? 0.0 : (widget.controller.offset / max).clamp(0.0, 1.0);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: widget.visible ? 0 : -112,
      child: Material(
        color: widget.colors.chrome.withValues(alpha: 0.97),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.colors.accent,
            inactiveTrackColor: widget.colors.text.withValues(alpha: 0.22),
            thumbColor: widget.colors.accent,
            overlayColor: widget.colors.accent.withValues(alpha: 0.12),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Slider(value: value, onChanged: widget.onSeek),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${(value * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: widget.colors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildReaderProgressBarForTest(ScrollController controller) {
  return _ProgressBar(
    visible: true,
    colors: _ReaderColors.from(ReaderPalette.paper),
    controller: controller,
    onSeek: (_) {},
  );
}

@visibleForTesting
Widget buildReaderToolbarForTest() {
  return _ReaderToolbar(
    visible: true,
    colors: _ReaderColors.from(ReaderPalette.paper),
    title: 'Book title',
    onBack: () {},
    onBookmark: () {},
    onBookmarks: () {},
    onAppearance: () {},
  );
}

final class _ReaderSlider extends StatelessWidget {
  const _ReaderSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 90, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

final class _ReaderColors {
  const _ReaderColors({
    required this.background,
    required this.text,
    required this.chrome,
    required this.accent,
  });
  final Color background;
  final Color text;
  final Color chrome;
  final Color accent;

  factory _ReaderColors.from(ReaderPalette palette) => switch (palette) {
    ReaderPalette.day => const _ReaderColors(
      background: Color(0xffffffff),
      text: Color(0xff202525),
      chrome: Color(0xfff7f8f6),
      accent: InkfoldTheme.teal,
    ),
    ReaderPalette.paper => const _ReaderColors(
      background: Color(0xfff4f0e7),
      text: Color(0xff2c2923),
      chrome: Color(0xffebe5da),
      accent: InkfoldTheme.oxblood,
    ),
    ReaderPalette.night => const _ReaderColors(
      background: Color(0xff181d1c),
      text: Color(0xffd9ddd7),
      chrome: Color(0xff222927),
      accent: Color(0xff9fc4bd),
    ),
  };
}
