import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/souk_api.dart';

void main() => runApp(const SoukApp());

const soukApiUrl = String.fromEnvironment('SOUK_API_URL');

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
      home: const AuthGate(),
    );
  }
}

enum AccountRole { customer, seller }

class AppSession {
  const AppSession({
    required this.name,
    required this.email,
    required this.role,
    this.store,
  });

  final String name;
  final String email;
  final AccountRole role;
  final ShopDraft? store;
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppSession? _session;

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return AccountEntryPage(
        onAuthenticated: (nextSession) =>
            setState(() => _session = nextSession),
      );
    }

    if (session.role == AccountRole.seller) {
      return SellerAppShell(
        session: session,
        onLogout: () => setState(() => _session = null),
      );
    }

    return MarketplaceShell(
      session: session,
      onLogout: () => setState(() => _session = null),
    );
  }
}

class AccountEntryPage extends StatefulWidget {
  const AccountEntryPage({super.key, required this.onAuthenticated});

  final ValueChanged<AppSession> onAuthenticated;

  @override
  State<AccountEntryPage> createState() => _AccountEntryPageState();
}

class _AccountEntryPageState extends State<AccountEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _storeName = TextEditingController();
  final _storeCategory = TextEditingController();
  final _storeCity = TextEditingController();
  bool _signup = true;
  AccountRole _role = AccountRole.customer;
  bool _authLoading = false;
  String? _authError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _storeName.dispose();
    _storeCategory.dispose();
    _storeCity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (soukApiUrl.isEmpty) {
      setState(() {
        _authError =
            'Backend is not configured. Run with SOUK_API_URL set to your Railway API URL.';
      });
      return;
    }
    if (!soukApiUrl.startsWith('https://')) {
      setState(() {
        _authError =
            'SOUK_API_URL must start with https:// and point to your Railway public domain.';
      });
      return;
    }

    setState(() {
      _authLoading = true;
      _authError = null;
    });

    try {
      final api = SoukApi(baseUrl: soukApiUrl);
      final response = _signup
          ? await api.signup(_signupPayload())
          : await api.login(_loginPayload());
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(_sessionFromAuthResponse(response));
    } on SoukApiException catch (error) {
      setState(() => _authError = error.message);
    } catch (error) {
      setState(() => _authError = 'Could not reach Souk: $error');
    } finally {
      if (mounted) {
        setState(() => _authLoading = false);
      }
    }
  }

  Map<String, dynamic> _signupPayload() {
    final Map<String, dynamic> payload = {
      'role': _role == AccountRole.seller ? 'SELLER' : 'CUSTOMER',
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
    };
    if (_role == AccountRole.seller) {
      payload['store'] = {
        'name': _storeName.text.trim(),
        'category': _storeCategory.text.trim(),
        'city': _storeCity.text.trim(),
        'story': '${_storeName.text.trim()} is selling on Souk.',
        'minimumOrder': 0,
        'deliveryLabel': 'Delivery available',
      };
    }
    return payload;
  }

  Map<String, dynamic> _loginPayload() {
    return {
      'role': _role == AccountRole.seller ? 'SELLER' : 'CUSTOMER',
      'email': _email.text.trim(),
      'password': _password.text,
    };
  }

  AppSession _sessionFromAuthResponse(Map<String, dynamic> response) {
    final user = response['user'] as Map<String, dynamic>;
    final shop = response['shop'] as Map<String, dynamic>?;
    return AppSession(
      name: user['name']?.toString() ?? _email.text.trim(),
      email: user['email']?.toString() ?? _email.text.trim(),
      role: user['role'] == 'SELLER'
          ? AccountRole.seller
          : AccountRole.customer,
      store: shop == null
          ? null
          : ShopDraft(
              id: shop['id']?.toString(),
              name: shop['name']?.toString() ?? 'My Souk Store',
              category: shop['category']?.toString() ?? 'Store',
              city: shop['city']?.toString() ?? 'Beirut',
              hasDelivery: true,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = _role == AccountRole.seller;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const HeaderBar(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF244335),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Souk',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customers shop with an account. Stores enter through a seller account and manage their dashboard from there.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<AccountRole>(
                        segments: const [
                          ButtonSegment(
                            value: AccountRole.customer,
                            icon: Icon(Icons.person_outline),
                            label: Text('Customer'),
                          ),
                          ButtonSegment(
                            value: AccountRole.seller,
                            icon: Icon(Icons.storefront_outlined),
                            label: Text('Store'),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (value) =>
                            setState(() => _role = value.first),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Sign up')),
                          ButtonSegment(value: false, label: Text('Login')),
                        ],
                        selected: {_signup},
                        onSelectionChanged: (value) =>
                            setState(() => _signup = value.first),
                      ),
                      const SizedBox(height: 14),
                      if (_signup) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: requiredField,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (_signup && isSeller) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Store setup',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _storeName,
                          decoration: const InputDecoration(
                            labelText: 'Store name',
                            prefixIcon: Icon(
                              Icons.store_mall_directory_outlined,
                            ),
                          ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _storeCategory,
                          decoration: const InputDecoration(
                            labelText: 'Store category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _storeCity,
                          decoration: const InputDecoration(
                            labelText: 'City or area',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: requiredField,
                        ),
                      ],
                      if (_authError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _authError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _authLoading ? null : _submit,
                          icon: _authLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isSeller
                                      ? Icons.storefront
                                      : Icons.shopping_bag,
                                ),
                          label: Text(
                            _authLoading
                                ? 'Please wait'
                                : (_signup ? 'Create account' : 'Login'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _tabIndex = 0;
  String _query = '';
  String _category = 'All';
  final List<CartLine> _cart = [];
  final Set<String> _favoriteIds = {};
  final List<Order> _orders = [];
  List<Shop> _shops = [];
  List<Product> _products = [];
  bool _catalogLoading = false;
  bool _showAllFeatured = false;
  String? _catalogMessage;

  int get _cartCount => _cart.fold(0, (sum, line) => sum + line.quantity);

  double get _subtotal =>
      _cart.fold(0, (sum, line) => sum + (line.product.price * line.quantity));

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadCustomerOrders();
  }

  Future<void> _loadCatalog() async {
    if (soukApiUrl.isEmpty) {
      setState(() {
        _catalogMessage = 'Run the app with SOUK_API_URL to load live stores.';
      });
      return;
    }
    setState(() {
      _catalogLoading = true;
      _catalogMessage = null;
    });
    try {
      final api = SoukApi(baseUrl: soukApiUrl);
      final shopRows = await api.fetchShops();
      final productRows = await api.fetchProducts();
      final shops = shopRows.map((item) => Shop.fromJson(item as Map<String, dynamic>)).toList();
      final products = productRows.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _shops = shops;
        _products = products;
        _catalogLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogLoading = false;
        _catalogMessage = 'Could not load live catalog from Souk.';
      });
    }
  }

  Future<void> _loadCustomerOrders() async {
    if (soukApiUrl.isEmpty) {
      return;
    }
    try {
      final rows = await SoukApi(baseUrl: soukApiUrl).fetchOrders(customerEmail: widget.session.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders
          ..clear()
          ..addAll(rows.map((item) => Order.fromJson(item as Map<String, dynamic>)));
      });
    } catch (_) {
      // Keep the local list; checkout errors surface separately.
    }
  }

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
        _cart[index] = _cart[index].copyWith(
          quantity: _cart[index].quantity + 1,
        );
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

  Future<void> _placeOrder(CheckoutInfo info) async {
    if (_cart.isEmpty) {
      return;
    }
    final shopIds = _cart.map((line) => line.product.shop.id).toSet();
    if (shopIds.length > 1) {
      _showSnack('Checkout one store at a time');
      return;
    }
    if (soukApiUrl.isEmpty) {
      _showSnack('SOUK_API_URL is required for checkout');
      return;
    }
    try {
      final body = await SoukApi(baseUrl: soukApiUrl).createOrder({
        'customerName': widget.session.name,
        'customerEmail': widget.session.email,
        'shopId': shopIds.first,
        'items': [
          for (final line in _cart)
            {'productId': line.product.id, 'quantity': line.quantity},
        ],
        'fulfillmentMethod': info.deliveryMethod == 'Pickup' ? 'PICKUP' : 'DELIVERY',
        'paymentMethod': 'CASH_ON_DELIVERY',
        'deliveryAddress': info.address,
        'note': info.note,
      });
      final orderJson = body['order'] as Map<String, dynamic>? ?? body;
      final total = parseDouble(orderJson['total']);
      final id = orderJson['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final order = Order(
        id: '#${id.substring(0, id.length > 8 ? 8 : id.length)}',
        shopName: _cart.first.product.shop.name,
        total: total == 0 ? _subtotal + 3.5 : total,
        status: orderJson['status'] as String? ?? 'PLACED',
        eta: info.deliveryMethod == 'Pickup' ? 'Ready in 2 hours' : 'Today, 6-8 PM',
        itemCount: _cartCount,
      );
      setState(() {
        _orders.insert(0, order);
        _cart.clear();
        _tabIndex = 2;
      });
      _loadCatalog();
      _showSnack('Order ${order.id} placed');
    } on SoukApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not place order');
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _products.where((product) {
      final q = _query.trim().toLowerCase();
      final inCategory = _category == 'All' || product.category == _category;
      final inSearch =
          q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.shop.name.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q);
      return inCategory && inSearch;
    }).toList();

    final pages = [
      HomePage(
        session: widget.session,
        onLogout: widget.onLogout,
        query: _query,
        category: _category,
        products: products,
        showAllFeatured: _showAllFeatured,
        loading: _catalogLoading,
        message: _catalogMessage,
        categories: _products.map((product) => product.category).toSet().toList()..sort(),
        favoriteIds: _favoriteIds,
        onViewAllFeatured: () => setState(() => _showAllFeatured = !_showAllFeatured),
        onQueryChanged: (value) => setState(() => _query = value),
        onCategoryChanged: (value) => setState(() => _category = value),
        onOpenProduct: _openProduct,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
      ),
      StoresPage(
        session: widget.session,
        onLogout: widget.onLogout,
        favoriteIds: _favoriteIds,
        shops: _shops,
        products: _products,
        onOpenProduct: _openProduct,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
      ),
      ActivityPage(
        session: widget.session,
        onLogout: widget.onLogout,
        orders: _orders,
        products: _products,
        favoriteIds: _favoriteIds,
      ),
      CartPage(
        session: widget.session,
        onLogout: widget.onLogout,
        cart: _cart,
        subtotal: _subtotal,
        onQuantityChanged: _updateQuantity,
        onCheckout: _placeOrder,
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
        ],
      ),
    );
  }
}

