import 'package:flutter/material.dart';

void main() => runApp(const SoukApp());

class SoukApp extends StatelessWidget {
  const SoukApp({super.key});

  @override
  Widget build(BuildContext context) {
    const leaf = Color(0xFF1F7A4D);
    const saffron = Color(0xFFE7A72E);
    const clay = Color(0xFFC8673A);
    const paper = Color(0xFFF8F4EC);
    const ink = Color(0xFF17211B);

    final scheme = ColorScheme.fromSeed(
      seedColor: leaf,
      primary: leaf,
      secondary: saffron,
      tertiary: clay,
      surface: paper,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Souk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: paper,
          foregroundColor: ink,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: leaf.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const MarketplaceShell(),
    );
  }
}

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key});

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _tabIndex = 0;
  String _query = '';
  String _category = 'All';
  final List<CartLine> _cart = [];
  final Set<String> _favoriteIds = {'silk-scarf'};
  final List<Order> _orders = List.of(seedOrders);
  final List<ShopDraft> _stores = [];
  final List<SellerProduct> _sellerProducts = [];

  int get _cartCount => _cart.fold(0, (sum, line) => sum + line.quantity);

  double get _subtotal => _cart.fold(
        0,
        (sum, line) => sum + (line.product.price * line.quantity),
      );

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((line) => line.product.id == product.id);
      if (index == -1) {
        _cart.add(CartLine(product: product));
      } else {
        _cart[index] = _cart[index].copyWith(quantity: _cart[index].quantity + 1);
      }
    });
    _showSnack('${product.name} added to basket');
  }

  void _updateQuantity(Product product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.removeWhere((line) => line.product.id == product.id);
      } else {
        final index = _cart.indexWhere((line) => line.product.id == product.id);
        if (index != -1) {
          _cart[index] = _cart[index].copyWith(quantity: quantity);
        }
      }
    });
  }

  void _toggleFavorite(Product product) {
    setState(() {
      if (_favoriteIds.contains(product.id)) {
        _favoriteIds.remove(product.id);
        _showSnack('Removed from favorites');
      } else {
        _favoriteIds.add(product.id);
        _showSnack('Saved to favorites');
      }
    });
  }

  void _openProduct(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return ProductDetailSheet(
          product: product,
          isFavorite: _favoriteIds.contains(product.id),
          onFavorite: () {
            Navigator.pop(context);
            _toggleFavorite(product);
          },
          onAddToCart: () {
            Navigator.pop(context);
            _addToCart(product);
          },
        );
      },
    );
  }

  void _placeOrder(CheckoutInfo info) {
    if (_cart.isEmpty) {
      return;
    }
    final order = Order(
      id: '#S${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      shopName: _cart.first.product.shop.name,
      total: _subtotal + 3.5,
      status: 'Placed',
      eta: info.deliveryMethod == 'Pickup' ? 'Ready in 2 hours' : 'Today, 6-8 PM',
      itemCount: _cartCount,
    );
    setState(() {
      _orders.insert(0, order);
      _cart.clear();
      _tabIndex = 2;
    });
    _showSnack('Order ${order.id} placed');
  }

  void _createStore(ShopDraft store) {
    setState(() {
      _stores.insert(0, store);
      _tabIndex = 4;
    });
    _showSnack('${store.name} store draft created');
  }

  void _createSellerProduct(SellerProduct product) {
    setState(() => _sellerProducts.insert(0, product));
    _showSnack('${product.name} added to inventory');
  }

  @override
  Widget build(BuildContext context) {
    final products = sampleProducts.where((product) {
      final q = _query.trim().toLowerCase();
      final inCategory = _category == 'All' || product.category == _category;
      final inSearch = q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.shop.name.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q);
      return inCategory && inSearch;
    }).toList();

    final pages = [
      HomePage(
        query: _query,
        category: _category,
        products: products,
        favoriteIds: _favoriteIds,
        onQueryChanged: (value) => setState(() => _query = value),
        onCategoryChanged: (value) => setState(() => _category = value),
        onOpenProduct: _openProduct,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
      ),
      StoresPage(
        favoriteIds: _favoriteIds,
        onOpenProduct: _openProduct,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
      ),
      ActivityPage(orders: _orders, favoriteIds: _favoriteIds),
      CartPage(
        cart: _cart,
        subtotal: _subtotal,
        onQuantityChanged: _updateQuantity,
        onCheckout: _placeOrder,
      ),
      SellerHubPage(
        stores: _stores,
        products: _sellerProducts,
        onCreateStore: _createStore,
        onCreateProduct: _createSellerProduct,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Souk',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Stores',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: _cartCount,
              isLabelVisible: _cartCount > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge.count(
              count: _cartCount,
              isLabelVisible: _cartCount > 0,
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Basket',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize),
            label: 'Sell',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.query,
    required this.category,
    required this.products,
    required this.favoriteIds,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final String query;
  final String category;
  final List<Product> products;
  final Set<String> favoriteIds;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeaderBar(),
                const SizedBox(height: 18),
                const MarketplaceHero(),
                const SizedBox(height: 14),
                SearchField(value: query, onChanged: onQueryChanged),
                const SizedBox(height: 12),
                CategoryRail(selected: category, onSelected: onCategoryChanged),
                const SizedBox(height: 16),
                QuickActions(
                  items: const [
                    QuickAction('Deals', Icons.local_offer, Color(0xFFE7A72E)),
                    QuickAction('Nearby', Icons.place, Color(0xFF357C83)),
                    QuickAction('Fresh', Icons.flash_on, Color(0xFF1F7A4D)),
                  ],
                ),
                const SizedBox(height: 16),
                SectionTitle(title: 'Featured today', action: '${products.length} items'),
              ],
            ),
          ),
        ),
        if (products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No matches yet',
              message: 'Try another shop, category, or product name.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  isFavorite: favoriteIds.contains(product.id),
                  onOpen: () => onOpenProduct(product),
                  onAdd: () => onAddToCart(product),
                  onFavorite: () => onToggleFavorite(product),
                );
              },
            ),
          ),
      ],
    );
  }
}

