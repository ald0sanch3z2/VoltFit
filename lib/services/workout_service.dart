import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/workout.dart';
import 'step_detector_service.dart';

class WorkoutService extends ChangeNotifier {

  // ==========================================
  // SUSCRIPCIONES
  // ==========================================

  StreamSubscription<StepCount>? _stepsSub;
  StreamSubscription<int>? _realStepsSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<Position>? _gpsSub;

  Timer? _timer;

  bool running = false;
  bool listening = false;
  bool _disposed = false;

  int _generation = 0;

  final Stopwatch _clock = Stopwatch();

  bool get paused => running && !listening;

  // ==========================================
  // PODÓMETRO
  // ==========================================

  int steps = 0;
  int seconds = 0;
  int? _lastRawSteps;
  double get strideMeters => 0.74;

  double get distanceMeters => steps * strideMeters;

  // ==========================================
  // ACELERÓMETRO
  // ==========================================

  double ax = 0;
  double ay = 0;
  double az = 0;

  double magnitude = 0;
  double movement = 0;

  double? _gravityX;
  double? _gravityY;
  double? _gravityZ;

  double _smoothedMovement = 0;

  bool accelerometerAvailable = false;

  DateTime? _quietSince;

  // Confirmar que el teléfono permanece inmóvil.
  bool get stationary =>
      accelerometerAvailable &&
          _quietSince != null &&
          DateTime.now().difference(_quietSince!) >=
              const Duration(seconds: 2);

  String intensity = 'Descanso';

  String _candidateIntensity = 'Descanso';

  int _candidateSamples = 0;

  // ==========================================
  // GIROSCOPIO
  // ==========================================

  double gx = 0;
  double gy = 0;
  double gz = 0;

  double roll = 0;
  double pitch = 0;
  double yaw = 0;

  bool gyroscopeAvailable = false;

  DateTime? _lastGyroTime;

  double? _accelRoll;
  double? _accelPitch;

  double _gyroBiasX = 0;
  double _gyroBiasY = 0;
  double _gyroBiasZ = 0;

  // ==========================================
  // GPS
  // ==========================================

  double? latitude;
  double? longitude;
  double? accuracy;

  final List<LatLng> route = [];

  final List<int> routeBreaks = [];

  bool _newSegment = true;

  double? _lastRouteAccuracy;

  // ==========================================
  // ESTADOS
  // ==========================================

  String sensorStatus = 'Sin iniciar';

  String stepStatus = 'Esperando podómetro';

  String gpsStatus = 'GPS sin iniciar';

  String accelerometerStatus = 'Sin iniciar';

  String gyroscopeStatus = 'Sin iniciar';

  final Map<String, int> _intensitySeconds = {
    'Descanso': 0,
    'Caminata': 0,
    'Trote': 0,
  };

  DateTime? _startedAt;

  AppUser? user;

  // ==========================================
  // ACTUALIZAR INTERFAZ
  // ==========================================

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _valid(int generation) {
    return !_disposed && generation == _generation;
  }

  bool _active(int generation) {
    return _valid(generation) && listening;
  }

  void setUser(AppUser value) {
    user = value;
    _notify();
  }

  // ==========================================
  // INTENSIDAD PREDOMINANTE
  // ==========================================

  String get dominantIntensity {

    var best = 'Descanso';

    for (final entry in _intensitySeconds.entries) {

      if (entry.value > (_intensitySeconds[best] ?? 0)) {
        best = entry.key;
      }
    }

    return best;
  }

  // ==========================================
  // SEPARAR SEGMENTOS DEL RECORRIDO
  // ==========================================

  List<List<LatLng>> get routeSegments {

    if (route.isEmpty) return [];

    final result = <List<LatLng>>[];

    final breaks = routeBreaks
        .where((i) => i > 0 && i < route.length)
        .toSet()
        .toList()
      ..sort();

    int start = 0;

    for (final end in breaks) {
      result.add(route.sublist(start, end));
      start = end;
    }

    result.add(route.sublist(start));

    return result;
  }

  // ==========================================
  // PERMISOS DE UBICACIÓN
  // ==========================================