class SellerAppShell extends StatefulWidget {
  const SellerAppShell({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<SellerAppShell> createState() => _SellerAppShellState();
}

class _SellerAppShellState extends State<SellerAppShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SellerHubPage(
          session: widget.session,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.query,
    required this.category,
    required this.products,
    required this.showAllFeatured,
    required this.loading,
    required this.message,
    required this.categories,
    required this.favoriteIds,
    required this.onViewAllFeatured,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String query;
  final String category;
  final List<Product> products;
  final bool showAllFeatured;
  final bool loading;
  final String? message;
  final List<String> categories;
  final Set<String> favoriteIds;
  final VoidCallback onViewAllFeatured;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final compactFeatured = query.trim().isEmpty && category == 'All' && !showAllFeatured;
    final featuredProducts = compactFeatured ? products.take(7).toList() : products;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeaderBar(session: session, onLogout: onLogout),
                const SizedBox(height: 18),
                const MarketplaceHero(),
                const SizedBox(height: 14),
                SearchField(value: query, onChanged: onQueryChanged),
                const SizedBox(height: 12),
                CategoryRail(
                  selected: category,
                  categories: categories,
                  onSelected: onCategoryChanged,
                ),
                const SizedBox(height: 16),
                QuickActions(
                  items: const [
                    QuickAction('Deals', Icons.local_offer, Color(0xFFE7A72E)),
                    QuickAction('Nearby', Icons.place, Color(0xFF357C83)),
                    QuickAction('Fresh', Icons.flash_on, Color(0xFF1F7A4D)),
                  ],
                ),
                const SizedBox(height: 16),
                SectionTitle(
                  title: 'Featured today',
                  action: '${products.length} items',
                  actionButton: products.length > 7
                      ? TextButton(
                          onPressed: onViewAllFeatured,
                          child: Text(compactFeatured ? 'View all' : 'Show less'),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (message != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off,
              title: 'Catalog unavailable',
              message: message!,
            ),
          )
        else if (products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No matches yet',
              message: 'Try another shop, category, or product name.',
            ),
          )
        else if (compactFeatured)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 245,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                scrollDirection: Axis.horizontal,
                itemCount: featuredProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = featuredProducts[index];
                  return SizedBox(
                    width: 156,
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
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                childAspectRatio: 0.56,
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
    required this.session,
    required this.onLogout,
    required this.favoriteIds,
    required this.shops,
    required this.products,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final Set<String> favoriteIds;
  final List<Shop> shops;
  final List<Product> products;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        HeaderBar(session: session, onLogout: onLogout),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Local shops', action: 'Verified sellers'),
        const SizedBox(height: 12),
        if (shops.isEmpty)
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No live stores yet',
            message: 'Stores will appear here after sellers create shops and sync products.',
          )
        else
          for (final shop in shops) ...[
          ShopCard(
            shop: shop,
            products: products.where((product) => product.shop.id == shop.id).toList(),
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
  const ActivityPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.orders,
    required this.products,
    required this.favoriteIds,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<Order> orders;
  final List<Product> products;
  final Set<String> favoriteIds;

  @override
  Widget build(BuildContext context) {
    final favorites = products
        .where((product) => favoriteIds.contains(product.id))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        HeaderBar(session: session, onLogout: onLogout),
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
    required this.session,
    required this.onLogout,
    required this.cart,
    required this.subtotal,
    required this.onQuantityChanged,
    required this.onCheckout,
  });

  final AppSession session;
  final VoidCallback onLogout;
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
        HeaderBar(session: widget.session, onLogout: widget.onLogout),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Basket', action: 'Direct checkout'),
        const SizedBox(height: 12),
        if (widget.cart.isEmpty)
          const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Your basket is waiting',
            message:
                'Add products from independent shops and check out in one flow.',
          )
        else ...[
          for (final line in widget.cart) ...[
            CartLineTile(
              line: line,
              onQuantityChanged: widget.onQuantityChanged,
            ),
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
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<SellerHubPage> createState() => _SellerHubPageState();
}

class _SellerHubPageState extends State<SellerHubPage>
    with WidgetsBindingObserver {
  final _shopifyStore = TextEditingController();
  List<SellerOrder> _sellerOrders = [];
  bool _shopifyConnected = false;
  bool _shopifyPending = false;
  bool _shopifySynced = false;
  bool _shopifySyncing = false;
  double _shopifySyncProgress = 0;
  String? _shopifyMessage;
  Timer? _shopifySyncTimer;
  List<SellerInventoryProduct> _syncedProducts = [];
  List<SellerInventoryCollection> _syncedCollections = [];
  String? _selectedCollectionId;
  String _collectionQuery = '';
  bool _inventoryLoading = false;
  String? _inventoryMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshShopifyStatus();
    _loadSellerInventory();
    _loadSellerOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shopifySyncTimer?.cancel();
    _shopifyStore.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshShopifyStatus();
    }
  }

  Future<void> _connectShopify() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Shopify connection is not configured'),
            content: const Text(
              'Login with a real store account and run the app with SOUK_API_URL set to your Railway API URL.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (_shopifyStore.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your Shopify store URL first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final api = SoukApi(baseUrl: soukApiUrl);
      final installUrl = await api.startShopifyOAuth({
        'shopId': shopId,
        'shopDomain': _shopifyStore.text.trim(),
      });
      final launched = await launchUrl(
        Uri.parse(installUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Shopify'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } on SoukApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start Shopify connection: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _shopifyPending = true;
      _shopifySynced = false;
      _shopifyMessage =
          'Opening Shopify login. Approve access there, then return to Souk.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Continue in Shopify to finish connection'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshShopifyStatus() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final status = await SoukApi(
        baseUrl: soukApiUrl,
      ).fetchShopifyStatus(shopId);
      if (!mounted) {
        return;
      }
      final connected = status['connected'] == true;
      final needsReconnect = status['needsReconnect'] == true;
      setState(() {
        _shopifyConnected = connected;
        if (connected) {
          _shopifyPending = false;
          _shopifyMessage = 'Shopify connected. You can sync products now.';
        } else if (needsReconnect) {
          _shopifyPending = false;
          _shopifyMessage = 'Reconnect Shopify once to refresh access.';
        }
      });
    } catch (_) {
      // Keep the current UI state; auth and sync actions surface explicit errors.
    }
  }

  Future<void> _syncShopify() async {
    if (_shopifySyncing) {
      return;
    }
    if (!_shopifyConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect Shopify first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    _startShopifySyncProgress();
    try {
      final result = await SoukApi(baseUrl: soukApiUrl).syncShopify(shopId);
      if (!mounted) {
        return;
      }
      _shopifySyncTimer?.cancel();
      setState(() {
        _shopifySyncing = false;
        _shopifySyncProgress = 1;
        _shopifySynced = true;
        _shopifyMessage =
            'Synced ${result['products'] ?? 0} products and ${result['collections'] ?? 0} collections.';
      });
      await _loadSellerInventory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shopify products synced'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on SoukApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _stopShopifySyncProgress('Sync failed. Check the message and try again.');
    } catch (error) {
      _stopShopifySyncProgress(
        'Sync failed. Check your connection and try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startShopifySyncProgress() {
    _shopifySyncTimer?.cancel();
    setState(() {
      _shopifySyncing = true;
      _shopifySynced = false;
      _shopifySyncProgress = 0.05;
      _shopifyMessage = 'Starting Shopify sync... 5%';
    });
    _shopifySyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _shopifySyncProgress = (_shopifySyncProgress + 0.07).clamp(0.05, 0.9);
        final percent = (_shopifySyncProgress * 100).round();
        _shopifyMessage = percent >= 90
            ? 'Shopify is still processing products and collections... 90%'
            : 'Syncing Shopify products... $percent%';
      });
    });
  }

  void _stopShopifySyncProgress(String message) {
    _shopifySyncTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _shopifySyncing = false;
      _shopifySyncProgress = 0;
      _shopifyMessage = message;
    });
  }

