// Scripted BiometricService for tests.

import 'package:droneaid/core/applock/biometric_service.dart';

class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.available = false, this.authResult = false});

  bool available;
  bool authResult;
  int authCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    authCalls++;
    return authResult;
  }
}
