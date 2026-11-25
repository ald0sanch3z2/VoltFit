import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthService {
  // ==========================================
  // CLAVES DE ALMACENAMIENTO
  // ==========================================

  static const String _usersKey = 'voltfit_users';

  static const String _sessionKey = 'voltfit_session';

  // Cuenta autorizada para iniciar con biometría.
  static const String _biometricKey =
      'voltfit_biometric_user';

  final LocalAuthentication _localAuth =
  LocalAuthentication();

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  // ==========================================
  // GENERAR SAL ALEATORIA
  // ==========================================

  String _generateSalt() {
    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
          (_) => random.nextInt(256),
    );

    return base64UrlEncode(bytes);
  }

  // ==========================================
  // PROTEGER CONTRASEÑA MEDIANTE HASH
  // ==========================================

  String _hashPassword(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');

    for (var i = 0; i < 120000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }

    return base64Encode(bytes);
  }

  // ==========================================
  // OBTENER USUARIOS
  // ==========================================

  Future<List<AppUser>> getUsers() async {
    final prefs = await _prefs;

    final raw = prefs.getString(_usersKey);

    if (raw == null) return [];

    final list = jsonDecode(raw) as List;

    return list.map((e) {
      return AppUser.fromJson(
        Map<String, dynamic>.from(e as Map),
      );
    }).toList();
  }

  // ==========================================
  // GUARDAR USUARIOS
  // ==========================================

  Future<void> _saveUsers(List<AppUser> users) async {
    final prefs = await _prefs;

    final saved = await prefs.setString(
      _usersKey,
      jsonEncode(
        users.map((e) => e.toJson()).toList(),
      ),
    );

    if (!saved) {
      throw Exception(
        'No se pudieron guardar los usuarios.',
      );
    }
  }

  // ==========================================
  // REGISTRAR USUARIO
  // ==========================================

  Future<void> register({
    required String name,
    required String email,
    required String sex,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();

    // Validar correo electrónico.
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,63}$',
    );

    if (!emailRegex.hasMatch(normalized)) {
      throw Exception('Correo electrónico inválido.');
    }

    if (name.trim().length < 3) {
      throw Exception('Introduce un nombre válido.');
    }

    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      throw Exception(
        'La contraseña debe incluir letras, números '
            'y un símbolo.',
      );
    }

    final users = await getUsers();

    if (users.any((u) => u.email == normalized)) {
      throw Exception(
        'Este correo ya está registrado.',
      );
    }

    final salt = _generateSalt();

    final newUser = AppUser(
      name: name.trim(),
      email: normalized,
      sex: sex,
      salt: salt,
      passwordHash: _hashPassword(password, salt),
      biometricEnabled: false,
    );

    users.add(newUser);

    await _saveUsers(users);
  }

  // ==========================================
  // INICIAR SESIÓN CON CONTRASEÑA
  // ==========================================

  Future<AppUser?> login(
      String email,
      String password,
      ) async {
    final normalized = email.trim().toLowerCase();

    final users = await getUsers();

    for (final user in users) {
      if (user.email != normalized) continue;

      final hash = _hashPassword(
        password,
        user.salt,
      );

      if (hash != user.passwordHash) {
        return null;
      }

      await _setSession(user.email);

      return user;
    }

    return null;
  }

  // ==========================================
  // GUARDAR SESIÓN
  // ==========================================

  Future<void> _setSession(String email) async {
    final prefs = await _prefs;

    await prefs.setString(_sessionKey, email);
  }

  // ==========================================
  // OBTENER USUARIO ACTUAL
  // ==========================================

  Future<AppUser?> currentUser() async {
    final prefs = await _prefs;

    final email = prefs.getString(_sessionKey);

    if (email == null) return null;

    final users = await getUsers();

    for (final user in users) {
      if (user.email == email) {
        return user;
      }
    }

    return null;
  }

  // ==========================================
  // CERRAR SESIÓN
  // ==========================================

  Future<void> logout() async {
    final prefs = await _prefs;

    // Eliminar la sesión, pero conservar
    // la cuenta autorizada para biometría.
    await prefs.remove(_sessionKey);
  }

  // ==========================================
  // COMPROBAR SENSORES BIOMÉTRICOS
  // ==========================================

  Future<bool> canUseBiometrics() async {
    try {
      final supported =
      await _localAuth.isDeviceSupported();

      final canCheck =
      await _localAuth.canCheckBiometrics;

      final available =
      await _localAuth.getAvailableBiometrics();

      return supported &&
          canCheck &&
          available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // OBTENER MÉTODOS BIOMÉTRICOS
  // ==========================================

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // AUTENTICACIÓN BIOMÉTRICA
  // ==========================================

  Future<bool> authenticateBiometric() async {
    try {
      if (!await canUseBiometrics()) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason:
        'Confirma tu identidad para acceder a VoltFit',

        biometricOnly: true,

        persistAcrossBackgrounding: true,

        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Acceso seguro a VoltFit',
            cancelButton: 'Cancelar',
          ),
        ],
      );
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // OBTENER CUENTA BIOMÉTRICA RECORDADA
  // ==========================================

  Future<AppUser?> lastBiometricUser() async {
    final prefs = await _prefs;

    final email = prefs.getString(_biometricKey);

    if (email == null) return null;

    final users = await getUsers();

    for (final user in users) {
      if (user.email == email &&
          user.biometricEnabled) {
        return user;
      }
    }

    // Eliminar referencias que ya no son válidas.
    await prefs.remove(_biometricKey);

    return null;
  }

  // ==========================================
  // INICIAR SESIÓN SIN CORREO NI CONTRASEÑA
  // ==========================================

  Future<AppUser?> biometricLogin([
    String? email,
  ]) async {
    final selected = await lastBiometricUser();

    if (selected == null) {
      return null;
    }

    // Mantener compatibilidad con llamadas anteriores.
    if (email != null &&
        email.trim().isNotEmpty &&
        selected.email != email.trim().toLowerCase()) {
      return null;
    }

    final authenticated =
    await authenticateBiometric();

    if (!authenticated) {
      return null;
    }

    // Comprobar nuevamente que la cuenta sigue autorizada.
    final verified = await lastBiometricUser();

    if (verified == null ||
        verified.email != selected.email) {
      return null;
    }

    await _setSession(verified.email);

    return verified;
  }

  // ==========================================
  // ACTIVAR O DESACTIVAR BIOMETRÍA
  // ==========================================

  Future<AppUser> setBiometrics(
      AppUser user,
      bool enabled,
      ) async {
    final session = await currentUser();

    // Solo modificar la cuenta que inició sesión.
    if (session == null ||
        session.email != user.email) {
      throw Exception(
        'No existe una sesión válida.',
      );
    }

    if (!await canUseBiometrics()) {
      throw Exception(
        'Configura una huella o biometría compatible '
            'en los ajustes del teléfono.',
      );
    }

    final authenticated =
    await authenticateBiometric();

    if (!authenticated) {
      throw Exception(
        'No se pudo verificar tu identidad.',
      );
    }

    final users = await getUsers();

    final index = users.indexWhere(
          (u) => u.email == user.email,
    );

    if (index == -1) {
      throw Exception('Usuario no encontrado.');
    }

    final updated = users[index].copyWith(
      biometricEnabled: enabled,
    );

    users[index] = updated;

    final prefs = await _prefs;

    if (enabled) {
      // Solo una cuenta biométrica por dispositivo.
      for (var i = 0; i < users.length; i++) {
        if (i != index && users[i].biometricEnabled) {
          users[i] = users[i].copyWith(
            biometricEnabled: false,
          );
        }
      }
    }

    await _saveUsers(users);

    if (enabled) {
      final saved = await prefs.setString(
        _biometricKey,
        updated.email,
      );

      if (!saved) {
        throw Exception(
          'No se pudo recordar la cuenta biométrica.',
        );
      }
    } else {
      if (prefs.getString(_biometricKey) ==
          updated.email) {
        await prefs.remove(_biometricKey);
      }
    }

    return updated;
  }
}