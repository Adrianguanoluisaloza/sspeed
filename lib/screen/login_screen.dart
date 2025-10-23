import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/services/database_service.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  // --- FUNCIÓN DE LOGIN ---
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final user = await databaseService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        // Guardar datos del usuario localmente
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return; // Confirmamos que el contexto sigue vivo tras obtener SharedPreferences.
        await prefs.setString('userEmail', user.correo);
        await prefs.setString('userPassword', _passwordController.text.trim());

        // --- LÓGICA DE REDIRECCIÓN SEGÚN ROL ---
        context.read<SessionController>().setUser(user);
        if (user.rol == 'admin') {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.adminHome,
            (route) => false,
            arguments: user,
          );
        } else if (user.rol == 'delivery') {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.deliveryHome,
            (route) => false,
            arguments: user,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.mainNavigator,
            (route) => false,
            arguments: user,
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas.')),
        );
      }
    } catch (e) {
      if (!mounted) return; // Evitamos usar ScaffoldMessenger sin contexto válido tras el await.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- INTERFAZ ---
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, ingresa tu correo.';
                    }
                    if (!value.contains('@')) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
