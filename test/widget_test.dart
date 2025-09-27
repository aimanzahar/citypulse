// Basic widget test to ensure the app builds
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citypulse/app.dart';

void main() {
  testWidgets('App builds MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const CityPulseApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
