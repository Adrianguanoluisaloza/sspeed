import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/producto.dart';
import 'package:flutter_application_2/services/api_exception.dart';
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
  late TextEditingController _stockController;
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
    _stockController = TextEditingController(text: widget.producto?.stock?.toString() ?? '0');
    _disponible = widget.producto?.disponible ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _imagenController.dispose();
    _categoriaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final database = Provider.of<DatabaseService>(context, listen: false);

      final producto = Producto(
        // El backend maneja el ID, por lo que lo enviamos solo en edición
        idProducto: widget.isEditing ? widget.producto!.idProducto : 0,
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        precio: double.tryParse(_precioController.text) ?? 0.0,
        imagenUrl: _imagenController.text,
        categoria: _categoriaController.text,
        disponible: _disponible,
        stock: int.tryParse(_stockController.text) ?? 0,
      );

      bool success = false;
      String action = widget.isEditing ? 'actualizado' : 'creado';

      if (widget.isEditing) {
        success = await database.updateProducto(producto);
      } else {
        final newProduct = await database.createProducto(producto);
        success = newProduct != null;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Producto $action correctamente' : 'Error al guardar el producto.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));

      if (success) {
        Navigator.pop(context, true); // Devuelve 'true' para refrescar la lista anterior
      } else {
        setState(() => _isLoading = false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    // Diálogo de confirmación para evitar borrados accidentales.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${widget.producto!.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final database = Provider.of<DatabaseService>(context, listen: false);
      final success = await database.deleteProducto(widget.producto!.idProducto);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Producto eliminado con éxito' : 'No se pudo eliminar el producto.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
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
        title: Text(widget.isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        // Añadimos el botón de eliminar solo en modo edición.
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteProduct, // Llama a la nueva función
              tooltip: 'Eliminar Producto',
            )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 100),
          children: _buildFormFields(),
        ),
      ),
      // --- Botón Flotante para Guardar ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveProduct,
        label: Text(widget.isEditing ? 'Guardar Cambios' : 'Crear Producto'),
        icon: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_alt_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<Widget> _buildFormFields() {
    return [
      // --- Tarjeta de Información Básica ---
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información Básica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.fastfood_outlined)),
                validator: (v) => v!.trim().isEmpty ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      // --- Tarjeta de Precios y Stock ---
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Precio y Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _precioController,
                      decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (double.tryParse(v) == null) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2_outlined)),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (int.tryParse(v) == null) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      // --- Tarjeta de Catalogación ---
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catalogación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(controller: _imagenController, decoration: const InputDecoration(labelText: 'URL de Imagen', border: OutlineInputBorder(), prefixIcon: Icon(Icons.image_outlined))),
              const SizedBox(height: 16),
              TextFormField(controller: _categoriaController, decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible para la venta'),
                value: _disponible,
                onChanged: (value) => setState(() => _disponible = value),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
