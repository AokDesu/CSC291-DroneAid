// P-U-03 Home / Request — browse catalog, build a cart, drop a pin, submit.
// Spec: docs/09-page-flow-design.md §5 P-U-03.
// Backend: submitRequest callable in functions/src/callable/submitRequest.ts.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import 'request/cart.dart';
import 'request/catalog.dart';
import 'request/pin_picker.dart';

const _functionsRegion = 'asia-southeast1';

class UserHomePage extends ConsumerWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(activeCatalogProvider);
    final cart = ref.watch(cartProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    // Seed the pin from the user's profile delivery address the first time
    // the catalog page renders with a non-null profile.
    if (cart.pin == null && profile?.deliveryAddress != null) {
      final addr = profile!.deliveryAddress!;
      final lat = (addr['lat'] as num?)?.toDouble();
      final lng = (addr['lng'] as num?)?.toDouble();
      final label = addr['label'] as String?;
      if (lat != null && lng != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(cartProvider.notifier).setPin(
                DeliveryPin(lat: lat, lng: lng, label: label),
              );
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Request supplies')),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load catalog: $e')),
        data: (catalog) {
          if (catalog.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No supplies available right now. Check back soon.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final totalKg = cartTotalWeightKg(cart, catalog);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Text(
                'Pick what you need, drop a pin.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final entry in catalog)
                _CatalogRow(
                  entry: entry,
                  qty: cart.lines[entry.id] ?? 0,
                  onChanged: (q) =>
                      ref.read(cartProvider.notifier).setQty(entry.id, q),
                ),
              const SizedBox(height: 20),
              _CartSection(
                cart: cart,
                catalog: catalog,
                onRemove: (id) =>
                    ref.read(cartProvider.notifier).remove(id),
              ),
              const SizedBox(height: 12),
              _WeightBar(totalKg: totalKg),
              const SizedBox(height: 16),
              _PinSection(pin: cart.pin),
              const SizedBox(height: 24),
              _SubmitSection(
                cart: cart,
                totalKg: totalKg,
                pin: cart.pin,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Catalog row with inline qty stepper.
// ────────────────────────────────────────────────────────────────────────

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.entry,
    required this.qty,
    required this.onChanged,
  });

  final CatalogEntry entry;
  final int qty;
  final ValueChanged<int> onChanged;

  IconData get _iconData {
    switch (entry.icon) {
      case 'food':
        return Icons.restaurant;
      case 'water':
        return Icons.water_drop;
      case 'med':
        return Icons.medical_services;
      case 'baby':
        return Icons.child_friendly;
      case 'blanket':
        return Icons.bed;
      case 'light':
        return Icons.flashlight_on;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = entry.outOfStock;
    final canAdd = !disabled && qty < entry.stock && qty < maxQtyPerLine;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconData)),
        title: Text(
          entry.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: disabled ? theme.disabledColor : null,
          ),
        ),
        subtitle: Text(
          disabled
              ? 'Out of stock'
              : '${entry.weightKg.toStringAsFixed(1)} kg   ${entry.stock} in stock',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('dec-${entry.id}'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: Key('inc-${entry.id}'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: canAdd ? () => onChanged(qty + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Cart summary.
// ────────────────────────────────────────────────────────────────────────

class _CartSection extends StatelessWidget {
  const _CartSection({
    required this.cart,
    required this.catalog,
    required this.onRemove,
  });

  final CartState cart;
  final List<CatalogEntry> catalog;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cart.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Cart is empty.', style: theme.textTheme.bodyMedium),
      );
    }
    final byId = {for (final c in catalog) c.id: c};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cart', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in cart.lines.entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${byId[entry.key]?.name ?? entry.key} ×${entry.value}',
              style: theme.textTheme.bodyLarge,
            ),
            trailing: IconButton(
              key: Key('remove-${entry.key}'),
              icon: const Icon(Icons.close),
              onPressed: () => onRemove(entry.key),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Weight bar (C-11). Pure visual; canSubmit() does the gate.
// ────────────────────────────────────────────────────────────────────────

class _WeightBar extends StatelessWidget {
  const _WeightBar({required this.totalKg});
  final double totalKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = totalKg > maxPayloadKg;
    final pct = (totalKg / maxPayloadKg).clamp(0.0, 1.0);
    final color = over ? theme.colorScheme.error : theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Weight', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              '${totalKg.toStringAsFixed(1)} / ${maxPayloadKg.toStringAsFixed(1)} kg',
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (over) ...[
          const SizedBox(height: 4),
          Text(
            'Total exceeds drone payload.',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Delivery pin section + Edit button (C-13).
// ────────────────────────────────────────────────────────────────────────

class _PinSection extends ConsumerWidget {
  const _PinSection({required this.pin});
  final DeliveryPin? pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = pin == null
        ? 'Not set'
        : '${pin!.lat.toStringAsFixed(5)}, ${pin!.lng.toStringAsFixed(5)}'
            '${pin!.label != null ? '  (${pin!.label})' : ''}';
    return Row(
      children: [
        const Icon(Icons.place_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delivery pin', style: theme.textTheme.bodyMedium),
              Text(label, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        TextButton.icon(
          key: const Key('edit-pin'),
          onPressed: () async {
            final picked = await showPinPicker(context, initial: pin);
            if (picked != null) {
              ref.read(cartProvider.notifier).setPin(picked);
            }
          },
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Edit'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Submit button + server-error feedback.
// ────────────────────────────────────────────────────────────────────────

class _SubmitSection extends ConsumerStatefulWidget {
  const _SubmitSection({
    required this.cart,
    required this.totalKg,
    required this.pin,
  });

  final CartState cart;
  final double totalKg;
  final DeliveryPin? pin;

  @override
  ConsumerState<_SubmitSection> createState() => _SubmitSectionState();
}

class _SubmitSectionState extends ConsumerState<_SubmitSection> {
  bool _submitting = false;
  String? _serverError;

  String? get _helperText {
    if (widget.cart.isEmpty) return 'Add at least one item to your cart.';
    if (widget.totalKg > maxPayloadKg) return 'Total exceeds drone payload.';
    if (widget.pin == null) return 'Please drop a delivery pin.';
    return null;
  }

  Future<void> _submit() async {
    final pin = widget.pin;
    if (pin == null) return;
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      final payload = buildSubmitPayload(cart: widget.cart, pin: pin);
      final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
      await fns
          .httpsCallable('submitRequest')
          .call<Map<String, dynamic>>(payload);
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted. Watch the Queue tab.')),
      );
      context.go('/user/queue');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !_submitting &&
        canSubmit(
          cart: widget.cart,
          totalWeightKg: widget.totalKg,
          pinSet: widget.pin != null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('submit-request'),
          onPressed: enabled ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit request'),
        ),
        if (_helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            _helperText!,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (_serverError != null) ...[
          const SizedBox(height: 8),
          Text(
            _serverError!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
