import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/usuario.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/cart_model.dart';
import '../routes/app_routes.dart';

class CartScreen extends StatelessWidget {
  final Usuario usuario;
  const CartScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    if (!usuario.isAuthenticated) {
      return _buildLoggedOutView(context);
    }

    return Consumer<CartModel>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi Carrito'),
          ),
          body: cart.items.isEmpty
              ? _buildEmptyCartView(context)
              : _buildCartListView(cart),
          bottomNavigationBar: cart.items.isNotEmpty
              ? _buildSummaryAndCheckout(context, cart, usuario)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 120, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text('Tu carrito está vacío', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Parece que todavía no has añadido ningún producto. ¡Empieza a explorar!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.store_outlined),
              onPressed: () => Navigator.of(context).pop(),
              label: const Text('Explorar productos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartListView(CartModel cart) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 140), // Padding inferior para que el último ítem no quede oculto por la barra
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final cartItem = cart.items[index];
        return CartItemCard(cartItem: cartItem);
      },
    );
  }

  Widget _buildSummaryAndCheckout(BuildContext context, CartModel cart, Usuario usuario) {
    const double shippingCost = 2.00;
    final double total = cart.total + shippingCost;

    return Container(
      padding: const EdgeInsets.all(16).copyWith(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total a pagar:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('\$${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.checkoutAddress, arguments: usuario);
              },
              child: const Text('Proceder al Pago'),
            ),
          )
        ],
      ),
    );
  }
  
  // --- VISTA PARA INVITADOS (VERSIÓN MEJORADA) ---
  Widget _buildLoggedOutView(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Carrito')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_person_outlined, size: 80, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Inicia sesión para ver tu carrito',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Guarda productos, sigue tus pedidos y finaliza tus compras más rápido.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                  label: const Text('Iniciar Sesión'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  const CartItemCard({super.key, required this.cartItem});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return Dismissible(
      key: ValueKey(cartItem.producto.idProducto),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        cart.removeItem(cartItem.producto.idProducto);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${cartItem.producto.nombre} eliminado'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
        ));
      },
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _CartImage(imageUrl: cartItem.producto.imagenUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cartItem.producto.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('\$${cartItem.producto.precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildQuantityControl(context, cart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(BuildContext context, CartModel cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: () {
              HapticFeedback.lightImpact();
              cart.decrementQuantity(cartItem.producto.idProducto);
            },
          ),
          Text('${cartItem.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: () {
              HapticFeedback.lightImpact();
              cart.incrementQuantity(cartItem.producto.idProducto);
            },
          ),
        ],
      ),
    );
  }
}

class _CartImage extends StatelessWidget {
  final String? imageUrl;
  const _CartImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(width: 80, height: 80, color: Colors.grey.shade200, alignment: Alignment.center, child: const Icon(Icons.fastfood, color: Colors.grey));
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, error, stackTrace) => Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
      memCacheHeight: 200,
      maxHeightDiskCache: 400,
    );
  }
}
