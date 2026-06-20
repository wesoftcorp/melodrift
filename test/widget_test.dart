import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melodrift/app.dart';
import 'package:melodrift/core/theme/theme_provider.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app is initialized and has a root App widget
    expect(find.byType(App), findsOneWidget);
  });
}
