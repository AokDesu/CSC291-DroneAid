// Add + Edit drone dialogs. Both reuse `showPinPicker` for base-location
// selection. Add: posts to `createDrone` (auto-id). Edit: posts to
// `editDrone` (sparse patch).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../user/request/cart.dart' show DeliveryPin;
import '../../user/request/pin_picker.dart';
import 'drone.dart';

const _functionsRegion = 'asia-southeast1';

/// Push the Add dialog. Returns true on success.
Future<bool> showAddDroneDialog(BuildContext context) async {
  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _AddDroneDialog(),
  );
  if (payload == null || !context.mounted) return false;
  return _callDrone(
    context,
    name: 'createDrone',
    payload: payload,
    success: 'Drone added.',
  );
}

/// Push the Edit dialog. Returns true on success.
Future<bool> showEditDroneDialog(BuildContext context, Drone drone) async {
  final patch = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _EditDroneDialog(drone: drone),
  );
  if (patch == null || !context.mounted) return false;
  // The dialog always returns at least `droneId`; check for any other key.
  if (patch.length <= 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to update.')),
    );
    return false;
  }
  return _callDrone(
    context,
    name: 'editDrone',
    payload: patch,
    success: 'Saved ${drone.name}.',
  );
}

class _AddDroneDialog extends StatefulWidget {
  const _AddDroneDialog();

  @override
  State<_AddDroneDialog> createState() => _AddDroneDialogState();
}

class _AddDroneDialogState extends State<_AddDroneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController(text: '6.0');
  DeliveryPin? _basePin;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBase() async {
    final picked = await showPinPicker(
      context,
      initial: _basePin,
      title: "Pick the drone's base location",
      labelFieldLabel: 'Base label (unused, leave blank)',
    );
    if (picked == null) return;
    setState(() => _basePin = picked);
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_basePin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a base location first.')),
      );
      return;
    }
    Navigator.of(context).pop({
      'name': _nameCtrl.text.trim(),
      'maxPayloadKg': double.parse(_payloadCtrl.text.trim()),
      'baseLocation': {'lat': _basePin!.lat, 'lng': _basePin!.lng},
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add drone'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'A `drn-NNN` id will be assigned automatically.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'e.g. Drone Echo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (s.length > 40) return 'Max 40 chars';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _payloadCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max payload (kg, 0 < w ≤ 10)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null) return 'Number required';
                  if (n <= 0 || n > 10) return '0 < w ≤ 10';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('add-drone-pick-base'),
                onPressed: _pickBase,
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  _basePin == null
                      ? 'Pick base location'
                      : 'Base: ${_basePin!.lat.toStringAsFixed(4)}, ${_basePin!.lng.toStringAsFixed(4)}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditDroneDialog extends StatefulWidget {
  const _EditDroneDialog({required this.drone});
  final Drone drone;

  @override
  State<_EditDroneDialog> createState() => _EditDroneDialogState();
}

class _EditDroneDialogState extends State<_EditDroneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _payloadCtrl;
  late DeliveryPin _basePin;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.drone.name);
    _payloadCtrl =
        TextEditingController(text: widget.drone.maxPayloadKg.toString());
    _basePin = DeliveryPin(
      lat: widget.drone.baseLat,
      lng: widget.drone.baseLng,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBase() async {
    final picked = await showPinPicker(
      context,
      initial: _basePin,
      title: "Pick the drone's base location",
      labelFieldLabel: 'Base label (unused, leave blank)',
    );
    if (picked == null) return;
    setState(() => _basePin = picked);
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final patch = <String, dynamic>{'droneId': widget.drone.id};
    final trimmedName = _nameCtrl.text.trim();
    final parsedPayload = double.tryParse(_payloadCtrl.text.trim());
    if (trimmedName != widget.drone.name) {
      patch['name'] = trimmedName;
    }
    if (parsedPayload != null && parsedPayload != widget.drone.maxPayloadKg) {
      patch['maxPayloadKg'] = parsedPayload;
    }
    if (_basePin.lat != widget.drone.baseLat ||
        _basePin.lng != widget.drone.baseLng) {
      patch['baseLocation'] = {'lat': _basePin.lat, 'lng': _basePin.lng};
    }
    Navigator.of(context).pop(patch);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.drone.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '#${widget.drone.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (s.length > 40) return 'Max 40 chars';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _payloadCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max payload (kg, 0 < w ≤ 10)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null) return 'Number required';
                  if (n <= 0 || n > 10) return '0 < w ≤ 10';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('edit-drone-pick-base'),
                onPressed: _pickBase,
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  'Base: ${_basePin.lat.toStringAsFixed(4)}, ${_basePin.lng.toStringAsFixed(4)}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> _callDrone(
  BuildContext context, {
  required String name,
  required Map<String, dynamic> payload,
  required String success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
    await fns.httpsCallable(name).call<Map<String, dynamic>>(payload);
    if (!context.mounted) return true;
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return false;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed: ${e.message ?? e.code}')),
    );
    return false;
  } catch (e) {
    if (!context.mounted) return false;
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    return false;
  }
}
