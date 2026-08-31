import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/inkfold_theme.dart';
import 'domain/reading_preferences.dart';
import 'providers.dart';
import 'ui/library_screen.dart';
import 'ui/reader_screen.dart';
import 'ui/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/library',
  routes: <RouteBase>[
    GoRoute(path: '/library', builder: (context, state) => const LibraryScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/reader/:bookId',
      builder: (context, state) => ReaderScreen(bookId: state.pathParameters['bookId']!),
    ),
  ],
));

final class InkfoldApp extends ConsumerWidget {
  const InkfoldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(readingPreferencesProvider).valueOrNull ??
        const ReadingPreferences();
    final themeMode = switch (preferences.appAppearance) {
      AppAppearance.system => ThemeMode.system,
      AppAppearance.light => ThemeMode.light,
      AppAppearance.dark => ThemeMode.dark,
    };
    return MaterialApp.router(
      title: 'Inkfold',
      debugShowCheckedModeBanner: false,
      theme: InkfoldTheme.light(),
      darkTheme: InkfoldTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
