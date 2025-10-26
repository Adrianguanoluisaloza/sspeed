import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_model.dart';
import '../models/ubicacion.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import '../routes/app_routes.dart';
import '../services/api_exception.dart';

class CheckoutScreen extends StatefulWidget {
  final Usuario usuario;
  final Ubicacion ubicacion;

  const CheckoutScreen({super.key, required this.usuario, required this.ubicacion});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'cash'; // Valor por defecto
  bool _isLoading = false;

  Future<void> _confirmOrder() async {
    final cart = context.read<CartModel>();
    final dbService = context.read<DatabaseService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (cart.items.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Tu carrito está vacío.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await dbService.placeOrder(
        user: widget.usuario,
        cart: cart,
        location: widget.ubicacion,
      );

      if (success) {
        cart.clearCart();
        navigator.pushNamedAndRemoveUntil(AppRoutes.orderSuccess, (route) => false);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo procesar el pedido.'), backgroundColor: Colors.red));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Ocurrió un error inesperado.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    const shippingCost = 2.00;
    final total = cart.total + shippingCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar y Pagar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de la dirección
            _buildSectionTitle(context, 'Dirección de Entrega'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Colors.green),
                title: Text(widget.ubicacion.direccion ?? 'Dirección no especificada'),
                subtitle: Text('Lat: ${widget.ubicacion.latitud.toStringAsFixed(4)}, Lon: ${widget.ubicacion.longitud.toStringAsFixed(4)}'),
              ),
            ),
            const SizedBox(height: 24),

            // Selección de método de pago
            _buildSectionTitle(context, 'Método de Pago'),
            Card(
              child: RadioListTile<String>(
                title: const Text('Efectivo contra entrega'),
                subtitle: const Text('Paga cuando recibas tu pedido'),
                secondary: const Icon(Icons.money, color: Colors.green),
                value: 'cash',
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
              ),
            ),
            // Aquí se podrían añadir más métodos de pago como tarjetas

            const SizedBox(height: 24),

            // Resumen del costo
            _buildSectionTitle(context, 'Resumen de Compra'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildCostRow('Subtotal', '\$${cart.total.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildCostRow('Costo de Envío', '\$${shippingCost.toStringAsFixed(2)}'),
                    const Divider(height: 24),
                    _buildCostRow('Total a Pagar', '\$${total.toStringAsFixed(2)}', isTotal: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _confirmOrder,
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Confirmar Pedido'),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCostRow(String label, String amount, {bool isTotal = false}) {
    final style = TextStyle(
      fontSize: isTotal ? 18 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(amount, style: style)],
    );
  }
}
