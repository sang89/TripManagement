import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trip_management/services/biometric_service.dart';

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late _MockLocalAuthentication mockAuth;
  late BiometricService service;

  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  setUp(() {
    mockAuth = _MockLocalAuthentication();
    service = BiometricService(auth: mockAuth);
  });

  group('BiometricService.isAvailable', () {
    test('returns false when device does not support biometrics', () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => false);
      expect(await service.isAvailable(), isFalse);
    });

    test('returns false when device supports but no biometrics enrolled',
        () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => false);
      expect(await service.isAvailable(), isFalse);
    });

    test('returns true when device supports and has enrolled biometrics',
        () async {
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
      expect(await service.isAvailable(), isTrue);
    });

    test('returns false when an exception is thrown', () async {
      when(() => mockAuth.isDeviceSupported()).thenThrow(Exception('error'));
      expect(await service.isAvailable(), isFalse);
    });
  });

  group('BiometricService.getAvailableTypes', () {
    test('returns the list of enrolled biometric types', () async {
      when(() => mockAuth.getAvailableBiometrics())
          .thenAnswer((_) async => [BiometricType.face]);
      final types = await service.getAvailableTypes();
      expect(types, [BiometricType.face]);
    });

    test('returns empty list when an exception is thrown', () async {
      when(() => mockAuth.getAvailableBiometrics())
          .thenThrow(Exception('error'));
      expect(await service.getAvailableTypes(), isEmpty);
    });
  });

  group('BiometricService.authenticate', () {
    test('returns true when authentication succeeds', () async {
      when(() => mockAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => true);

      final result = await service.authenticate(
          localizedReason: 'Authenticate to access your account');
      expect(result, isTrue);
    });

    test('returns false when user cancels', () async {
      when(() => mockAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => false);

      final result = await service.authenticate(
          localizedReason: 'Authenticate to access your account');
      expect(result, isFalse);
    });

    test('returns false when a PlatformException is thrown', () async {
      when(() => mockAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenThrow(PlatformException(code: 'NotAvailable'));

      final result = await service.authenticate(
          localizedReason: 'Authenticate to access your account');
      expect(result, isFalse);
    });
  });
}
