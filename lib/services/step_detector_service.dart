import 'package:flutter/services.dart';

class StepDetectorService {

  // Comunicación con el código nativo de Android.
  static const EventChannel _channel = EventChannel(
    'voltfit/step_detector',
  );

  // Recibir cada paso detectado por Android.
  static Stream<int> get stepStream {

    return _channel
        .receiveBroadcastStream()
        .map((event) => (event as num).toInt());
  }
}