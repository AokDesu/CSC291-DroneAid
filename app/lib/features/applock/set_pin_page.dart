// Set / change PIN flow: enter a new PIN, then confirm it. Returns the chosen
// PIN string, or null if cancelled. Reuses PinKeypad. Used from the profile
// Security section. (Changing a PIN while already unlocked in-app does not
// re-prompt for the old PIN — the user is past the lock; the value of a
// re-verify here is low, so we keep the flow to two steps.)

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'pin_keypad.dart';

Future<String?> showSetPinFlow(BuildContext context, {String title = 'Set a PIN'}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => _SetPinPage(title: title), fullscreenDialog: true),
  );
}

enum _Phase { enter, confirm }

class _SetPinPage extends StatefulWidget {
  const _SetPinPage({required this.title});
  final String title;

  @override
  State<_SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<_SetPinPage> {
  _Phase _phase = _Phase.enter;
  String _entry = '';
  String? _first;
  String? _error;

  void _onKey(String d) {
    if (_entry.length >= kPinLength) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == kPinLength) _advance();
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _advance() {
    if (_phase == _Phase.enter) {
      setState(() {
        _first = _entry;
        _entry = '';
        _phase = _Phase.confirm;
      });
      return;
    }
    if (_entry == _first) {
      Navigator.of(context).pop(_entry);
    } else {
      setState(() {
        _error = "PINs didn't match. Try again.";
        _entry = '';
        _first = null;
        _phase = _Phase.enter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = _phase == _Phase.enter ? 'Choose a $kPinLength-digit PIN' : 'Re-enter your PIN';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(prompt, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 24,
                    child: _error != null
                        ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PinKeypad(value: _entry, onKey: _onKey, onBackspace: _onBackspace),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
