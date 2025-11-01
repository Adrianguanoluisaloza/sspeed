import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/negocio.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

class RegisterBusinessScreen extends StatefulWidget {
  final Usuario usuario;
  const RegisterBusinessScreen({super.key, required this.usuario});

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();

  bool _isLoading = false;
  Negocio? _negocioActual;

  @override
  void initState() {
    super.initState();
    _cargarNegocio();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _rucCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarNegocio() async {
    setState(() => _isLoading = true);
    try {
      final service = context.read<DatabaseService>();
      final negocio =
          await service.getNegocioDeUsuario(widget.usuario.idUsuario);
      if (!mounted) return;
      if (negocio != null) {
        _negocioActual = negocio;
        _nombreCtrl.text = negocio.nombreComercial;
        _rucCtrl.text = negocio.ruc;
        _direccionCtrl.text = negocio.direccion ?? '';
        _telefonoCtrl.text = negocio.telefono ?? '';
        _logoCtrl.text = negocio.logoUrl ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar el negocio: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final servicio = context.read<DatabaseService>();
      final negocio = Negocio(
        idNegocio: _negocioActual?.idNegocio ?? 0,
        idUsuario: widget.usuario.idUsuario,
        nombreComercial: _nombreCtrl.text.trim(),
        ruc: _rucCtrl.text.trim(),
        direccion:
            _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        telefono:
            _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        logoUrl: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
        activo: true,
      );

      final guardado = await servicio.registrarNegocioParaUsuario(
          widget.usuario.idUsuario, negocio);

      if (!mounted) return;

      if (guardado != null) {
        setState(() => _negocioActual = guardado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_negocioActual == null
                ? 'Negocio registrado correctamente'
                : 'Negocio actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el negocio.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el negocio: $e'),
          backgroundColor: Colors.red.shade600,
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
      appBar: AppBar(
        title: const Text('Registrar negocio'),
      ),
      body: _isLoading && _negocioActual == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparte los datos de tu negocio. Tu cuenta seguirÃ¡ siendo de cliente; esta informaciÃ³n se utilizarÃ¡ para futuras herramientas administrativas.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre comercial',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre comercial es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rucCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RUC',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'El RUC es obligatorio';
                        }
                        if (trimmed.length < 10 || trimmed.length > 13) {
                          return 'Debe tener entre 10 y 13 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'DirecciÃ³n',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'TelÃ©fono de contacto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _logoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Logo (URL opcional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _guardar,
                        icon: const Icon(Icons.store_mall_directory_outlined),
                        label: Text(_negocioActual == null
                            ? 'Registrar negocio'
                            : 'Actualizar negocio'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_negocioActual != null)
                      Text(
                        'Ãšltima informaciÃ³n guardada. Puedes actualizarla cuando desees.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