class StoresPage extends StatelessWidget {
  const StoresPage({
    super.key,
    required this.favoriteIds,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final Set<String> favoriteIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        const HeaderBar(),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Local shops', action: 'Verified sellers'),
        const SizedBox(height: 12),
        for (final shop in sampleShops) ...[
          ShopCard(
            shop: shop,
            favoriteIds: favoriteIds,
            onOpenProduct: onOpenProduct,
            onAddToCart: onAddToCart,
            onToggleFavorite: onToggleFavorite,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.orders, required this.favoriteIds});

  final List<Order> orders;
  final Set<String> favoriteIds;

  @override
  Widget build(BuildContext context) {
    final favorites = sampleProducts.where((product) => favoriteIds.contains(product.id)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        const HeaderBar(),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Orders', action: 'Track purchases'),
        const SizedBox(height: 12),
        for (final order in orders) ...[
          OrderTile(order: order),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        SectionTitle(title: 'Favorites', action: '${favorites.length} saved'),
        const SizedBox(height: 12),
        if (favorites.isEmpty)
          const EmptyState(
            icon: Icons.favorite_border,
            title: 'No favorites yet',
            message: 'Save products you want to revisit later.',
          )
        else
          for (final product in favorites) FavoriteTile(product: product),
      ],
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.onQuantityChanged,
    required this.onCheckout,
  });

  final List<CartLine> cart;
  final double subtotal;
  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<CheckoutInfo> onCheckout;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _address = TextEditingController(text: 'Beirut, Lebanon');
  final _note = TextEditingController();
  String _method = 'Delivery';
  String _payment = 'Cash on delivery';

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const delivery = 3.5;
    final total = widget.cart.isEmpty ? 0.0 : widget.subtotal + delivery;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        const HeaderBar(),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Basket', action: 'Direct checkout'),
        const SizedBox(height: 12),
        if (widget.cart.isEmpty)
          const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Your basket is waiting',
            message: 'Add products from independent shops and check out in one flow.',
          )
        else ...[
          for (final line in widget.cart) ...[
            CartLineTile(line: line, onQuantityChanged: widget.onQuantityChanged),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          CheckoutForm(
            address: _address,
            note: _note,
            method: _method,
            payment: _payment,
            onMethodChanged: (value) => setState(() => _method = value),
            onPaymentChanged: (value) => setState(() => _payment = value),
          ),
          const SizedBox(height: 12),
          CheckoutSummary(
            subtotal: widget.subtotal,
            delivery: delivery,
            total: total,
            onCheckout: () => widget.onCheckout(
              CheckoutInfo(
                address: _address.text,
                note: _note.text,
                deliveryMethod: _method,
                paymentMethod: _payment,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SellerHubPage extends StatefulWidget {
  const SellerHubPage({
    super.key,
    required this.stores,
    required this.products,
    required this.onCreateStore,
    required this.onCreateProduct,
  });

  final List<ShopDraft> stores;
  final List<SellerProduct> products;
  final ValueChanged<ShopDraft> onCreateStore;
  final ValueChanged<SellerProduct> onCreateProduct;

  @override
  State<SellerHubPage> createState() => _SellerHubPageState();
}

class _SellerHubPageState extends State<SellerHubPage> {
  final _storeFormKey = GlobalKey<FormState>();
  final _productFormKey = GlobalKey<FormState>();
  final _storeName = TextEditingController();
  final _storeCategory = TextEditingController();
  final _storeCity = TextEditingController();
  final _productName = TextEditingController();
  final _productPrice = TextEditingController();
  final _productStock = TextEditingController(text: '12');
  bool _delivery = true;

  @override
  void dispose() {
    _storeName.dispose();
    _storeCategory.dispose();
    _storeCity.dispose();
    _productName.dispose();
    _productPrice.dispose();
    _productStock.dispose();
    super.dispose();
  }

  void _submitStore() {
    if (!_storeFormKey.currentState!.validate()) {
      return;
    }
    widget.onCreateStore(
      ShopDraft(
        name: _storeName.text.trim(),
        category: _storeCategory.text.trim(),
        city: _storeCity.text.trim(),
        hasDelivery: _delivery,
      ),
    );
    _storeName.clear();
    _storeCategory.clear();
    _storeCity.clear();
    setState(() => _delivery = true);
  }

  void _submitProduct() {
    if (!_productFormKey.currentState!.validate()) {
      return;
    }
    widget.onCreateProduct(
      SellerProduct(
        name: _productName.text.trim(),
        price: double.tryParse(_productPrice.text.trim()) ?? 0,
        stock: int.tryParse(_productStock.text.trim()) ?? 0,
      ),
    );
    _productName.clear();
    _productPrice.clear();
    _productStock.text = '12';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        const HeaderBar(),
        const SizedBox(height: 18),
        const SellerHero(),
        const SizedBox(height: 16),
        const SellerMetricGrid(),
        const SizedBox(height: 16),
        StoreFormCard(
          formKey: _storeFormKey,
          name: _storeName,
          category: _storeCategory,
          city: _storeCity,
          delivery: _delivery,
          onDeliveryChanged: (value) => setState(() => _delivery = value),
          onSubmit: _submitStore,
        ),
        const SizedBox(height: 12),
        ProductFormCard(
          formKey: _productFormKey,
          name: _productName,
          price: _productPrice,
          stock: _productStock,
          onSubmit: _submitProduct,
        ),
        const SizedBox(height: 16),
        SectionTitle(title: 'Store drafts', action: '${widget.stores.length} drafts'),
        const SizedBox(height: 10),
        if (widget.stores.isEmpty)
          const EmptyState(
            icon: Icons.add_business,
            title: 'No store drafts yet',
            message: 'Create your first shop profile, then add products and delivery rules.',
          )
        else
          for (final store in widget.stores) DraftStoreTile(draft: store),
        const SizedBox(height: 16),
        SectionTitle(title: 'Inventory', action: '${widget.products.length} products'),
        const SizedBox(height: 10),
        if (widget.products.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No seller products yet',
            message: 'Add products with price and stock before publishing your store.',
          )
        else
          for (final product in widget.products) SellerProductTile(product: product),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Incoming orders', action: 'Manage'),
        const SizedBox(height: 10),
        for (final order in sellerOrders) SellerOrderTile(order: order),
      ],
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shopping_basket, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Souk',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'Shops, makers, and quick checkout',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }
}

class MarketplaceHero extends StatelessWidget {
  const MarketplaceHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF244335),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HeroPill(icon: Icons.flash_on, label: 'Same day finds'),
              HeroPill(icon: Icons.verified, label: 'Verified shops'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Discover stores that feel close, fresh, and easy to buy from.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Browse curated local products, save favorites, and check out directly from one basket.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ],
      ),
    );
  }
}

class SellerHero extends StatelessWidget {
  const SellerHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF6E3F2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_graph, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Open your shop in minutes.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a storefront, add inventory, manage orders, and prepare your payout flow.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeroPill extends StatelessWidget {
  const HeroPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search shops, products, makers',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Filters',
          onPressed: () {},
          icon: const Icon(Icons.tune),
        ),
      ),
    );
  }
}

