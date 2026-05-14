import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ci_example/main.dart';

void main() {
  testWidgets('HomePage renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('CI/CD Works! 🚀'), findsOneWidget);
    expect(find.text('Built with GitHub Actions'), findsOneWidget);
    expect(find.byIcon(Icons.build), findsOneWidget);
  });
}
