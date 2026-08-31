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
}
