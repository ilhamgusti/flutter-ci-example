import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_ci_example/screens/name_entry_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NameEntryScreen renders and joins with the entered name',
      (WidgetTester tester) async {
    String? joinedName;
    await tester.pumpWidget(
      MaterialApp(home: NameEntryScreen(onJoin: (name) => joinedName = name)),
    );

    expect(find.text('Music Sync'), findsOneWidget);
    expect(find.text('Gabung'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ilham');
    await tester.tap(find.text('Gabung'));
    await tester.pumpAndSettle();

    expect(joinedName, 'Ilham');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NameEntryScreen.storageKey), 'Ilham');
  });
}
