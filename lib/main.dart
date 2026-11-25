import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const VoltFitApp());
}

class VoltFitApp extends StatefulWidget {
  const VoltFitApp({super.key});

  @override
  State<VoltFitApp> createState() => _VoltFitAppState();
}

class _VoltFitAppState extends State<VoltFitApp> {
  AppUser? currentUser;

  // ==========================================
  // INICIAR SESIÓN
  // ==========================================

  void _onLogin(AppUser user) {
    setState(() => currentUser = user);
  }

  // ==========================================
  // CERRAR SESIÓN
  // ==========================================

  void _onLogout() {
    setState(() => currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de colores profesional.
    const background = Color(0xFF080F1C);
    const surface = Color(0xFF111D2E);
    const border = Color(0xFF26364B);
    const cyan = Color(0xFF22D3EE);
    const emerald = Color(0xFF10B981);

    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      primary: cyan,
      secondary: emerald,
      surface: surface,
      onSurface: Colors.white,
    );

    return MaterialApp(
      title: 'VoltFit',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        brightness: Brightness.dark,

        colorScheme: scheme,

        scaffoldBackgroundColor: background,

        // ====================================
        // TIPOGRAFÍA
        // ====================================

        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),

          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),

          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),

          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),

        // ====================================
        // BARRA SUPERIOR
        // ====================================

        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        // ====================================
        // TARJETAS
        // ====================================

        cardTheme: CardThemeData(
          color: surface,

          elevation: 0,

          margin: const EdgeInsets.symmetric(
            vertical: 6,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),

            side: const BorderSide(
              color: border,
            ),
          ),
        ),

        // ====================================
        // CAMPOS DE TEXTO
        // ====================================

        inputDecorationTheme: InputDecorationTheme(
          filled: true,

          fillColor: surface,

          labelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
          ),

          prefixIconColor: cyan,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),

            borderSide: const BorderSide(
              color: border,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),

            borderSide: const BorderSide(
              color: cyan,
              width: 1.7,
            ),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),

            borderSide: const BorderSide(
              color: Colors.redAccent,
            ),
          ),
        ),

        // ====================================
        // BOTONES PRINCIPALES
        // ====================================

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: cyan,

            foregroundColor: background,

            minimumSize: const Size(0, 56),

            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ====================================
        // BOTONES SECUNDARIOS
        // ====================================

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: cyan,

            minimumSize: const Size(0, 54),

            side: const BorderSide(
              color: border,
            ),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ====================================
        // MENÚ INFERIOR
        // ====================================

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,

          height: 74,

          elevation: 0,

          indicatorColor: cyan.withValues(
            alpha: 0.15,
          ),

          iconTheme: WidgetStateProperty.resolveWith(
                (states) {
              final selected = states.contains(
                WidgetState.selected,
              );

              return IconThemeData(
                color: selected
                    ? cyan
                    : const Color(0xFF94A3B8),
              );
            },
          ),

          labelTextStyle: WidgetStateProperty.resolveWith(
                (states) {
              final selected = states.contains(
                WidgetState.selected,
              );

              return TextStyle(
                fontSize: 11,
                color: selected
                    ? cyan
                    : const Color(0xFF94A3B8),

                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              );
            },
          ),
        ),

        // ====================================
        // MENSAJES EMERGENTES
        // ====================================

        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF24364B),

          contentTextStyle: const TextStyle(
            color: Colors.white,
          ),

          behavior: SnackBarBehavior.floating,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Siempre solicitar autenticación al abrir la app.
      home: currentUser == null
          ? LoginScreen(
        onLogin: _onLogin,
      )
          : HomeScreen(
        key: ValueKey(currentUser!.email),

        user: currentUser!,

        onLogout: _onLogout,
      ),
    );
  }
}