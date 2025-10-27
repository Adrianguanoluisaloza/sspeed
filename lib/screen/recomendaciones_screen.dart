import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../services/database_service.dart';

class RecomendacionesScreen extends StatefulWidget {
  const RecomendacionesScreen({super.key});

  @override
  State<RecomendacionesScreen> createState() => _RecomendacionesScreenState();
}

class _RecomendacionesScreenState extends State<RecomendacionesScreen> {
  late Future<List<ProductoRankeado>> _recomendacionesFuture;

  @override
  void initState() {
    super.initState();
    _loadRecomendaciones();
  }

  void _loadRecomendaciones() {
    _recomendacionesFuture = Provider.of<DatabaseService>(context, listen: false).getRecomendaciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Recomendaciones'),
        // Usamos el color del tema para consistencia
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _loadRecomendaciones()),
        child: FutureBuilder<List<ProductoRankeado>>(
          future: _recomendacionesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar el ranking.'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No hay recomendaciones disponibles.'));
            }

            final ranking = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: ranking.length,
              itemBuilder: (context, index) {
                return _RankingItem(index: index, productoRankeado: ranking[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGETS DE LA UI REDISEÑADOS ---

class _RankingItem extends StatelessWidget {
  final int index;
  final ProductoRankeado productoRankeado;
  const _RankingItem({required this.index, required this.productoRankeado});

  @override
  Widget build(BuildContext context) {
    final ranking = index + 1;
    Color rankColor = Colors.grey.shade600;
    IconData? rankIcon;

    if (ranking == 1) {
      rankColor = const Color(0xFFD4AF37); // Oro
      rankIcon = Icons.emoji_events;
    }
    if (ranking == 2) {
      rankColor = const Color(0xFFC0C0C0); // Plata
      rankIcon = Icons.emoji_events;
    }
    if (ranking == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronce
      rankIcon = Icons.emoji_events;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Borde destacado para el Top 3
        side: ranking <= 3 ? BorderSide(color: rankColor, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text('#$ranking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: rankColor)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rankIcon != null) Icon(rankIcon, color: rankColor, size: 20),
                      if (rankIcon != null) const SizedBox(width: 8),
                      Expanded(child: Text(productoRankeado.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _StarRating(rating: productoRankeado.ratingPromedio, reviewCount: productoRankeado.totalReviews),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  final int reviewCount;
  const _StarRating({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            if (index < rating.floor()) {
              return const Icon(Icons.star, color: Colors.amber, size: 18);
            } else if (index < rating) {
              return const Icon(Icons.star_half, color: Colors.amber, size: 18);
            } else {
              return const Icon(Icons.star_border, color: Colors.amber, size: 18);
            }
          }),
        ),
        const SizedBox(width: 8),
        Text('${rating.toStringAsFixed(1)} ($reviewCount)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}
