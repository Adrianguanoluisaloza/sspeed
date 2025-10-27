import 'package:flutter/material.dart';
import '../models/usuario.dart';
import 'package:provider/provider.dart';

import '../models/cart_model.dart';
import '../routes/app_routes.dart';

class CartScreen extends StatelessWidget {
  final Usuario usuario;
  const CartScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    // La lógica para usuarios no autenticados se mantiene igual
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
              ? _buildEmptyCartView(context) // Vista rediseñada para carrito vacío
              : _buildCartListView(cart), // Vista rediseñada para la lista
          // El resumen y botón de pago ahora están en una barra inferior fija
          bottomNavigationBar: cart.items.isNotEmpty
              ? _buildSummaryAndCheckout(context, cart, usuario)
              : null,
        );
      },
    );
  }

  // --- WIDGETS DE LA UI REDISEÑADOS ---

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
              onPressed: () => Navigator.of(context).pop(), // Vuelve a la pantalla anterior (tienda)
              label: const Text('Explorar productos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartListView(CartModel cart) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 90), // Padding inferior para que el último ítem no quede oculto por la barra
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
      padding: const EdgeInsets.all(16).copyWith(bottom: 24), // Padding seguro para la parte inferior
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -5))],
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
  
  Widget _buildLoggedOutView(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Carrito')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Inicia sesión para usar el carrito', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                  child: const Text('Iniciar Sesión o Registrarse'),
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
          IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => cart.decrementQuantity(cartItem.producto.idProducto)),
          Text('${cartItem.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => cart.incrementQuantity(cartItem.producto.idProducto)),
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
    return Image.network(imageUrl!, width: 80, height: 80, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(width: 80, height: 80, color: Colors.grey.shade200, alignment: Alignment.center, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
    );
  }
}
