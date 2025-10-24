import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:flutter_application_2/services/api_exception.dart';
import 'package:flutter_application_2/models/session_state.dart';
import 'package:flutter_application_2/routes/app_routes.dart';

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final sessionController = context.read<SessionController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final user = await databaseService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.setString('userEmail', user.correo);
        await prefs.setString('userPassword', _passwordController.text.trim());

        sessionController.setUser(user);

        switch (user.rol) {
          case 'admin':
            navigator.pushNamedAndRemoveUntil(AppRoutes.adminHome, (route) => false, arguments: user);
            break;
          case 'delivery':
            navigator.pushNamedAndRemoveUntil(AppRoutes.deliveryHome, (route) => false, arguments: user);
            break;
          default:
            navigator.pushNamedAndRemoveUntil(AppRoutes.mainNavigator, (route) => false, arguments: user);
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final fallbackMessage = e is ApiException
          ? e.message
          : 'Error de conexión, verifica tu red e inténtalo nuevamente.';
      messenger.showSnackBar(SnackBar(content: Text(fallbackMessage)));
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
          builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
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
                  const SizedBox(height: 40),
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
      ),
    );
  }
}
