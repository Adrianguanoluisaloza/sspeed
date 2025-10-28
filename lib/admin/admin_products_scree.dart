import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/producto.dart';
import 'package:flutter_application_2/services/api_exception.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

import 'admin_edit_product_screen.dart' show AdminEditProductScreen;

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late Future<List<Producto>> _productosFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    _productosFuture = Provider.of<DatabaseService>(context, listen: false).getAllProductosAdmin();
  }

  void _refreshProducts() {
    setState(() {
      _loadProducts();
    });
  }



  void _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (result == true && mounted) {
      _refreshProducts();
    }
  }

  Future<void> _deleteProduct(Producto product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${product.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final success = await db.deleteProducto(product.idProducto);

      if (success) {
        messenger.showSnackBar(const SnackBar(content: Text('Producto eliminado con éxito'), backgroundColor: Colors.green));
        _refreshProducts();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo eliminar el producto'), backgroundColor: Colors.red));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Productos'),
      ),
      body: FutureBuilder<List<Producto>>(
        future: _productosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final productos = snapshot.data ?? [];
          return ListView.builder(
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final producto = productos[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            producto.imagenUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Colors.grey, size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Precio: \$${producto.precio.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            _buildAvailabilityChip(producto.disponible),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Editar',
                        onPressed: () => _navigateAndRefresh(AdminEditProductScreen(producto: producto)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteProduct(producto),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const AdminEditProductScreen()), // Navega a la pantalla de creación
        tooltip: 'Añadir Producto',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAvailabilityChip(bool available) {
    return Chip(
      avatar: Icon(available ? Icons.check_circle_outline : Icons.cancel_outlined, color: Colors.white, size: 16),
      label: Text(available ? 'Disponible' : 'No Disponible', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: available ? Colors.green.shade400 : Colors.red.shade400,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      labelPadding: const EdgeInsets.only(left: 2.0, right: 6.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
