import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/cart_model.dart';
import 'package:flutter_application_2/models/ubicacion.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/screen/order_tracking_screen.dart';
import 'package:flutter_application_2/services/database_service.dart';
import 'package:provider/provider.dart';

class CheckoutSummaryScreen extends StatefulWidget {
  final Usuario usuario;
  final Ubicacion selectedLocation;

  const CheckoutSummaryScreen({
    super.key,
    required this.usuario,
    required this.selectedLocation,
  });

  @override
  State<CheckoutSummaryScreen> createState() => _CheckoutSummaryScreenState();
}

class _CheckoutSummaryScreenState extends State<CheckoutSummaryScreen> {
  bool _isLoading = false;

  Future<void> _placeOrder(CartModel cart) async {
    setState(() => _isLoading = true);

    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      // --- AHORA SE USA EL MÉTODO REAL ---
      final success = await databaseService.placeOrder(
        user: widget.usuario,
        cart: cart,
        location: widget.selectedLocation, paymentMethod: '',
      );
      // -----------------------------------

      if (!mounted) return;

      if (success) {
        cart.clearCart();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OrderTrackingScreen()),
              (Route<dynamic> route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hubo un error al procesar tu pedido.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
        title: const Text('Confirmar Pedido'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Entregar en:'),
            _buildAddressCard(widget.selectedLocation),
            _buildSectionTitle('Productos en tu pedido:'),
            _buildProductsList(cart),
            _buildSectionTitle('Método de Pago:'),
            _buildPaymentMethodCard(),
            _buildSectionTitle('Resumen de Costos:'),
            _buildCostsSummary(cart.total, shippingCost, total),
          ],
        ),
      ),
      bottomNavigationBar: _buildConfirmButton(cart),
    );
  }

  // --- Widgets de la pantalla ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAddressCard(Ubicacion location) {
    final direccionVisible = (location.direccion ?? 'Sin datos').trim().isEmpty
        ? 'Sin datos'
        : (location.direccion ?? 'Sin datos').trim();
    // Mostramos dirección segura para evitar nulos provenientes de la base.
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.deepOrange),
        title: Text(direccionVisible, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Lat: ${location.latitud?.toStringAsFixed(4) ?? 'N/A'}, Lon: ${location.longitud?.toStringAsFixed(4) ?? 'N/A'}'),
      ),
    );
  }

  Widget _buildProductsList(CartModel cart) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return ListTile(
          leading: Text('${item.quantity}x',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          title: Text(item.producto.nombre),
          trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
        );
      },
    );
  }

  Widget _buildPaymentMethodCard() {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.money, color: Colors.green),
        title: Text('Efectivo al recibir'),
        subtitle: Text('Pagarás al repartidor en la entrega.'),
      ),
    );
  }

  Widget _buildCostsSummary(double subtotal, double shipping, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text('\$${subtotal.toStringAsFixed(2)}')
                ]),
            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Envío:'),
                  Text('\$${shipping.toStringAsFixed(2)}')
                ]),
            const Divider(height: 20),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(CartModel cart) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _placeOrder(cart),
        icon: _isLoading
            ? Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(2.0),
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        )
            : const Icon(Icons.check_circle),
        label: const Text('Confirmar Pedido'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle:
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