  Future<void> _loadSellerInventory() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    setState(() {
      _inventoryLoading = true;
      _inventoryMessage = null;
    });
    try {
      final data = await SoukApi(
        baseUrl: soukApiUrl,
      ).fetchShopInventory(shopId);
      final products = (data['products'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                SellerInventoryProduct.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      final collections = (data['collections'] as List<dynamic>? ?? [])
          .map(
            (item) => SellerInventoryCollection.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _syncedProducts = products;
        _syncedCollections = collections;
        if (_selectedCollectionId != null &&
            !collections.any((collection) => collection.id == _selectedCollectionId)) {
          _selectedCollectionId = null;
        }
        _inventoryLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inventoryLoading = false;
        _inventoryMessage = 'Could not load synced inventory.';
      });
    }
  }

  Future<void> _loadSellerOrders() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final rows = await SoukApi(baseUrl: soukApiUrl).fetchOrders(shopId: shopId);
      if (!mounted) {
        return;
      }
      setState(() {
        _sellerOrders = rows
            .map((item) => SellerOrder.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // Orders can stay empty until the backend has customer checkout activity.
    }
  }

  @override
  Widget build(BuildContext context) {
    final store =
        widget.session.store ??
        const ShopDraft(
          name: 'My Souk Store',
          category: 'Store',
          city: 'Beirut',
          hasDelivery: true,
        );
    final productCount = _syncedProducts.length;
    final visibleSyncedProducts = _selectedCollectionId == null
        ? _syncedProducts.take(80).toList()
        : _syncedProducts
            .where((product) => product.collectionIds.contains(_selectedCollectionId))
            .toList();
    final selectedCollection = _selectedCollectionId == null
        ? null
        : firstWhereOrNull(
            _syncedCollections,
            (collection) => collection.id == _selectedCollectionId,
          );
    final visibleCollections = _syncedCollections
        .where((collection) => collection.title.toLowerCase().contains(_collectionQuery.toLowerCase()))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        HeaderBar(session: widget.session, onLogout: widget.onLogout),
        const SizedBox(height: 18),
        const SellerHero(),
        const SizedBox(height: 16),
        SellerStoreCard(store: store, ownerName: widget.session.name),
        const SizedBox(height: 16),
        ShopifySyncCard(
          shopifyStore: _shopifyStore,
          connected: _shopifyConnected,
          pending: _shopifyPending,
          synced: _shopifySynced,
          syncing: _shopifySyncing,
          syncProgress: _shopifySyncProgress,
          message: _shopifyMessage,
          onConnect: _connectShopify,
          onSync: _syncShopify,
        ),
        const SizedBox(height: 16),
        SellerMetricGrid(
          productCount: productCount,
          collectionCount: _syncedCollections.length,
        ),
        const SizedBox(height: 16),
        SectionTitle(
          title: 'Collections',
          action: '${_syncedCollections.length} synced',
        ),
        const SizedBox(height: 10),
        if (_inventoryLoading)
          const LinearProgressIndicator(minHeight: 6)
        else if (_syncedCollections.isEmpty)
          const EmptyState(
            icon: Icons.category_outlined,
            title: 'No synced collections yet',
            message: 'Sync Shopify products to import collections into Souk.',
          )
        else
          CollectionBrowser(
            collections: visibleCollections,
            selectedId: _selectedCollectionId,
            query: _collectionQuery,
            onQueryChanged: (value) => setState(() => _collectionQuery = value),
            onSelected: (collectionId) {
              setState(() {
                _selectedCollectionId = _selectedCollectionId == collectionId ? null : collectionId;
              });
            },
          ),
        const SizedBox(height: 16),
        SectionTitle(
          title: selectedCollection?.title ?? 'Inventory',
          action: _selectedCollectionId == null ? '$productCount products' : '${visibleSyncedProducts.length} products',
        ),
        const SizedBox(height: 10),
        if (_inventoryMessage != null)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Inventory unavailable',
            message: _inventoryMessage!,
          )
        else if (visibleSyncedProducts.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            message: 'Choose another collection or sync Shopify again.',
          )
        else ...[
          if (_selectedCollectionId == null && _syncedProducts.length > visibleSyncedProducts.length)
            Text(
              'Showing first ${visibleSyncedProducts.length} products. Choose a collection to narrow the list.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final product in visibleSyncedProducts)
            SellerInventoryTile(product: product),
        ],
        const SizedBox(height: 16),
        const SectionTitle(title: 'Incoming orders', action: 'Live orders'),
        const SizedBox(height: 10),
        if (_sellerOrders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No live orders yet',
            message: 'Customer orders will appear here after checkout.',
          )
        else
          for (final order in _sellerOrders) SellerOrderTile(order: order),
      ],
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, this.session, this.onLogout});

  final AppSession? session;
  final VoidCallback? onLogout;

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                session == null
                    ? 'Shops, makers, and quick checkout'
                    : '${session!.name} - ${_roleLabel(session!.role)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: session == null ? 'Notifications' : 'Logout',
          onPressed: onLogout,
          icon: Icon(session == null ? Icons.notifications_none : Icons.logout),
        ),
      ],
    );
  }

  String _roleLabel(AccountRole role) {
    return role == AccountRole.seller ? 'Store account' : 'Customer account';
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
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
  const CategoryRail({
    super.key,
    required this.selected,
    required this.categories,
    required this.onSelected,
  });

  final String selected;
  final List<String> categories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = ['All', ...categories];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = visibleCategories[index];
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Icon(item.icon, color: item.color),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
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
  const SectionTitle({
    super.key,
    required this.title,
    required this.action,
    this.actionButton,
  });

  final String title;
  final String action;
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionButton != null)
          actionButton!
        else
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
            ProductArt(
              product: product,
              isFavorite: isFavorite,
              onFavorite: onFavorite,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFE7A72E),
                        ),
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.formattedPrice,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Add to basket',
                          onPressed: onAdd,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          padding: EdgeInsets.zero,
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
              child: product.imageUrl == null
                  ? Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: product.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(product.icon, color: Colors.white, size: 38),
                    )
                  : Image.network(
                      product.imageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: product.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(product.icon, color: Colors.white, size: 38),
                        );
                      },
                    ),
            ),
            Positioned(left: 10, top: 10, child: Tag(label: product.category)),
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
    required this.products,
    required this.favoriteIds,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final Shop shop;
  final List<Product> products;
  final Set<String> favoriteIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
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
                      Text(
                        shop.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${shop.category} in ${shop.location}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
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
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: product.images.isEmpty
                  ? Container(
                      color: product.color.withValues(alpha: 0.15),
                      child: Icon(product.icon, color: product.color, size: 78),
                    )
                  : PageView(
                      children: [
                        for (final image in product.images)
                          Image.network(image, fit: BoxFit.cover),
                      ],
                    ),
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
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            Text(
              '${product.shop.name} - ${product.category}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
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
            if (product.variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Variants', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in product.variants.take(10))
                    Tag(label: '${variant.title} - ${money(variant.price)}'),
                ],
              ),
            ],
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
  const CartLineTile({
    super.key,
    required this.line,
    required this.onQuantityChanged,
  });

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
                  Text(
                    line.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    line.product.shop.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(line.product.formattedPrice),
                ],
              ),
            ),
            QuantityStepper(
              quantity: line.quantity,
              onChanged: (quantity) =>
                  onQuantityChanged(line.product, quantity),
            ),
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

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
            Text(
              'Checkout details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Delivery',
                  icon: Icon(Icons.local_shipping),
                  label: Text('Delivery'),
                ),
                ButtonSegment(
                  value: 'Pickup',
                  icon: Icon(Icons.store),
                  label: Text('Pickup'),
                ),
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
              initialValue: payment,
              decoration: const InputDecoration(
                labelText: 'Payment',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Cash on delivery',
                  child: Text('Cash on delivery'),
                ),
                DropdownMenuItem(
                  value: 'Card on delivery',
                  child: Text('Card on delivery'),
                ),
                DropdownMenuItem(
                  value: 'Wallet later',
                  child: Text('Wallet later'),
                ),
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
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

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
        title: Text(
          '${order.id} - ${order.shopName}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${order.itemCount} items - ${order.eta}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(order.total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(product.shop.name),
        trailing: Text(product.formattedPrice),
      ),
    );
  }
}

