import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../services/database_service.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  late Future<List<Producto>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    _productsFuture =
        Provider.of<DatabaseService>(context, listen: false).getAllProductosAdmin();
  }

  void _refresh() {
    setState(() {
      _loadProducts();
    });
  }

  /// Widget auxiliar para mostrar el estado del stock de forma visual.
  Widget _buildStockChip(int? stock) {
    if (stock == null) {
      return const Chip(
        avatar: Icon(Icons.help_outline, color: Colors.white, size: 16),
        label: Text('N/A'),
        backgroundColor: Colors.grey,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    Color chipColor;
    String label;
    IconData iconData;

    if (stock == 0) {
      chipColor = Colors.red.shade400;
      label = 'Agotado';
      iconData = Icons.error_outline;
    } else if (stock <= 10) { // Límite para considerar stock bajo
      chipColor = Colors.orange.shade400;
      label = 'Stock bajo ($stock)';
      iconData = Icons.warning_amber_outlined;
    } else {
      chipColor = Colors.green.shade400;
      label = 'En Stock ($stock)';
      iconData = Icons.check_circle_outline;
    }

    return Chip(
      avatar: Icon(iconData, color: Colors.white, size: 16),
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      labelPadding: const EdgeInsets.only(left: 2.0, right: 6.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Productos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<Producto>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar productos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos para mostrar.'));
          }

          final products = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 2, // Sombra sutil para dar profundidad
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Imagen del producto
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imagenUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                                size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Información del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              'Precio: \$${product.precio.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            // --- CAMBIO REALIZADO AQUÍ ---
                            // Se reemplaza el Text simple por el Chip visual.
                            _buildStockChip(product.stock),
                          ],
                        ),
                      ),
                      // Botones de acción
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            /* TODO: Implementar edición */
                          }),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            /* TODO: Implementar eliminación */
                          }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar lógica para añadir un nuevo producto
        },
        tooltip: 'Añadir Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
