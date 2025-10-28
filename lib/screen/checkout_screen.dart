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
    // Usamos read() fuera del async gap para evitar problemas con el context.
    final cart = context.read<CartModel>();
    final dbService = context.read<DatabaseService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (cart.items.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Tu carrito está vacío.')));
      return;
    }

    // Verificamos si el widget sigue montado antes de cambiar el estado.
    if (!mounted) return;
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
        // Navegamos solo si el widget sigue montado.
        if (navigator.mounted) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.orderSuccess, (route) => false);
        }
      } else {
        if (messenger.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('No se pudo procesar el pedido.'), backgroundColor: Colors.red));
        }
      }
    } on ApiException catch (e) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (messenger.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Ocurrió un error inesperado.'), backgroundColor: Colors.red));
      }
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
                  isEnabled: true,
                ),
                _buildPaymentOption(
                  title: 'Tarjeta de Crédito/Débito',
                  subtitle: 'No disponible por el momento',
                  value: 'tarjeta',
                  icon: Icons.credit_card_outlined,
                  isEnabled: false,
                ),
                _buildPaymentOption(
                  title: 'Transferencia Bancaria',
                  subtitle: 'No disponible por el momento',
                  value: 'transferencia',
                  icon: Icons.account_balance_outlined,
                  isEnabled: false,
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
        subtitle: Text('Lat: ${widget.ubicacion.latitud?.toStringAsFixed(4) ?? 'N/A'}, Lon: ${widget.ubicacion.longitud?.toStringAsFixed(4) ?? 'N/A'}'),
      ),
    );
  }

  Widget _buildPaymentOption({required String title, required String subtitle, required String value, required IconData icon, bool isEnabled = true}) {
    final theme = Theme.of(context);
    final isSelected = _paymentMethod == value;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected ? BorderSide(color: theme.primaryColor, width: 2) : BorderSide(color: Colors.grey.shade300),
        ),
        child: InkWell(
          onTap: isEnabled ? () => setState(() => _paymentMethod = value) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              Icon(icon, color: isSelected ? theme.primaryColor : Colors.grey.shade600, size: 32),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ])),
              if (isSelected) Icon(Icons.check_circle, color: theme.primaryColor),
              if (!isEnabled) const Chip(label: Text('Próximamente'), visualDensity: VisualDensity.compact),
            ]),
          ),
        ),
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
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -5))],
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

// Widget auxiliar para la línea punteada
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
