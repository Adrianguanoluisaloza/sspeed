import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/cart_model.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../widgets/recomendaciones_carousel.dart'; 
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
  late DatabaseService _databaseService;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "Todos";
  Timer? _debounce;

  final List<String> _categories = const [
    'Todos', 'Pizzas', 'Hamburguesas', 'Acompañamientos', 'Bebidas',
    'Postres', 'Ensaladas', 'Pastas', 'Mexicana', 'Japonesa', 'Mariscos',
  ];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _loadData() => _loadProducts();

  void _loadProducts() {
    final query = _searchController.text.trim();
    final categoryFilter = _selectedCategory == 'Todos' ? '' : _selectedCategory;
    setState(() {
      _productosFuture = _databaseService.getProductos(query: query, categoria: categoryFilter);
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _loadProducts);
  }

  void _handleCartTap() {
    if (!widget.usuario.isAuthenticated) {
      showLoginRequiredDialog(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(usuario: widget.usuario)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.usuario.nombre.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${!widget.usuario.isAuthenticated ? 'invitado' : firstName}'),
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, child) => Badge(
              label: Text(cart.items.length.toString()),
              isLabelVisible: cart.items.isNotEmpty,
              child: IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: _handleCartTap),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const RecomendacionesCarousel(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Nuestro Menú', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  _buildCategoryList(),
                ],
              ),
            ),
            _buildProductsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar pizzas, hamburguesas...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
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
                labelStyle: TextStyle(color: _selectedCategory == category ? Colors.white : Colors.black),
                selected: category == _selectedCategory,
                selectedColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.white,
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
            return SliverFillRemaining(child: InfoMessage(icon: Icons.cloud_off, message: 'Error al cargar productos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SliverFillRemaining(child: InfoMessage(icon: Icons.search_off, message: 'No se encontraron productos.'));
          }
          final productos = snapshot.data!;
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 16,
              ),
              itemCount: productos.length,
              itemBuilder: (context, index) => ProductCard(producto: productos[index], usuario: widget.usuario),
            ),
          );
        },
      );
}

// --- WIDGETS AUXILIARES MEJORADOS ---

class ProductCard extends StatelessWidget {
  final Producto producto;
  final Usuario usuario;

  const ProductCard({required this.producto, required this.usuario, super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(producto: producto, usuario: usuario))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 12, // Proporción de imagen
                  child: Hero(
                    tag: 'product-${producto.idProducto}',
                    child: _ProductImage(imageUrl: producto.imagenUrl),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text('\$${producto.precio.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            // Botón de añadir superpuesto
            Positioned(
              bottom: 8,
              right: 8,
              child: ElevatedButton(
                onPressed: !usuario.isAuthenticated ? () => showLoginRequiredDialog(context) : () {
                  cart.addToCart(producto);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${producto.nombre} añadido al carrito.'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
                },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 22),
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
    return Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const _ImagePlaceholder(), loadingBuilder: (c, child, progress) {
      return progress == null ? child : const Center(child: CircularProgressIndicator());
    });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => Container(color: Colors.grey.shade200, child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 40));
}

class InfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const InfoMessage({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary.withAlpha(153)),
    const SizedBox(height: 12),    
    Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemCount: 6,
        itemBuilder: (c, i) => const Card(),
      )
  );
}
