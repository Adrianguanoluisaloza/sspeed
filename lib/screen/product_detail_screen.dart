import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import 'widgets/login_required_dialog.dart';

class ProductDetailScreen extends StatefulWidget {
  final Producto producto;
  final Usuario usuario;

  const ProductDetailScreen({
    super.key,
    required this.producto,
    required this.usuario,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  double _userRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;

  // CORRECCIÓN COMPLETA DE LA LÓGICA
  Future<void> _submitReview() async {
    // Se usa la nueva lógica de autenticación
    if (!widget.usuario.isAuthenticated) {
      showLoginRequiredDialog(context);
      return;
    }

    // Se obtienen las dependencias ANTES de cualquier await
    final messenger = ScaffoldMessenger.of(context);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    if (_userRating == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una puntuación (estrellas).'), backgroundColor: Colors.orange),
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
          content: Text(success ? '¡Gracias por tu reseña!' : 'Error al enviar la reseña.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _commentController.clear();
        setState(() {
          _userRating = 0;
        });
      }
    } catch (e) {
        messenger.showSnackBar(
             SnackBar(content: Text('Ocurrió un error: ${e.toString()}'), backgroundColor: Colors.red),
        );
    } finally {
        if(mounted) {
            setState(() => _isSubmittingReview = false);
        }
    }
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
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),
                  Text(widget.producto.descripcion ?? 'Sin descripción disponible.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5)),
                  const SizedBox(height: 30),
                  const Text('Deja tu reseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                        : const Text('Enviar Reseña'),
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
          label: const Text('Añadir al Carrito'),
          onPressed: !widget.usuario.isAuthenticated // CORRECCIÓN
              ? () => showLoginRequiredDialog(context)
              : () {
                  cart.addToCart(widget.producto);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.producto.nombre} fue añadido al carrito.'),
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
