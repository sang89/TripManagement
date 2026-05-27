import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/services/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('starts with isOnline = true before init', () {
      final service = ConnectivityService();
      // Default is true (optimistic — init hasn't been called yet in test env).
      expect(service.isOnline, isTrue);
    });

    test('notifyListeners is not called during construction', () {
      int calls = 0;
      final service = ConnectivityService()..addListener(() => calls++);
      expect(calls, 0);
      service.removeListener(() {});
    });

    test('dispose does not throw when init was never called', () {
      final service = ConnectivityService();
      expect(service.dispose, returnsNormally);
    });
  });
}
