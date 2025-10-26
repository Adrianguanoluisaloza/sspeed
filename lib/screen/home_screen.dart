import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../models/session_state.dart';
import '../models/cart_model.dart';
import '../services/database_service.dart';

import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Producto> _productos = [];
  List<Producto> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = context.read<DatabaseService>();
      final items = await db.getProductos();
      setState(() {
        _productos = items;
        _filtered = items;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sspeed Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (ctx) => CartScreen(usuario: session.usuario),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (session.isAuthenticated) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => ProfileScreen(usuario: session.usuario),
                ));
              } else {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => const LoginScreen(),
                ));
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text(session.isAuthenticated
                  ? 'Bienvenido, ${session.usuario.nombre}'
                  : 'Bienvenido'),
            ),
            ListTile(
              title: const Text('Inicio'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              title: const Text('Mis Pedidos'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => OrderHistoryScreen(usuario: session.usuario),
                ));
              },
            ),
            ListTile(
              title: const Text('Soporte (Chat)'),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => ChatScreen(initialSection: ChatSection.soporte),
                ));
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar productos...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    final query = _searchController.text;
                    if (query.isNotEmpty) {
                      setState(() {
                        _filtered = _productos
                            .where((p) => p.nombre.toLowerCase().contains(query.toLowerCase()))
                            .toList();
                      });
                    } else {
                      setState(() => _filtered = _productos);
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  setState(() {
                    _filtered = _productos
                        .where((p) => p.nombre.toLowerCase().contains(query.toLowerCase()))
                        .toList();
                  });
                } else {
                  setState(() => _filtered = _productos);
                }
              },
            ),
          ),

          // Banner simple
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [Colors.orange.shade300, Colors.deepOrange.shade400]),
            ),
            child: const Center(
              child: Text(
                'Promociones',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),

          // Lista de Productos
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _filtered.isEmpty
                        ? const Center(child: Text('No se encontraron productos.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(10.0),
                            itemCount: _filtered.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3 / 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemBuilder: (ctx, i) => Card(
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (ctx) => ProductDetailScreen(
                                      producto: _filtered[i],
                                      usuario: session.usuario,
                                    ),
                                  ));
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15.0)),
                                        child: Image.network(
                                          _filtered[i].imagenUrl ?? '',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Icon(Icons.fastfood, size: 80, color: Colors.grey[400]),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        _filtered[i].nombre,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        '\$${_filtered[i].precio.toStringAsFixed(2)}',
                                        style: TextStyle(color: Colors.green[700], fontSize: 15, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                                        label: const Text('Añadir'),
                                        onPressed: () {
                                          context.read<CartModel>().addToCart(_filtered[i]);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${_filtered[i].nombre} añadido al carrito!'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
