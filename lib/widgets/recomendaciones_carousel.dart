import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/producto.dart';
import '../services/database_service.dart';

class RecomendacionesCarousel extends StatefulWidget {
  const RecomendacionesCarousel({super.key});

  @override
  State<RecomendacionesCarousel> createState() => _RecomendacionesCarouselState();
}

class _RecomendacionesCarouselState extends State<RecomendacionesCarousel> {
  late Future<List<ProductoRankeado>> _recomendacionesFuture;

  @override
  void initState() {
    super.initState();
    // Se instancia el future aquí para que no se llame en cada rebuild
    _recomendacionesFuture = context.read<DatabaseService>().getRecomendaciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductoRankeado>>(
      future: _recomendacionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RecommendationsLoading(); // Efecto Shimmer
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          // No muestra nada si hay error o no hay datos, para no ensuciar la UI.
          return const SizedBox.shrink();
        }

        final recomendaciones = snapshot.data!;
        return CarouselSlider.builder(
          itemCount: recomendaciones.length,
          itemBuilder: (context, index, realIndex) {
            final rec = recomendaciones[index];
            return RecommendationCard(producto: rec);
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
  final ProductoRankeado producto;
  const RecommendationCard({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(producto.ratingPromedio.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(' (${producto.totalReviews} reseñas)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(child: const Text('Ver Producto'), onPressed: () { /* TODO: Navegar al detalle */ }),
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
