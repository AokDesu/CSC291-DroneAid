// P-U-09 Profile + Settings + P-U-09a logout dialog.
// Spec: docs/09-page-flow-design.md §5 P-U-09.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile data.'));
          }
          return _ProfileForm(initial: profile);
        },
      ),
    );
  }
}

/// Pure diff helper — produces the sparse patch the `updateProfile` callable
/// expects. Only fields whose value actually changed appear in the result.
@visibleForTesting
Map<String, dynamic> buildProfilePatch({
  required UserProfile initial,
  required String name,
  required String phone,
  required double? lat,
  required double? lng,
  required String label,
  required String theme,
  required bool notificationsEnabled,
}) {
  final patch = <String, dynamic>{};

  if (name.trim() != (initial.name ?? '')) {
    patch['name'] = name.trim();
  }
  if (phone.trim() != (initial.phone ?? '')) {
    patch['phone'] = phone.trim();
  }

  if (lat != null && lng != null) {
    final addr = initial.deliveryAddress;
    final origLat = (addr?['lat'] as num?)?.toDouble();
    final origLng = (addr?['lng'] as num?)?.toDouble();
    final origLabel = (addr?['label'] as String?) ?? '';
    final trimmedLabel = label.trim();
    final changed = addr == null
        || origLat != lat
        || origLng != lng
        || origLabel != trimmedLabel;
    if (changed) {
      patch['deliveryAddress'] = {
        'lat': lat,
        'lng': lng,
        if (trimmedLabel.isNotEmpty) 'label': trimmedLabel,
      };
    }
  }

  final prefsChanged =
      theme != initial.theme || notificationsEnabled != initial.notificationsEnabled;
  if (prefsChanged) {
    patch['prefs'] = {
      'theme': theme,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  return patch;
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _label;
  late String _theme;
  late bool _notificationsEnabled;
  bool _saving = false;
  String? _serverError;
  String? _serverSuccess;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p.name ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    final addr = p.deliveryAddress;
    _lat = TextEditingController(text: (addr?['lat'] as num?)?.toString() ?? '');
    _lng = TextEditingController(text: (addr?['lng'] as num?)?.toString() ?? '');
    _label = TextEditingController(text: (addr?['label'] as String?) ?? '');
    _theme = p.theme;
    _notificationsEnabled = p.notificationsEnabled;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _lat.dispose();
    _lng.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _serverError = null;
      _serverSuccess = null;
    });

    final patch = buildProfilePatch(
      initial: widget.initial,
      name: _name.text,
      phone: _phone.text,
      lat: double.tryParse(_lat.text.trim()),
      lng: double.tryParse(_lng.text.trim()),
      label: _label.text,
      theme: _theme,
      notificationsEnabled: _notificationsEnabled,
    );

    if (patch.isEmpty) {
      setState(() => _serverSuccess = 'Nothing to save.');
      return;
    }

    setState(() => _saving = true);
    try {
      final fns =
          FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      await fns.httpsCallable('updateProfile').call<Map<String, dynamic>>(patch);
      ref.invalidate(userProfileProvider);
      if (mounted) setState(() => _serverSuccess = 'Saved.');
    } catch (e) {
      if (mounted) setState(() => _serverError = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authRepositoryProvider).signOut();
    // Router redirect carries us back to /login.
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(s)) return '10–15 digits';
    return null;
  }

  String? _validateCoord(String? v, {required bool isLat}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null) return 'Must be a number';
    if (isLat && (n < -90 || n > 90)) return '-90..90';
    if (!isLat && (n < -180 || n > 180)) return '-180..180';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: 24),
          Text('Delivery address', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pin picker coming with #9 — for now, enter coordinates manually.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _validateCoord(v, isLat: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _validateCoord(v, isLat: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label (e.g. "Home")',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Preferences', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _theme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (v) => setState(() => _theme = v ?? 'system'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _notificationsEnabled,
            title: const Text('Notifications'),
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_serverError != null) ...[
            const SizedBox(height: 12),
            Text(
              _serverError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (_serverSuccess != null) ...[
            const SizedBox(height: 12),
            Text(
              _serverSuccess!,
              style: TextStyle(color: Colors.green.shade700),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving ? null : _confirmLogout,
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
