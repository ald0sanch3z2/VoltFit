import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<AppUser> onLogin;

  const LoginScreen({
    super.key,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();

  final _password = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;

  bool _visible = false;

  bool _checking = true;

  bool _biometricAvailable = false;

  AppUser? _biometricUser;

  static const cyan = Color(0xFF22D3EE);


  // ==========================================
  // COMPROBAR BIOMETRÍA AL ABRIR LA PANTALLA
  // ==========================================

  @override
  void initState() {
    super.initState();

    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final user = await _auth.lastBiometricUser();

      final available = await _auth.canUseBiometrics();

      if (!mounted) return;

      setState(() {
        _biometricUser = user;

        _biometricAvailable = available;

        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _checking = false);
    }
  }

  // ==========================================
  // MOSTRAR MENSAJES
  // ==========================================

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  // ==========================================
  // INICIO DE SESIÓN NORMAL
  // ==========================================

  Future<void> _login() async {
    if (_loading) return;

    if (_email.text.trim().isEmpty) {
      _message('Introduce tu correo electrónico');
      return;
    }

    if (_password.text.isEmpty) {
      _message('Introduce tu contraseña');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      final user = await _auth.login(
        _email.text,
        _password.text,
      );

      if (!mounted) return;

      if (user == null) {
        _message('Correo o contraseña incorrectos');
        return;
      }

      widget.onLogin(user);
    } catch (e) {
      _message('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // INICIO DE SESIÓN BIOMÉTRICO DIRECTO
  // ==========================================

  Future<void> _loginBiometric() async {
    if (_loading || _checking) return;

    if (_biometricUser == null) {
      _message(
        'Primero inicia sesión con contraseña '
            'y activa la biometría desde tu perfil.',
      );

      return;
    }

    if (!_biometricAvailable) {
      _message(
        'No hay biometría compatible configurada. '
            'Utiliza tu contraseña.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      // No se envía correo ni contraseña.
      final user = await _auth.biometricLogin();

      if (!mounted) return;

      if (user == null) {
        _message(
          'No se pudo completar la autenticación.',
        );

        return;
      }

      widget.onLogin(user);
    } catch (e) {
      _message('Error de autenticación: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // ABRIR REGISTRO
  // ==========================================

  Future<void> _openRegister() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    if (mounted) {
      await _checkBiometric();
    }
  }

  @override
  void dispose() {
    _email.dispose();

    _password.dispose();

    super.dispose();
  }

  // ==========================================
  // TARJETA DE ACCESO BIOMÉTRICO
  // ==========================================

  Widget _biometricCard() {
    final ready = _biometricUser != null &&
        _biometricAvailable;

    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF123247),
            Color(0xFF111D2E),
          ],
        ),

        borderRadius: BorderRadius.circular(24),

        border: Border.all(
          color: cyan.withValues(alpha: 0.30),
        ),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.fingerprint,
            size: 64,
            color: cyan,
          ),

          const SizedBox(height: 14),

          const Text(
            'Acceso rápido',

            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _checking
                ? 'Comprobando disponibilidad...'
                : ready
                ? 'Accede con tu huella o rostro compatible.'
                : 'Activa esta función desde tu perfil.',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Color(0xFF94A3B8),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed: _loading || _checking
                  ? null
                  : _loginBiometric,

              icon: const Icon(Icons.fingerprint),

              label: const Text(
                'Iniciar con biometría',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // INTERFAZ DE INICIO DE SESIÓN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,

            end: Alignment.bottomLeft,

            colors: [
              Color(0xFF10263A),
              Color(0xFF080F1C),
              Color(0xFF080F1C),
            ],
          ),
        ),

        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),

              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,

                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,

                          decoration: BoxDecoration(
                            color: cyan.withValues(
                              alpha: 0.12,
                            ),

                            borderRadius:
                            BorderRadius.circular(18),
                          ),

                          child: const Icon(
                            Icons.bolt,
                            size: 38,
                            color: cyan,
                          ),
                        ),

                        const SizedBox(width: 14),

                        const Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            Text(
                              'VoltFit',

                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            Text(
                              'SMART ACTIVITY SYSTEM',

                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: cyan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      height: 75,

                      child: CustomPaint(
                        painter: PulsePainter(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Bienvenido de nuevo',

                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Accede a tu espacio de actividad.',

                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // La biometría aparece directamente.
                    _biometricCard(),

                    const SizedBox(height: 24),

                    const Row(
                      children: [
                        Expanded(child: Divider()),

                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),

                          child: Text(
                            'Acceso con contraseña',

                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _email,

                      enabled: !_loading,

                      keyboardType:
                      TextInputType.emailAddress,

                      autocorrect: false,

                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',

                        prefixIcon: Icon(
                          Icons.email_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _password,

                      enabled: !_loading,

                      obscureText: !_visible,

                      onSubmitted: (_) => _login(),

                      decoration: InputDecoration(
                        labelText: 'Contraseña',

                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                                  () => _visible = !_visible,
                            );
                          },

                          icon: Icon(
                            _visible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : _login,

                      icon: const Icon(Icons.login),

                      label: const Text(
                        'Iniciar sesión',
                      ),
                    ),

                    if (_loading) ...[
                      const SizedBox(height: 18),

                      const LinearProgressIndicator(),
                    ],

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : _openRegister,

                      child: const Text(
                        '¿No tienes cuenta? Regístrate',
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Colors.white38,
                        ),

                        SizedBox(width: 8),

                        Text(
                          'Autenticación local del dispositivo',

                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DIBUJAR GRÁFICA DECORATIVA DE PULSO
// ==========================================

class PulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF26364B)
      ..strokeWidth = 0.6;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final paint = Paint()
      ..color = const Color(0xFF22D3EE)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;

    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.18, h * 0.55)
      ..lineTo(w * 0.23, h * 0.35)
      ..lineTo(w * 0.28, h * 0.55)
      ..lineTo(w * 0.36, h * 0.55)
      ..lineTo(w * 0.41, h * 0.90)
      ..lineTo(w * 0.47, h * 0.05)
      ..lineTo(w * 0.53, h * 0.78)
      ..lineTo(w * 0.59, h * 0.35)
      ..lineTo(w * 0.64, h * 0.55)
      ..lineTo(w * 0.80, h * 0.55)
      ..lineTo(w * 0.85, h * 0.42)
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