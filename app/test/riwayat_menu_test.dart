import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/riwayat_menu.dart';

void main() {
  Future<void> open(WidgetTester t, ReaderSettings settings) async {
    t.view.physicalSize = const Size(600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiwayatMenu(
            settings: settings,
            variants: VariantRepository({'warsh', 'qalun'}),
          ),
        ),
      ),
    );
    await t.tap(find.byType(RiwayatMenu));
    await t.pumpAndSettle();
  }

  Finder hafsRadio() => find.byWidgetPredicate(
    (w) => w is RadioMenuButton<String> && w.value == 'hafs',
  );
  Finder checkbox(String name) =>
      find.widgetWithText(CheckboxMenuButton, 'رواية $name');

  testWidgets('Hafs appears as a base choice only while selected below', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = 'warsh';
    await open(t, settings);
    expect(hafsRadio(), findsNothing);
    t.widget<CheckboxMenuButton>(checkbox('حفص')).onChanged!(true);
    await t.pumpAndSettle();
    expect(hafsRadio(), findsOneWidget);
    expect(settings.displayed, 'warsh');
    expect(settings.compareHafs, isTrue);
    t.widget<RadioMenuButton<String>>(hafsRadio()).onChanged!('hafs');
    await t.pumpAndSettle();
    expect(settings.displayed, isNull);
    t.widget<CheckboxMenuButton>(checkbox('حفص')).onChanged!(false);
    await t.pumpAndSettle();
    expect(hafsRadio(), findsNothing);
    expect(settings.displayed, 'warsh');
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'selecting Warsh without Hafs chooses Warsh as the displayed reading',
    (t) async {
      final settings = ReaderSettings.memory();
      await open(t, settings);
      t.widget<CheckboxMenuButton>(checkbox('ورش')).onChanged!(true);
      await t.pumpAndSettle();
      expect(settings.displayed, 'warsh');
      expect(hafsRadio(), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Hafs can be selected alone and adding another reading retains it',
    (t) async {
      final settings = ReaderSettings.memory();
      await open(t, settings);
      t.widget<CheckboxMenuButton>(checkbox('حفص')).onChanged!(true);
      await t.pumpAndSettle();
      expect(hafsRadio(), findsOneWidget);
      expect(settings.displayed, isNull);
      t.widget<CheckboxMenuButton>(checkbox('ورش')).onChanged!(true);
      await t.pumpAndSettle();
      expect(settings.displayed, isNull);
      expect(settings.compareHafs, isTrue);
      expect(t.takeException(), isNull);
    },
  );
}
