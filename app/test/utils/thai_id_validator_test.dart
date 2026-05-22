import 'package:droneaid/utils/thai_id_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThaiIdValidator.isValid', () {
    test('rejects empty / wrong length', () {
      expect(ThaiIdValidator.isValid(''), isFalse);
      expect(ThaiIdValidator.isValid('123'), isFalse);
      expect(ThaiIdValidator.isValid('12345678901234'), isFalse);
    });

    test('rejects non-numeric', () {
      expect(ThaiIdValidator.isValid('110000000000a'), isFalse);
      expect(ThaiIdValidator.isValid('1100000000-01'), isFalse);
    });

    test('rejects wrong checksum', () {
      expect(ThaiIdValidator.isValid('1234567890123'), isFalse);
    });

    test('accepts a checksum-valid ID', () {
      expect(ThaiIdValidator.isValid(_buildValid('110000000010')), isTrue);
    });
  });

  test('toSyntheticEmail', () {
    expect(
      ThaiIdValidator.toSyntheticEmail('1100000000101'),
      equals('1100000000101@drone-aid.local'),
    );
  });
}

String _buildValid(String stem12) {
  if (stem12.length != 12) {
    throw ArgumentError('stem must be 12 digits');
  }
  final digits = stem12.split('').map(int.parse).toList(growable: false);
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += digits[i] * (13 - i);
  }
  final check = (11 - (sum % 11)) % 10;
  return '$stem12$check';
}
