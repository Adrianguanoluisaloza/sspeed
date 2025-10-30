import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/recomendacion_data.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import 'widgets/login_required_dialog.dart';

class ProductDetailScreen extends StatefulWidget {
  final Producto producto;
  final Usuario usuario;
  final bool openReviews;

  const ProductDetailScreen({
    super.key,
    required this.producto,
    required this.usuario,
    this.openReviews = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  double _userRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  late Future<RecomendacionesProducto> _recomendacionesFuture;
  final GlobalKey _reviewsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _recomendacionesFuture =
        dbService.getRecomendacionesPorProducto(widget.producto.idProducto);
    if (widget.openReviews) {
      // Desplazar a la sección de reseñas al cargar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _reviewsKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350));
        }
      });
    }
  }

  void _refreshReviews() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _recomendacionesFuture =
          dbService.getRecomendacionesPorProducto(widget.producto.idProducto);
    });
  }

  Future<void> _submitReview() async {
    if (!widget.usuario.isAuthenticated) {
      showLoginRequiredDialog(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    if (_userRating == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una puntuacion (estrellas).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final success = await dbService.addRecomendacion(
        idProducto: widget.producto.idProducto,
        idUsuario: widget.usuario.idUsuario,
        puntuacion: _userRating.toInt(),
        comentario: _commentController.text.trim(),
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'Gracias por tu resena!' : 'Error al enviar la resena.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _commentController.clear();
        _refreshReviews();
        setState(() {
          _userRating = 0;
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ocurrio un error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  Widget _buildReviewsSection() {
    return FutureBuilder<RecomendacionesProducto>(
      future: _recomendacionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No se pudieron cargar las resenas.'),
          );
        }

        final data = snapshot.data ?? RecomendacionesProducto.vacio;
        final resumen = data.resumen;
        final lista = data.recomendaciones;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  resumen.ratingPromedio.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('(${resumen.totalResenas} resenas)', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              const Text('Aun no hay resenas. Se el primero en opinar.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ReviewTile(review: lista[index]),
              ),
          ],
        );
      },
    );
  }
@override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.producto.nombre),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Hero(
              tag: 'product-${widget.producto.idProducto}',
              child: _DetailImage(imageUrl: widget.producto.imagenUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.producto.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('\$${widget.producto.precio.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  const SizedBox(height: 20),
                  const Text('Descripcion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),
                  Text(widget.producto.descripcion ?? 'Sin descripcion disponible.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5)),
                  const SizedBox(height: 24),
                  const Text('Calificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),
                  const SizedBox(height: 12),
                  Container(key: _reviewsKey, child: _buildReviewsSection()),
                  const SizedBox(height: 30),
                  const Text('Deja tu resena', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),
                  const SizedBox(height: 10),
                  Center(
                    child: RatingBar.builder(
                      initialRating: _userRating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      itemCount: 5,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) => setState(() => _userRating = rating),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Escribe tu comentario (opcional)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSubmittingReview ? null : _submitReview,
                    child: _isSubmittingReview
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enviar resena'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Anadir al Carrito'),
          onPressed: () {
              cart.addToCart(widget.producto);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.producto.nombre} fue anadido al carrito.'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Recomendacion review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final dateText = review.fechaRecomendacion != null
        ? review.fechaRecomendacion!.toLocal().toIso8601String().split('T').first
        : 'Fecha no disponible';
    final rating = review.puntuacion.clamp(0, 5).toInt();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Usuario #${review.idUsuario}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(dateText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final filled = index < rating;
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 18,
                  color: filled ? Colors.amber : Colors.grey.shade400,
                );
              }),
            ),
            if ((review.comentario ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comentario!, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
class _DetailImage extends StatelessWidget {
  final String? imageUrl;
  const _DetailImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _DetailPlaceholder(icon: Icons.fastfood);
    }
    return Image.network(
      imageUrl!,
      height: 300,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _DetailPlaceholder(icon: Icons.image_not_supported),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(height: 300, child: const Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  final IconData icon;
  const _DetailPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.grey.shade400, size: 80),
    );
  }
}






