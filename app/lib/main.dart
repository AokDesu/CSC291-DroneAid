// DroneAid — Flutter app entry point.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/widgets/auth_splash.dart';
import 'features/user/notifications/fcm_register.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // runZonedGuarded wraps Dart-side async errors so Crashlytics can record
  // anything Flutter's own error handlers don't see (top-level async, isolate
  // boundaries, microtask queue).
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Crashlytics: collect in release only by default. In debug we want
    // crashes to surface in the console + IDE, not get swallowed by upload.
    // Override with --dart-define=FORCE_CRASHLYTICS=true if you need to test
    // the upload path locally.
    const forceCrashlytics = bool.fromEnvironment('FORCE_CRASHLYTICS', defaultValue: false);
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode || forceCrashlytics);

    // Send Flutter framework errors (build/layout/paint) to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Send uncaught platform-dispatcher errors (async gaps, native bridge).
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    if (kDebugMode) {
      await _useLocalEmulators();
    }
    runApp(const ProviderScope(child: DroneAidApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
    ref.watch(fcmRegistrationProvider);
    // Tag every Crashlytics report with the signed-in uid so reports
    // are filterable per user in the Console.
    ref.listen(authStateProvider, (_, next) {
      final uid = next.valueOrNull?.uid ?? '';
      FirebaseCrashlytics.instance.setUserIdentifier(uid);
    });
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
