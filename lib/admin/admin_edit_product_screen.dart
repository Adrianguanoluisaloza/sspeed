import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/producto.dart';
import '../services/database_service.dart' show DatabaseService;

import 'package:provider/provider.dart';

class AdminEditProductScreen extends StatefulWidget {
  final Producto? producto;
  const AdminEditProductScreen({super.key, this.producto});

  bool get isEditing => producto != null;

  @override
  State<AdminEditProductScreen> createState() => _AdminEditProductScreenState();
}

class _AdminEditProductScreenState extends State<AdminEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _precioController;
  late TextEditingController _imagenController;
  late TextEditingController _categoriaController;
  late bool _disponible;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.producto?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.producto?.descripcion ?? '');
    _precioController = TextEditingController(text: widget.producto?.precio.toString() ?? '');
    _imagenController = TextEditingController(text: widget.producto?.imagenUrl ?? '');
    _categoriaController = TextEditingController(text: widget.producto?.categoria ?? '');
    _disponible = widget.producto?.disponible ?? true;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final database = Provider.of<DatabaseService>(context, listen: false);

    final producto = Producto(
      idProducto: widget.isEditing ? widget.producto!.idProducto : 0,
      nombre: _nombreController.text,
      descripcion: _descripcionController.text,
      precio: double.tryParse(_precioController.text) ?? 0.0,
      imagenUrl: _imagenController.text,
      categoria: _categoriaController.text,
      disponible: _disponible,
    );

    bool success = false;
    String action = widget.isEditing ? 'actualizado' : 'creado';

    if (widget.isEditing) {
      success = await database.updateProducto(producto);
    } else {
      final newProduct = await database.createProducto(producto);
      success = newProduct != null;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Producto $action correctamente' : 'Error al guardar el producto.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) {
        Navigator.pop(context, true);
      }
    }
    if (!mounted) return; // Evitamos llamar setState cuando la pantalla ya no está activa.
    setState(() => _isLoading = false);
  }

  Future<void> _deleteProduct() async {
    // Diálogo de confirmación para evitar borrados accidentales
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este producto? Esta acción lo marcará como "no disponible".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) {
      // Validamos el contexto tras el diálogo para evitar usarlo cuando ya no existe.
      return;
    }

    setState(() => _isLoading = true);
    final database = Provider.of<DatabaseService>(context, listen: false);
    final success = await database.deleteProducto(widget.producto!.idProducto);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Producto eliminado' : 'Error al eliminar'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) {
        Navigator.pop(context, true);
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        // Añadimos el botón de eliminar solo en modo edición
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _deleteProduct,
            )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            TextFormField(controller: _descripcionController, decoration: const InputDecoration(labelText: 'Descripción')),
            TextFormField(controller: _precioController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
            TextFormField(controller: _imagenController, decoration: const InputDecoration(labelText: 'URL de Imagen')),
            TextFormField(controller: _categoriaController, decoration: const InputDecoration(labelText: 'Categoría')),
            SwitchListTile(
              title: const Text('Disponible'),
              value: _disponible,
              onChanged: (value) => setState(() => _disponible = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProduct,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                  : Text(widget.isEditing ? 'Guardar Cambios' : 'Crear Producto'),
            ),
          ],
        ),
      ),
    );
  }
}

