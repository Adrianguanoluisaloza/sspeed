import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/producto.dart';
import '../models/usuario.dart';
import '../screen/product_detail_screen.dart';
import '../services/database_service.dart';

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
            return RecommendationCard(productoRankeado: rec, usuario: usuario);
          },
          options: CarouselOptions(
            height: 200,
            enlargeCenterPage: true,
            enableInfiniteScroll: recomendaciones.length > 1,
            autoPlay: recomendaciones.length > 1,
            autoPlayInterval: const Duration(seconds: 6),
            viewportFraction: 0.78,
          ),
        );
      },
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final ProductoRankeado productoRankeado;
  final Usuario usuario;
  const RecommendationCard({
    super.key,
    required this.productoRankeado,
    required this.usuario,
  });

  Future<void> _navigateToProduct(BuildContext context,
      {bool openReviews = false}) async {
    final dbService = context.read<DatabaseService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final fullProduct =
          await dbService.getProductoById(productoRankeado.idProducto);
      if (!context.mounted) return;

      if (fullProduct != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              producto: fullProduct,
              usuario: usuario,
              openReviews: openReviews,
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Producto no encontrado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al cargar el producto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comentario = productoRankeado.comentarioReciente;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToProduct(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RecommendationImage(
                    url: productoRankeado.imagenUrl,
                    size: 86,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((productoRankeado.negocio ?? '').isNotEmpty)
                          Text(
                            productoRankeado.negocio!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          productoRankeado.nombre,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (productoRankeado.precio != null)
                          Text(
                            '\$${productoRankeado.precio!.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.amber.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              productoRankeado.ratingPromedio
                                  .toStringAsFixed(1),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${productoRankeado.totalReviews} reseñas',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.hintColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (comentario != null && comentario.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '"$comentario"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.hintColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _navigateToProduct(context, openReviews: false),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Ver producto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Ver reseñas',
                    onPressed: () =>
                        _navigateToProduct(context, openReviews: true),
                    icon: const Icon(Icons.reviews_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationImage extends StatelessWidget {
  final String? url;
  final double size;
  const _RecommendationImage({required this.url, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    if (url == null || url!.isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(38),
              Theme.of(context).colorScheme.primary.withAlpha(13),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, size: 32, color: Colors.black54),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url!,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.fastfood, size: 32, color: Colors.black54),
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
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}
