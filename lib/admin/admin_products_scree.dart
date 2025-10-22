import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/producto.dart';
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
    if (result == true) {
      _refreshProducts();
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(producto.imagenUrl),
                  onBackgroundImageError: (_, __) {},
                  child: producto.imagenUrl.isEmpty ? const Icon(Icons.fastfood) : null,
                ),
                title: Text(producto.nombre),
                subtitle: Text('\$${producto.precio.toStringAsFixed(2)}'),
                trailing: producto.disponible
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.cancel, color: Colors.red),
                onTap: () => _navigateAndRefresh(
                  AdminEditProductScreen(producto: producto),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(const AdminEditProductScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
