import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/screen/checkout_address_screen.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../routes/app_routes.dart';

// 1. AÑADE EL PARÁMETRO 'usuario'
class CartScreen extends StatelessWidget {
  final Usuario usuario;
  const CartScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Se usa la nueva lógica de autenticación
    if (!usuario.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Carrito de Compras'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 96, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Inicia sesión para usar el carrito',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Necesitamos tu cuenta para guardar tu carrito y tus pedidos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.login),
                  child: const Text('Iniciar sesión'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.register),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Consumer<CartModel>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi Carrito de Compras'),
          ),
          body: cart.items.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 100, color: Colors.grey),
                SizedBox(height: 20),
                Text('Tu carrito está vacío',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Añade productos para verlos aquí.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          )
              : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items[index];
                    return CartItemCard(cartItem: cartItem);
                  },
                ),
              ),
              // 2. PASA EL 'usuario' AL WIDGET DE RESUMEN
              _buildSummaryCard(context, cart, usuario),
            ],
          ),
        );
      },
    );
  }
}

// ... (El widget CartItemCard no necesita cambios)
class CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  const CartItemCard({super.key, required this.cartItem});
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return Dismissible(
        key: Key(cartItem.producto.idProducto.toString()),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) {
          cart.removeItem(cartItem.producto.idProducto);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${cartItem.producto.nombre} eliminado del carrito.'),
              backgroundColor: Colors.red));
        },
        background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _CartImage(imageUrl: cartItem.producto.imagenUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cartItem.producto.nombre,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                '\$${cartItem.producto.precio.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey))
                          ])),
                  const SizedBox(width: 12),
                  _buildQuantityControl(context, cart)
                ]))));
  }

  Widget _buildQuantityControl(BuildContext context, CartModel cart) {
    return Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () {
                cart.decrementQuantity(cartItem.producto.idProducto);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
          Text('${cartItem.quantity}',
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                cart.incrementQuantity(cartItem.producto.idProducto);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints())
        ]));
  }
}

class _CartImage extends StatelessWidget {
  final String? imageUrl;

  const _CartImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.grey),
      );
    }

    return Image.network(
      imageUrl!,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 70,
        height: 70,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}

// 3. RECIBE EL 'usuario' Y ÚSALO EN LA NAVEGACIÓN
Widget _buildSummaryCard(BuildContext context, CartModel cart, Usuario usuario) {
  const double shippingCost = 2.00;
  final double total = cart.total + shippingCost;

  return Card(
    margin: const EdgeInsets.all(12),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                Text('\$${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16))
              ]),
          const SizedBox(height: 8),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Costo de envío:', style: TextStyle(fontSize: 16)),
                Text('\$${shippingCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16))
              ]),
          const Divider(height: 24),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total a pagar:',
                    style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold))
              ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 4. NAVEGACIÓN A LA NUEVA PANTALLA
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CheckoutAddressScreen(usuario: usuario),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              child: const Text('Proceder al Pago'),
            ),
          )
        ],
      ),
    ),
  );
}
