import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../services/database_service.dart';

class AdminProductoFormScreen extends StatefulWidget {
  final Producto? producto;
  const AdminProductoFormScreen({super.key, this.producto});

  @override
  State<AdminProductoFormScreen> createState() =>
      _AdminProductoFormScreenState();
}

class _AdminProductoFormScreenState extends State<AdminProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _precioController;
  late TextEditingController _imagenController;
  late TextEditingController _categoriaController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.producto?.nombre ?? '');
    _descripcionController =
        TextEditingController(text: widget.producto?.descripcion ?? '');
    _precioController = TextEditingController(
        text:
            widget.producto != null ? widget.producto!.precio.toString() : '');
    _imagenController =
        TextEditingController(text: widget.producto?.imagenUrl ?? '');
    _categoriaController =
        TextEditingController(text: widget.producto?.categoria ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _imagenController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final producto = Producto(
        idProducto: widget.producto?.idProducto ?? 0,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        precio: double.tryParse(_precioController.text.trim()) ?? 0.0,
        imagenUrl: _imagenController.text.trim(),
        categoria: _categoriaController.text.trim(),
      );
      bool ok;
      if (widget.producto == null) {
        // Crear nuevo producto
        await dbService.createProducto(producto);
        ok = true;
      } else {
        // Editar producto existente
        ok = await dbService.updateProducto(producto);
      }
      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al guardar producto'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.producto == null ? 'Nuevo Producto' : 'Editar Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoriaController,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (v) => v == null || v.isEmpty
                    ? 'La categoría es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imagenController,
                decoration: const InputDecoration(labelText: 'URL de imagen'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _guardarProducto,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