  Future<bool> requestLocation({
    bool ask = true,
  }) async {

    try {

      final enabled =
      await Geolocator.isLocationServiceEnabled();

      if (!enabled) {

        gpsStatus = 'Activa la ubicación del teléfono';

        _notify();

        return false;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && ask) {

        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {

        gpsStatus = 'Habilita la ubicación desde Ajustes';

        _notify();

        return false;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {

        gpsStatus = 'Permiso de ubicación no concedido';

        _notify();

        return false;
      }

      return true;

    } catch (_) {

      gpsStatus = 'Ubicación no disponible';

      _notify();

      return false;
    }
  }

  // ==========================================
  // REINICIAR FILTROS
  // ==========================================

  void _resetFilters() {

    _gravityX = null;
    _gravityY = null;
    _gravityZ = null;

    _quietSince = null;

    _smoothedMovement = 0;

    movement = 0;

    _candidateSamples = 0;
    _candidateIntensity = 'Descanso';

    intensity = 'Descanso';

    _accelRoll = null;
    _accelPitch = null;

    _lastGyroTime = null;

    _gyroBiasX = 0;
    _gyroBiasY = 0;
    _gyroBiasZ = 0;

    ax = 0;
    ay = 0;
    az = 0;

    gx = 0;
    gy = 0;
    gz = 0;

    magnitude = 0;
  }

  // ==========================================
  // INICIAR ENTRENAMIENTO
  // ==========================================

  Future<void> start() async {

    if (running || _disposed) return;

    await stopListening();

    if (_disposed) return;

    steps = 0;
    seconds = 0;

    _lastRawSteps = null;

    route.clear();
    routeBreaks.clear();

    latitude = null;
    longitude = null;
    accuracy = null;

    _newSegment = true;
    _lastRouteAccuracy = null;

    _resetFilters();

    roll = 0;
    pitch = 0;
    yaw = 0;

    for (final key in _intensitySeconds.keys) {
      _intensitySeconds[key] = 0;
    }

    _clock
      ..stop()
      ..reset();

    _startedAt = DateTime.now();

    running = true;

    _notify();
  }

  // ==========================================
  // CRONÓMETRO
  // ==========================================

  void _resumeClock() {

    if (!running || !listening || _disposed) return;

    _clock.start();

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _tick(),
    );
  }

  void _pauseClock() {

    _clock.stop();

    _tick();

    _timer?.cancel();

    _timer = null;
  }

  void _tick() {

    if (!running || _disposed) return;

    final elapsed = _clock.elapsed.inSeconds;

    final delta = elapsed - seconds;

    if (delta > 0) {

      seconds = elapsed;

      _intensitySeconds[intensity] =
          (_intensitySeconds[intensity] ?? 0) + delta;
    }

    _notify();
  }

  // ==========================================
  // FILTRO DE ZONA MUERTA
  // ==========================================

  // Ignorar variaciones muy pequeñas del sensor.
  double _deadZone(double value, double tolerance) {

    if (value.abs() < tolerance) {
      return 0.0;
    }

    return value;
  }

  // ==========================================
  // CLASIFICAR MOVIMIENTO
  // ==========================================

  void _classifyMovement() {

    String candidate;

    if (stationary || movement < 0.35) {

      candidate = 'Descanso';

    } else if (movement < 1.5) {

      candidate = 'Caminata';

    } else {

      candidate = 'Trote';
    }

    // Confirmar varias lecturas antes de cambiar.
    if (candidate == _candidateIntensity) {

      _candidateSamples++;

    } else {

      _candidateIntensity = candidate;

      _candidateSamples = 1;
    }

    if (stationary || _candidateSamples >= 5) {
      intensity = candidate;
    }
  }

  // ==========================================
  // PROCESAR ACELERÓMETRO
  // ==========================================

  void _processAccelerometer(
      AccelerometerEvent event,
      ) {

    final x = event.x;
    final y = event.y;
    final z = event.z;

    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      return;
    }

    // Inicializar el filtro de gravedad.
    _gravityX ??= x;
    _gravityY ??= y;
    _gravityZ ??= z;

    // Filtro de paso bajo.
    const alpha = 0.85;

    _gravityX = alpha * _gravityX! +
        (1 - alpha) * x;

    _gravityY = alpha * _gravityY! +
        (1 - alpha) * y;

    _gravityZ = alpha * _gravityZ! +
        (1 - alpha) * z;

    // Separar aproximadamente el movimiento
    // de la componente gravitacional.
    final linearX = x - _gravityX!;
    final linearY = y - _gravityY!;
    final linearZ = z - _gravityZ!;

    final linearMagnitude = sqrt(
      linearX * linearX +
          linearY * linearY +
          linearZ * linearZ,
    );

    _smoothedMovement =
        0.80 * _smoothedMovement +
            0.20 * linearMagnitude;

    final rawMagnitude = sqrt(
      x * x + y * y + z * z,
    );

    final angularMagnitude = sqrt(
      gx * gx + gy * gy + gz * gz,
    );

    // Detectar reposo sin confundirlo con gravedad.
    final quiet =
        _smoothedMovement < 0.12 &&
            (rawMagnitude - 9.81).abs() < 0.6 &&
            (!gyroscopeAvailable ||
                angularMagnitude < 0.04);

    if (quiet) {

      _quietSince ??= DateTime.now();

    } else {

      _quietSince = null;
    }

    accelerometerAvailable = true;

    // En reposo mostrar los valores suavizados.
    // No se fuerza el eje Z a 9.81.
    if (stationary) {

      ax = _deadZone(_gravityX!, 0.08);
      ay = _deadZone(_gravityY!, 0.08);
      az = _deadZone(_gravityZ!, 0.08);

      movement = 0;

    } else {

      ax = _deadZone(x, 0.08);
      ay = _deadZone(y, 0.08);
      az = _deadZone(z, 0.08);

      movement = _deadZone(
        _smoothedMovement,
        0.08,
      );
    }

    magnitude = sqrt(
      ax * ax + ay * ay + az * az,
    );

    // Calcular la inclinación usando la gravedad.
    if ((rawMagnitude - 9.81).abs() < 0.8 &&
        _smoothedMovement < 0.35) {

      _accelRoll =
          atan2(_gravityY!, _gravityZ!) *
              180 / pi;

      _accelPitch =
          atan2(
            -_gravityX!,
            sqrt(
              _gravityY! * _gravityY! +
                  _gravityZ! * _gravityZ!,
            ),
          ) *
              180 / pi;

    } else {

      _accelRoll = null;
      _accelPitch = null;
    }

    _classifyMovement();

    accelerometerStatus = stationary
        ? 'Acelerómetro activo · En reposo'
        : 'Acelerómetro activo';
  }

