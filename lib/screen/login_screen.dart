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

      if (user != null && user.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', user.correo);
        // Por seguridad, no es ideal guardar la contraseña, pero lo mantenemos por ahora
        await prefs.setString('userPassword', _passwordController.text.trim());

        sessionController.setUser(user);
        String targetRoute = AppRoutes.mainNavigator;
        if (user.rol == 'admin') {
          targetRoute = AppRoutes.adminHome;
        } else if (user.rol == 'delivery') {
          targetRoute = AppRoutes.deliveryHome;
        }
        navigator.pushNamedAndRemoveUntil(targetRoute, (route) => false, arguments: user);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Credenciales incorrectas.')));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Error de conexión. Inténtalo de nuevo.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFF1E3A8A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.delivery_dining, size: 50, color: Color(0xFFF97316)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Unite7speed', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Tu comida favorita a un clic', style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildRegisterButton(context),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.register),
        child: Container(
        color: const Color(0xFF1E3A8A), // Azul oscuro
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('¿No tienes cuenta? ', style: TextStyle(color: Colors.white70)),
            Text('Regístrate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ), 
    );
  }
}
