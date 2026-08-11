import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_ci_example/services/pip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('music_sync/pip');
  const eventChannel = MethodChannel('music_sync/pip_events');

  setUp(() {
    // Method channel: isSupported / enter / setAutoEnter.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'enter':
          return true;
        case 'setAutoEnter':
          return null;
        default:
          return null;
      }
    });
    // Event channel: acknowledge listen/cancel without emitting events.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, null);
  });

  group('PipService', () {
    test('isSupported reflects the native response', () async {
      final service = PipService();
      expect(await service.isSupported, isTrue);
    });

    test('enter returns the native success flag', () async {
      final service = PipService();
      expect(await service.enter(), isTrue);
    });

    test('setAutoEnable forwards the enabled flag', () async {
      bool? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'setAutoEnter') {
          received = call.arguments['enabled'] as bool?;
        }
        return null;
      });

      final service = PipService();
      await service.setAutoEnter(true);
      expect(received, isTrue);

      await service.setAutoEnter(false);
      expect(received, isFalse);

      await service.dispose();
    });

    test('inPipMode starts as false when no event is emitted', () async {
      final service = PipService();
      final events = <bool>[];
      final sub = service.inPipMode.listen(events.add);
      // Allow the listen handshake to settle.
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
      await service.dispose();
    });

    test('isSupported swallows PlatformException and returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        throw PlatformException(code: 'unavailable');
      });

      final service = PipService();
      expect(await service.isSupported, isFalse);
      expect(await service.enter(), isFalse);
    });
  });
}
