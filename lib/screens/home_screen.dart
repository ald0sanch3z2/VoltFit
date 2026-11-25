import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:permission_handler/permission_handler.dart';

import '../models/app_user.dart';
import '../models/workout.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {

  // ==========================================
  // COLORES DE VOLTFIT
  // ==========================================

  static const background = Color(0xFF080F1C);
  static const surface = Color(0xFF111D2E);
  static const border = Color(0xFF26364B);
  static const cyan = Color(0xFF22D3EE);
  static const emerald = Color(0xFF10B981);
  static const muted = Color(0xFF94A3B8);

  // ==========================================
  // SERVICIOS Y VARIABLES
  // ==========================================

  final WorkoutService service = WorkoutService();
  final AuthService auth = AuthService();

  final ScrollController _profileController =
  ScrollController();

  final GlobalKey _securityKey = GlobalKey();

  late AppUser user;

  int tab = 0;

  bool busy = false;
  bool profileUnlocked = false;
  bool _pendingProfileUnlock = false;

  bool _foreground = true;
  bool _preview = false;
  bool _permissionFlow = false;

  bool _biometricOfferShown = false;

  int _activation = 0;

  List<Workout> history = [];

  // ==========================================
  // INICIALIZAR PANTALLA
  // ==========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    user = widget.user;

    service.setUser(user);

    service.addListener(_refresh);

    _loadHistory();

    // Mostrar alerta después de iniciar sesión.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _offerBiometrics();
      }
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================
  // ALERTA PARA ACTIVAR BIOMETRÍA
  // ==========================================

  Future<void> _offerBiometrics() async {
    if (_biometricOfferShown || !mounted) return;

    _biometricOfferShown = true;

    try {
      final remembered = await auth.lastBiometricUser();

      // No mostrar alerta si ya está configurada.
      if (user.biometricEnabled &&
          remembered?.email == user.email) {
        return;
      }

      final available = await auth.canUseBiometrics();

      if (!mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: surface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),

          icon: Container(
            width: 85,
            height: 85,
            alignment: Alignment.center,

            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.fingerprint,
              size: 52,
              color: cyan,
            ),
          ),

          title: const Text(
            'Activa tu acceso biométrico',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),

          content: Text(
            available
                ? '¿Quieres activar el acceso mediante '
                'huella dactilar o reconocimiento facial '
                'compatible?\n\n'
                'Podrás iniciar sesión sin escribir '
                'tu correo ni tu contraseña.\n\n'
                'Solo una cuenta puede tener acceso '
                'biométrico en este dispositivo.'
                : 'Puedes configurar el acceso biométrico '
                'desde tu perfil.\n\n'
                'Primero deberás registrar una huella '
                'o un método compatible en los ajustes '
                'de tu teléfono.',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: muted,
              height: 1.5,
            ),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Ahora no'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (!mounted || accepted != true) return;

      // Redirigir al perfil.
      await _changeTab(4);

      if (!mounted) return;

      // Desplazarse al apartado de seguridad.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final securityContext = _securityKey.currentContext;

        if (securityContext != null) {
          Scrollable.ensureVisible(
            securityContext,

            duration: const Duration(milliseconds: 500),

            curve: Curves.easeInOut,

            alignment: 0.1,
          );
        }
      });
    } catch (_) {
      _message(
        'No se pudo comprobar la disponibilidad biométrica.',
      );
    }
  }

  // ==========================================
  // CARGAR HISTORIAL
  // ==========================================

  Future<void> _loadHistory() async {
    try {
      final data = await service.getHistory();

      if (mounted) {
        setState(() => history = data);
      }
    } catch (_) {
      _message('No se pudo cargar el historial.');
    }
  }

  // ==========================================
  // MOSTRAR MENSAJES
  // ==========================================

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================
  // EXPLICAR PERMISOS
  // ==========================================

  Future<bool> _explainPermissions() async {
    final accepted = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,

        icon: const Icon(
          Icons.shield_outlined,
          color: cyan,
          size: 42,
        ),

        title: const Text(
          'Permisos de actividad',
        ),

        content: const Text(
          'VoltFit utiliza el permiso de actividad física '
              'para registrar pasos y el permiso de ubicación '
              'para guardar recorridos GPS.\n\n'
              'Los registros se almacenan localmente.\n\n'
              'Puedes rechazar los permisos, aunque algunas '
              'funciones no estarán disponibles.',
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },

            child: const Text('Cancelar'),
          ),

          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },

            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    return accepted == true;
  }

  // ==========================================
  // ACTIVAR SENSORES
  // ==========================================

  Future<void> _activate({
    bool ask = false,
  }) async {
    if (busy || !_foreground || tab > 2) return;

    final token = ++_activation;

    setState(() => busy = true);

    try {
      _permissionFlow = ask;

      if (ask && !await _explainPermissions()) {
        return;
      }

      if (!mounted || token != _activation) return;

      bool activityGranted = false;
      bool locationGranted = false;

      // Solicitar actividad únicamente si existe
      // un entrenamiento activo.
      if (service.running) {
        final activity = ask
            ? await Permission.activityRecognition.request()
            : await Permission.activityRecognition.status;

        activityGranted = activity.isGranted;
      }

      // Solicitar GPS únicamente cuando sea necesario.
      if (service.running || tab == 2) {
        locationGranted = await service.requestLocation(
          ask: ask,
        );
      }

      if (!mounted ||
          token != _activation ||
          !_foreground ||
          tab > 2) {
        return;
      }

      _preview = !service.running;

      await service.activateSensors(
        activity: activityGranted,

        location: locationGranted,

        motion: service.running || tab == 1,

        askPermissions: false,
      );

      if (!mounted ||
          token != _activation ||
          !_foreground) {
        await service.stopListening();
      }
    } catch (e) {
      _message('Error al activar los sensores: $e');
    } finally {
      _permissionFlow = false;

      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // INICIAR ENTRENAMIENTO
  // ==========================================

  Future<void> _start() async {
    if (busy || service.running) return;

    setState(() => busy = true);

    _permissionFlow = true;

    final token = ++_activation;

    try {
      if (!await _explainPermissions()) return;

      if (!mounted || token != _activation) return;

      final activity =
      await Permission.activityRecognition.request();

      final location = await service.requestLocation();

      if (!mounted ||
          token != _activation ||
          !_foreground) {
        return;
      }

      if (!activity.isGranted) {
        _message(
          'Sin permiso de actividad no se contarán pasos.',
        );
      }

      await service.start();

      if (!mounted ||
          token != _activation ||
          !_foreground) {
        return;
      }

      _preview = false;

      await service.activateSensors(
        activity: activity.isGranted,

        location: location,

        askPermissions: false,
      );

      if (!mounted ||
          token != _activation ||
          !_foreground) {
        await service.stopListening();
        return;
      }

      _message('Entrenamiento iniciado');
    } catch (e) {
      _message('Error al iniciar: $e');
    } finally {
      _permissionFlow = false;

      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // PAUSAR ENTRENAMIENTO
  // ==========================================

  Future<void> _pause() async {
    if (busy || !service.running) return;

    setState(() => busy = true);

    ++_activation;

    try {
      await service.stopListening();

      _message('Entrenamiento pausado');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // FINALIZAR ENTRENAMIENTO
  // ==========================================

  Future<void> _finish() async {
    if (busy) return;

    setState(() => busy = true);

    ++_activation;

    try {
      final workout = await service.finish();

      _preview = false;

      await _loadHistory();

      if (workout != null) {
        _message(
          'Entrenamiento guardado correctamente',
        );
      }
    } catch (e) {
      _message(
        'Error al guardar el entrenamiento: $e',
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // CAMBIAR PANTALLA
  // ==========================================

  Future<void> _changeTab(int index) async {
    if (index == tab || busy) return;

    ++_activation;

    _preview = false;
    _pendingProfileUnlock = false;

    setState(() {
      tab = index;
      profileUnlocked = false;
    });

    // Suspender sensores al entrar al historial
    // o al perfil.
    if (index > 2 || !service.running) {
      await service.stopListening();
    }

    if (!mounted || tab != index) return;

    if (index == 3) {
      await _loadHistory();
    }

    // Los entrenamientos pausados pueden
    // reanudarse manualmente.
  }

  // ==========================================
  // CICLO DE VIDA DE LA APLICACIÓN
  // ==========================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    _foreground = state == AppLifecycleState.resumed;

    if (!_foreground) {
      if (!_permissionFlow ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {

        if (!_permissionFlow) {
          ++_activation;
        }

        unawaited(service.stopListening());
      }

      // Invalidar resultados pendientes si se abandona realmente la app.
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        _pendingProfileUnlock = false;
      }
      // Bloquear datos personales al salir de la app.
      if (mounted && profileUnlocked) {
        setState(() => profileUnlocked = false);
      }

      return;
    }

    // Mostrar datos solo tras una autenticación exitosa y al volver.
    if (_pendingProfileUnlock) {
      _pendingProfileUnlock = false;
      if (mounted && tab == 4 && user.biometricEnabled) {
        setState(() => profileUnlocked = true);
      }
    }

    // Reactivar únicamente la vista previa.
    // Los entrenamientos se reanudan manualmente.
    if (!busy &&
        !_permissionFlow &&
        tab <= 2 &&
        _preview &&
        !service.running) {
      unawaited(_activate());
    }
  }

  // ==========================================
  // LIBERAR RECURSOS
  // ==========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _profileController.dispose();

    service.removeListener(_refresh);

    service.dispose();

    super.dispose();
  }

  // ==========================================
  // FORMATO DE DURACIÓN
  // ==========================================

  String _duration(int value) {
    final h = value ~/ 3600;
    final m = (value % 3600) ~/ 60;
    final s = value % 60;

    String two(int n) {
      return n.toString().padLeft(2, '0');
    }

    return '${two(h)}:${two(m)}:${two(s)}';
  }

  // ==========================================
  // FORMATO DE MEDICIONES
  // ==========================================

  String _measurement(
      double value,
      String unit,
      bool available, {
        int decimals = 2,
      }) {
    if (!available || !value.isFinite) {
      return 'Sin datos';
    }

    final formatted = value.toStringAsFixed(decimals);

    final number = double.parse(formatted);

    final result = number == 0
        ? 0.0.toStringAsFixed(decimals)
        : formatted;

    return '$result $unit';
  }

  // ==========================================
  // ENCABEZADO DE PANTALLA
  // ==========================================

  Widget _pageHeader(
      String title,
      String subtitle,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),

      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(18),

              border: Border.all(
                color: cyan.withValues(alpha: 0.20),
              ),
            ),

            child: Icon(
              icon,
              color: cyan,
              size: 30,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,

                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TÍTULO DE SECCIÓN
  // ==========================================

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 12,
      ),

      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,

            decoration: BoxDecoration(
              color: cyan,

              borderRadius: BorderRadius.circular(5),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              title,

              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TARJETA PROFESIONAL REUTILIZABLE
  // ==========================================

  Widget _tile(
      String title,
      String value,
      IconData icon, {
        Color color = cyan,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xFF152337),
            surface,
          ],
        ),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: border),
      ),

      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(15),
            ),

            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value,

                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TARJETA COMPACTA DE ESTADÍSTICAS
  // ==========================================

  Widget _metricCard(
      String title,
      String value,
      String unit,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: surface,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(13),
            ),

            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,

            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,

            alignment: Alignment.centerLeft,

            child: Text(
              value,

              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),

          const SizedBox(height: 3),

          Text(
            unit,

            style: const TextStyle(
              fontSize: 11,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ESTADO DE ENTRENAMIENTO
  // ==========================================

  Widget _statusChip(
      String text,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: color,
          ),

          const SizedBox(width: 8),

          Text(
            text,

            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PANTALLA PRINCIPAL
  // ==========================================

  Widget _home() {
    final firstName = user.name.trim().split(' ').first;

    final status = service.paused
        ? 'PAUSADO'
        : service.running
        ? 'EN CURSO'
        : 'DISPONIBLE';

    final statusColor = service.paused
        ? Colors.orange
        : service.running
        ? emerald
        : cyan;

    return ListView(
      padding: const EdgeInsets.all(20),

      children: [
        _pageHeader(
          'Hola, $firstName',
          'Panel de actividad',
          Icons.dashboard_outlined,
        ),

        // ====================================
        // TARJETA PRINCIPAL
        // ====================================

        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                Color(0xFF164E63),
                Color(0xFF102B40),
                surface,
              ],
            ),

            borderRadius: BorderRadius.circular(28),

            border: Border.all(
              color: cyan.withValues(alpha: 0.25),
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SESIÓN DE ACTIVIDAD',

                      style: TextStyle(
                        color: cyan,
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  _statusChip(status, statusColor),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Tiempo registrado',

                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              FittedBox(
                fit: BoxFit.scaleDown,

                child: Text(
                  _duration(service.seconds),

                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const SizedBox(
                height: 50,
                width: double.infinity,

                child: CustomPaint(
                  painter: VoltPulsePainter(),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                service.running
                    ? 'Registro de actividad'
                    : 'Inicia una sesión para registrar '
                    'tus mediciones.',

                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        _section('Estadísticas de la sesión'),

        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Pasos',
                '${service.steps}',
                'Pasos registrados',
                Icons.directions_walk,
                cyan,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _metricCard(
                'Distancia',
                service.distanceMeters.toStringAsFixed(1),
                'Metros estimados',
                Icons.route,
                emerald,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _tile(
          'Actividad detectada',

          service.accelerometerAvailable
              ? service.intensity
              : 'Sin datos',

          Icons.monitor_heart_outlined,

          color: emerald,
        ),

        _section('Control de actividad'),

        // ====================================
        // BOTÓN DE INICIO
        // ====================================

        if (!service.running)
          FilledButton.icon(
            onPressed: busy ? null : _start,

            icon: const Icon(Icons.play_arrow_rounded),

            label: const Text('Iniciar entrenamiento'),
          ),

        // ====================================
        // BOTONES DE PAUSA Y REANUDACIÓN
        // ====================================

        if (service.running) ...[
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : service.paused
                ? () => _activate()
                : _pause,

            icon: Icon(
              service.paused
                  ? Icons.play_arrow
                  : Icons.pause,
            ),

            label: Text(
              service.paused
                  ? 'Reanudar entrenamiento'
                  : 'Pausar entrenamiento',
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: busy ? null : _finish,

            icon: const Icon(Icons.stop_circle_outlined),

            label: const Text('Finalizar y guardar'),
          ),
        ],

        _section('Estado de los servicios'),

        _tile(
          'Podómetro',
          service.stepStatus,
          Icons.directions_walk,
        ),

        _tile(
          'Localización',
          service.gpsStatus,
          Icons.gps_fixed,
          color: emerald,
        ),

        const SizedBox(height: 15),

        const Text(
          'VOLTFIT · SMART ACTIVITY SYSTEM',

          textAlign: TextAlign.center,

          style: TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TARJETA DE EJES DEL SENSOR
  // ==========================================

  Widget _axisCard(
      String axis,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 18,
      ),

      decoration: BoxDecoration(
        color: surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: border),
      ),

      child: Column(
        children: [
          CircleAvatar(
            radius: 17,

            backgroundColor: color.withValues(alpha: 0.15),

            child: Text(
              axis,

              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 14),

          FittedBox(
            fit: BoxFit.scaleDown,

            child: Text(
              value,

              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PANTALLA DE SENSORES
  // ==========================================

  Widget _sensors() {
    return ListView(
      padding: const EdgeInsets.all(20),

      children: [
        _pageHeader(
          'Sensores',
          'Mediciones del dispositivo en tiempo real',
          Icons.sensors,
        ),

        Container(
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: surface,

            borderRadius: BorderRadius.circular(24),

            border: Border.all(color: border),
          ),

          child: Column(
            children: [
              Icon(
                service.stationary
                    ? Icons.smartphone
                    : Icons.sensors,

                size: 54,

                color: service.stationary
                    ? emerald
                    : cyan,
              ),

              const SizedBox(height: 15),

              Text(
                !service.accelerometerAvailable
                    ? 'Sensores sin datos'
                    : service.stationary
                    ? 'Dispositivo en reposo'
                    : 'Reposo no confirmado',

                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              _statusChip(
                service.listening
                    ? 'MONITOREO ACTIVO'
                    : 'MONITOREO SUSPENDIDO',

                service.listening
                    ? emerald
                    : Colors.orange,
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        if (!service.listening)
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => _activate(ask: true),

            icon: const Icon(Icons.sensors),

            label: const Text('Activar sensores'),
          ),

        // ====================================
        // ACELERÓMETRO
        // ====================================

        _section('Acelerómetro'),

        const Text(
          'Aceleración por eje · m/s²',

          style: TextStyle(
            color: muted,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _axisCard(
                'X',

                _measurement(
                  service.ax,
                  '',
                  service.accelerometerAvailable,
                ),

                Colors.redAccent,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _axisCard(
                'Y',

                _measurement(
                  service.ay,
                  '',
                  service.accelerometerAvailable,
                ),

                emerald,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _axisCard(
                'Z',

                _measurement(
                  service.az,
                  '',
                  service.accelerometerAvailable,
                ),

                cyan,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _tile(
          'Magnitud de aceleración',

          _measurement(
            service.magnitude,
            'm/s²',
            service.accelerometerAvailable,
          ),

          Icons.analytics_outlined,
        ),

        _tile(
          'Movimiento sin gravedad estimado',

          _measurement(
            service.movement,
            'm/s²',
            service.accelerometerAvailable,
          ),

          Icons.vibration,
        ),

        _tile(
          'Actividad detectada',

          service.accelerometerAvailable
              ? service.intensity
              : 'Sin datos',

          Icons.directions_walk,

          color: emerald,
        ),

        const SizedBox(height: 10),

        const Text(
          'En reposo, la magnitud debe permanecer cerca '
              'de 9.81 m/s². Los valores de cada eje dependen '
              'de la orientación del dispositivo.',

          style: TextStyle(
            color: muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),

        // ====================================
        // GIROSCOPIO
        // ====================================

        _section('Giroscopio'),

        const Text(
          'Velocidad angular · rad/s',

          style: TextStyle(
            color: muted,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _axisCard(
                'X',

                _measurement(
                  service.gx,
                  '',
                  service.gyroscopeAvailable,
                ),

                Colors.redAccent,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _axisCard(
                'Y',

                _measurement(
                  service.gy,
                  '',
                  service.gyroscopeAvailable,
                ),

                emerald,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _axisCard(
                'Z',

                _measurement(
                  service.gz,
                  '',
                  service.gyroscopeAvailable,
                ),

                cyan,
              ),
            ),
          ],
        ),

        // ====================================
        // ORIENTACIÓN
        // ====================================

        _section('Orientación estimada'),

        _tile(
          'Roll · Rotación lateral',

          _measurement(
            service.roll,
            '°',
            service.gyroscopeAvailable,
            decimals: 1,
          ),

          Icons.rotate_right,
        ),

        _tile(
          'Pitch · Inclinación',

          _measurement(
            service.pitch,
            '°',
            service.gyroscopeAvailable,
            decimals: 1,
          ),

          Icons.screen_rotation,
        ),

        _tile(
          'Yaw · Rotación relativa',

          _measurement(
            service.yaw,
            '°',
            service.gyroscopeAvailable,
            decimals: 1,
          ),

          Icons.explore_outlined,
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: service.gyroscopeAvailable
              ? service.resetOrientation
              : null,

          icon: const Icon(Icons.restart_alt),

          label: const Text('Reiniciar orientación'),
        ),

        const SizedBox(height: 16),

        const Text(
          'Los filtros reducen el ruido de los sensores. '
              'La orientación es aproximada y el yaw puede '
              'acumular error con el tiempo.',

          style: TextStyle(
            color: muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),

        _section('Diagnóstico'),

        _tile(
          'Acelerómetro',
          service.accelerometerStatus,
          Icons.sensors,
        ),

        _tile(
          'Giroscopio',
          service.gyroscopeStatus,
          Icons.screen_rotation,
        ),
      ],
    );
  }

  // ==========================================
  // PANTALLA DEL MAPA
  // ==========================================

  Widget _map() {
    final hasPosition =
        service.latitude != null &&
            service.longitude != null;

    final center = hasPosition
        ? LatLng(
      service.latitude!,
      service.longitude!,
    )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: const EdgeInsets.all(20),

          children: [
            _pageHeader(
              'Localización',
              'Recorrido y posicionamiento GPS',
              Icons.map_outlined,
            ),

            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: surface,

                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: border),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons.gps_fixed,

                    color: hasPosition
                        ? emerald
                        : Colors.orange,

                    size: 30,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Estado de localización',

                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          service.gpsStatus,

                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ==================================
            // MAPA INTERACTIVO
            // ==================================

            Container(
              height: 330,

              decoration: BoxDecoration(
                color: surface,

                borderRadius: BorderRadius.circular(24),

                border: Border.all(color: border),
              ),

              clipBehavior: Clip.antiAlias,

              child: center == null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [
                      const Icon(
                        Icons.location_searching,

                        color: cyan,
                        size: 60,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Esperando ubicación GPS',

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Activa la ubicación para '
                            'visualizar tu posición.',

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 20),

                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _activate(
                          ask: true,
                        ),

                        icon: const Icon(
                          Icons.my_location,
                        ),

                        label: const Text(
                          'Activar ubicación',
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : FlutterMap(
                key: const ValueKey('live-map'),

                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 17,
                ),

                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                    userAgentPackageName:
                    'com.example.app_fitnes',
                  ),

                  PolylineLayer(
                    polylines: [
                      for (final segment
                      in service.routeSegments)
                        if (segment.length >= 2)
                          Polyline(
                            points: segment,
                            color: cyan,
                            strokeWidth: 5,
                          ),
                    ],
                  ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,

                        width: 48,
                        height: 48,

                        child: Container(
                          decoration: BoxDecoration(
                            color: cyan.withValues(
                              alpha: 0.20,
                            ),

                            shape: BoxShape.circle,
                          ),

                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: cyan,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!service.listening && center != null) ...[
              const SizedBox(height: 14),

              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _activate(ask: true),

                icon: const Icon(Icons.gps_fixed),

                label: const Text('Reactivar ubicación'),
              ),
            ],

            _section('Información geográfica'),

            _tile(
              'Latitud',

              service.latitude?.toStringAsFixed(6)
                  ?? 'Sin datos',

              Icons.location_on_outlined,
            ),

            _tile(
              'Longitud',

              service.longitude?.toStringAsFixed(6)
                  ?? 'Sin datos',

              Icons.explore_outlined,
            ),

            _tile(
              'Precisión GPS estimada',

              service.accuracy != null
                  ? '±${service.accuracy!.toStringAsFixed(1)} m'
                  : 'Sin datos',

              Icons.gps_fixed,

              color: emerald,
            ),

            _tile(
              'Puntos del recorrido',

              '${service.route.length}',

              Icons.route,
            ),

            const SizedBox(height: 12),

            const Text(
              'La precisión depende de la señal GPS y '
                  'las condiciones del entorno. Los mapas '
                  'requieren conexión a Internet.',

              style: TextStyle(
                color: muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // RECONSTRUIR RECORRIDOS DEL HISTORIAL
  // ==========================================

  List<List<LatLng>> _historySegments(
      Workout item,
      ) {
    final points = item.route
        .map(
          (p) => LatLng(p[0], p[1]),
    )
        .toList();

    if (points.isEmpty) return [];

    final breaks = item.routeBreaks
        .where(
          (i) => i > 0 && i < points.length,
    )
        .toSet()
        .toList()
      ..sort();

    final result = <List<LatLng>>[];

    int start = 0;

    for (final end in breaks) {
      result.add(
        points.sublist(start, end),
      );

      start = end;
    }

    result.add(
      points.sublist(start),
    );

    return result;
  }

  // ==========================================
  // ELIMINAR ENTRENAMIENTO
  // ==========================================

  Future<void> _deleteWorkout(
      Workout item,
      ) async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),

        icon: const Icon(
          Icons.delete_forever_outlined,
          color: Colors.redAccent,
          size: 48,
        ),

        title: const Text(
          'Eliminar entrenamiento',
        ),

        content: const Text(
          '¿Estás seguro de eliminar este registro?\n\n'
              'Se eliminarán los pasos, la duración, '
              'la distancia y el recorrido almacenado.\n\n'
              'Esta acción no se puede deshacer.',
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },

            child: const Text('Cancelar'),
          ),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),

            onPressed: () {
              Navigator.pop(dialogContext, true);
            },

            icon: const Icon(Icons.delete_outline),

            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || busy) {
      return;
    }

    setState(() => busy = true);

    try {
      await service.deleteWorkout(item.id);

      await _loadHistory();

      _message(
        'Entrenamiento eliminado correctamente',
      );
    } catch (e) {
      _message('Error al eliminar el registro: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // FORMATO DE FECHA
  // ==========================================

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();

    if (date == null) return value;

    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return '${date.day} de '
        '${months[date.month - 1]} '
        'de ${date.year}';
  }

  // ==========================================
  // TARJETA DE ENTRENAMIENTO GUARDADO
  // ==========================================

  Widget _historyCard(Workout item) {
    return Card(
      key: ValueKey(item.id),

      clipBehavior: Clip.antiAlias,

      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),

        childrenPadding: const EdgeInsets.all(16),

        leading: Container(
          width: 46,
          height: 46,

          decoration: BoxDecoration(
            color: emerald.withValues(alpha: 0.12),

            borderRadius: BorderRadius.circular(14),
          ),

          child: const Icon(
            Icons.history,
            color: emerald,
          ),
        ),

        title: Text(
          _formatDate(item.date),

          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),

          child: Text(
            '${item.steps} pasos · '
                '${item.distanceMeters.toStringAsFixed(1)} m',

            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ),

        children: [
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Pasos',
                  '${item.steps}',
                  'Registrados',
                  Icons.directions_walk,
                  cyan,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _metricCard(
                  'Distancia',
                  item.distanceMeters.toStringAsFixed(1),
                  'Metros estimados',
                  Icons.route,
                  emerald,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _tile(
            'Duración',

            _duration(item.seconds),

            Icons.timer_outlined,
          ),

          _tile(
            'Actividad predominante',

            item.intensity,

            Icons.monitor_heart_outlined,

            color: emerald,
          ),

          _tile(
            'Puntos GPS registrados',

            '${item.route.length}',

            Icons.route,
          ),

          // ==================================
          // MAPA DEL RECORRIDO GUARDADO
          // ==================================

          if (item.route.isNotEmpty) ...[
            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(18),

              child: SizedBox(
                height: 230,

                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      item.route.first[0],
                      item.route.first[1],
                    ),

                    initialZoom: 15,
                  ),

                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                      userAgentPackageName:
                      'com.example.app_fitnes',
                    ),

                    PolylineLayer(
                      polylines: [
                        for (final segment
                        in _historySegments(item))
                          if (segment.length >= 2)
                            Polyline(
                              points: segment,
                              color: emerald,
                              strokeWidth: 5,
                            ),
                      ],
                    ),

                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ==================================
          // BOTÓN ELIMINAR
          // ==================================

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _deleteWorkout(item),

              icon: const Icon(Icons.delete_outline),

              label: const Text(
                'Eliminar entrenamiento',
              ),

              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,

                side: const BorderSide(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PANTALLA DE HISTORIAL
  // ==========================================

  Widget _history() {
    return ListView(
      padding: const EdgeInsets.all(20),

      children: [
        _pageHeader(
          'Historial',
          'Consulta tus registros de actividad',
          Icons.history,
        ),

        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF164E63),
                surface,
              ],
            ),

            borderRadius: BorderRadius.circular(24),

            border: Border.all(color: border),
          ),

          child: Row(
            children: [
              const Icon(
                Icons.folder_copy_outlined,
                color: cyan,
                size: 42,
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      '${history.length}',

                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const Text(
                      'Entrenamientos guardados',

                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        _section('Registros de actividad'),

        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),

            decoration: BoxDecoration(
              color: surface,

              borderRadius: BorderRadius.circular(24),

              border: Border.all(color: border),
            ),

            child: Column(
              children: [
                const Icon(
                  Icons.history_toggle_off,
                  size: 65,
                  color: muted,
                ),

                const SizedBox(height: 20),

                const Text(
                  'No hay registros',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Los entrenamientos que guardes '
                      'aparecerán en esta sección.',

                  textAlign: TextAlign.center,

                  style: TextStyle(color: muted),
                ),

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _changeTab(0),

                  icon: const Icon(Icons.home_outlined),

                  label: const Text('Ir al inicio'),
                ),
              ],
            ),
          )
        else
          for (final item in history)
            _historyCard(item),
      ],
    );
  }

  // ==========================================
  // ACTIVAR O DESACTIVAR BIOMETRÍA
  // ==========================================

  Future<void> _toggleBiometric(
      bool enabled,
      ) async {
    if (busy) return;

    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,

        builder: (dialogContext) => AlertDialog(
          backgroundColor: surface,

          icon: const Icon(
            Icons.fingerprint,
            size: 52,
            color: cyan,
          ),

          title: const Text(
            'Configurar acceso biométrico',
          ),

          content: const Text(
            'VoltFit utilizará la huella dactilar o '
                'el reconocimiento facial compatible '
                'configurado en Android.\n\n'
                'Si otra cuenta tiene acceso biométrico '
                'en este dispositivo, será sustituida.\n\n'
                'Confirma tu identidad para continuar.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancelar'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('Verificar'),
            ),
          ],
        ),
      );

      if (accepted != true) return;
    }

    if (!mounted || busy) return;

    setState(() => busy = true);

    try {
      final updated = await auth.setBiometrics(
        user,
        enabled,
      );

      if (!mounted) return;

      setState(() {
        user = updated;
        profileUnlocked = false;
      });

      service.setUser(updated);

      _message(
        enabled
            ? 'Acceso biométrico activado correctamente'
            : 'Acceso biométrico desactivado',
      );
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // DESBLOQUEAR INFORMACIÓN DEL PERFIL
  // ==========================================

  Future<void> _unlockProfile() async {
    if (busy || tab != 4 || !_foreground || !user.biometricEnabled) return;

    _pendingProfileUnlock = false;
    setState(() {
      busy = true;
      profileUnlocked = false;
    });

    try {
      final authenticated = await auth.authenticateBiometric();
      if (!mounted || tab != 4) return;

      if (!authenticated) {
        _message('No se pudo verificar tu identidad.');
        return;
      }

      // Android puede devolver el resultado antes de emitir resumed.
      if (_foreground) {
        setState(() => profileUnlocked = true);
      } else {
        _pendingProfileUnlock = true;
      }
    } catch (e) {
      _pendingProfileUnlock = false;
      _message('Error de autenticación: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ==========================================
  // CERRAR SESIÓN
  // ==========================================

  Future<void> _logout() async {
    if (busy) return;

    if (service.running) {
      _message(
        'Finaliza el entrenamiento antes de cerrar sesión.',
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,

        icon: const Icon(
          Icons.logout,
          size: 42,
          color: cyan,
        ),

        title: const Text('Cerrar sesión'),

        content: const Text(
          '¿Quieres cerrar tu sesión de VoltFit?\n\n'
              'Tus entrenamientos y la configuración '
              'biométrica permanecerán guardados.',
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },

            child: const Text('Cancelar'),
          ),

          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },

            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || busy) return;

    setState(() => busy = true);

    ++_activation;

    try {
      await service.stopListening();

      await auth.logout();

      if (!mounted) return;

      widget.onLogout();
    } catch (e) {
      _message('Error al cerrar sesión: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================
  // PANTALLA DEL PERFIL
  // ==========================================

  Widget _profile() {
    final locked =
        user.biometricEnabled && !profileUnlocked;

    final initial = user.name.trim().isEmpty
        ? 'V'
        : user.name.trim()[0].toUpperCase();

    return ListView(
      controller: _profileController,

      padding: const EdgeInsets.all(20),

      children: [
        _pageHeader(
          'Mi perfil',
          'Cuenta, privacidad y seguridad',
          Icons.manage_accounts_outlined,
        ),

        // ====================================
        // ENCABEZADO DEL PERFIL
        // ====================================

        Container(
          padding: const EdgeInsets.all(26),

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                Color(0xFF164E63),
                Color(0xFF102B40),
                surface,
              ],
            ),

            borderRadius: BorderRadius.circular(28),

            border: Border.all(
              color: cyan.withValues(alpha: 0.20),
            ),
          ),

          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(5),

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  border: Border.all(
                    color: cyan.withValues(alpha: 0.50),
                    width: 2,
                  ),
                ),

                child: CircleAvatar(
                  radius: 43,

                  backgroundColor: cyan.withValues(
                    alpha: 0.15,
                  ),

                  child: locked
                      ? const Icon(
                    Icons.person_outline,
                    color: cyan,
                    size: 42,
                  )
                      : Text(
                    initial,

                    style: const TextStyle(
                      color: cyan,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                locked ? 'Perfil protegido' : user.name,

                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Cuenta personal de VoltFit',

                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 18),

              _statusChip(
                user.biometricEnabled
                    ? 'BIOMETRÍA ACTIVADA'
                    : 'ACCESO CON CONTRASEÑA',

                user.biometricEnabled
                    ? emerald
                    : Colors.orange,
              ),
            ],
          ),
        ),

        _section('Información personal'),

        // ====================================
        // INFORMACIÓN PROTEGIDA
        // ====================================

        if (locked)
          Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: surface,

              borderRadius: BorderRadius.circular(24),

              border: Border.all(color: border),
            ),

            child: Column(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: cyan,
                  size: 48,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Información protegida',

                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Verifica tu identidad para consultar '
                      'tus datos personales.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: muted,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,

                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : _unlockProfile,

                    icon: const Icon(Icons.fingerprint),

                    label: const Text(
                      'Desbloquear perfil',
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _tile(
            'Nombre completo',
            user.name,
            Icons.person_outline,
          ),

          _tile(
            'Correo electrónico',
            user.email,
            Icons.email_outlined,
          ),

          _tile(
            'Sexo',
            user.sex,
            Icons.badge_outlined,
          ),

          if (user.biometricEnabled)
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () {
                setState(
                      () => profileUnlocked = false,
                );
              },

              icon: const Icon(Icons.lock_outline),

              label: const Text('Bloquear perfil'),
            ),
        ],

        // ====================================
        // SEGURIDAD Y ACCESO
        // ====================================

        Container(
          key: _securityKey,

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,

            children: [
              _section('Seguridad y acceso'),

              Container(
                decoration: BoxDecoration(
                  color: surface,

                  borderRadius: BorderRadius.circular(24),

                  border: Border.all(
                    color: cyan.withValues(alpha: 0.35),
                  ),
                ),

                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding:
                      const EdgeInsets.all(18),

                      secondary: Container(
                        width: 48,
                        height: 48,

                        decoration: BoxDecoration(
                          color: cyan.withValues(
                            alpha: 0.12,
                          ),

                          borderRadius:
                          BorderRadius.circular(14),
                        ),

                        child: const Icon(
                          Icons.fingerprint,
                          color: cyan,
                          size: 30,
                        ),
                      ),

                      title: const Text(
                        'Acceso biométrico',

                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      subtitle: const Text(
                        'Huella o reconocimiento facial '
                            'compatible',

                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),

                      value: user.biometricEnabled,

                      onChanged: busy
                          ? null
                          : _toggleBiometric,
                    ),

                    const Divider(
                      indent: 18,
                      endIndent: 18,
                    ),

                    const Padding(
                      padding: EdgeInsets.all(18),

                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: emerald,
                            size: 27,
                          ),

                          SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              'La autenticación biométrica '
                                  'es administrada por Android. '
                                  'VoltFit no almacena imágenes '
                                  'de tu rostro ni de tu huella.',

                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actualizar cuentas que utilizaban
              // la configuración biométrica anterior.
              if (user.biometricEnabled) ...[
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _toggleBiometric(true),

                  icon: const Icon(Icons.refresh),

                  label: const Text(
                    'Actualizar acceso biométrico',
                  ),
                ),
              ],
            ],
          ),
        ),

        // ====================================
        // INFORMACIÓN DE PRIVACIDAD
        // ====================================

        _section('Privacidad'),

        _tile(
          'Almacenamiento',

          'Datos locales',

          Icons.storage_outlined,

          color: emerald,
        ),

        const Padding(
          padding: EdgeInsets.all(8),

          child: Text(
            'Los registros de actividad se almacenan '
                'en este dispositivo. Puedes eliminarlos '
                'individualmente desde el historial.',

            style: TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 22),

        // ====================================
        // CERRAR SESIÓN
        // ====================================

        OutlinedButton.icon(
          onPressed: busy ? null : _logout,

          icon: const Icon(Icons.logout),

          label: const Text('Cerrar sesión'),

          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,

            side: const BorderSide(
              color: Colors.redAccent,
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Icon(
          Icons.bolt,
          color: cyan,
          size: 30,
        ),

        const SizedBox(height: 8),

        const Text(
          'VOLTFIT',

          textAlign: TextAlign.center,

          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'SMART ACTIVITY SYSTEM',

          textAlign: TextAlign.center,

          style: TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1.8,
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // SELECCIONAR PANTALLA ACTUAL
  // ==========================================

  Widget _currentPage() {
    switch (tab) {
      case 0:
        return _home();

      case 1:
        return _sensors();

      case 2:
        return _map();

      case 3:
        return _history();

      case 4:
        return _profile();

      default:
        return _home();
    }
  }

  // ==========================================
  // INTERFAZ PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && tab != 0 && !busy) {
          unawaited(_changeTab(0));
        }
      },

      child: Scaffold(
        backgroundColor: background,

        // ====================================
        // BARRA SUPERIOR
        // ====================================

        appBar: AppBar(
          backgroundColor: background,

          elevation: 0,

          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,

                decoration: BoxDecoration(
                  color: cyan.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  Icons.bolt,
                  color: cyan,
                  size: 28,
                ),
              ),

              const SizedBox(width: 12),

              const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    'VoltFit',

                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  Text(
                    'SMART ACTIVITY SYSTEM',

                    style: TextStyle(
                      color: cyan,
                      fontSize: 8,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),

              child: Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  color: surface,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: border),
                ),

                child: Icon(
                  service.running
                      ? Icons.monitor_heart_outlined
                      : Icons.shield_outlined,

                  color: service.paused
                      ? Colors.orange
                      : emerald,

                  size: 22,
                ),
              ),
            ),
          ],

          bottom: busy
              ? const PreferredSize(
            preferredSize: Size.fromHeight(3),

            child: LinearProgressIndicator(
              minHeight: 3,
              color: cyan,
            ),
          )
              : null,
        ),

        // ====================================
        // CONTENIDO
        // ====================================

        body: SafeArea(
          top: false,

          child: _currentPage(),
        ),

        // ====================================
        // MENÚ INFERIOR
        // ====================================

        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: surface,

            border: Border(
              top: BorderSide(color: border),
            ),
          ),

          child: NavigationBar(
            backgroundColor: surface,

            height: 74,

            elevation: 0,

            selectedIndex: tab,

            indicatorColor: cyan.withValues(alpha: 0.15),

            onDestinationSelected:
            busy ? null : _changeTab,

            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),

                selectedIcon: Icon(Icons.home_rounded),

                label: 'Inicio',
              ),

              NavigationDestination(
                icon: Icon(Icons.sensors_outlined),

                selectedIcon: Icon(Icons.sensors),

                label: 'Sensores',
              ),

              NavigationDestination(
                icon: Icon(Icons.map_outlined),

                selectedIcon: Icon(Icons.map),

                label: 'Mapa',
              ),

              NavigationDestination(
                icon: Icon(Icons.history),

                selectedIcon: Icon(Icons.history),

                label: 'Historial',
              ),

              NavigationDestination(
                icon: Icon(Icons.person_outline),

                selectedIcon: Icon(Icons.person),

                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================
// GRÁFICA DECORATIVA DE VOLTFIT
// ==============================================

// Esta gráfica es decorativa.
// No representa una medición cardíaca real.

class VoltPulsePainter extends CustomPainter {
  const VoltPulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF334155)
          .withValues(alpha: 0.50)
      ..strokeWidth = 0.6;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        grid,
      );
    }

    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        grid,
      );
    }

    final paint = Paint()
      ..color = const Color(0xFF22D3EE)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.16, h * 0.55)
      ..lineTo(w * 0.21, h * 0.35)
      ..lineTo(w * 0.26, h * 0.55)
      ..lineTo(w * 0.36, h * 0.55)
      ..lineTo(w * 0.42, h * 0.90)
      ..lineTo(w * 0.48, h * 0.05)
      ..lineTo(w * 0.54, h * 0.80)
      ..lineTo(w * 0.60, h * 0.35)
      ..lineTo(w * 0.66, h * 0.55)
      ..lineTo(w * 0.80, h * 0.55)
      ..lineTo(w * 0.85, h * 0.40)
      ..lineTo(w * 0.90, h * 0.55)
      ..lineTo(w, h * 0.55);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}
