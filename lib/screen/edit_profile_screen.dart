import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_state.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/database_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Usuario usuario;
  const EditProfileScreen({super.key, required this.usuario});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.usuario.nombre);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dbService = context.read<DatabaseService>();
    final session = context.read<SessionController>();

    setState(() => _isLoading = true);

    try {
      final updatedUser = await dbService.updateUsuario(
        widget.usuario.copyWith(
          nombre: _nameController.text.trim(),
          // Solo se envía la contraseña si el campo no está vacío
          contrasena: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        ),
      );

      if (updatedUser != null) {
        // Actualiza el estado de la sesión en la app
        session.setUser(updatedUser);

        // Si se cambió la contraseña, actualiza SharedPreferences para el auto-login
        if (_passwordController.text.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userPassword', _passwordController.text);
        }

        messenger.showSnackBar(const SnackBar(content: Text('Perfil actualizado con éxito.'), backgroundColor: Colors.green));
        navigator.pop(); // Vuelve a la pantalla de perfil
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo actualizar el perfil.'), backgroundColor: Colors.red));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ocurrió un error inesperado: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Campo para el nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person_outline)),
                validator: (val) => (val == null || val.isEmpty) ? 'El nombre no puede estar vacío' : null,
              ),
              const SizedBox(height: 16),
              // Campo para el correo (solo lectura)
              TextFormField(
                initialValue: widget.usuario.correo,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico (no editable)',
                  prefixIcon: Icon(Icons.email_outlined),
                  fillColor: Colors.black12, // Color para indicar que está deshabilitado
                ),
              ),
              const Divider(height: 32),
              // Sección para cambiar contraseña
              const Text('Cambiar Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Deja los campos en blanco si no deseas cambiar tu contraseña.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar Nueva Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                validator: (val) {
                  if (_passwordController.text.isNotEmpty && val != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Guardar Cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
