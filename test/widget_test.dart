import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waan_ofii_hub/core/theme/app_theme.dart';
import 'package:waan_ofii_hub/main.dart';

void main() {
  testWidgets(
    'WaanOfiiHubApp mounts and displays setup screen when unconfigured',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
          child: const WaanOfiiHubApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verifies unconfigured fallback when compile-time env variables are absent
      expect(find.text('Setup Required'), findsOneWidget);
      expect(find.text('Supabase Configuration Needed'), findsOneWidget);
    },
  );
}
