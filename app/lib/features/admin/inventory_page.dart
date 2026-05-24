// P-A-07 Admin Inventory + restock.
// Spec: docs/09-page-flow-design.md §6 P-A-07.
// Flows: F-23 (restock), F-24 (create), spec also mentions deactivate.
// Backend: restockItem, createCatalogItem, toggleCatalogActive callables.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory/catalog_item.dart';
import 'inventory/catalog_providers.dart';

/// Region pinned to match `functions/src/index.ts` `setGlobalOptions`.
const _functionsRegion = 'asia-southeast1';

/// Pure helper — payload for the `restockItem` callable. Extracted so the
/// dialog logic stays testable without spinning up Firebase.
@visibleForTesting
Map<String, dynamic> buildRestockPayload({
  required String itemId,
  required int qty,
}) {
  return {'itemId': itemId, 'qty': qty};
}

/// Pure helper — payload for the `createCatalogItem` callable. Server-side
/// Zod schema lives in `functions/src/callable/createCatalogItem.ts`.
@visibleForTesting
Map<String, dynamic> buildCreateCatalogPayload({
  required String itemId,
  required String name,
  required double weightKg,
  required int initialStock,
  String? icon,
  bool active = true,
}) {
  final trimmedIcon = icon?.trim();
  return <String, dynamic>{
    'itemId': itemId.trim(),
    'name': name.trim(),
    'weightKg': weightKg,
    'initialStock': initialStock,
    if (trimmedIcon != null && trimmedIcon.isNotEmpty) 'icon': trimmedIcon,
    'active': active,
  };
}

/// Same kebab-case rule as the server-side Zod schema:
/// `/^[a-z0-9][a-z0-9-]{1,40}$/`.
@visibleForTesting
final itemIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,40}$');

class AdminInventoryPage extends ConsumerWidget {
  const AdminInventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCatalogStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load catalog: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No catalog items yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _InventoryRow(item: items[i]),
          );
        },
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});
  final CatalogItem item;

  IconData get _iconData {
    switch (item.icon) {
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
    return ListTile(
      leading: CircleAvatar(child: Icon(_iconData)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: item.active ? null : theme.disabledColor,
              ),
            ),
          ),
          if (item.isLowStock)
            Container(
              key: const Key('low-stock-pill'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Low stock',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${item.weightKg.toStringAsFixed(1)} kg   ${item.stock} in stock',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            key: Key('restock-${item.id}'),
            onPressed: () => _showRestockDialog(context, item),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Restock'),
          ),
          Switch(
            key: Key('active-${item.id}'),
            value: item.active,
            onChanged: (next) => _toggleActive(context, item, next),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Restock dialog (F-23)
// ────────────────────────────────────────────────────────────────────────

Future<void> _showRestockDialog(BuildContext context, CatalogItem item) async {
  final controller = TextEditingController(text: '1');
  final preset = ValueNotifier<int?>(1);

  void selectPreset(int? n) {
    preset.value = n;
    if (n != null) controller.text = '$n';
  }

  final qty = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Restock — ${item.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<int?>(
              valueListenable: preset,
              builder: (_, current, __) => Wrap(
                spacing: 8,
                children: [
                  for (final n in const [1, 5, 10])
                    ChoiceChip(
                      label: Text('+$n'),
                      selected: current == n,
                      onSelected: (_) => selectPreset(n),
                    ),
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: current == null,
                    onSelected: (_) => selectPreset(null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('restock-qty-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => preset.value = null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = int.tryParse(controller.text.trim());
            if (parsed == null || parsed < 1 || parsed > 999) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Quantity must be 1–999.')),
              );
              return;
            }
            Navigator.of(ctx).pop(parsed);
          },
          child: const Text('Restock'),
        ),
      ],
    ),
  );

  if (qty == null || !context.mounted) return;
  await _invokeCallable(
    context,
    name: 'restockItem',
    payload: buildRestockPayload(itemId: item.id, qty: qty),
    success: 'Restocked ${item.name} +$qty.',
  );
}

// ────────────────────────────────────────────────────────────────────────
// Add-item dialog (F-24)
// ────────────────────────────────────────────────────────────────────────

Future<void> _showAddItemDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final idCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final stockCtrl = TextEditingController(text: '0');
  final iconCtrl = TextEditingController();

  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add catalog item'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item id (kebab-case)',
                  hintText: 'e.g. food-kit',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (!itemIdPattern.hasMatch(s)) {
                    return 'lowercase a-z, 0-9 and -, 2-41 chars';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameCtrl,
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
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg, max 6)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null) return 'Number required';
                  if (n <= 0 || n > 6) return '0 < weight ≤ 6';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Initial stock',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Integer required';
                  if (n < 0 || n > 9999) return '0 ≤ stock ≤ 9999';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                  labelText: 'Icon key (optional)',
                  hintText: 'food, water, med, baby, blanket, light',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.of(ctx).pop(
              buildCreateCatalogPayload(
                itemId: idCtrl.text,
                name: nameCtrl.text,
                weightKg: double.parse(weightCtrl.text.trim()),
                initialStock: int.parse(stockCtrl.text.trim()),
                icon: iconCtrl.text,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (payload == null || !context.mounted) return;
  await _invokeCallable(
    context,
    name: 'createCatalogItem',
    payload: payload,
    success: 'Created ${payload['name']}.',
  );
}

// ────────────────────────────────────────────────────────────────────────
// Deactivate toggle (spec §6 P-A-07 Deactivate scenario)
// ────────────────────────────────────────────────────────────────────────

Future<void> _toggleActive(
  BuildContext context,
  CatalogItem item,
  bool next,
) async {
  if (!next) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${item.name}?'),
        content: const Text(
          'It will disappear from the user catalog. Existing requests are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }

  await _invokeCallable(
    context,
    name: 'toggleCatalogActive',
    payload: {'itemId': item.id, 'active': next},
    success: next ? '${item.name} active.' : '${item.name} deactivated.',
  );
}

// ────────────────────────────────────────────────────────────────────────
// Shared callable invoker — handles SnackBar feedback + error narrowing.
// ────────────────────────────────────────────────────────────────────────

Future<void> _invokeCallable(
  BuildContext context, {
  required String name,
  required Map<String, dynamic> payload,
  required String success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final fns = FirebaseFunctions.instanceFor(region: _functionsRegion);
    await fns.httpsCallable(name).call<Map<String, dynamic>>(payload);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(success)));
  } on FirebaseFunctionsException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}