  // ==========================================
  // NORMALIZAR ÁNGULOS
  // ==========================================

  double _normalizeAngle(double angle) {

    return ((angle + 180) % 360) - 180;
  }

  double _correctAngle(
      double estimated,
      double measured,
      ) {

    final difference =
    _normalizeAngle(measured - estimated);

    return _normalizeAngle(
      estimated + 0.02 * difference,
    );
  }

  // ==========================================
  // PROCESAR GIROSCOPIO
  // ==========================================

  void _processGyroscope(
      GyroscopeEvent event,
      ) {

    if (!event.x.isFinite ||
        !event.y.isFinite ||
        !event.z.isFinite) {
      return;
    }

    // Estimar pequeñas desviaciones durante el reposo.
    final rawAngularMagnitude = sqrt(
      event.x * event.x +
          event.y * event.y +
          event.z * event.z,
    );

    if (stationary && rawAngularMagnitude < 0.04) {

      _gyroBiasX =
          0.98 * _gyroBiasX + 0.02 * event.x;

      _gyroBiasY =
          0.98 * _gyroBiasY + 0.02 * event.y;

      _gyroBiasZ =
          0.98 * _gyroBiasZ + 0.02 * event.z;
    }

    // Eliminar pequeñas variaciones de ruido.
    gx = _deadZone(
      event.x - _gyroBiasX,
      0.015,
    );

    gy = _deadZone(
      event.y - _gyroBiasY,
      0.015,
    );

    gz = _deadZone(
      event.z - _gyroBiasZ,
      0.015,
    );

    final angularMagnitude = sqrt(
      gx * gx + gy * gy + gz * gz,
    );

    // Si existe rotación, dejar el estado de reposo.
    if (angularMagnitude >= 0.04) {
      _quietSince = null;
    }

    final now = DateTime.now();

    if (_lastGyroTime != null) {

      final dt = now
          .difference(_lastGyroTime!)
          .inMicroseconds /
          1000000.0;

      if (dt > 0 && dt < 0.5) {

        // Evitar acumulación de error en reposo.
        if (!stationary) {

          roll = _normalizeAngle(
            roll + gx * dt * 180 / pi,
          );

          pitch = _normalizeAngle(
            pitch + gy * dt * 180 / pi,
          );

          yaw = _normalizeAngle(
            yaw + gz * dt * 180 / pi,
          );
        }

        // Corregir inclinación con el acelerómetro.
        if (_accelRoll != null) {

          roll = _correctAngle(
            roll,
            _accelRoll!,
          );
        }

        if (_accelPitch != null) {

          pitch = _correctAngle(
            pitch,
            _accelPitch!,
          );
        }
      }

    } else {

      roll = _accelRoll ?? roll;

      pitch = _accelPitch ?? pitch;
    }

    _lastGyroTime = now;

    gyroscopeAvailable = true;

    gyroscopeStatus = stationary
        ? 'Giroscopio activo · En reposo'
        : 'Giroscopio activo';
  }

