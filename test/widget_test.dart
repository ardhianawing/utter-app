import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utter_app/main.dart';
import 'package:utter_app/features/cashier/presentation/pages/staff_login_page.dart';

void main() {
  testWidgets('Staff Login Page loads test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap with ProviderScope because the app uses Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StaffLoginPage(),
        ),
      ),
    );

    // Verify that the login page elements are present
    expect(find.text('Staff Login'), findsOneWidget);
    expect(find.text('Utter F&B POS System'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // Phone and PIN
    expect(find.text('Login'), findsOneWidget);
    
    // Verify demo credentials are shown
    expect(find.textContaining('Admin: 081234567890'), findsOneWidget);
  });
}
