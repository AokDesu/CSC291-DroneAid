// P-U-02 Create an account.
// Layout + behaviour mirror docs/10-prototype-design.md §P-U-02.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../utils/thai_id_validator.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _terms = false;
  bool _submitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _idCtrl, _phoneCtrl, _pwCtrl, _pw2Ctrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _idCtrl, _phoneCtrl, _pwCtrl, _pw2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit {
    if (!_terms) return false;
    final id = _idCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    return _nameCtrl.text.trim().isNotEmpty &&
        id.length == 13 &&
        ThaiIdValidator.isValid(id) &&
        RegExp(r'^\+?\d{10,15}$').hasMatch(phone) &&
        _pwCtrl.text.length >= 8 &&
        _pwCtrl.text == _pw2Ctrl.text;
  }

  String? _vName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _vId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length != 13) return 'Must be 13 digits';
    if (!ThaiIdValidator.isValid(s)) return 'Invalid national ID';
    return null;
  }

  String? _vPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(s)) return 'Use 10-15 digits, optional +';
    return null;
  }

  String? _vPw(String? v) {
    if ((v ?? '').length < 8) return 'At least 8 characters';
    return null;
  }

  String? _vPw2(String? v) {
    if (v != _pwCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate() || !_terms) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).registerWithNationalId(
            nationalId: _idCtrl.text.trim(),
            password: _pwCtrl.text,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      // Router redirect carries us to /user/home once userProfileProvider
      // resolves the freshly-provisioned doc.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _serverError = switch (e.code) {
          'email-already-in-use' =>
            'A user with this national ID already exists.',
          'weak-password' => 'Password is too weak.',
          _ => 'Could not create the account. Try again.',
        };
      });
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Create an account'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: _vName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
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
                  validator: _vId,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (e.g. +66 81 ...)',
                    border: OutlineInputBorder(),
                  ),
                  validator: _vPhone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: _vPw,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pw2Ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    border: OutlineInputBorder(),
                  ),
                  validator: _vPw2,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                  title: const Text('I agree to the program terms.'),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _serverError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_canSubmit && !_submitting) ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
