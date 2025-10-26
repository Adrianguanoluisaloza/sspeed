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
  String _paymentMethod = 'efectivo'; 
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
        paymentMethod: _paymentMethod,
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
            _buildSectionTitle(context, 'Dirección de Entrega'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Colors.green),
                title: Text(widget.ubicacion.direccion ?? 'Dirección no especificada'),
                subtitle: Text('Lat: ${widget.ubicacion.latitud.toStringAsFixed(4)}, Lon: ${widget.ubicacion.longitud.toStringAsFixed(4)}'),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, 'Método de Pago'),
            Card(
              child: Column(
                children: [
                  // Efectivo
                  _buildPaymentOption(
                    title: 'Efectivo contra entrega',
                    value: 'efectivo',
                    icon: Icons.money_outlined,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Tarjeta
                  _buildPaymentOption(
                    title: 'Tarjeta de Crédito/Débito',
                    value: 'tarjeta',
                    icon: Icons.credit_card_outlined,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Transferencia
                  _buildPaymentOption(
                    title: 'Transferencia Bancaria',
                    value: 'transferencia',
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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

  // Widget auxiliar para las opciones de pago
  Widget _buildPaymentOption({required String title, required String value, required IconData icon}) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        value: value,
        groupValue: _paymentMethod,
        onChanged: (newValue) {
          if (newValue != null) {
            setState(() => _paymentMethod = newValue);
          }
        },
      ),
      trailing: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      onTap: () => setState(() => _paymentMethod = value),
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
