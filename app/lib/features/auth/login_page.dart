// P-U-01 Log in.
// Layout + behaviour mirror docs/10-prototype-design.md §P-U-01.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/dev_mode.dart';
import '../../utils/thai_id_validator.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  String? _validateNationalId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length != 13) return 'Must be 13 digits';
    if (!ThaiIdValidator.isValid(s)) return 'Invalid national ID';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 8) return 'At least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).signInWithNationalId(
            nationalId: _idCtrl.text.trim(),
            password: _pwCtrl.text,
          );
      // Router redirect carries us to /user/home or /admin/requests.
    } on FirebaseAuthException catch (_) {
      setState(() => _serverError = 'Wrong national ID or password.');
    } catch (_) {
      setState(() => _serverError = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Icon(
                  Icons.flight_takeoff,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'DroneAid',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Relief delivery, on demand.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: const InputDecoration(
                    labelText: '13-digit national ID',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateNationalId,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _serverError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log in'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _submitting ? null : () => context.push('/register'),
                  child: const Text('New here?  Create an account →'),
                ),
                const SizedBox(height: 32),
                if (kShowDevSurfaces) ...[
                  const _DemoAccountsCard(),
                  const SizedBox(height: 12),
                  const _CrashTestCard(),
                ],
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoAccountsCard extends StatelessWidget {
  const _DemoAccountsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo accounts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Mali (user)   1100000000105 · Demo#101',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            Text(
              'Admin         1100000000008 · Admin#001',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crashlytics test surface.
///
/// Crashlytics collection is disabled in debug unless you run with:
///   flutter run --dart-define=FORCE_CRASHLYTICS=true
/// (or use a release build). Without that flag, the buttons below
/// still fire but no upload happens — the crash is swallowed locally.
///
/// Verification flow:
///   1. flutter run --dart-define=FORCE_CRASHLYTICS=true
///   2. Tap "Force fatal crash" — app dies.
///   3. Restart the app. Crashlytics uploads the previous crash on launch.
///   4. Firebase Console → Crashlytics → see the event within a few minutes.
///
/// Non-fatal uploads immediately (no app restart needed) and shows under
/// the "non-fatals" tab.
class _CrashTestCard extends StatelessWidget {
  const _CrashTestCard();

  void _forceFatalCrash() {
    // Crashes the process. Use after running with FORCE_CRASHLYTICS=true.
    FirebaseCrashlytics.instance.crash();
  }

  void _recordNonFatal() {
    FirebaseCrashlytics.instance.recordError(
      Exception('Test non-fatal error from DroneAid login screen'),
      StackTrace.current,
      reason: 'manual crash-test card',
      fatal: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crashlytics test',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Run with --dart-define=FORCE_CRASHLYTICS=true to enable '
              'uploads in debug. Fatal crash uploads on next app launch.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('crashlytics-non-fatal'),
                    onPressed: () {
                      _recordNonFatal();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Non-fatal recorded. Check Crashlytics.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: const Text('Non-fatal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('crashlytics-force-crash'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _forceFatalCrash,
                    icon: const Icon(Icons.dangerous_outlined),
                    label: const Text('Force crash'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
