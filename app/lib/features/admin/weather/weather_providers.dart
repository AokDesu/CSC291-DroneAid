// Riverpod provider for the singleton `weather/current` Firestore doc.
//
// autoDispose + watch authStateProvider so the Firestore listener tears
// down on sign-out and re-attaches with fresh credentials on sign-in.
// Without this, an unauthenticated listener attached during cold start
// caches a permission-denied AsyncError that surfaces on
// admin/weather_page.dart even after the admin signs in successfully.
//
// Pre-auth window short-circuits to a synthetic "clear" doc so the
// AppBar WeatherChip never has to render an error state during the
// brief unauthenticated splash.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import 'weather.dart';

final weatherStreamProvider = StreamProvider.autoDispose<Weather>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const Weather(state: 'clear'));
  }
  final ref0 = FirebaseFirestore.instance.doc('weather/current');
  return ref0.snapshots().map((snap) {
    if (!snap.exists) {
      return const Weather(state: 'clear');
    }
    return Weather.fromSnap(snap);
  });
});
