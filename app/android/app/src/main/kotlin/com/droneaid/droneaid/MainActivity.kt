package com.droneaid.droneaid

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// BiometricPrompt needs a FragmentActivity host. Safe drop-in — the existing
// plugins (firebase_*, geolocator, flutter_map) use the v2 embedding and do
// not depend on a plain FlutterActivity.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
