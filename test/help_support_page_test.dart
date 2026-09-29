import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/help_support_page.dart';

void main() {
  testWidgets('HelpSupportPage shows support information', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportPage()));

    expect(find.text('Help & Support'), findsWidgets);
    expect(find.text('sabarishasabarisha415@gmail.com'), findsWidgets);
    expect(find.text('1.0.0'), findsOneWidget);
  });
}
