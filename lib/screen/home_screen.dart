import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../services/database_service.dart';
import 'cart_screen.dart' show CartScreen;
import 'product_detail_screen.dart';
import 'widgets/login_required_dialog.dart';

class HomeScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Producto>> _productosFuture;
  late Future<List<ProductoRankeado>> _recomendacionesFuture;
  late DatabaseService _databaseService;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "Todos";
  Timer? _debounce;

  bool get _isGuest => widget.usuario.isGuest;

  final List<String> _categories = const [
    'Todos',
    'Pizzas',
    'Hamburguesas',
    'Acompañamientos',
    'Bebidas',
  ];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _fetchData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _fetchData() {
    _recomendacionesFuture = _databaseService.getRecomendaciones();
    _loadProducts();
  }

  void _loadProducts() {
    final query = _searchController.text.trim();
    final categoryFilter = _selectedCategory == 'Todos' ? '' : _selectedCategory;
    setState(() {
      _productosFuture = _databaseService.getProductos(
        query: query,
        categoria: categoryFilter,
      );
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadProducts());
  }

  void _handleCartTap() {
    if (_isGuest) {
      showLoginRequiredDialog(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(usuario: widget.usuario)));
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _searchController.clear();
      _selectedCategory = "Todos";
       _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.usuario.nombre.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${_isGuest ? 'invitado' : firstName}'),
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, child) => Badge(
              label: Text(cart.items.length.toString()), // CORREGIDO
              isLabelVisible: cart.items.isNotEmpty, // CORREGIDO
              child: IconButton(icon: const Icon(Icons.shopping_cart), onPressed: _handleCartTap),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  _buildCategoryList(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Recomendaciones para ti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  _buildRecomendaciones(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Nuestro Menú', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            _buildProductsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 40,
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
  }

  Widget _buildRecomendaciones() {
    return FutureBuilder<List<ProductoRankeado>>(
      future: _recomendacionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RecommendationsListLoading();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // No ocupa espacio si no hay nada
        }
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) => _RecommendationCard(producto: snapshot.data![index]),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid() {
    return FutureBuilder<List<Producto>>(
      future: _productosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: ProductsGridLoading());
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(child: InfoState(icon: Icons.cloud_off, title: 'Error de Conexión', onAction: _loadProducts));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(child: InfoState(icon: Icons.search_off, title: 'No se encontraron productos', onAction: _loadProducts));
        }
        final productos = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(producto: productos[index], usuario: widget.usuario, isGuest: _isGuest),
              childCount: productos.length,
            ),
          ),
        );
      },
    );
  }
}

// --- WIDGETS AUXILIARES ---

class ProductCard extends StatelessWidget {
  final Producto producto;
  final Usuario usuario;
  final bool isGuest;

  const ProductCard({required this.producto, required this.usuario, required this.isGuest, super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(producto: producto, usuario: usuario))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Hero(tag: 'product-${producto.idProducto}', child: _ProductImage(imageUrl: producto.imagenUrl))),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('\$${producto.precio.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: isGuest ? () => showLoginRequiredDialog(context) : () => cart.addToCart(producto), child: const Text('Añadir')),
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

class _RecommendationCard extends StatelessWidget {
  final ProductoRankeado producto;
  const _RecommendationCard({required this.producto});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(child: Padding(padding: const EdgeInsets.all(8.0), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(children: [const Icon(Icons.star, color: Colors.amber, size: 16), Text(' ${producto.ratingPromedio.toStringAsFixed(1)}')]),
          Text('${producto.totalReviews} reviews', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ))),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _ImagePlaceholder();
    return Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _ImagePlaceholder(), loadingBuilder: (c, child, progress) {
      return progress == null ? child : const Center(child: CircularProgressIndicator());
    });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(color: Colors.grey.shade200, child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40));
}

class InfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onAction;
  const InfoState({super.key, required this.icon, required this.title, this.onAction});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 12),    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
    if (onAction != null) ...[const SizedBox(height: 16), OutlinedButton(onPressed: onAction, child: const Text('Reintentar'))]
  ]));
}

class ProductsGridLoading extends StatelessWidget {
  const ProductsGridLoading({super.key});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemCount: 6,
        itemBuilder: (c, i) => const Card(),
      )
  );
}

class RecommendationsListLoading extends StatelessWidget {
  const RecommendationsListLoading({super.key});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
    child: ListView.builder(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 4, itemBuilder: (c, i) => SizedBox(width: 150, child: const Card()),
    )
  );
}
