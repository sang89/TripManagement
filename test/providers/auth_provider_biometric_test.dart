import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/providers/auth_provider.dart';

void main() {
  group('AuthProvider.biometricVerified', () {
    test('starts as false on a new instance', () {
      final provider = AuthProvider();
      expect(provider.biometricVerified, isFalse);
    });

    test('markBiometricVerified sets it to true', () {
      final provider = AuthProvider();
      expect(provider.biometricVerified, isFalse);
      provider.markBiometricVerified();
      expect(provider.biometricVerified, isTrue);
    });

    test('markBiometricVerified notifies listeners', () {
      final provider = AuthProvider();
      int callCount = 0;
      provider.addListener(() => callCount++);
      provider.markBiometricVerified();
      expect(callCount, 1);
    });

    test('markBiometricVerified is idempotent: calling twice notifies once per call',
        () {
      final provider = AuthProvider();
      int callCount = 0;
      provider.addListener(() => callCount++);
      provider.markBiometricVerified();
      provider.markBiometricVerified();
      expect(callCount, 2);
      expect(provider.biometricVerified, isTrue);
    });
  });

  group('AuthProvider.biometricVerified — cold start simulation', () {
    test('biometricVerified is false on a new AuthProvider (cold start)', () {
      final provider = AuthProvider();
      // On cold start, the flag is always false regardless of any stored
      // settings — the biometric gate decides whether to prompt.
      expect(provider.biometricVerified, isFalse);
    });
  });
}
