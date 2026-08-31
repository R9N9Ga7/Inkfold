import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkfold/ui/app_scaffold.dart';

void main() {
  testWidgets('phone shell uses bottom navigation without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide shell uses the persistent editorial sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp());

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Inkfold'), findsOneWidget);
    expect(find.text('TEXT READER  /  01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp() {
  final router = GoRouter(
    initialLocation: '/library',
    routes: <RouteBase>[
      GoRoute(
        path: '/library',
        builder: (context, state) => const AppScaffold(
          selectedIndex: 0,
          title: 'Library',
          body: Center(child: Text('Library body')),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const AppScaffold(
          selectedIndex: 1,
          title: 'Settings',
          body: Center(child: Text('Settings body')),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}
