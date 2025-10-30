import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

class BusinessProductsView extends StatefulWidget {
  final Usuario negocioUser;
  const BusinessProductsView({super.key, required this.negocioUser});

  @override
  State<BusinessProductsView> createState() => _BusinessProductsViewState();
}

class _BusinessProductsViewState extends State<BusinessProductsView> {
  late Future<List<Producto>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context
        .read<DatabaseService>()
        .getProductosPorNegocio(widget.negocioUser.idUsuario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis productos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewProductDialog,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Producto>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <Producto>[];
          if (items.isEmpty) {
            return const Center(child: Text('Aun no tienes productos.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.nombre),
                subtitle: Text(p.descripcion ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\$${p.precio.toStringAsFixed(2)}'),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar',
                      onPressed: () => _showEditProductDialog(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar',
                      onPressed: () => _confirmDelete(p),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showNewProductDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imagenCtrl = TextEditingController();
    final categoriaCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              TextField(
                controller: imagenCtrl,
                decoration: const InputDecoration(labelText: 'Imagen URL'),
              ),
              TextField(
                controller: categoriaCtrl,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final nombre = nameCtrl.text.trim();
    final precio = double.tryParse(priceCtrl.text.trim()) ?? 0;
    if (nombre.isEmpty || precio <= 0) return;

    final nuevo = Producto(
      idProducto: 0,
      nombre: nombre,
      precio: precio,
      descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      imagenUrl: imagenCtrl.text.trim().isEmpty ? null : imagenCtrl.text.trim(),
      categoria:
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim(),
      disponible: true,
    );

    // Muestra un loader modal mientras se crea el producto
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await context
          .read<DatabaseService>()
          .createProductoParaNegocio(widget.negocioUser.idUsuario, nuevo);
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(_reload);
      messenger.showSnackBar(
        SnackBar(
          content: Text(created != null ? 'Producto creado' : 'No se pudo crear el producto'),
          backgroundColor: created != null ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Error al crear producto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showEditProductDialog(Producto p) async {
    final nameCtrl = TextEditingController(text: p.nombre);
    final priceCtrl = TextEditingController(text: p.precio.toStringAsFixed(2));
    final descCtrl = TextEditingController(text: p.descripcion ?? '');
    final imagenCtrl = TextEditingController(text: p.imagenUrl ?? '');
    final categoriaCtrl = TextEditingController(text: p.categoria ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              TextField(
                controller: imagenCtrl,
                decoration: const InputDecoration(labelText: 'Imagen URL'),
              ),
              TextField(
                controller: categoriaCtrl,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != true) return;

    final updated = Producto(
      idProducto: p.idProducto,
      nombre: nameCtrl.text.trim().isEmpty ? p.nombre : nameCtrl.text.trim(),
      precio: double.tryParse(priceCtrl.text.trim()) ?? p.precio,
      descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      imagenUrl: imagenCtrl.text.trim().isEmpty ? null : imagenCtrl.text.trim(),
      categoria:
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim(),
      disponible: p.disponible,
      idNegocio: p.idNegocio,
      idCategoria: p.idCategoria,
      stock: p.stock,
      fechaCreacion: p.fechaCreacion,
    );

    final db2 = context.read<DatabaseService>();
    await db2.updateProducto(updated);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _confirmDelete(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('Eliminar "${p.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final db3 = context.read<DatabaseService>();
      await db3.deleteProducto(p.idProducto);
      if (!mounted) return;
      setState(_reload);
    }
  }
}
