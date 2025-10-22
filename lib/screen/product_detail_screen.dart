import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // <-- Importar paquete

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/usuario.dart'; // <-- Necesitamos el usuario para enviar la reseña
import '../services/database_service.dart'; // <-- Necesitamos el servicio

// AÑADIR EL PARÁMETRO 'usuario'
class ProductDetailScreen extends StatefulWidget {
  final Producto producto;
  final Usuario usuario; // <-- AÑADIDO

  const ProductDetailScreen({
    super.key,
    required this.producto,
    required this.usuario, // <-- AÑADIDO
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Estado para la reseña
  double _userRating = 0; // 0 significa sin calificar aún
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;

  // Método para enviar la reseña
  Future<void> _submitReview() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una puntuación (estrellas).'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    final success = await dbService.addRecomendacion(
      idProducto: widget.producto.idProducto,
      idUsuario: widget.usuario.idUsuario, // <-- Usar ID del usuario actual
      puntuacion: _userRating.toInt(),
      comentario: _commentController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '¡Gracias por tu reseña!' : 'Error al enviar la reseña.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      // Opcional: Limpiar campos o cerrar si fue exitoso
      if(success) {
        // Podrías limpiar _userRating = 0; _commentController.clear();
        // O incluso Navigator.pop(context);
      }
    }

    setState(() => _isSubmittingReview = false);
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
              child: Image.network(
                widget.producto.imagenUrl,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.fastfood,
                        color: Colors.grey.shade400, size: 80),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.producto.nombre,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${widget.producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(),
                  Text(
                    widget.producto.descripcion,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),

                  // --- SECCIÓN DE RESEÑAS ---
                  const SizedBox(height: 30),
                  const Text(
                    'Deja tu reseña',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Widget de Estrellas
                  Center(
                    child: RatingBar.builder(
                      initialRating: _userRating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: false, // Permitir solo estrellas completas
                      itemCount: 5,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _userRating = rating;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo de Comentario
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu comentario (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Botón de Enviar Reseña
                  ElevatedButton(
                    onPressed: _isSubmittingReview ? null : _submitReview,
                    child: _isSubmittingReview
                        ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enviar Reseña'),
                  ),
                  // --- FIN SECCIÓN DE RESEÑAS ---

                ],
              ),
            ),
          ],
        ),
      ),
      // Botón flotante para añadir al carrito (sin cambios)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Añadir al Carrito'),
          onPressed: () {
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
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

