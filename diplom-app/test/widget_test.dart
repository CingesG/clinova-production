import 'package:diplom_app/src/app/app.dart';
import 'package:diplom_app/src/core/storage/token_storage.dart';
import 'package:diplom_app/src/features/settings/presentation/language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App mounts and reaches guest home (MN tagline)', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = InMemoryTokenStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(tokenStorage),
        ],
        child: const ClinovaApp(),
      ),
    );

    await tester.pump();
    // Bootstrap (splash) then redirect to /welcome for guests.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('Таны эрүүл мэнд').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Таны эрүүл мэнд'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });
}
