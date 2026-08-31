import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold/ui/reader_screen.dart';

void main() {
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
