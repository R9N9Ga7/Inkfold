import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold/ui/reader_screen.dart';

void main() {
  test('Google Translate URL preserves selected Unicode text', () {
    final uri = buildGoogleTranslateUriForTest(
      '  \u7d66\u4e0e \u652f\u6255  ',
      'ja',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'translate.google.com');
    expect(uri.path, '/m');
    expect(uri.queryParameters['sl'], 'auto');
    expect(uri.queryParameters['tl'], 'ja');
    expect(uri.queryParameters['q'], '\u7d66\u4e0e \u652f\u6255');
  });

  testWidgets(
    'selected reader text offers a Translate action',
    (tester) async {
      String? translatedText;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildTranslatableSelectionAreaForTest(
              onTranslate: (text) async => translatedText = text,
              child: const Text('Translate this word'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Translate this word'),
          matching: find.byType(RichText),
        ),
      );
      final gesture = await tester.startGesture(
        paragraph.localToGlobal(
          paragraph.getOffsetForCaret(
                const TextPosition(offset: 3),
                const Rect.fromLTWH(0, 0, 2, 20),
              ) +
              Offset(0, paragraph.size.height / 2),
        ),
      );
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 500));
      expect(paragraph.selections, isNotEmpty);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
      await tester.tap(find.text('Translate'));
      await tester.pump();

      expect(translatedText, 'Translate');
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );

  testWidgets('phone back is handled inside the reader', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: buildReaderBackScopeForTest(
          onBack: () => backCount++,
          child: const Scaffold(body: Text('Reader')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(backCount, 1);
    expect(find.text('Reader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress bar tolerates an attached pre-layout controller', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              SingleChildScrollView(
                controller: controller,
                child: const SizedBox(height: 2000),
              ),
              buildReaderProgressBarForTest(controller),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('0%'), findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('paper reader chrome keeps dark text under a dark app theme', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              SingleChildScrollView(
                controller: controller,
                child: const SizedBox(height: 2000),
              ),
              buildReaderToolbarForTest(),
              buildReaderProgressBarForTest(controller),
            ],
          ),
        ),
      ),
    );

    const paperForeground = Color(0xff2c2923);
    final title = tester.widget<Text>(find.text('Book title'));
    final percentage = tester.widget<Text>(find.text('0%'));
    expect(title.style?.color, paperForeground);
    expect(percentage.style?.color, paperForeground);
    expect(tester.takeException(), isNull);
  });
}
