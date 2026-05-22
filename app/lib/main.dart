// DroneAid — Flutter app entry point.
//
// Sets up Firebase, ProviderScope, theme, and go_router.
//
// On first run Belle's task is to flesh out the auth gate + login + register.
// Other owners drop their page widgets under `lib/features/<area>/`.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase.initializeApp() is wired here once flutterfire_cli generates
  // firebase_options.dart on Day 1. Until then the app still boots and
  // shows the placeholder pages.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allow the app to run without Firebase during early UI work.
  }
  runApp(const ProviderScope(child: DroneAidApp()));
}

class DroneAidApp extends ConsumerWidget {
  const DroneAidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DroneAid',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
