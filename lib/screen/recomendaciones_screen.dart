import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

// ¡CAMBIO CLAVE!
// Importamos el archivo que contiene la definición correcta de ProductoRankeado,
// que es la misma que usa DatabaseService.
import '../models/producto.dart';

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
    _recomendacionesFuture = Provider.of<DatabaseService>(context, listen: false).getRecomendaciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Recomendaciones'),
        backgroundColor: Colors.red.shade400,
        elevation: 0,
      ),
      body: FutureBuilder<List<ProductoRankeado>>(
        future: _recomendacionesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }
          if (snapshot.hasError) {
            debugPrint('Error al cargar recomendaciones: ${snapshot.error}');
            return const Center(child: Text('Error al cargar el ranking.'));
          }

          final ranking = snapshot.data ?? [];

          if (ranking.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No hay productos en el ranking. Intenta añadir recomendaciones a la BD.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: ranking.length,
            itemBuilder: (context, index) {
              final productoRankeado = ranking[index];
              return _RankingItem(
                index: index,
                productoRankeado: productoRankeado,
              );
            },
          );
        },
      ),
    );
  }
}

class _RankingItem extends StatelessWidget {
  final int index;
  final ProductoRankeado productoRankeado;
  const _RankingItem({required this.index, required this.productoRankeado});

  @override
  Widget build(BuildContext context) {
    final ranking = index + 1;
    Color rankColor = Colors.grey.shade400;
    if (ranking == 1) rankColor = Colors.amber.shade700;
    if (ranking == 2) rankColor = Colors.blueGrey.shade300;
    if (ranking == 3) rankColor = Colors.brown.shade400;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$ranking',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          productoRankeado.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${productoRankeado.totalReviews} opiniones',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              productoRankeado.ratingPromedio.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade600,
              ),
            ),
            const Icon(Icons.star, color: Colors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}

