import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import 'widgets/login_required_dialog.dart';
import 'product_detail_screen.dart';
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
  late DatabaseService _databaseService;
  late final PageController _recommendationsController;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "Todos";
  bool _hasQuery = false;
  Timer? _debounce;
  Timer? _repartidoresRefreshTimer;
  int _currentRecommendationPage = 0;

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
    _recommendationsController = PageController(viewportFraction: 0.82);
    _loadProducts();
    _loadRecommendations();
    _loadRepartidoresLocation();
    _searchController.addListener(_onSearchChanged);
  }


  @override
  void dispose() {
    _debounce?.cancel();
    _repartidoresRefreshTimer?.cancel();
    _recommendationsController.dispose();
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _hasQuery
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                    _loadProducts();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onSubmitted: (_) => _loadProducts(),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedCategory = category);
              _loadProducts();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _categories.length,
      ),
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

  Widget _buildProductosTab() {
  return RefreshIndicator(
    onRefresh: () async {
      await _productosFuture;
      _loadProducts();
    },
    child: CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              if (!_hasQuery) ...[
                _buildRecommendationsCarousel(),
                const SizedBox(height: 16),
                _buildLiveTrackingCard(),
              ],
              const SizedBox(height: 16),
              _buildCategoryList(),
            ],
          ),
        ),
        _buildProductsGrid(),
      ],
    ),
  );
}
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
          return const _RecommendationsLoading();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar recomendaciones: \\'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No hay recomendaciones disponibles en este momento.'),
            ),
          );
        }

        final recommendations = snapshot.data!;
        if (_currentRecommendationPage >= recommendations.length) {
          _currentRecommendationPage = 0;
        }
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: PageView.builder(
                    key: ValueKey(recommendations.length),
                    controller: _recommendationsController,
                    onPageChanged: (index) {
                      setState(() => _currentRecommendationPage = index);
                    },
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final producto = recommendations[index];
                      final isFocused = index == _currentRecommendationPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.symmetric(
                          horizontal: isFocused ? 12 : 20,
                          vertical: isFocused ? 4 : 16,
                        ),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                  ((isFocused ? 0.14 : 0.08) * 255).round()),
                              blurRadius: isFocused ? 18 : 10,
                              offset: Offset(0, isFocused ? 10 : 6),
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: isFocused ? 1 : 0.95,
                          child: _buildRecommendationCard(producto),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (recommendations.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(recommendations.length, (index) {
                      final isActive = index == _currentRecommendationPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: isActive ? 22 : 10,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((0.25 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveTrackingCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _repartidoresLocationFuture,
      builder: (context, snapshot) {
        final hasLocations = snapshot.hasData && snapshot.data!.isNotEmpty;
        Widget child;
        String keyTag;

        if (!hasLocations) {
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          child = waiting ? const _LiveMapPlaceholder() : const SizedBox.shrink();
          keyTag = waiting ? 'map-placeholder' : 'map-empty';
        } else {
          final locations = snapshot.data!;
          final markers = locations
              .map((loc) {
                final lat = (loc['latitud'] as num?)?.toDouble();
                final lon = (loc['longitud'] as num?)?.toDouble();
                if (lat == null || lon == null) return null;

                return Marker(
                  markerId: MarkerId('repartidor_'),
                  position: LatLng(lat, lon),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange),
                );
              })
              .whereType<Marker>()
              .toSet();

          if (markers.isEmpty) {
            child = const SizedBox.shrink();
            keyTag = 'map-empty';
          } else {
            keyTag = 'map-';
            child = Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 180,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: markers.first.position,
                          zoom: 13,
                        ),
                        markers: markers,
                        liteModeEnabled: true,
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
                            ' repartidor(es) en camino',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey<String>(keyTag),
            child: child,
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
                child: CachedNetworkImage(
                  imageUrl: producto.imagenUrl ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey),
                  memCacheHeight: 400,
                  maxHeightDiskCache: 800,
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
      body: isCliente ? _buildProductosTab() : Container(),
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
                        HapticFeedback.lightImpact();
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
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _ImagePlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => const _ImagePlaceholder(isLoading: true),
      errorWidget: (c, url, error) => const _ImagePlaceholder(),
      fadeInDuration: const Duration(milliseconds: 280),
      fadeInCurve: Curves.easeOutCubic,
      memCacheHeight: 600,
      maxHeightDiskCache: 1200,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool isLoading;
  const _ImagePlaceholder({this.isLoading = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isLoading
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ],
                )
              : null,
          color: isLoading ? null : Colors.grey.shade200,
        ),
        child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40),
      );
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
        itemBuilder: (c, i) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

class _RecommendationsLoading extends StatelessWidget {
  const _RecommendationsLoading();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: 3,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: 220,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveMapPlaceholder extends StatelessWidget {
  const _LiveMapPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Icon(Icons.delivery_dining,
                  color: Colors.grey.shade500, size: 32),
              const SizedBox(width: 12),
              Text(
                'Cargando mapa…',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