  // ==========================================
  // REINICIAR ORIENTACIÓN
  // ==========================================

  void resetOrientation() {

    roll = _accelRoll ?? 0;

    pitch = _accelPitch ?? 0;

    yaw = 0;

    _lastGyroTime = null;

    _notify();
  }

  // ==========================================
  // PROCESAR PODÓMETRO
  // ==========================================

  void _processSteps(StepCount event) {

    final raw = event.steps;

    if (raw < 0) return;

    if (_lastRawSteps != null && running) {

      final delta = raw - _lastRawSteps!;

      // Conservar el contador nativo.
      // No descartar pasos legítimos reportados
      // con retraso por el sistema operativo.
      if (delta > 0) {
        steps += delta;
      }
    }

    // Si el contador se reinicia, actualizar
    // la referencia sin restar pasos acumulados.
    _lastRawSteps = raw;

    stepStatus = 'Podómetro acumulativo activo';
  }

  // ==========================================
  // PROCESAR GPS
  // ==========================================

  void _processPosition(Position position) {

    accuracy = position.accuracy;

    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0) {

      gpsStatus = 'Lectura GPS no válida';

      return;
    }

    // No registrar coordenadas poco confiables.
    if (position.accuracy > 20) {

      gpsStatus =
      'Señal GPS imprecisa · '
          '${position.accuracy.toStringAsFixed(1)} m';

      return;
    }

    final point = LatLng(
      position.latitude,
      position.longitude,
    );

    // Actualizar posición si todavía no hay datos.
    if (latitude == null || longitude == null) {

      latitude = position.latitude;

      longitude = position.longitude;

    } else {

      final displacement = const Distance().as(
        LengthUnit.Meter,
        LatLng(latitude!, longitude!),
        point,
      );

      // Reducir saltos de posición en reposo.
      final threshold = max(
        5.0,
        position.accuracy,
      );

      if (!stationary ||
          displacement > threshold * 2) {

        latitude = position.latitude;

        longitude = position.longitude;
      }
    }

    gpsStatus =
    'GPS activo · '
        '±${position.accuracy.toStringAsFixed(1)} m';

    if (!running) return;

    // Primer punto de un segmento.
    if (_newSegment || route.isEmpty) {

      if (route.isNotEmpty) {
        routeBreaks.add(route.length);
      }

      route.add(point);

      _lastRouteAccuracy = position.accuracy;

      _newSegment = false;

      return;
    }

    final distance = const Distance().as(
      LengthUnit.Meter,
      route.last,
      point,
    );

    // Ajustar el desplazamiento mínimo según
    // la incertidumbre de las coordenadas.
    final threshold = max(
      5.0,
      max(
        position.accuracy,
        _lastRouteAccuracy ?? 5.0,
      ),
    );

