// Reusable numeric PIN keypad: a row of progress dots above a 3×4 digit grid.
// Controlled — the parent owns the entered string and reacts to onKey/onBackspace.
// Named PinKeypad (NOT PinPicker) to stay clear of the unrelated map
// DeliveryPin / showPinPicker in features/user/request.

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Fixed PIN length. Set-PIN and verify share this so they can never disagree.
const int kPinLength = 6;

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.value,
    required this.onKey,
    required this.onBackspace,
    this.length = kPinLength,
    this.enabled = true,
    this.leading,
  });

  /// Digits entered so far.
  final String value;
  final int length;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final bool enabled;

  /// Optional widget in the bottom-left slot (e.g. a fingerprint button).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(filled: value.length, total: length),
        const SizedBox(height: AppSpacing.xl),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row) _DigitKey(digit: d, enabled: enabled, onTap: () => onKey(d)),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 72, height: 72, child: Center(child: leading)),
            _DigitKey(digit: '0', enabled: enabled, onTap: () => onKey('0')),
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: enabled && value.isNotEmpty ? onBackspace : null,
                icon: Icon(Icons.backspace_outlined, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? theme.colorScheme.primary : Colors.transparent,
              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onTap, required this.enabled});
  final String digit;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                digit,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
