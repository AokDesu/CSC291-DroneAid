// Thai national-ID checksum.
// Validation rule V-01 in docs/09-page-flow-design.md.
//
// Algorithm:
//   sum = Σ digit[i] × (13 − i)  for i in [0..11]
//   check = (11 − (sum mod 11)) mod 10
//   valid ⇔ check == digit[12]

class ThaiIdValidator {
  ThaiIdValidator._();

  static bool isValid(String id) {
    final trimmed = id.trim();
    if (!RegExp(r'^\d{13}$').hasMatch(trimmed)) return false;
    final digits = trimmed.split('').map(int.parse).toList(growable: false);
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += digits[i] * (13 - i);
    }
    final check = (11 - (sum % 11)) % 10;
    return check == digits[12];
  }

  /// Synthetic Firebase-Auth email derived from a 13-digit national ID.
  static String toSyntheticEmail(String id) => '$id@drone-aid.local';
}
