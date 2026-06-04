// App-lock state machine + Riverpod wiring.
//
// The controller owns the AppLifecycleListener (re-lock on background→resume
// past a grace window) and reacts to auth changes (per-uid hydration, disable
// on sign-out). The GATE — which screen to show — lives in main.dart's
// MaterialApp.router `builder:`, reusing the existing AuthSplash seam.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'app_lock_store.dart';
import 'biometric_service.dart';
import 'pin_service.dart';

/// Quick app-switches (under this window) don't re-prompt; longer absences do.
const kAppLockGraceWindow = Duration(seconds: 30);

enum AppLockStatus {
  /// Hydrating — gate shows the splash, never content.
  unknown,

  /// No PIN set for this user → app behaves exactly as if the feature is off.
  disabled,

  /// Enabled and awaiting PIN/biometric.
  locked,

  /// Verified for this foreground session.
  unlocked,
}

@immutable
class AppLockState {
  const AppLockState({
    required this.status,
    this.hasPin = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
  });

  static const initial = AppLockState(status: AppLockStatus.unknown);

  final AppLockStatus status;
  final bool hasPin;
  final bool biometricEnabled;
  final bool biometricAvailable;

  /// Show the "Use fingerprint" affordance only when opted-in AND the device
  /// actually has an enrolled biometric.
  bool get canUseBiometric => biometricEnabled && biometricAvailable;

  AppLockState copyWith({
    AppLockStatus? status,
    bool? hasPin,
    bool? biometricEnabled,
    bool? biometricAvailable,
  }) {
    return AppLockState(
      status: status ?? this.status,
      hasPin: hasPin ?? this.hasPin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    required PinService pinService,
    required BiometricService biometric,
    Duration graceWindow = kAppLockGraceWindow,
    DateTime Function()? clock,
    bool bindLifecycle = true,
  })  : _pin = pinService,
        _biometric = biometric,
        _grace = graceWindow,
        _now = clock ?? DateTime.now,
        super(AppLockState.initial) {
    if (bindLifecycle) {
      _lifecycle = AppLifecycleListener(
        onPause: handlePaused,
        onResume: handleResumed,
      );
    }
  }

  final PinService _pin;
  final BiometricService _biometric;
  final Duration _grace;
  final DateTime Function() _now;

  AppLifecycleListener? _lifecycle;
  String? _uid;
  DateTime? _backgroundedAt;

  // ---- auth wiring ---------------------------------------------------------

  /// Maps an `authStateProvider` emission to a lock decision.
  ///
  /// CRITICAL: while auth is still loading we do NOTHING — status stays
  /// `unknown` so the gate shows the splash, never content. Collapsing a
  /// loading state to `disabled` here would, for a PIN user, let the home page
  /// paint during the (async, plugin-backed) hydrate window before the lock
  /// appears — a content flash on the security path.
  Future<void> onAuthState({required bool isLoading, required String? uid}) async {
    if (isLoading) return;
    await onUserChanged(uid);
  }

  /// Cold start / login / user-switch all flow through here once auth has
  /// resolved. Sign-out (`uid == null`) disables without wiping the secret.
  Future<void> onUserChanged(String? uid) async {
    if (uid == null) {
      _uid = null;
      _backgroundedAt = null;
      state = const AppLockState(status: AppLockStatus.disabled);
      return;
    }
    if (uid == _uid && state.status != AppLockStatus.unknown) return;
    _uid = uid;
    await _hydrate();
  }

  /// Reads enrolment for the current uid and LOCKS if a PIN exists (cold-start
  /// / re-entry semantics — the grace window only applies on resume).
  Future<void> _hydrate() async {
    final uid = _uid;
    if (uid == null) {
      state = const AppLockState(status: AppLockStatus.disabled);
      return;
    }
    final hasPin = await _pin.hasPin(uid);
    final available = await _biometric.isAvailable();
    final biometricEnabled = hasPin && await _pin.isBiometricEnabled(uid);
    state = AppLockState(
      status: hasPin ? AppLockStatus.locked : AppLockStatus.disabled,
      hasPin: hasPin,
      biometricEnabled: biometricEnabled,
      biometricAvailable: available,
    );
  }

  /// Recompute flags after a settings change WITHOUT touching lock status.
  Future<void> _refreshFlags() async {
    final uid = _uid;
    if (uid == null) return;
    final hasPin = await _pin.hasPin(uid);
    final available = await _biometric.isAvailable();
    final biometricEnabled = hasPin && await _pin.isBiometricEnabled(uid);
    state = state.copyWith(
      hasPin: hasPin,
      biometricEnabled: biometricEnabled,
      biometricAvailable: available,
    );
  }

  // ---- unlock paths --------------------------------------------------------

  Future<PinVerifyResult> verifyPin(String pin) async {
    final uid = _uid;
    if (uid == null) return const PinVerifyResult.wrong(0);
    final result = await _pin.verifyPin(uid, pin);
    if (result.ok) state = state.copyWith(status: AppLockStatus.unlocked);
    return result;
  }

  Future<bool> authenticateBiometric(String reason) async {
    if (!state.canUseBiometric) return false;
    final ok = await _biometric.authenticate(reason);
    if (ok) state = state.copyWith(status: AppLockStatus.unlocked);
    return ok;
  }

  void lockNow() {
    if (state.hasPin) state = state.copyWith(status: AppLockStatus.locked);
  }

  // ---- settings mutations (called from the profile Security section) -------

  Future<void> setPin(String pin) async {
    final uid = _uid;
    if (uid == null) return;
    await _pin.setPin(uid, pin);
    // User set the PIN while inside the app → leave them unlocked.
    state = state.copyWith(status: AppLockStatus.unlocked, hasPin: true);
    await _refreshFlags();
  }

  Future<void> removePin() async {
    final uid = _uid;
    if (uid == null) return;
    await _pin.clearPin(uid);
    state = AppLockState(
      status: AppLockStatus.disabled,
      hasPin: false,
      biometricAvailable: state.biometricAvailable,
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final uid = _uid;
    if (uid == null) return;
    await _pin.setBiometricEnabled(uid, enabled);
    await _refreshFlags();
  }

  // ---- lifecycle (also the test seam) --------------------------------------

  @visibleForTesting
  void handlePaused() {
    if (state.status == AppLockStatus.unlocked) _backgroundedAt = _now();
  }

  @visibleForTesting
  void handleResumed() {
    if (state.status != AppLockStatus.unlocked || !state.hasPin) return;
    final bg = _backgroundedAt;
    _backgroundedAt = null;
    if (bg == null || _now().difference(bg) >= _grace) {
      state = state.copyWith(status: AppLockStatus.locked);
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}

// ---- providers -------------------------------------------------------------

final appLockStoreProvider = Provider<AppLockStore>((ref) => SecureAppLockStore());

final pinServiceProvider =
    Provider<PinService>((ref) => PinService(ref.watch(appLockStoreProvider)));

final biometricServiceProvider =
    Provider<BiometricService>((ref) => LocalAuthBiometricService());

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  final controller = AppLockController(
    pinService: ref.watch(pinServiceProvider),
    biometric: ref.watch(biometricServiceProvider),
  );
  // Cold start, login, and user-switch all arrive here; fireImmediately picks
  // up the session that already exists when the provider is first read.
  ref.listen(
    authStateProvider,
    (_, next) => controller.onAuthState(
      isLoading: next.isLoading,
      uid: next.valueOrNull?.uid,
    ),
    fireImmediately: true,
  );
  return controller;
});
