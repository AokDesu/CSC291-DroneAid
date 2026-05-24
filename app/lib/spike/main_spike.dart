// PROTOTYPE — throwaway entry point for issue #28. DELETE after P-U-05 verdict.
// Run: flutter run -t lib/spike/main_spike.dart -d <android-emulator>
// No Firebase. No routing. No Riverpod. Pure flutter_map smoke test.

import 'package:flutter/material.dart';
import 'flutter_map_spike.dart';

void main() => runApp(const _SpikeApp());

class _SpikeApp extends StatelessWidget {
  const _SpikeApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '[SPIKE] flutter_map',
      debugShowCheckedModeBanner: true,
      home: FlutterMapSpikePage(),
    );
  }
}
