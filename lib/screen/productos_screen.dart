import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/producto.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  late Future<List<Producto>> _productosFuture;

  @override
  void initState() {
    super.initState();
    // ¡CAMBIO CLAVE!
    // Obtenemos la instancia de DatabaseService del Provider.
    // listen: false es importante en initState.
    _productosFuture = Provider.of<DatabaseService>(context, listen: false).getProductos(query: '', categoria: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de Productos'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<Producto>>(
        future: _productosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Error al cargar productos: ${snapshot.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Error al cargar productos. Revisa la conexión a Neon y las credenciales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          final productos = snapshot.data ?? [];
          if (productos.isEmpty) {
            return const Center(
              child: Text('No hay productos disponibles.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final producto = productos[index];
              return _ProductCard(producto: producto);
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Producto producto;
  const _ProductCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (producto.imagenUrl ?? '').trim();
    final descripcionVisible = (producto.descripcion ?? 'Sin descripción').trim().isEmpty
        ? 'Sin descripción'
        : (producto.descripcion ?? 'Sin descripción').trim();
    // Resguardamos valores nulos del backend para no romper la UI ni el análisis estático.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
          child: imageUrl.isEmpty || imageUrl.contains('placeholder')
              ? Icon(Icons.fastfood, color: Colors.orange.shade700) // Fallback si es placeholder
              : null,
        ),
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          descripcionVisible,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '\$${producto.precio.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Seleccionaste: ${producto.nombre}')),
          );
        },
      ),
    );
  }
}
