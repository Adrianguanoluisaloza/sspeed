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
    _recomendacionesFuture = context.read<DatabaseService>().getRecomendaciones();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductoRankeado>>(
      future: _recomendacionesFuture,
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
            final producto = recomendaciones[index];
            return RecommendationCard(producto: producto);
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
  const RecommendationCard({super.key, required this.producto});

  final ProductoRankeado producto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              producto.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(producto.ratingPromedio.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  ' (${producto.totalReviews} resenas)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navegar al detalle del producto.
                },
                child: const Text('Ver Producto'),
              ),
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
          itemBuilder: (_, __) => const SizedBox(width: 280, child: Card()),
        ),
      ),
    );
  }
}
