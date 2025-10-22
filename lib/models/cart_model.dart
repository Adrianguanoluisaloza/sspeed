
import 'package:flutter/foundation.dart';
import '../models/producto.dart'; // Asegúrate de que la ruta de Producto sea correcta

/// Clase que envuelve un Producto y añade información específica del carrito (cantidad y subtotal).
class CartItem {
  final Producto producto;
  int quantity;

  // El subtotal es calculado
  double get subtotal => producto.precio * quantity;

  CartItem({
    required this.producto,
    this.quantity = 1,
  });
}

class CartModel extends ChangeNotifier {
  // Cambiamos la lista para guardar CartItem en lugar de solo Producto
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;
  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  void addToCart(Producto producto) {
    // 1. Verificar si el producto ya existe en el carrito
    final existingItemIndex = _items.indexWhere((item) => item.producto.idProducto == producto.idProducto);

    if (existingItemIndex >= 0) {
      // Si existe, incrementa la cantidad
      _items[existingItemIndex].quantity++;
      debugPrint('🛒 Cantidad incrementada para: ${producto.nombre}');
    } else {
      // Si no existe, crea un nuevo CartItem
      _items.add(CartItem(producto: producto, quantity: 1));
      debugPrint('🛒 Producto añadido: ${producto.nombre}');
    }

    notifyListeners();
  }

  void removeItem(int idProducto) {
    // Remueve el CartItem basado en el idProducto
    _items.removeWhere((item) => item.producto.idProducto == idProducto);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // Opcional: Para controlar la cantidad desde la vista
  void incrementQuantity(int idProducto) {
    final item = _items.firstWhere((item) => item.producto.idProducto == idProducto);
    item.quantity++;
    notifyListeners();
  }

  void decrementQuantity(int idProducto) {
    final item = _items.firstWhere((item) => item.producto.idProducto == idProducto);
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      // Si llega a 0, lo eliminamos
      removeItem(idProducto);
    }
    notifyListeners();
  }
}