class SellerStoreCard extends StatelessWidget {
  const SellerStoreCard({
    super.key,
    required this.store,
    required this.ownerName,
  });

  final ShopDraft store;
  final String ownerName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.storefront, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${store.category} - ${store.city}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Tag(label: 'Owner: $ownerName'),
                      Tag(
                        label: store.hasDelivery
                            ? 'Delivery enabled'
                            : 'Pickup only',
                      ),
                      const Tag(label: 'Draft store'),
                    ],
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

class ShopifySyncCard extends StatelessWidget {
  const ShopifySyncCard({
    super.key,
    required this.shopifyStore,
    required this.connected,
    required this.pending,
    required this.synced,
    required this.syncing,
    required this.syncProgress,
    required this.message,
    required this.onConnect,
    required this.onSync,
  });

  final TextEditingController shopifyStore;
  final bool connected;
  final bool pending;
  final bool synced;
  final bool syncing;
  final double syncProgress;
  final String? message;
  final VoidCallback onConnect;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF95BF47),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Shopify products',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Import collections, images, descriptions, prices, and inventory.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Enter the store URL, then login with Shopify and approve access.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: shopifyStore,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Shopify store URL',
                hintText: 'your-store.myshopify.com',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(label: connected ? 'Connected' : 'Not connected'),
                if (pending && !connected) const Tag(label: 'Login pending'),
                Tag(
                  label: syncing
                      ? 'Syncing'
                      : synced
                      ? 'Inventory synced'
                      : 'Waiting to sync',
                ),
                const Tag(label: 'Two-way stock'),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (syncing) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: syncProgress.clamp(0, 0.95),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(syncProgress * 100).round()}% complete',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: syncing ? null : onConnect,
                    icon: const Icon(Icons.login),
                    label: const Text('Connect Shopify'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: syncing ? null : onSync,
                    icon: syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync_outlined),
                    label: Text(syncing ? 'Syncing...' : 'Sync products'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SellerMetricGrid extends StatelessWidget {
  const SellerMetricGrid({
    super.key,
    required this.productCount,
    required this.collectionCount,
  });

  final int productCount;
  final int collectionCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      const SellerMetric('Orders', '24', Icons.receipt_long),
      SellerMetric('Products', productCount.toString(), Icons.inventory_2),
      SellerMetric('Collections', collectionCount.toString(), Icons.category),
      const SellerMetric('Rating', '4.8', Icons.star),
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
                      Text(
                        metric.value,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        metric.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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

class CollectionBrowser extends StatelessWidget {
  const CollectionBrowser({
    super.key,
    required this.collections,
    required this.selectedId,
    required this.query,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final List<SellerInventoryCollection> collections;
  final String? selectedId;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            labelText: 'Search collections',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: collections.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No collections match',
                  message: 'Try another collection name.',
                )
              : ListView.separated(
                  itemCount: collections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final selected = selectedId == collection.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      selected: selected,
                      leading: Icon(selected ? Icons.folder_open : Icons.folder_outlined),
                      title: Text(collection.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${collection.productCount} products'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelected(collection.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SellerInventoryTile extends StatelessWidget {
  const SellerInventoryTile({super.key, required this.product});

  final SellerInventoryProduct product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.imageUrl == null
                  ? Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFFE7F0EA),
                      child: const Icon(Icons.inventory_2),
                    )
                  : Image.network(
                      product.imageUrl!,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: 58,
                          height: 58,
                          color: const Color(0xFFE7F0EA),
                          child: const Icon(Icons.image_not_supported_outlined),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
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
                    '${product.stock} in stock - ${product.category}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (product.variants.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final variant in product.variants.take(3))
                          Tag(label: variant.title),
                      ],
                    ),
                  ],
                  if (product.collections.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final collection in product.collections.take(3))
                          Tag(label: collection),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(product.price),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
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
        title: Text(
          order.customer,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
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

  factory Shop.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Store';
    return Shop(
      id: json['id'] as String? ?? '',
      name: name,
      category: json['category'] as String? ?? 'Store',
      location: json['city'] as String? ?? '',
      story: json['story'] as String? ?? 'Shop products directly from this Souk store.',
      rating: parseDouble(json['rating']) == 0 ? 4.8 : parseDouble(json['rating']),
      color: const Color(0xFF1F7A4D),
      icon: Icons.storefront,
      delivery: json['deliveryLabel'] as String? ?? 'Delivery available',
      minimumOrder: parseDouble(json['minimumOrder']),
      orderCount: parseInt(json['orderCount']),
    );
  }

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
    required this.images,
    required this.variants,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final shopJson = json['shop'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final images = (json['images'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    final variants = (json['variants'] as List<dynamic>? ?? [])
        .map((item) => ProductVariant.fromJson(item as Map<String, dynamic>))
        .toList();
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Product',
      category: json['category'] as String? ?? 'Shopify',
      price: parseDouble(json['price']),
      shop: Shop.fromJson(shopJson),
      color: const Color(0xFF1F7A4D),
      icon: Icons.inventory_2,
      description: json['description'] as String? ?? '',
      rating: parseDouble(json['rating']) == 0 ? 4.8 : parseDouble(json['rating']),
      stock: parseInt(json['stock']),
      imageUrl: json['imageUrl'] as String?,
      images: images.isEmpty && json['imageUrl'] != null ? [json['imageUrl'] as String] : images,
      variants: variants,
    );
  }

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
  final String? imageUrl;
  final List<String> images;
  final List<ProductVariant> variants;

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

class ProductVariant {
  const ProductVariant({
    required this.title,
    required this.price,
    required this.stock,
    this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      title: json['title'] as String? ?? 'Variant',
      price: parseDouble(json['price']),
      stock: parseInt(json['stock']),
      sku: json['sku'] as String?,
    );
  }

  final String title;
  final double price;
  final int stock;
  final String? sku;
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

  factory Order.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final items = json['items'] as List<dynamic>? ?? const [];
    final id = json['id'] as String? ?? '';
    return Order(
      id: '#${id.substring(0, id.length > 8 ? 8 : id.length)}',
      shopName: shop['name'] as String? ?? 'Store',
      total: parseDouble(json['total']),
      status: json['status'] as String? ?? 'PLACED',
      eta: 'Live order',
      itemCount: items.length,
    );
  }

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
    this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.hasDelivery,
  });

  final String? id;
  final String name;
  final String category;
  final String city;
  final bool hasDelivery;
}

class SellerInventoryProduct {
  const SellerInventoryProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.collections,
    required this.collectionIds,
    required this.variants,
    required this.images,
    this.imageUrl,
  });

  factory SellerInventoryProduct.fromJson(Map<String, dynamic> json) {
    final productCollections = json['collections'] as List<dynamic>? ?? [];
    final collectionRows = productCollections
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['collection'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();
    final imageRows = (json['images'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    return SellerInventoryProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Product',
      category: json['category'] as String? ?? 'Shopify',
      price: parseDouble(json['price']),
      stock: parseInt(json['stock']),
      imageUrl: json['imageUrl'] as String?,
      images: imageRows.isEmpty && json['imageUrl'] != null ? [json['imageUrl'] as String] : imageRows,
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((item) => ProductVariant.fromJson(item as Map<String, dynamic>))
          .toList(),
      collections: collectionRows
          .map((collection) => collection['title'] as String? ?? 'Collection')
          .toList(),
      collectionIds: collectionRows
          .map((collection) => collection['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
    );
  }

  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String? imageUrl;
  final List<String> images;
  final List<ProductVariant> variants;
  final List<String> collections;
  final List<String> collectionIds;
}

class SellerInventoryCollection {
  const SellerInventoryCollection({
    required this.id,
    required this.title,
    required this.productCount,
  });

  factory SellerInventoryCollection.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>? ?? {};
    return SellerInventoryCollection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Collection',
      productCount: parseInt(count['products']),
    );
  }

  final String id;
  final String title;
  final int productCount;
}

class SellerOrder {
  const SellerOrder(this.customer, this.summary, this.status);

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final items = json['items'] as List<dynamic>? ?? const [];
    final summary = items.isEmpty
        ? 'No items'
        : items.map((item) {
            final row = item as Map<String, dynamic>;
            final product = row['product'] as Map<String, dynamic>? ?? const <String, dynamic>{};
            return '${row['quantity'] ?? 1} x ${product['name'] ?? 'Product'}';
          }).join(', ');
    return SellerOrder(
      (customer['name'] as String?) ?? (customer['email'] as String?) ?? 'Customer',
      summary,
      json['status'] as String? ?? 'PLACED',
    );
  }

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

double parseDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int parseInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) {
      return item;
    }
  }
  return null;
}

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
