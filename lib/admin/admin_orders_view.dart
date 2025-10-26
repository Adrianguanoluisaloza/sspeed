import 'package:flutter/material.dart';

class AdminOrdersView extends StatelessWidget {
  const AdminOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos Pendientes'),
      ),
      body: const Center(
        child: Text('Aquí se mostrará la lista de pedidos pendientes para gestionar.'),
      ),
    );
  }
}