class CategoryRail extends StatelessWidget {
  const CategoryRail({super.key, required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...sampleCategories];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return FilterChip(
            selected: selected == category,
            showCheckmark: false,
            label: Text(category),
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.items});

  final List<QuickAction> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  children: [
                    Icon(item.icon, color: item.color),
                    const SizedBox(height: 6),
                    Text(item.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          if (item != items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Text(
          action,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onOpen,
    required this.onAdd,
    required this.onFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductArt(product: product, isFavorite: isFavorite, onFavorite: onFavorite),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Color(0xFFE7A72E)),
                        const SizedBox(width: 4),
                        Text(product.rating.toStringAsFixed(1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${product.stock} left',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.formattedPrice,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Add to basket',
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_shopping_cart),
                        ),
                      ],
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

class ProductArt extends StatelessWidget {
  const ProductArt({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.16,
      child: Container(
        color: product.color.withValues(alpha: 0.14),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: product.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(product.icon, color: Colors.white, size: 38),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Tag(label: product.category),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filledTonal(
                tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                onPressed: onFavorite,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.shop,
    required this.favoriteIds,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final Shop shop;
  final Set<String> favoriteIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final products = sampleProducts.where((product) => product.shop.id == shop.id).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: shop.color,
                  child: Icon(shop.icon, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                        '${shop.category} in ${shop.location}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.star, size: 16),
                  label: Text(shop.rating.toStringAsFixed(1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(shop.story),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(label: shop.delivery),
                Tag(label: '${shop.orderCount} orders'),
                Tag(label: 'Min ${money(shop.minimumOrder)}'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: 142,
                    child: ProductMiniCard(
                      product: product,
                      isFavorite: favoriteIds.contains(product.id),
                      onOpen: () => onOpenProduct(product),
                      onAdd: () => onAddToCart(product),
                      onFavorite: () => onToggleFavorite(product),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductMiniCard extends StatelessWidget {
  const ProductMiniCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onOpen,
    required this.onAdd,
    required this.onFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: product.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(product.icon, color: product.color, size: 30),
                  const Spacer(),
                  IconButton(
                    tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                    onPressed: onFavorite,
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(product.formattedPrice),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: 'Add to basket',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailSheet extends StatelessWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAddToCart,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                color: product.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(product.icon, color: product.color, size: 78),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                  onPressed: onFavorite,
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            ),
            Text(
              '${product.shop.name} - ${product.category}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(product.description),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(label: '${product.rating.toStringAsFixed(1)} rating'),
                Tag(label: '${product.stock} in stock'),
                Tag(label: product.shop.delivery),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.formattedPrice,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to basket'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CartLineTile extends StatelessWidget {
  const CartLineTile({super.key, required this.line, required this.onQuantityChanged});

  final CartLine line;
  final void Function(Product product, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: line.product.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(line.product.icon, color: line.product.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(line.product.shop.name, style: Theme.of(context).textTheme.bodySmall),
                  Text(line.product.formattedPrice),
                ],
              ),
            ),
            QuantityStepper(
              quantity: line.quantity,
              onChanged: (quantity) => onQuantityChanged(line.product, quantity),
            ),
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Decrease',
          onPressed: () => onChanged(quantity - 1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Increase',
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class CheckoutForm extends StatelessWidget {
  const CheckoutForm({
    super.key,
    required this.address,
    required this.note,
    required this.method,
    required this.payment,
    required this.onMethodChanged,
    required this.onPaymentChanged,
  });

  final TextEditingController address;
  final TextEditingController note;
  final String method;
  final String payment;
  final ValueChanged<String> onMethodChanged;
  final ValueChanged<String> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Delivery', icon: Icon(Icons.local_shipping), label: Text('Delivery')),
                ButtonSegment(value: 'Pickup', icon: Icon(Icons.store), label: Text('Pickup')),
              ],
              selected: {method},
              onSelectionChanged: (value) => onMethodChanged(value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: payment,
              decoration: const InputDecoration(
                labelText: 'Payment',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Cash on delivery', child: Text('Cash on delivery')),
                DropdownMenuItem(value: 'Card on delivery', child: Text('Card on delivery')),
                DropdownMenuItem(value: 'Wallet later', child: Text('Wallet later')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onPaymentChanged(value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Order note',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutSummary extends StatelessWidget {
  const CheckoutSummary({
    super.key,
    required this.subtotal,
    required this.delivery,
    required this.total,
    required this.onCheckout,
  });

  final double subtotal;
  final double delivery;
  final double total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF17211B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SummaryRow(label: 'Subtotal', value: money(subtotal)),
            const SizedBox(height: 8),
            SummaryRow(label: 'Delivery', value: money(delivery)),
            const Divider(height: 24, color: Colors.white24),
            SummaryRow(label: 'Total', value: money(total), strong: true),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
      fontSize: strong ? 18 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        title: Text('${order.id} - ${order.shopName}', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${order.itemCount} items - ${order.eta}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(order.total), style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(order.status),
          ],
        ),
      ),
    );
  }
}

class FavoriteTile extends StatelessWidget {
  const FavoriteTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: product.color.withValues(alpha: 0.16),
          child: Icon(product.icon, color: product.color),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(product.shop.name),
        trailing: Text(product.formattedPrice),
      ),
    );
  }
}

class SellerMetricGrid extends StatelessWidget {
  const SellerMetricGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const metrics = [
      SellerMetric('Orders', '24', Icons.receipt_long),
      SellerMetric('Products', '86', Icons.inventory_2),
      SellerMetric('Payout', r'$1.2k', Icons.account_balance_wallet),
      SellerMetric('Rating', '4.8', Icons.star),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(metric.icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(metric.value, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(metric.label, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StoreFormCard extends StatelessWidget {
  const StoreFormCard({
    super.key,
    required this.formKey,
    required this.name,
    required this.category,
    required this.city,
    required this.delivery,
    required this.onDeliveryChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController category;
  final TextEditingController city;
  final bool delivery;
  final ValueChanged<bool> onDeliveryChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create a store', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Store name', prefixIcon: Icon(Icons.store_mall_directory_outlined)),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Main category', prefixIcon: Icon(Icons.category_outlined)),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City or area', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: requiredField,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offer delivery'),
                value: delivery,
                onChanged: onDeliveryChanged,
              ),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.add_business),
                label: const Text('Launch store draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductFormCard extends StatelessWidget {
  const ProductFormCard({
    super.key,
    required this.formKey,
    required this.name,
    required this.price,
    required this.stock,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController stock;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a product', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name', prefixIcon: Icon(Icons.sell_outlined)),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(Icons.attach_money)),
                      validator: requiredNumber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(Icons.inventory_2_outlined)),
                      validator: requiredNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DraftStoreTile extends StatelessWidget {
  const DraftStoreTile({super.key, required this.draft});

  final ShopDraft draft;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.storefront, color: Colors.white),
        ),
        title: Text(draft.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${draft.category} - ${draft.city}'),
        trailing: Icon(draft.hasDelivery ? Icons.local_shipping : Icons.store),
      ),
    );
  }
}

class SellerProductTile extends StatelessWidget {
  const SellerProductTile({super.key, required this.product});

  final SellerProduct product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${product.stock} in stock'),
        trailing: Text(money(product.price)),
      ),
    );
  }
}

class SellerOrderTile extends StatelessWidget {
  const SellerOrderTile({super.key, required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
        title: Text(order.customer, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(order.summary),
        trailing: FilledButton.tonal(
          onPressed: () {},
          child: Text(order.status),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.story,
    required this.rating,
    required this.color,
    required this.icon,
    required this.delivery,
    required this.minimumOrder,
    required this.orderCount,
  });

  final String id;
  final String name;
  final String category;
  final String location;
  final String story;
  final double rating;
  final Color color;
  final IconData icon;
  final String delivery;
  final double minimumOrder;
  final int orderCount;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.shop,
    required this.color,
    required this.icon,
    required this.description,
    required this.rating,
    required this.stock,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final Shop shop;
  final Color color;
  final IconData icon;
  final String description;
  final double rating;
  final int stock;

  String get formattedPrice => money(price);
}

class CartLine {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(product: product, quantity: quantity ?? this.quantity);
  }
}

class Order {
  const Order({
    required this.id,
    required this.shopName,
    required this.total,
    required this.status,
    required this.eta,
    required this.itemCount,
  });

  final String id;
  final String shopName;
  final double total;
  final String status;
  final String eta;
  final int itemCount;
}

class CheckoutInfo {
  const CheckoutInfo({
    required this.address,
    required this.note,
    required this.deliveryMethod,
    required this.paymentMethod,
  });

  final String address;
  final String note;
  final String deliveryMethod;
  final String paymentMethod;
}

class ShopDraft {
  const ShopDraft({
    required this.name,
    required this.category,
    required this.city,
    required this.hasDelivery,
  });

  final String name;
  final String category;
  final String city;
  final bool hasDelivery;
}

class SellerProduct {
  const SellerProduct({required this.name, required this.price, required this.stock});

  final String name;
  final double price;
  final int stock;
}

class SellerOrder {
  const SellerOrder(this.customer, this.summary, this.status);

  final String customer;
  final String summary;
  final String status;
}

class SellerMetric {
  const SellerMetric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class QuickAction {
  const QuickAction(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

String money(double value) => '\$${value.toStringAsFixed(2)}';

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

String? requiredNumber(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  if (double.tryParse(value.trim()) == null) {
    return 'Use a number';
  }
  return null;
}

const cedarPantry = Shop(
  id: 'cedar-pantry',
  name: 'Cedar Pantry',
  category: 'Grocery',
  location: 'Gemmayze',
  story: 'Small-batch pantry staples, roasted nuts, spices, and weekly bundles.',
  rating: 4.9,
  color: Color(0xFF1F7A4D),
  icon: Icons.local_grocery_store,
  delivery: '45 min delivery',
  minimumOrder: 15,
  orderCount: 1240,
);

const loomHouse = Shop(
  id: 'loom-house',
  name: 'Loom House',
  category: 'Home',
  location: 'Mar Mikhael',
  story: 'Handwoven linens, table pieces, and warm objects for everyday homes.',
  rating: 4.7,
  color: Color(0xFFC8673A),
  icon: Icons.chair_alt,
  delivery: 'Ships tomorrow',
  minimumOrder: 20,
  orderCount: 680,
);

const atelierNour = Shop(
  id: 'atelier-nour',
  name: 'Atelier Nour',
  category: 'Fashion',
  location: 'Achrafieh',
  story: 'Independent clothing, jewelry, and accessories from emerging designers.',
  rating: 4.8,
  color: Color(0xFF6B5B95),
  icon: Icons.checkroom,
  delivery: 'Pickup or courier',
  minimumOrder: 25,
  orderCount: 930,
);

const sampleShops = [cedarPantry, loomHouse, atelierNour];
const sampleCategories = ['Grocery', 'Home', 'Fashion', 'Beauty'];

const sampleProducts = [
  Product(
    id: 'zaatar-box',
    name: 'Zaatar Breakfast Box',
    category: 'Grocery',
    price: 18,
    shop: cedarPantry,
    color: Color(0xFF1F7A4D),
    icon: Icons.breakfast_dining,
    description: 'A ready morning box with zaatar, olives, labneh crackers, and roasted nuts.',
    rating: 4.9,
    stock: 18,
  ),
  Product(
    id: 'spice-flight',
    name: 'Seven Spice Flight',
    category: 'Grocery',
    price: 12.5,
    shop: cedarPantry,
    color: Color(0xFFE7A72E),
    icon: Icons.spa,
    description: 'A compact spice set for rice, grills, soups, and weekly cooking.',
    rating: 4.8,
    stock: 34,
  ),
  Product(
    id: 'linen-runner',
    name: 'Olive Linen Runner',
    category: 'Home',
    price: 42,
    shop: loomHouse,
    color: Color(0xFFC8673A),
    icon: Icons.table_restaurant,
    description: 'Handwoven table runner with soft olive tones and a durable daily finish.',
    rating: 4.7,
    stock: 9,
  ),
  Product(
    id: 'ceramic-cup',
    name: 'Stackable Ceramic Cups',
    category: 'Home',
    price: 28,
    shop: loomHouse,
    color: Color(0xFF357C83),
    icon: Icons.coffee,
    description: 'Four stackable cups made for small counters, espresso, and tea.',
    rating: 4.6,
    stock: 14,
  ),
  Product(
    id: 'silk-scarf',
    name: 'Printed Silk Scarf',
    category: 'Fashion',
    price: 54,
    shop: atelierNour,
    color: Color(0xFF6B5B95),
    icon: Icons.style,
    description: 'Light silk scarf with limited-run artwork from an independent designer.',
    rating: 4.9,
    stock: 7,
  ),
  Product(
    id: 'amber-oil',
    name: 'Amber Body Oil',
    category: 'Beauty',
    price: 24,
    shop: atelierNour,
    color: Color(0xFFB15B43),
    icon: Icons.water_drop,
    description: 'Warm amber body oil blended for daily use, gifting, and travel.',
    rating: 4.8,
    stock: 22,
  ),
];

const seedOrders = [
  Order(
    id: '#S2041',
    shopName: 'Cedar Pantry',
    total: 31.5,
    status: 'On the way',
    eta: 'Today, 5-7 PM',
    itemCount: 2,
  ),
  Order(
    id: '#S1988',
    shopName: 'Loom House',
    total: 45.5,
    status: 'Delivered',
    eta: 'Delivered yesterday',
    itemCount: 1,
  ),
];

const sellerOrders = [
  SellerOrder('Maya Haddad', '2 items - Zaatar Breakfast Box', 'Pack'),
  SellerOrder('Karim Saleh', '1 item - Seven Spice Flight', 'Accept'),
  SellerOrder('Rana Nassar', '3 items - Mixed pantry bundle', 'Ready'),
];
