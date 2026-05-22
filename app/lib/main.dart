// DroneAid — Flutter app entry point.

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/widgets/auth_splash.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    await _useLocalEmulators();
  }
  runApp(const ProviderScope(child: DroneAidApp()));
}

Future<void> _useLocalEmulators() async {
  // Android emulator reaches host loopback via 10.0.2.2.
  final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .useFunctionsEmulator(host, 5001);
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
      builder: (context, child) {
        final auth = ref.watch(authStateProvider);
        if (auth.isLoading) return const AuthSplash();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
