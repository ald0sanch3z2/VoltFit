import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();

  final _email = TextEditingController();

  final _password = TextEditingController();

  final _confirm = TextEditingController();

  final _auth = AuthService();

  String _sex = 'Otro';

  bool _loading = false;

  bool _visible = false;

  bool _confirmVisible = false;

  static const cyan = Color(0xFF22D3EE);

  // ==========================================
  // LIBERAR CONTROLADORES
  // ==========================================

  @override
  void dispose() {
    _name.dispose();

    _email.dispose();

    _password.dispose();

    _confirm.dispose();

    super.dispose();
  }

  // ==========================================
  // REGISTRAR USUARIO
  // ==========================================

  Future<void> _register() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await _auth.register(
        name: _name.text,

        email: _email.text,

        sex: _sex,

        password: _password.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta creada correctamente. Inicia sesión.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // ENCABEZADO DE SECCIÓN
  // ==========================================

  Widget _section(
      String number,
      String title,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 18,
      ),

      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(10),
            ),

            child: Text(
              number,

              style: const TextStyle(
                color: cyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            title,

            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 480,
            ),

            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,

                  children: [
                    Align(
                      alignment: Alignment.centerLeft,

                      child: Container(
                        width: 70,
                        height: 70,

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF164E63),
                              Color(0xFF111D2E),
                            ],
                          ),

                          borderRadius:
                          BorderRadius.circular(22),
                        ),

                        child: const Icon(
                          Icons.person_add_alt_1,

                          color: cyan,

                          size: 34,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Comienza con VoltFit',

                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Crea tu cuenta para guardar tus '
                          'actividades y configurar tu acceso.',

                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                      ),
                    ),

                    const SizedBox(height: 28),

                    _section(
                      '01',
                      'Información personal',
                    ),

                    TextFormField(
                      controller: _name,

                      enabled: !_loading,

                      textCapitalization:
                      TextCapitalization.words,

                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',

                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().length < 3 ||
                            !value.trim().contains(' ')) {
                          return 'Escribe tu nombre completo';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _email,

                      enabled: !_loading,

                      keyboardType:
                      TextInputType.emailAddress,

                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',

                        prefixIcon: Icon(
                          Icons.email_outlined,
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }

                        final expression = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,63}$',
                        );

                        if (!expression.hasMatch(
                          value.trim(),
                        )) {
                          return 'Correo electrónico inválido';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _sex,

                      decoration: const InputDecoration(
                        labelText: 'Sexo',

                        prefixIcon: Icon(
                          Icons.badge_outlined,
                        ),
                      ),

                      items: [
                        'Masculino',
                        'Femenino',
                        'Otro',
                      ].map((value) {
                        return DropdownMenuItem(
                          value: value,

                          child: Text(value),
                        );
                      }).toList(),

                      onChanged: _loading
                          ? null
                          : (value) {
                        if (value != null) {
                          setState(
                                () => _sex = value,
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    _section(
                      '02',
                      'Seguridad de la cuenta',
                    ),

                    TextFormField(
                      controller: _password,

                      enabled: !_loading,

                      obscureText: !_visible,

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

                      validator: (value) {
                        if (value == null ||
                            value.length < 8) {
                          return 'Mínimo 8 caracteres';
                        }

                        if (!RegExp(r'[A-Za-z]')
                            .hasMatch(value) ||
                            !RegExp(r'[0-9]')
                                .hasMatch(value) ||
                            !RegExp(r'[^A-Za-z0-9\s]')
                                .hasMatch(value)) {
                          return 'Usa letras, números y un símbolo';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirm,

                      enabled: !_loading,

                      obscureText: !_confirmVisible,

                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña',

                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                        ),

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                                  () => _confirmVisible =
                              !_confirmVisible,
                            );
                          },

                          icon: Icon(
                            _confirmVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),

                      validator: (value) {
                        if (value != _password.text) {
                          return 'Las contraseñas no coinciden';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: cyan.withValues(
                          alpha: 0.07,
                        ),

                        borderRadius:
                        BorderRadius.circular(16),
                      ),

                      child: const Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: cyan,
                            size: 28,
                          ),

                          SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              'Después de iniciar sesión '
                                  'podrás configurar el acceso '
                                  'mediante biometría.',

                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : _register,

                      icon: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.arrow_forward,
                      ),

                      label: Text(
                        _loading
                            ? 'Creando cuenta...'
                            : 'Crear cuenta',
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context),

                      child: const Text(
                        'Ya tengo una cuenta',
                      ),
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