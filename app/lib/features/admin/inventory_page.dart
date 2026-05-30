// P-A-07 Admin Inventory + restock.
// Spec: docs/09-page-flow-design.md §6 P-A-07.
// Flows: F-23 (restock), F-24 (create), spec also mentions deactivate.
// Backend: restockItem, createCatalogItem, toggleCatalogActive callables.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_extensions.dart';
import '../../core/tokens.dart';
import '../../core/widgets/category_icon_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/page_header.dart';
import 'inventory/catalog_icons.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load catalog: $e',
          onRetry: () => ref.invalidate(adminCatalogStreamProvider),
        ),
        data: (items) {
          final active = items.where((i) => i.active).length;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                eyebrow: 'P-A-07 · INVENTORY',
                title: 'Inventory',
                subtitle: '${items.length} items · $active active.',
              ),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No catalog items yet',
                  helper: 'Tap "Add item" to create your first one.',
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  child: Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _InventoryRow(item: items[i]),
                          if (i < items.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl + AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CategoryIconTile(catalogId: item.id),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                'Low stock',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${item.weightKg.toStringAsFixed(1)} kg · ${item.stock} in stock',
        style: context.appText.mono,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('edit-${item.id}'),
            tooltip: 'Edit item',
            onPressed: () => _showEditItemDialog(context, item),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: Key('restock-${item.id}'),
            tooltip: 'Restock',
            onPressed: () => _showRestockDialog(context, item),
            icon: const Icon(Icons.add_box_outlined),
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
  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _AddItemDialog(),
  );

  if (payload == null || !context.mounted) return;
  await _invokeCallable(
    context,
    name: 'createCatalogItem',
    payload: payload,
    success: 'Created ${payload['name']}.',
  );
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  String? _iconKey;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      buildCreateCatalogPayload(
        itemId: _idCtrl.text,
        name: _nameCtrl.text,
        weightKg: double.parse(_weightCtrl.text.trim()),
        initialStock: int.parse(_stockCtrl.text.trim()),
        icon: _iconKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add catalog item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _idCtrl,
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
                controller: _weightCtrl,
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
                controller: _stockCtrl,
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
              const SizedBox(height: 12),
              _IconPicker(
                value: _iconKey,
                onChanged: (next) => setState(() => _iconKey = next),
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

// ────────────────────────────────────────────────────────────────────────
// Edit-item dialog
// ────────────────────────────────────────────────────────────────────────

Future<void> _showEditItemDialog(BuildContext context, CatalogItem item) async {
  final patch = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _EditItemDialog(item: item),
  );
  if (patch == null || !context.mounted) return;
  if (patch.length <= 1) {
    // Only `itemId` would be present — nothing changed.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to update.')),
    );
    return;
  }
  await _invokeCallable(
    context,
    name: 'editCatalogItem',
    payload: patch,
    success: 'Saved ${item.name}.',
  );
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});
  final CatalogItem item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late String? _iconKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _weightCtrl = TextEditingController(
      text: widget.item.weightKg.toString(),
    );
    _iconKey = widget.item.icon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final patch = <String, dynamic>{'itemId': widget.item.id};
    final trimmedName = _nameCtrl.text.trim();
    final parsedWeight = double.tryParse(_weightCtrl.text.trim());
    if (trimmedName != widget.item.name) {
      patch['name'] = trimmedName;
    }
    if (parsedWeight != null && parsedWeight != widget.item.weightKg) {
      patch['weightKg'] = parsedWeight;
    }
    if (_iconKey != widget.item.icon) {
      patch['icon'] = _iconKey;
    }
    Navigator.of(context).pop(patch);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.item.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '#${widget.item.id}',
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
                controller: _weightCtrl,
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
              const SizedBox(height: 12),
              _IconPicker(
                value: _iconKey,
                onChanged: (next) => setState(() => _iconKey = next),
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

// ────────────────────────────────────────────────────────────────────────
// Themed icon picker (used by Add + Edit dialogs)
// ────────────────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in catalogIcons)
              ChoiceChip(
                key: Key('icon-${opt.key}'),
                avatar: Icon(opt.icon, size: 18),
                label: Text(opt.label),
                selected: value == opt.key,
                onSelected: (selected) =>
                    onChanged(selected ? opt.key : null),
              ),
          ],
        ),
      ],
    );
  }
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
