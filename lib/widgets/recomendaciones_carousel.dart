import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/producto.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import '../screen/product_detail_screen.dart';

// CORRECCIÓN: El widget ahora requiere el usuario para la navegación
class RecomendacionesCarousel extends StatelessWidget {
  final Usuario usuario;
  const RecomendacionesCarousel({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductoRankeado>>(
      future: context.watch<DatabaseService>().getRecomendaciones(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RecommendationsLoading();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recomendaciones = snapshot.data!;
        return CarouselSlider.builder(
          itemCount: recomendaciones.length,
          itemBuilder: (context, index, realIndex) {
            final rec = recomendaciones[index];
            // Se pasa el usuario a la tarjeta
            return RecommendationCard(productoRankeado: rec, usuario: usuario);
          },
          options: CarouselOptions(
            height: 180,
            enlargeCenterPage: true,
            autoPlay: recomendaciones.length > 1,
            autoPlayInterval: const Duration(seconds: 6),
            viewportFraction: 0.8,
          ),
        );
      },
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final ProductoRankeado productoRankeado;
  final Usuario usuario; // Se recibe el usuario
  const RecommendationCard({super.key, required this.productoRankeado, required this.usuario});

  // CORRECCIÓN: Se implementa la lógica del botón
  Future<void> _navigateToProduct(BuildContext context) async {
    final dbService = context.read<DatabaseService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final fullProduct = await dbService.getProductoById(productoRankeado.idProducto);
      
      if (!context.mounted) return;

      if (fullProduct != null) {
        navigator.push(MaterialPageRoute(
          builder: (context) => ProductDetailScreen(producto: fullProduct, usuario: usuario),
        ));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Producto no encontrado.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al cargar el producto: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(productoRankeado.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(productoRankeado.ratingPromedio.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(' (${productoRankeado.totalReviews} reseñas)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => _navigateToProduct(context), child: const Text('Ver Producto')),
            ),
          ],
        ),
      ),
    );
  }
}

class RecommendationsLoading extends StatelessWidget {
  const RecommendationsLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 3,
          itemBuilder: (c, i) => const SizedBox(width: 280, child: Card()),
        ),
      ),
    );
  }
}
