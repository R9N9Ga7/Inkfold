import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkfold/app.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

void main() {
  testWidgets('PDF selection toolbar has material_ui localizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: inkfoldLocalizationsDelegates,
        home: Scaffold(
          body: material_ui.AdaptiveTextSelectionToolbar.buttonItems(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(20, 20),
            ),
            buttonItems: <material_ui.ContextMenuButtonItem>[
              material_ui.ContextMenuButtonItem(
                onPressed: () {},
                type: material_ui.ContextMenuButtonType.copy,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Copy',
      ),
      findsOneWidget,
    );
  });
}
