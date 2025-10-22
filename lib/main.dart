import 'package:flutter/material.dart';
import 'package:flutter_application_2/screen/login_screen.dart';
import 'package:flutter_application_2/screen/main_navigator.dart';
import 'package:flutter_application_2/screen/register_screen.dart';
import 'package:flutter_application_2/screen/splash_screen.dart'; // Asegúrate de tener este import
import 'package:provider/provider.dart';
import 'models/usuario.dart';
import 'models/cart_model.dart';
import 'services/database_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartModel()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ... (Tu ThemeData no cambia)
    const Color primaryOrange = Color(0xFFFF5722);
    const Color primaryIndigo = Color(0xFF3F51B5);

    return MaterialApp(
      title: 'Unite7speed Delivery App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryOrange,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepOrange)
            .copyWith(secondary: primaryIndigo),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryOrange,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
      // La ruta inicial ahora es la SplashScreen
      initialRoute: '/',
      routes: {
        // --- CAMBIOS AQUÍ ---
        '/':(context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegisterScreen(),
        // Se eliminó la ruta '/cart_screen' para evitar el conflicto.
        // La navegación al carrito ahora siempre pasará el usuario.
        '/main_navigator': (context) {
          final usuario = ModalRoute.of(context)?.settings.arguments as Usuario?;
          if (usuario == null) {
            return const LoginScreen();
          }
          return MainNavigator(usuario: usuario);
        },
      },
    );
  }
}

