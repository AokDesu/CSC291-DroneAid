// Tiny helper for surfacing Cloud Functions callable errors to users.
//
// Pattern: every callable invocation across the app does the same dance —
// catch FirebaseFunctionsException to extract a human message, otherwise
// fall back to the stringified exception. Centralising it keeps SnackBar
// copy consistent.

import 'package:cloud_functions/cloud_functions.dart';

String describeFunctionsError(Object e) {
  if (e is FirebaseFunctionsException) {
    final msg = e.message;
    final code = e.code;
    if (msg != null && msg.isNotEmpty) return '[$code] $msg';
    return '[$code]';
  }
  return e.toString();
}