    // Evitar dibujar recorridos falsos por ruido GPS.
    if (!stationary && distance >= threshold) {

      route.add(point);

      _lastRouteAccuracy = position.accuracy;
    }
  }

  // ==========================================
  // ACTIVAR SENSORES
  // ==========================================

  Future<void> activateSensors({
    bool location = true,
    bool activity = true,
    bool motion = true,
    bool askPermissions = true,
  }) async {

    final generation = ++_generation;

    await _cancelSubscriptions();

    if (!_valid(generation)) return;

    bool hasLocation = false;

    if (location) {

      hasLocation = await requestLocation(
        ask: askPermissions,
      );
    }

    if (!_valid(generation)) return;

    listening = true;

    sensorStatus = 'Sensores iniciados';

    _lastRawSteps = null;

    _resetFilters();

    // ========================================
    // ACELERÓMETRO
    // ========================================

    if (motion) {

      accelerometerStatus = 'Esperando acelerómetro';

      try {

        _accelSub = accelerometerEventStream(
          samplingPeriod:
          const Duration(milliseconds: 100),
        ).listen(

              (event) {

            if (!_active(generation)) return;

            _processAccelerometer(event);

            _notify();
          },

          onError: (Object error) {

            if (!_active(generation)) return;

            accelerometerAvailable = false;

            _quietSince = null;

            accelerometerStatus =
            'Acelerómetro no disponible';

            _notify();
          },

          cancelOnError: true,
        );

      } catch (_) {

        accelerometerAvailable = false;

        accelerometerStatus =
        'Acelerómetro no disponible';
      }

      // ======================================
      // GIROSCOPIO
      // ======================================

      gyroscopeStatus = 'Esperando giroscopio';

      try {

        _gyroSub = gyroscopeEventStream(
          samplingPeriod:
          const Duration(milliseconds: 100),
        ).listen(

              (event) {

            if (!_active(generation)) return;

            _processGyroscope(event);

            _notify();
          },

          onError: (Object error) {

            if (!_active(generation)) return;

            gyroscopeAvailable = false;

            gyroscopeStatus =
            'Giroscopio no disponible';

            _notify();
          },

          cancelOnError: true,
        );

      } catch (_) {

        gyroscopeAvailable = false;

        gyroscopeStatus =
        'Giroscopio no disponible';
      }

    } else {

      accelerometerStatus = 'Acelerómetro sin activar';

      gyroscopeStatus = 'Giroscopio sin activar';
    }

    // ========================================
    // PODÓMETRO
    // ========================================

    if (activity && running) {
      stepStatus = 'Esperando detector de pasos';

      // Respaldo: actualizar directamente los pasos acumulados.
      void fallback() {
        if (!_active(generation) || !running || _stepsSub != null) return;
        _lastRawSteps = null;
        stepStatus = 'Esperando podómetro acumulativo';
        try {
          _stepsSub = Pedometer.stepCountStream.listen(
                (event) {
              if (!_active(generation) || !running) return;
              _processSteps(event);
              _notify();
            },
            onError: (Object error) {
              if (!_active(generation)) return;
              stepStatus = 'Podómetro no disponible';
              _notify();
            },
            cancelOnError: true,
          );
        } catch (_) {
          stepStatus = 'Podómetro no disponible';
        }
        _notify();
      }

      try {
        _realStepsSub = StepDetectorService.stepStream.listen(
              (event) {
            if (!_active(generation) || !running || event != 1) return;
            steps++;
            stepStatus = 'Detector de pasos activo';
            _notify();
          },
          onError: (Object error) => fallback(),
          onDone: fallback,
          cancelOnError: true,
        );
      } catch (_) {
        fallback();
      }
    } else {
      stepStatus = 'Podómetro sin activar o sin permiso';
    }

    // ========================================
    // GPS
    // ========================================

    if (hasLocation) {

      gpsStatus = 'Buscando señal GPS';

      try {

        _gpsSub = Geolocator.getPositionStream(

          locationSettings: const LocationSettings(

            accuracy: LocationAccuracy.high,

            distanceFilter: 3,
          ),

        ).listen(

              (position) {

            if (!_active(generation)) return;

            _processPosition(position);

            _notify();
          },

          onError: (Object error) {

            if (!_active(generation)) return;

            gpsStatus = 'Error de ubicación';

            _notify();
          },

          cancelOnError: true,
        );

      } catch (_) {

        gpsStatus = 'GPS no disponible';
      }

    } else if (!location) {

      gpsStatus = 'GPS sin activar';
    }

    _resumeClock();

    _notify();
  }

  // ==========================================
  // LIBERAR SUSCRIPCIONES
  // ==========================================

  Future<void> _cancelSubscriptions() async {

    listening = false;

    _pauseClock();

    final subscriptions =
    <StreamSubscription<dynamic>?>[
      _stepsSub,
      _realStepsSub,
      _accelSub,
      _gyroSub,
      _gpsSub,
    ];

    _stepsSub = null;
    _realStepsSub = null;
    _accelSub = null;
    _gyroSub = null;
    _gpsSub = null;

    _lastRawSteps = null;

    _lastGyroTime = null;

    accelerometerAvailable = false;

    gyroscopeAvailable = false;

    _quietSince = null;

    _newSegment = true;

    await Future.wait(

      subscriptions
          .whereType<StreamSubscription<dynamic>>()
          .map((subscription) async {

        try {

          await subscription.cancel();

        } catch (_) {

          // Continuar liberando los demás sensores.
        }
      }),
    );
  }

  // ==========================================
  // PAUSAR SENSORES
  // ==========================================

  Future<void> stopListening() async {

    final generation = ++_generation;

    await _cancelSubscriptions();

    if (!_valid(generation)) return;

    sensorStatus = 'Sensores suspendidos';

    accelerometerStatus = 'Acelerómetro suspendido';

    gyroscopeStatus = 'Giroscopio suspendido';

    stepStatus = 'Podómetro suspendido';

    gpsStatus = 'GPS suspendido';

    _notify();
  }

  // ==========================================
  // FINALIZAR ENTRENAMIENTO
  // ==========================================

  Future<Workout?> finish() async {

    if (!running) return null;

    _pauseClock();

    running = false;

    await stopListening();

    final workout = Workout(

      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),

      date: (_startedAt ?? DateTime.now())
          .toIso8601String(),

      seconds: seconds,

      steps: steps,

      distanceMeters: distanceMeters,

      intensity: dominantIntensity,

      route: route
          .map((p) => [
        p.latitude,
        p.longitude,
      ])
          .toList(),

      routeBreaks: List<int>.from(routeBreaks),
    );

    await saveWorkout(workout);

    _notify();

    return workout;
  }

  // ==========================================
  // HISTORIAL POR USUARIO
  // ==========================================

  String get _historyKey {

    final email = user?.email ?? 'unknown';

    // Conservar la clave original.
    return 'nexpulse_history_$email';
  }

  // ==========================================
  // GUARDAR ENTRENAMIENTO
  // ==========================================

  Future<void> saveWorkout(Workout workout) async {

    final prefs =
    await SharedPreferences.getInstance();

    final history = await getHistory();

    history.insert(0, workout);

    final saved = await prefs.setString(

      _historyKey,

      jsonEncode(
        history.map((e) => e.toJson()).toList(),
      ),
    );

    if (!saved) {

      throw Exception(
        'No se pudo guardar el entrenamiento.',
      );
    }
  }

  // ==========================================
  // ELIMINAR ENTRENAMIENTO
  // ==========================================

  Future<void> deleteWorkout(String id) async {

    final prefs =
    await SharedPreferences.getInstance();

    final history = await getHistory();

    // Eliminar únicamente el registro seleccionado.
    history.removeWhere(
          (workout) => workout.id == id,
    );

    // Guardar los registros restantes.
    final saved = await prefs.setString(

      _historyKey,

      jsonEncode(
        history.map((e) => e.toJson()).toList(),
      ),
    );

    if (!saved) {

      throw Exception(
        'No se pudo eliminar el entrenamiento.',
      );
    }

    _notify();
  }

  // ==========================================
  // OBTENER HISTORIAL
  // ==========================================

  Future<List<Workout>> getHistory() async {

    final prefs =
    await SharedPreferences.getInstance();

    final raw = prefs.getString(_historyKey);

    if (raw == null) return [];

    final list = jsonDecode(raw) as List;

    return list.map((e) {

      return Workout.fromJson(
        Map<String, dynamic>.from(e as Map),
      );

    }).toList();
  }

  // ==========================================
  // LIBERAR RECURSOS
  // ==========================================

  @override
  void dispose() {

    _disposed = true;

    _generation++;

    running = false;

    listening = false;

    _clock.stop();

    _timer?.cancel();

    unawaited(_cancelSubscriptions());

    super.dispose();
  }
}
