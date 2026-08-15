import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SpotifySyncApp());
    expect(find.text('Music Sync'), findsOneWidget);
    expect(find.text('Create Sync Room'), findsOneWidget);
  });
}
