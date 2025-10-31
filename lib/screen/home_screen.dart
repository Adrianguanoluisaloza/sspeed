import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import 'live_map_screen.dart';
import 'profile_screen.dart';
import '../services/database_service.dart';
import 'widgets/login_required_dialog.dart';
import 'product_detail_screen.dart';
import 'admin_productos_screen.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Producto>> _productosFuture;
  late Future<List<ProductoRankeado>> _recommendationsFuture;
  late Future<List<Map<String, dynamic>>> _repartidoresLocationFuture;
  late Future<Map<String, dynamic>> _adminStatsFuture;
  late DatabaseService _databaseService;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "Todos";
  bool _hasQuery = false;
  Timer? _debounce;
  Timer? _repartidoresRefreshTimer;

  final List<String> _categories = const [
    'Todos',
    'Pizzas',
    'Hamburguesas',
    'Acompanamientos',
    'Bebidas',
    'Postres',
    'Ensaladas',
    'Pastas',
    'Mexicana',
    'Japonesa',
    'Mariscos',
  ];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadProducts();
    _loadRecommendations();
    _loadRepartidoresLocation();
    if (widget.usuario.rol == 'admin') {
      _loadAdminStats();
    }
    _searchController.addListener(_onSearchChanged);
  }

  void _loadAdminStats() {
    setState(() {
      _adminStatsFuture = _databaseService.getAdminStats();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _repartidoresRefreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecommendations() {
    _recommendationsFuture = _databaseService.getRecomendaciones();
  }

  void _loadProducts() {
    final query = _searchController.text.trim();
    final categoryFilter =
        _selectedCategory == 'Todos' ? '' : _selectedCategory;
    setState(() {
      _productosFuture = _databaseService.getProductos(
          query: query, categoria: categoryFilter);
    });
  }

  void _loadRepartidoresLocation() {
    // CORRECCIÓN: Ahora primero obtenemos los pedidos 'en camino' para saber qué repartidores buscar.
    // Esto soluciona el problema de que los marcadores de repartidor no aparecían.
    Future<List<Map<String, dynamic>>> fetchLocations() async {
      final pedidosEnCamino =
          await _databaseService.getPedidosPorEstado('en camino');
      final deliveryIds = pedidosEnCamino
          .where((p) => p.idDelivery != null)
          .map((p) => p.idDelivery!)
          .toSet()
          .toList();

      if (deliveryIds.isEmpty) return [];
      return _databaseService.getRepartidoresLocation(deliveryIds);
    }

    setState(() {
      _repartidoresLocationFuture = fetchLocations();
    });
    _repartidoresRefreshTimer?.cancel();
    _repartidoresRefreshTimer = Timer.periodic(
      const Duration(
          seconds:
              30), // MEJORA: Se ajusta el tiempo de refresco a 30 segundos.
      (_) {
        if (mounted) {
          setState(() {
            _repartidoresLocationFuture = fetchLocations();
          });
        }
      },
    );
  }

  void _onSearchChanged() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (_hasQuery != hasQuery) {
      setState(() => _hasQuery = hasQuery);
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadProducts);
  }

  void _handleCartTap() {
    if (!widget.usuario.isAuthenticated) {
      showLoginRequiredDialog(context);
    } else {
      // CORRECCIÓN: Se navega a la pantalla del carrito en lugar de directamente al checkout.
      // Esto evita el crash de la app, ya que la pantalla del carrito es el paso previo
      // donde el usuario puede revisar su pedido antes de seleccionar la dirección.
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CartScreen(usuario: widget.usuario)));
    }
  }

  final int _selectedIndex = 0;

  Widget _buildProductosTab() {
    if (widget.usuario.rol == 'admin') {
      // Para admin, muestra el dashboard y luego el resto.
      // CORRECCIÓN: Se corrige el error "setState() callback argument returned a Future".
      // Las operaciones asíncronas (await) se realizan antes de llamar a setState.
      return RefreshIndicator(
        onRefresh: () async {
          await _databaseService.getProductos(
              query: _searchController.text.trim(),
              categoria: _selectedCategory == 'Todos' ? '' : _selectedCategory);
          await _databaseService.getAdminStats();
          if (mounted) setState(() {});
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdminDashboard(), // Dashboard primero
                  _buildSearchBar(),
                  if (!_hasQuery) ...[
                    _buildRecommendationsCarousel(),
                    _buildLiveTrackingCard(),
                    const SizedBox(height: 12),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Nuestro Menu',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildCategoryList(),
                ],
              ),
            ),
            _buildProductsGrid(),
          ],
        ),
      );
    }

    // Para otros usuarios, muestra la vista normal.
    return RefreshIndicator(
      onRefresh: () async => _loadProducts(),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                if (!_hasQuery) ...[
                  _buildRecommendationsCarousel(),
                  _buildLiveTrackingCard(),
                  const SizedBox(height: 12),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Nuestro Menu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildCategoryList(),
              ],
            ),
          ),
          _buildProductsGrid(),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _adminStatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error al cargar estadísticas: ${snapshot.error}'));
        }
        final stats = snapshot.data ?? {};
        final pedidosHoy = stats['pedidos_hoy'] ?? 0;
        final ingresosHoy = (stats['ingresos_hoy'] as num?)?.toDouble() ?? 0.0;
        final clientesNuevos = stats['clientes_nuevos_mes'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard de Administrador',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard('Pedidos Hoy', pedidosHoy.toString(),
                      Icons.receipt_long, Colors.blue),
                  _buildStatCard(
                      'Ingresos Hoy',
                      '\$${ingresosHoy.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green),
                  _buildStatCard(
                      'Clientes Nuevos (Mes)',
                      clientesNuevos.toString(),
                      Icons.person_add,
                      Colors.orange),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_applications),
                label: const Text('Gestionar Productos'),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminProductosScreen()));
                  _loadAdminStats(); // Refrescar stats al volver
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const Spacer(),
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapaTab() => const LiveMapScreen();
  Widget _buildPerfilTab() => ProfileScreen(usuario: widget.usuario);

  // Eliminado metodo no referenciado

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar pizzas, hamburguesas...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear())
                : null,
          ),
        ),
      );

  Widget _buildCategoryList() => SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(category),
                selected: category == _selectedCategory,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = category);
                    _loadProducts();
                  }
                },
              ),
            );
          },
        ),
      );

  Widget _buildProductsGrid() => FutureBuilder<List<Producto>>(
        future: _productosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(child: ProductsGridLoading());
          }
          if (snapshot.hasError) {
            return SliverFillRemaining(
                child: InfoMessage(
                    icon: Icons.cloud_off,
                    message: 'Error al cargar productos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SliverFillRemaining(
                child: InfoMessage(
                    icon: Icons.search_off,
                    message: 'No se encontraron productos.'));
          }
          final productos = snapshot.data!;
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: productos.length,
              itemBuilder: (context, index) => ProductCard(
                  producto: productos[index], usuario: widget.usuario),
            ),
          );
        },
      );

  // MEJORA: Se rediseña el carrusel para ser más atractivo y robusto.
  Widget _buildRecommendationsCarousel() {
    return FutureBuilder<List<ProductoRankeado>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar recomendaciones: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child:
                  Text('No hay recomendaciones disponibles en este momento.'),
            ),
          );
        }

        final recommendations = snapshot.data!;
        return SizedBox(
          height: 250, // Aumentamos la altura para el nuevo diseño
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final producto = recommendations[index];
              return _buildRecommendationCard(producto);
            },
          ),
        );
      },
    );
  }

  Widget _buildLiveTrackingCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _repartidoresLocationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            (snapshot.data == null || snapshot.data!.isEmpty)) {
          return const SizedBox
              .shrink(); // No mostrar nada mientras carga inicialmente
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox
              .shrink(); // No mostrar la tarjeta si no hay repartidores
        }

        final locations = snapshot.data!;
        final markers = locations
            .map((loc) {
              final lat = (loc['latitud'] as num?)?.toDouble();
              final lon = (loc['longitud'] as num?)?.toDouble();
              if (lat == null || lon == null) return null;

              return Marker(
                markerId: MarkerId('repartidor_${loc['id_repartidor']}'),
                position: LatLng(lat, lon),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
              );
            })
            .whereType<Marker>()
            .toSet();

        if (markers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LiveMapScreen()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: markers.first.position,
                        zoom: 13,
                      ),
                      markers: markers,
                      liteModeEnabled:
                          true, // Modo ligero para mejor rendimiento
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining,
                            color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Text(
                          '${markers.length} repartidor(es) en camino',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCard(ProductoRankeado producto) {
    return GestureDetector(
      // CORRECCIÓN: Se reutiliza el método de navegación que ya funciona en el resto de la app.
      // Se crea un objeto 'Producto' a partir de 'ProductoRankeado' y se pasa directamente.
      // Esto asegura que la pantalla de detalles siempre reciba los datos correctos.
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              producto: producto.toProducto(), // Conversión directa
              usuario: widget.usuario,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Image.network(
                  producto.imagenUrl ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${producto.ratingPromedio.toStringAsFixed(1)} (${producto.totalReviews})',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Se permite que el rol 'admin' también vea la interfaz de cliente.
    final isCliente =
        widget.usuario.rol == 'cliente' || widget.usuario.rol == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.usuario.nombre.split(' ').first}'),
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, child) => Badge(
              label: Text(cart.items.length.toString()),
              isLabelVisible: cart.items.isNotEmpty,
              child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: _handleCartTap),
            ),
          ),
        ],
      ),
      body: isCliente
          ? (_selectedIndex == 0
              ? _buildProductosTab()
              : _selectedIndex == 1
                  ? _buildMapaTab()
                  : _selectedIndex == 2
                      ? _buildPerfilTab()
                      : Container())
          : Container(),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Producto producto;
  final Usuario usuario;

  const ProductCard({required this.producto, required this.usuario, super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ProductDetailScreen(producto: producto, usuario: usuario))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 12,
                  child: Hero(
                    tag: 'product-${producto.idProducto}',
                    child: _ProductImage(imageUrl: producto.imagenUrl),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Text(producto.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Text('\$${producto.precio.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: ElevatedButton(
                onPressed: !usuario.isAuthenticated
                    ? () => showLoginRequiredDialog(context)
                    : () {
                        cart.addToCart(producto);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('${producto.nombre} anadido al carrito.'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1)));
                      },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Icon(Icons.add_shopping_cart,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return const _ImagePlaceholder();
    return Image.network(imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const _ImagePlaceholder(),
        loadingBuilder: (c, child, progress) {
          return progress == null
              ? child
              : const Center(child: CircularProgressIndicator());
        });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40));
}

class InfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const InfoMessage({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withAlpha(153)),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]))
      ]));
}

class ProductsGridLoading extends StatelessWidget {
  const ProductsGridLoading({super.key}); // ignore: unused_element
  @override
  Widget build(BuildContext context) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16),
        itemCount: 6,
        itemBuilder: (c, i) => const Card(),
      );
}
