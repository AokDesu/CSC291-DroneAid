// Full-screen lock gate. Rendered by main.dart's MaterialApp.router builder
// when the session is authenticated AND app-lock status == locked. Not a route
// (no Navigator entry), so the Android back button can't pop past it — PopScope
// is belt-and-suspenders.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/applock/app_lock_providers.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/tokens.dart';
import '../../core/widgets/brand_mark.dart';
import 'pin_keypad.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entry = '';
  String? _error;
  bool _busy = false;
  Timer? _cooldownTimer;
  Duration? _cooldownLeft;

  @override
  void initState() {
    super.initState();
    // Auto-offer the fingerprint sheet once when the screen first appears.
    // initState runs once per State, so this never re-fires on rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(appLockControllerProvider);
      if (state.canUseBiometric) _tryBiometric();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _lockedOut => _cooldownLeft != null;

  Future<void> _onKey(String digit) async {
    if (_busy || _lockedOut || _entry.length >= kPinLength) return;
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length == kPinLength) await _submit();
  }

  void _onBackspace() {
    if (_busy || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref.read(appLockControllerProvider.notifier).verifyPin(_entry);
    if (!mounted) return;
    // On success the controller flips status→unlocked and the gate swaps this
    // screen out for the app content — nothing to navigate here.
    if (result.ok) {
      setState(() => _busy = false);
      return;
    }
    if (result.lockedOut) {
      _startCooldown(result.retryAfter ?? const Duration(seconds: 30));
      setState(() {
        _busy = false;
        _entry = '';
      });
      return;
    }
    setState(() {
      _busy = false;
      _entry = '';
      _error = result.remainingAttempts > 0
          ? 'Wrong PIN. ${result.remainingAttempts} attempt(s) left.'
          : 'Wrong PIN.';
    });
  }

  Future<void> _tryBiometric() async {
    if (_busy || _lockedOut) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .authenticateBiometric('Unlock DroneAid');
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = null; // silent — user falls back to the keypad
    });
  }

  void _startCooldown(Duration initial) {
    _cooldownTimer?.cancel();
    _cooldownLeft = initial;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_cooldownLeft ?? Duration.zero) - const Duration(seconds: 1);
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (left <= Duration.zero) {
          _cooldownLeft = null;
          _error = null;
          t.cancel();
        } else {
          _cooldownLeft = left;
        }
      });
    });
  }

  Future<void> _forgotPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset PIN?'),
        content: const Text(
          'You will be signed out and your PIN removed from this device. '
          'Log back in to set a new one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm != true) return;
    // Clear the PIN for this uid FIRST (so it's gone), then sign out — the
    // auth-state listener disables the lock and the router shows /login.
    await ref.read(appLockControllerProvider.notifier).removePin();
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(userProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(appLockControllerProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    const BrandMark(size: 26),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Enter your PIN', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 24,
                      child: _lockedOut
                          ? Text(
                              'Too many tries. Wait ${_cooldownLeft!.inSeconds}s.',
                              style: TextStyle(color: theme.colorScheme.error),
                            )
                          : (_error != null
                              ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
                              : const SizedBox.shrink()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PinKeypad(
                      value: _entry,
                      enabled: !_busy && !_lockedOut,
                      onKey: _onKey,
                      onBackspace: _onBackspace,
                      leading: state.canUseBiometric
                          ? IconButton(
                              tooltip: 'Use fingerprint',
                              onPressed: _busy || _lockedOut ? null : _tryBiometric,
                              icon: Icon(Icons.fingerprint, color: theme.colorScheme.primary),
                              iconSize: 32,
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: _busy ? null : _forgotPin,
                      child: const Text('Forgot PIN? Sign out'),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
