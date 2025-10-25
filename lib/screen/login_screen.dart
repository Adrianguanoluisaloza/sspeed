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
  bool _obscurePassword = true;

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

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final sessionController = context.read<SessionController>();

      if (user != null) {
        // Sincronizamos el token con el cliente HTTP antes de tocar SharedPreferences.
        databaseService.setAuthToken(user.token);

        // Guardar datos del usuario localmente
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return; // Confirmamos que el contexto sigue vivo tras obtener SharedPreferences.
        await prefs.setString('userEmail', user.correo);
        await prefs.setString('userPassword', _passwordController.text.trim());
        if (user.token != null && user.token!.isNotEmpty) {
          await prefs.setString('authToken', user.token!);
        } else {
          await prefs.remove('authToken');
        }

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
        navigator.pushNamedAndRemoveUntil(targetRoute, (route) => false, arguments: user);
      } else {
        databaseService.setAuthToken(null);
        messenger.showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas.')),
        );
      }
    } catch (e) {
      databaseService.setAuthToken(null);
      if (!mounted) return; // Evitamos usar ScaffoldMessenger sin contexto válido tras el await.
      final messenger = ScaffoldMessenger.of(context);
      final fallbackMessage = e is ApiException
          ? e.message
          : 'Error de conexión, verifica tu red e inténtalo nuevamente.';
      messenger.showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  const SizedBox(height: 20),
                  const Text(
                    'Unite7speed',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu comida favorita a un clic',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                              validator: (val) => !(val?.contains('@') ?? false) ? 'Ingresa un correo válido' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (val) => (val?.isEmpty ?? true) ? 'Ingresa tu contraseña' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: theme.elevatedButtonTheme.style?.copyWith(
                                  padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                    : const Text('Ingresar'),
                              ),
                            ),
                          ],
                        ),
                      ),
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
      bottomNavigationBar: _buildRegisterButton(context),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Container(
      color: const Color(0xFF1E3A8A), // Color azul oscuro del fondo
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('¿No tienes cuenta? ', style: TextStyle(color: Colors.white70)),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.register),
            child: const Text('Regístrate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
