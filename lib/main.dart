import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/env_config.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught error listeners
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('⚠️ [FlutterError] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('⚠️ [PlatformDispatcher] $error\n$stack');
    return true;
  };

  // Pre-load SharedPreferences for instant theme mode retrieval
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Supabase client if configured
  await initSupabase();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const WaanOfiiHubApp(),
    ),
  );
}

/// Root Application Widget for WAAN-OFIIHUB
class WaanOfiiHubApp extends ConsumerWidget {
  const WaanOfiiHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
