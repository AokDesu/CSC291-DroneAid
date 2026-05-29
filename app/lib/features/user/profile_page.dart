// P-U-09 Profile + Settings + P-U-09a logout dialog.
// Spec: docs/09-page-flow-design.md §5 P-U-09.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/firebase_errors.dart';
import '../../core/widgets/drone_map.dart';
import '../../core/widgets/loading_placeholder.dart';
import 'request/cart.dart' show DeliveryPin;
import 'request/pin_picker.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userProfileProvider);
    return Scaffold(
      body: async.when(
        loading: () => const LoadingPlaceholder(label: 'Loading your profile…'),
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
  double? hubLat,
  double? hubLng,
  String hubLabel = '',
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

  if (hubLat != null && hubLng != null) {
    final hub = initial.hubLocation;
    final origLat = (hub?['lat'] as num?)?.toDouble();
    final origLng = (hub?['lng'] as num?)?.toDouble();
    final origLabel = (hub?['label'] as String?) ?? '';
    final trimmedLabel = hubLabel.trim();
    final changed = hub == null
        || origLat != hubLat
        || origLng != hubLng
        || origLabel != trimmedLabel;
    if (changed) {
      patch['hubLocation'] = {
        'lat': hubLat,
        'lng': hubLng,
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
  late String _theme;
  late bool _notificationsEnabled;
  DeliveryPin? _deliveryPin;
  DeliveryPin? _hubPin;
  bool _saving = false;
  String? _serverError;
  String? _serverSuccess;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p.name ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _deliveryPin = _readPin(p.deliveryAddress);
    _hubPin = _readPin(p.hubLocation);
    _theme = p.theme;
    _notificationsEnabled = p.notificationsEnabled;
  }

  static DeliveryPin? _readPin(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return DeliveryPin(lat: lat, lng: lng, label: raw['label'] as String?);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDelivery() async {
    final picked = await showPinPicker(
      context,
      initial: _deliveryPin,
      title: 'Drop a delivery pin',
      labelFieldLabel: 'Label (optional, e.g. "Home")',
    );
    if (picked == null) return;
    setState(() => _deliveryPin = picked);
  }

  Future<void> _pickHub() async {
    final picked = await showPinPicker(
      context,
      initial: _hubPin,
      title: 'Pick your hub location',
      labelFieldLabel: 'Hub label (optional, e.g. "Warehouse A")',
    );
    if (picked == null) return;
    setState(() => _hubPin = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _serverError = null;
      _serverSuccess = null;
    });

    final isAdmin = widget.initial.isAdmin;
    final patch = buildProfilePatch(
      initial: widget.initial,
      name: _name.text,
      phone: isAdmin ? (widget.initial.phone ?? '') : _phone.text,
      lat: isAdmin ? null : _deliveryPin?.lat,
      lng: isAdmin ? null : _deliveryPin?.lng,
      label: isAdmin ? '' : (_deliveryPin?.label ?? ''),
      hubLat: _hubPin?.lat,
      hubLng: _hubPin?.lng,
      hubLabel: _hubPin?.label ?? '',
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
      if (mounted) setState(() => _serverError = 'Could not save: ${describeFunctionsError(e)}');
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
    ref.invalidate(userProfileProvider);
    // Router redirect carries us back to /login.
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(s)) return '10–15 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = widget.initial.isAdmin;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ProfileHeader(profile: widget.initial),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Account',
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isAdmin) ...[
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
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (isAdmin)
            _PinCard(
              title: 'Hub',
              subtitle:
                  'Your distribution hub. Drop a pin where this account dispatches from.',
              pin: _hubPin,
              onPick: _pickHub,
              emptyLabel: 'No hub set yet',
              setLabel: 'Set hub',
              changeLabel: 'Change hub',
            )
          else
            _PinCard(
              title: 'Delivery address',
              subtitle:
                  'Where the drone drops your packages. Tap to drop a pin or use your current location.',
              pin: _deliveryPin,
              onPick: _pickDelivery,
              emptyLabel: 'No delivery pin yet',
              setLabel: 'Set pin',
              changeLabel: 'Change pin',
            ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Preferences',
            children: [
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
              const SizedBox(height: 4),
              SwitchListTile(
                value: _notificationsEnabled,
                title: const Text('Notifications'),
                onChanged: (v) => setState(() => _notificationsEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (profile.name?.trim().isNotEmpty ?? false)
        ? profile.name!.trim()
        : 'Unnamed user';
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(name: name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _RolePill(role: profile.role),
                      if (profile.nationalId != null)
                        Text(
                          'ID ${_maskNationalId(profile.nationalId!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? theme.colorScheme.primary
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isAdmin
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 13-digit Thai national IDs: show first 4 + last 3 digits, mask the rest.
/// "1234567890123" → "1234-XXXXXX-123".
String _maskNationalId(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return raw;
  final head = digits.substring(0, 4);
  final tail = digits.substring(digits.length - 3);
  final hiddenCount = digits.length - 7;
  return '$head-${'X' * hiddenCount}-$tail';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.onPick,
    required this.emptyLabel,
    required this.setLabel,
    required this.changeLabel,
  });

  final String title;
  final String subtitle;
  final DeliveryPin? pin;
  final VoidCallback onPick;
  final String emptyLabel;
  final String setLabel;
  final String changeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (pin == null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  emptyLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: IgnorePointer(
                    child: DroneMap(
                      center: LatLng(pin!.lat, pin!.lng),
                      zoom: 14,
                      markers: [
                        DroneMapMarker(
                          id: 'pin',
                          position: LatLng(pin!.lat, pin!.lng),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${pin!.lat.toStringAsFixed(5)}, ${pin!.lng.toStringAsFixed(5)}'
                '${pin!.label != null && pin!.label!.isNotEmpty ? '  ·  ${pin!.label}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: Key('set-pin-${title.toLowerCase().replaceAll(' ', '-')}'),
              onPressed: onPick,
              icon: const Icon(Icons.place_outlined),
              label: Text(pin == null ? setLabel : changeLabel),
            ),
          ],
        ),
      ),
    );
  }
}
