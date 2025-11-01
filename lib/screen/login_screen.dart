import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/api_exception.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      // OPTIMIZACIÓN: Se reduce la duración para una sensación más rápida.
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sessionController = context.read<SessionController>();
    final databaseService = context.read<DatabaseService>();

    setState(() => _isLoading = true);

    try {
      final future = databaseService.login(
          _emailController.text.trim(), _passwordController.text);
      final user = await future.timeout(const Duration(seconds: 15));

      if (user != null && user.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', user.token ?? '');
        databaseService.setAuthToken(user.token);
        sessionController.setUser(user);

        // Navega segun el rol normalizado
        final normalizedRole = () {
          final raw = user.rol.trim().toLowerCase();
          const roleMap = {
            'cliente': 'cliente',
            'delivery': 'delivery',
            'repartidor': 'delivery',
            'negocio': 'negocio',
            'admin': 'admin',
            'soporte': 'soporte',
          };
          return roleMap[raw] ?? 'cliente';
        }();

        switch (normalizedRole) {
          case 'admin':
            navigator.pushNamedAndRemoveUntil(
              AppRoutes.mainNavigator,
              (route) => false,
              arguments: user,
            );
            break;
          case 'negocio':
            navigator.pushNamedAndRemoveUntil(
              AppRoutes.negocioHome,
              (route) => false,
              arguments: user,
            );
            break;
          case 'delivery':
            navigator.pushNamedAndRemoveUntil(
              AppRoutes.deliveryHome,
              (route) => false,
              arguments: user,
            );
            break;
          case 'soporte':
            navigator.pushNamedAndRemoveUntil(
              AppRoutes.supportHome,
              (route) => false,
              arguments: user,
            );
            break;
          default:
            navigator.pushNamedAndRemoveUntil(
              AppRoutes.mainNavigator,
              (route) => false,
              arguments: user,
            );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ocurrio un error inesperado.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // OPTIMIZACIÓN: Usar una imagen local para carga instantánea.
          // Asegúrate de agregar la imagen a tus assets en pubspec.yaml
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/fondo-login.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Capa de degradado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.8),
                  theme.colorScheme.secondary.withOpacity(0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Contenido del login
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo y título animados
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            color: theme.primaryColor,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Unite7speed',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black26, blurRadius: 10)
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Tu comida favorita a un clic',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimary
                                    .withOpacity(0.7))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Formulario animado
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildInputField(
                              controller: _emailController,
                              hintText: 'Correo electrónico',
                              icon: Icons.mail_outline,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Ingresa un correo válido'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _buildPasswordField(),
                            const SizedBox(height: 32),
                            _buildLoginButton(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildRegisterLink(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary), // Texto blanco
      decoration: _buildInputDecoration(hintText: hintText, icon: icon),
      keyboardType: TextInputType.emailAddress,
      validator: validator,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary), // Texto blanco
      decoration: _buildInputDecoration(
        hintText: 'Contraseña',
        icon: Icons.lock_outline,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Theme.of(context)
                .colorScheme
                .onPrimary
                .withOpacity(0.7),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, const Color(0xFFE55D45)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'INGRESAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            '¿No tienes cuenta? ',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7))),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.register),
          child: Text(
            'Regístrate',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onPrimary
              .withOpacity(0.7)),
      prefixIcon: Icon(icon,
          color: Theme.of(context)
              .colorScheme
              .onPrimary
              .withOpacity(0.7)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
    );
  }
}
