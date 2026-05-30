// P-U-03 Home / Request — browse catalog, build a cart, drop a pin, submit.
// Spec: docs/09-page-flow-design.md §5 P-U-03.
// Visual: docs/prototype-screens/user/P-U-03_request.png.
// Backend: submitRequest callable in functions/src/callable/submitRequest.ts.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/category_icon_tile.dart';
import '../../core/widgets/loading_placeholder.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/weight_bar.dart';
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
      body: catalogAsync.when(
        loading: () => const LoadingPlaceholder(label: 'Loading supplies…'),
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
            padding: EdgeInsets.zero,
            children: [
              const PageHeader(
                eyebrow: 'P-U-03 · REQUEST',
                title: 'Request supplies',
                subtitle: 'Pick what you need, drop a pin, send a drone.',
              ),
              const SectionLabel('CATALOG'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < catalog.length; i++) ...[
                        _CatalogRow(
                          entry: catalog[i],
                          qty: cart.lines[catalog[i].id] ?? 0,
                          onChanged: (q) => ref
                              .read(cartProvider.notifier)
                              .setQty(catalog[i].id, q),
                        ),
                        if (i < catalog.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
              if (!cart.isEmpty) ...[
                const SectionLabel('CART'),
                _CartSection(
                  cart: cart,
                  catalog: catalog,
                  onRemove: (id) =>
                      ref.read(cartProvider.notifier).remove(id),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: WeightBar(currentKg: totalKg, maxKg: maxPayloadKg),
                ),
              ],
              const SectionLabel('DELIVERY PIN'),
              _PinSection(pin: cart.pin),
              const SectionLabel('PRIORITY'),
              _PriorityToggle(
                value: cart.priority,
                onChanged: (v) =>
                    ref.read(cartProvider.notifier).setPriority(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: _SubmitSection(
                  cart: cart,
                  totalKg: totalKg,
                  pin: cart.pin,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Catalog row — tinted icon tile + bold name + mono detail line + circle +.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = entry.outOfStock;
    final canAdd = !disabled && qty < entry.stock && qty < maxQtyPerLine;
    final monoStrong = context.appText.mono;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          CategoryIconTile(catalogId: entry.id),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: disabled ? theme.disabledColor : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled
                      ? 'Out of stock'
                      : '${entry.weightKg.toStringAsFixed(1)} kg · ${entry.stock} in stock',
                  style: monoStrong,
                ),
              ],
            ),
          ),
          if (qty > 0) ...[
            IconButton(
              key: Key('dec-${entry.id}'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => onChanged(qty - 1),
              tooltip: 'Remove one',
            ),
            SizedBox(
              width: 22,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
          _AddButton(
            inkKey: Key('inc-${entry.id}'),
            onPressed: canAdd ? () => onChanged(qty + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.inkKey, required this.onPressed});
  final Key inkKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final disabled = onPressed == null;
    final fg = disabled
        ? t.colorScheme.onSurface.withValues(alpha: 0.35)
        : t.colorScheme.onSurface;
    final borderColor = t.dividerColor;
    return InkResponse(
      key: inkKey,
      onTap: onPressed,
      radius: 24,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Icon(Icons.add, size: 18, color: fg),
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
    final byId = {for (final c in catalog) c.id: c};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < cart.lines.length; i++) ...[
              () {
                final entry = cart.lines.entries.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(
                    '${byId[entry.key]?.name ?? entry.key} ×${entry.value}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: IconButton(
                    key: Key('remove-${entry.key}'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onRemove(entry.key),
                  ),
                );
              }(),
              if (i < cart.lines.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Delivery pin card.
// ────────────────────────────────────────────────────────────────────────

class _PinSection extends ConsumerWidget {
  const _PinSection({required this.pin});
  final DeliveryPin? pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final mono = context.appText.mono;
    final title = pin?.label ?? (pin == null ? 'Not set' : 'Custom pin');
    final coords = pin == null
        ? 'Tap Edit to drop a pin.'
        : '${pin!.lat.toStringAsFixed(4)}, ${pin!.lng.toStringAsFixed(4)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.iconTile),
                ),
                child: Icon(
                  Icons.place_outlined,
                  color: t.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(coords, style: mono),
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
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Priority pill toggle (Normal / Urgent).
// ────────────────────────────────────────────────────────────────────────

class _PriorityToggle extends StatelessWidget {
  const _PriorityToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final status = context.statusColors;

    Widget pill({
      required String id,
      required String label,
      IconData? icon,
      required Color selectedBg,
      required Color selectedFg,
    }) {
      final selected = value == id;
      final bg = selected
          ? selectedBg
          : t.colorScheme.surface;
      final fg = selected ? selectedFg : t.colorScheme.onSurface;
      final border = selected ? selectedBg : t.dividerColor;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(id),
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: 1.2),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          pill(
            id: 'normal',
            label: 'Normal',
            selectedBg: const Color(0xFFB5E8DF),
            selectedFg: const Color(0xFF0E3B38),
          ),
          const SizedBox(width: AppSpacing.sm),
          pill(
            id: 'urgent',
            label: 'Urgent',
            icon: Icons.warning_amber_outlined,
            selectedBg: status.urgentBg,
            selectedFg: status.urgentFg,
          ),
        ],
      ),
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
    final label = widget.cart.isEmpty
        ? 'Add items to submit'
        : 'Submit request';
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
              : Text(label),
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
