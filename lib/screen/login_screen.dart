import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:flutter_application_2/services/api_exception.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 2. Obtener dependencias del BuildContext ANTES de cualquier 'await'.
    //    Esta es la única vez que necesitas definirlas.
    final sessionController = context.read<SessionController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final user = await databaseService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // 3. Comprobar si el widget sigue "montado" después del await
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final sessionController = context.read<SessionController>();

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return; // Confirmamos que el contexto sigue vivo tras obtener SharedPreferences.
        await prefs.setString('userEmail', user.correo);
        await prefs.setString('userPassword', _passwordController.text.trim());

        // --- LÓGICA DE REDIRECCIÓN SEGÚN ROL ---
        sessionController.setUser(user);
        if (user.rol == 'admin') {
          navigator.pushNamedAndRemoveUntil(
            AppRoutes.adminHome,
            (route) => false,
            arguments: user,
          );
        } else if (user.rol == 'delivery') {
          navigator.pushNamedAndRemoveUntil(
            AppRoutes.deliveryHome,
            (route) => false,
            arguments: user,
          );
        } else {
          navigator.pushNamedAndRemoveUntil(
            AppRoutes.mainNavigator,
            (route) => false,
            arguments: user,
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas.')),
        );
      }
    } catch (e) {
      if (!mounted) return; // Evitamos usar ScaffoldMessenger sin contexto válido tras el await.
      final messenger = ScaffoldMessenger.of(context);
      final fallbackMessage = e is ApiException
          ? e.message
          : 'Error de conexión, verifica tu red e inténtalo nuevamente.';
      messenger.showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          tween: Tween(begin: 0, end: 1),
          // Pequeña animación de entrada para suavizar la transición desde el splash.
          builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.delivery_dining, size: 100, color: Colors.deepOrange),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email),
                  ),

                  // --- CAMPO DE CONTRASEÑA (corregido y añadido) ---
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true, // Oculta la contraseña
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu contraseña.';
                      }
                      return null;
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, ingresa tu contraseña.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isLoading
                      ? const Center(
                          key: ValueKey('loading_indicator'),
                          child: CircularProgressIndicator(),
                        )
                      : ElevatedButton(
                          key: const ValueKey('login_button'),
                          onPressed: _handleLogin,
                          child: const Text('INICIAR SESIÓN'),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                  child: const Text('¿No tienes cuenta? Regístrate aquí'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

