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

class _CheckoutScreenState extends State<CheckoutScreen> with SingleTickerProviderStateMixin {
  String _paymentMethod = 'efectivo';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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

      if (!mounted) return;

      if (success) {
        cart.clearCart();
        navigator.pushNamedAndRemoveUntil(AppRoutes.orderSuccess, (route) => false);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo procesar el pedido.'), backgroundColor: Colors.red));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Ocurrió un error inesperado.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar y Pagar'),
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _animationController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, 'Dirección de Entrega'),
                _buildAddressCard(context),
                const SizedBox(height: 24),

                _buildSectionTitle(context, 'Método de Pago'),
                _buildPaymentOption(
                  title: 'Efectivo contra entrega',
                  subtitle: 'Paga cuando recibas tu pedido',
                  value: 'efectivo',
                  icon: Icons.money_outlined,
                ),
                _buildPaymentOption(
                  title: 'Tarjeta de Crédito/Débito',
                  subtitle: 'Paga de forma segura online',
                  value: 'tarjeta',
                  icon: Icons.credit_card_outlined,
                ),
                _buildPaymentOption(
                  title: 'Transferencia Bancaria',
                  subtitle: 'Te daremos los datos al confirmar',
                  value: 'transferencia',
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle(context, 'Resumen de Compra'),
                _buildSummaryCard(context),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildConfirmButton(context),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAddressCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined, color: Colors.green, size: 32),
        title: Text(widget.ubicacion.direccion ?? 'Dirección no especificada', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Lat: ${widget.ubicacion.latitud.toStringAsFixed(4)}, Lon: ${widget.ubicacion.longitud.toStringAsFixed(4)}'),
      ),
    );
  }

  Widget _buildPaymentOption({required String title, required String subtitle, required String value, required IconData icon}) {
    final theme = Theme.of(context);
    final isSelected = _paymentMethod == value;
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: theme.primaryColor, width: 2) : BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: () => setState(() => _paymentMethod = value),
        leading: Icon(icon, color: isSelected ? theme.primaryColor : Colors.grey.shade600, size: 32),
        title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(subtitle),
        trailing: isSelected ? Icon(Icons.check_circle, color: theme.primaryColor) : null,
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final cart = context.watch<CartModel>();
    const shippingCost = 2.00;
    final total = cart.total + shippingCost;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCostRow('Subtotal', '\$${cart.total.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _buildCostRow('Costo de Envío', '\$${shippingCost.toStringAsFixed(2)}'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: DottedLine(),
            ),
            _buildCostRow('Total a Pagar', '\$${total.toStringAsFixed(2)}', isTotal: true, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, String amount, {bool isTotal = false, TextStyle? style}) {
    final defaultStyle = TextStyle(
      fontSize: isTotal ? 18 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? Theme.of(context).colorScheme.primary : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style ?? defaultStyle), Text(amount, style: style ?? defaultStyle)],
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmOrder,
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
            : const Text('Confirmar Pedido'),
      ),
    );
  }
}

class DottedLine extends StatelessWidget {
  const DottedLine({super.key, this.height = 1, this.color = Colors.grey});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        final dashHeight = height;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
