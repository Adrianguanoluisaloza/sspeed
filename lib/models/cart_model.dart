import 'package:flutter/foundation.dart';

import 'producto.dart';

/// Clase que envuelve un Producto y añade información específica del carrito (cantidad y subtotal).
class CartItem {
  final Producto producto;
  int quantity;

  double get subtotal => producto.precio * quantity;

  CartItem({
    required this.producto,
    this.quantity = 1,
  });
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;
  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  void addToCart(Producto producto) {
    final existingItemIndex =
        _items.indexWhere((item) => item.producto.idProducto == producto.idProducto);

    if (existingItemIndex >= 0) {
      _items[existingItemIndex].quantity++;
      debugPrint('Cantidad incrementada para: ${producto.nombre}');
    } else {
      _items.add(CartItem(producto: producto));
      debugPrint('Producto añadido: ${producto.nombre}');
    }

    notifyListeners();
  }

  void removeItem(int idProducto) {
    _items.removeWhere((item) => item.producto.idProducto == idProducto);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  void incrementQuantity(int idProducto) {
    final item = _items.firstWhere((item) => item.producto.idProducto == idProducto);
    item.quantity++;
    notifyListeners();
  }

  void decrementQuantity(int idProducto) {
    final item = _items.firstWhere((item) => item.producto.idProducto == idProducto);
    // If quantity is greater than 1, decrement it. Otherwise, do nothing.
    // The user must explicitly remove the item from the cart.
    if (item.quantity > 1) {
      item.quantity--;
      notifyListeners();
    }
  }
}

