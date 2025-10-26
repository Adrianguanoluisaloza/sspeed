import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:flutter_application_2/services/api_exception.dart';
import '../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final success = await dbService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _phoneController.text.trim(),
      );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Registro exitoso. ¡Ahora inicia sesión!'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pushReplacementNamed(AppRoutes.login);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('El correo ya está registrado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado.'),
          backgroundColor: Colors.red,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Fondo con imagen
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1170',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Degradado con nueva sintaxis
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withValues(alpha: 0.8),
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Contenido
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Crea tu Cuenta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Es rápido y fácil',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                hint: 'Nombre Completo',
                                icon: Icons.person_outline,
                                validator: (val) =>
                                val!.isEmpty ? 'Ingresa tu nombre' : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _emailController,
                                hint: 'Correo electrónico',
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) => !val!.contains('@')
                                    ? 'Correo inválido'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _phoneController,
                                hint: 'Teléfono',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (val) => val!.isEmpty
                                    ? 'Ingresa tu teléfono'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildPasswordField(
                                controller: _passwordController,
                                hint: 'Contraseña',
                                obscure: _obscurePassword,
                                toggle: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                                validator: (val) => val!.length < 6
                                    ? 'Mínimo 6 caracteres'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildPasswordField(
                                controller: _confirmPasswordController,
                                hint: 'Confirmar Contraseña',
                                obscure: _obscureConfirmPassword,
                                toggle: () => setState(() =>
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword),
                                validator: (val) => val !=
                                    _passwordController.text
                                    ? 'Las contraseñas no coinciden'
                                    : null,
                              ),
                              const SizedBox(height: 32),
                              _buildRegisterButton(theme),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(hintText: hint, icon: icon),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(hintText: hint, icon: Icons.lock_outline)
          .copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white70,
          ),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildRegisterButton(ThemeData theme) {
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
              color: Colors.black.withValues(alpha: 0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
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
              : const Text(
            'REGISTRARME',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.3),
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
