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

  final List<String> _categories = [
    "Todos", "Pizza", "Hamburguesa", "Bebidas", "Postres", "Varios"
  ];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _recomendacionesFuture = _databaseService.getRecomendaciones();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _loadProducts() {
    setState(() {
      _productosFuture = _databaseService.getProductos(
        query: _searchController.text.trim(),
        categoria: _selectedCategory,
      );
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.usuario.nombre.split(' ')[0]}'),
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, child) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(usuario: widget.usuario),
                    ),
                  ),
                ),
                if (cart.items.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cart.items.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _searchController.clear();
          setState(() {
            _selectedCategory = "Todos";
            _recomendacionesFuture = _databaseService.getRecomendaciones();
          });
          _loadProducts();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              _buildCategoryList(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Recomendaciones para ti',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 120,
                child: FutureBuilder<List<ProductoRankeado>>(
                  future: _recomendacionesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const RecommendationsListLoading();
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No hay recomendaciones.'));
                    }
                    return _buildRecommendationsList(snapshot.data!);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Todos los Productos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              FutureBuilder<List<Producto>>(
                future: _productosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ProductsGridLoading();
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hay productos.'));
                  }
                  return _buildProductsGrid(snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar pizzas, hamburguesas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                  });
                  _loadProducts();
                }
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationsList(List<ProductoRankeado> recomendaciones) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recomendaciones.length,
      itemBuilder: (context, index) {
        final rec = recomendaciones[index];
        return SizedBox(
          width: 150,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(rec.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(' ${rec.ratingPromedio.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text('${rec.totalReviews} reviews',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid(List<Producto> productos) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        return ProductCard(producto: producto, usuario: widget.usuario);
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Producto producto;
  final Usuario usuario;

  const ProductCard({
    required this.producto,
    required this.usuario,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context, listen: false);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              producto: producto,
              usuario: usuario,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Hero(
                tag: 'product-${producto.idProducto}',
                child: Image.network(
                  producto.imagenUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.fastfood,
                          color: Colors.grey.shade400, size: 40),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('\$${producto.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          cart.addToCart(producto);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('${producto.nombre} añadido'),
                                duration: const Duration(seconds: 1)),
                          );
                        },
                        child: const Text('Añadir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductsGridLoading extends StatelessWidget {
  const ProductsGridLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return const ProductCardSkeleton();
        },
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Container(color: Colors.white)),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: double.infinity, height: 16, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 100, height: 16, color: Colors.white),
                  const Spacer(),
                  Container(width: 60, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                      width: double.infinity,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendationsListLoading extends StatelessWidget {
  const RecommendationsListLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return const RecommendationCardSkeleton();
        },
      ),
    );
  }
}

class RecommendationCardSkeleton extends StatelessWidget {
  const RecommendationCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: double.infinity, height: 16, color: Colors.white),
              const SizedBox(height: 4),
              Container(width: 80, height: 16, color: Colors.white),
              const Spacer(),
              Container(width: 60, height: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
