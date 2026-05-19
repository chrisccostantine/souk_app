import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

enum AccountRole { customer, seller, admin }

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

    if (session.role == AccountRole.admin) {
      return AdminDashboardPage(
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
  bool _signup = false;
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

    if (_signup && _role == AccountRole.admin) {
      setState(() => _authError = 'Admin access is login only.');
      return;
    }

    if (!_signup &&
        _email.text.trim().toLowerCase() == 'scalora.socialmedia.agency@gmail.com' &&
        _password.text == '12345678') {
      widget.onAuthenticated(
        const AppSession(
          name: 'Scalora Admin',
          email: 'Scalora.socialmedia.agency@gmail.com',
          role: AccountRole.admin,
        ),
      );
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
          : user['role'] == 'ADMIN'
          ? AccountRole.admin
          : AccountRole.customer,
      store: shop == null
          ? null
          : ShopDraft.fromJson(shop),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var loading = false;
    String? error;
    var codeRequested = false;
    String? helperText;
    var dialogOpen = true;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeSetDialogState(VoidCallback update) {
              if (dialogOpen && dialogContext.mounted) {
                setDialogState(update);
              }
            }

            Future<void> submit() async {
              if (loading) {
                return;
              }
              final email = emailController.text.trim();
              if (email.isEmpty) {
                safeSetDialogState(() => error = 'Enter your account email.');
                return;
              }
              if (soukApiUrl.isEmpty) {
                safeSetDialogState(() => error = 'SOUK_API_URL is required.');
                return;
              }
              safeSetDialogState(() {
                loading = true;
                error = null;
              });
              try {
                final api = SoukApi(baseUrl: soukApiUrl);
                if (!codeRequested) {
                  final response = await api.forgotPassword({'email': email});
                  final nextCode = response['resetCode']?.toString();
                  safeSetDialogState(() {
                    codeRequested = true;
                    if (nextCode != null) {
                      codeController.text = nextCode;
                    }
                    helperText = nextCode == null
                        ? 'Check your email for the reset code.'
                        : 'Reset code: $nextCode';
                  });
                } else {
                  if (newPasswordController.text.length < 6) {
                    safeSetDialogState(() => error = 'Use at least 6 characters.');
                    return;
                  }
                  if (newPasswordController.text != confirmPasswordController.text) {
                    safeSetDialogState(() => error = 'Passwords do not match.');
                    return;
                  }
                  await api.confirmPasswordReset({
                    'email': email,
                    'resetCode': codeController.text.trim(),
                    'newPassword': newPasswordController.text,
                  });
                  if (dialogContext.mounted) {
                    dialogOpen = false;
                    Navigator.pop(dialogContext, newPasswordController.text);
                  }
                }
              } on SoukApiException catch (apiError) {
                safeSetDialogState(() => error = authFriendlyError(apiError));
              } on TimeoutException {
                safeSetDialogState(
                  () => error =
                      'Email request timed out. Redeploy the latest backend and check Railway SMTP variables.',
                );
              } catch (submitError) {
                safeSetDialogState(() => error = resetFriendlyError(submitError));
              } finally {
                safeSetDialogState(() => loading = false);
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              title: const Text('Forgot password'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.62,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !codeRequested
                              ? 'Enter your email to receive a reset code. Your password will not change yet.'
                              : 'Enter the reset code from your email and choose your new password.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          enabled: !codeRequested,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        if (helperText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            helperText!,
                            style: const TextStyle(
                              color: Color(0xFF1F7A4D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (codeRequested) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reset code',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: newPasswordController,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'New password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submit(),
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          dialogOpen = false;
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: Text(
                    loading
                        ? 'Working...'
                        : !codeRequested
                            ? 'Get code'
                            : 'Set password',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    dialogOpen = false;
    final selectedPassword = newPassword;
    if (!mounted || selectedPassword == null) {
      return;
    }
    _password.text = selectedPassword;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password updated'),
        content: const Text('Your new password is filled in. You can login now.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Login'),
          ),
        ],
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
                      Text(
                        _signup
                            ? (_role == AccountRole.seller ? 'Register your store' : 'Create shopper account')
                            : (_role == AccountRole.seller ? 'Store login' : 'Shopper login'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _signup
                            ? 'Fill in the details once, then continue to your account.'
                            : 'Choose where you want to enter Souk.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceCardButton(
                              icon: Icons.person_outline,
                              label: 'Shopper',
                              selected: _role == AccountRole.customer,
                              onTap: () => setState(() => _role = AccountRole.customer),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceCardButton(
                              icon: Icons.storefront_outlined,
                              label: 'Store',
                              selected: _role == AccountRole.seller,
                              onTap: () => setState(() => _role = AccountRole.seller),
                            ),
                          ),
                        ],
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
                      if (!_signup) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _authLoading ? null : _showForgotPasswordDialog,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      ],
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _authLoading
                              ? null
                              : () => setState(() {
                                    _signup = !_signup;
                                    _authError = null;
                                  }),
                          icon: Icon(_signup ? Icons.login : Icons.person_add_alt),
                          label: Text(
                            _signup
                                ? 'Already have an account? Login'
                                : (_role == AccountRole.seller
                                    ? 'Register a store'
                                    : 'Register as shopper'),
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
  MarketplaceFilters _filters = const MarketplaceFilters();
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

  int get _cartShopCount => _cart.map((line) => line.product.shop.id).toSet().length;

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
    _trackShopEvent(product, 'addToCart');
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
    if (_favoriteIds.contains(product.id)) {
      _persistFavorite(product);
    }
  }

  Future<void> _persistFavorite(Product product) async {
    if (soukApiUrl.isEmpty || product.id.isEmpty) {
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).favoriteProduct(product.id, {
        'customerEmail': widget.session.email,
        'customerName': widget.session.name,
      });
    } catch (_) {
      // Local favorite still works if persistence is temporarily unavailable.
    }
  }

  Future<void> _followShop(Shop shop) async {
    if (soukApiUrl.isEmpty || shop.id.isEmpty) {
      _showSnack('SOUK_API_URL is required to follow stores');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).followShop(shop.id, {
        'email': widget.session.email,
        'name': widget.session.name,
      });
      _showSnack('Following ${shop.name}');
    } on SoukApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not follow store');
    }
  }

  void _openProduct(Product product) {
    _trackShopEvent(product, 'view');
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
          onReview: (rating, comment) => _createReview(product, rating, comment),
        );
      },
    );
  }

  Future<void> _createReview(Product product, int rating, String comment) async {
    if (soukApiUrl.isEmpty || product.shop.id.isEmpty) {
      _showSnack('SOUK_API_URL is required to review stores');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createReview(product.shop.id, {
        'customerEmail': widget.session.email,
        'customerName': widget.session.name,
        'rating': rating,
        'comment': comment,
      });
      _loadCatalog();
      _showSnack('Review submitted');
    } on SoukApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not submit review');
    }
  }

  void _trackShopEvent(Product product, String event) {
    if (soukApiUrl.isEmpty || product.shop.id.isEmpty) {
      return;
    }
    SoukApi(baseUrl: soukApiUrl).trackShopAnalytics(product.shop.id, {
      'event': event,
      'bestProductId': product.id,
      'topCity': product.shop.location,
    }).catchError((_) => <String, dynamic>{});
  }

  Future<void> _placeOrder(CheckoutInfo info) async {
    if (_cart.isEmpty) {
      return;
    }
    if (soukApiUrl.isEmpty) {
      _showSnack('SOUK_API_URL is required for checkout');
      return;
    }
    try {
      final groupedLines = <String, List<CartLine>>{};
      for (final line in _cart) {
        groupedLines.putIfAbsent(line.product.shop.id, () => []).add(line);
      }
      final placedOrders = <Order>[];
      final api = SoukApi(baseUrl: soukApiUrl);

      for (final entry in groupedLines.entries) {
        final lines = entry.value;
        final body = await api.createOrder({
          'customerName': widget.session.name,
          'customerEmail': widget.session.email,
          'shopId': entry.key,
          'items': [
            for (final line in lines)
              {'productId': line.product.id, 'quantity': line.quantity},
          ],
          'fulfillmentMethod': info.deliveryMethod == 'Pickup' ? 'PICKUP' : 'DELIVERY',
          'paymentMethod': paymentMethodCode(info.paymentMethod),
          'deliveryAddress': info.address,
          'note': info.note,
        });
        final orderJson = body['order'] as Map<String, dynamic>? ?? body;
        final total = parseDouble(orderJson['total']);
        final id = orderJson['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
        placedOrders.add(
          Order(
            id: '#${id.substring(0, id.length > 8 ? 8 : id.length)}',
            shopName: lines.first.product.shop.name,
            total: total == 0
                ? lines.fold<double>(
                      0,
                      (sum, line) => sum + line.product.price * line.quantity,
                    ) +
                    (info.deliveryMethod == 'Pickup' ? 0 : 3.5)
                : total,
            status: orderJson['status'] as String? ?? 'PLACED',
            eta: info.deliveryMethod == 'Pickup' ? 'Ready in 2 hours' : 'Today, 6-8 PM',
            itemCount: lines.fold(0, (sum, line) => sum + line.quantity),
          ),
        );
      }
      setState(() {
        _orders.insertAll(0, placedOrders);
        _cart.clear();
        _tabIndex = 2;
      });
      _loadCatalog();
      _showSnack(
        placedOrders.length == 1
            ? 'Order ${placedOrders.first.id} placed'
            : '${placedOrders.length} store orders placed',
      );
    } on SoukApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not place order');
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    var loading = false;
    String? error;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (newPassword.text.length < 6) {
                setDialogState(() => error = 'Use at least 6 characters.');
                return;
              }
              if (newPassword.text != confirmPassword.text) {
                setDialogState(() => error = 'Passwords do not match.');
                return;
              }
              if (soukApiUrl.isEmpty) {
                setDialogState(() => error = 'SOUK_API_URL is required.');
                return;
              }
              setDialogState(() {
                loading = true;
                error = null;
              });
              try {
                await SoukApi(baseUrl: soukApiUrl).changePassword({
                  'email': widget.session.email,
                  'currentPassword': currentPassword.text,
                  'newPassword': newPassword.text,
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } on SoukApiException catch (apiError) {
                setDialogState(() => error = apiError.message);
              } catch (submitError) {
                setDialogState(() => error = 'Could not update password: $submitError');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Change password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(loading ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();

    if (changed == true) {
      _showSnack('Password updated');
    }
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.88,
            child: CartPage(
              session: widget.session,
              onLogout: widget.onLogout,
              cart: _cart,
              subtotal: _subtotal,
              shopCount: _cartShopCount,
              onQuantityChanged: _updateQuantity,
              onCheckout: (info) {
                Navigator.pop(sheetContext);
                _placeOrder(info);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products.where((product) {
      final q = _query.trim().toLowerCase();
      final inCategory =
          _category == 'All' || product.category == _category || product.collectionNames.contains(_category);
      final inSearch =
          q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.shop.name.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q) ||
          product.collectionNames.any((name) => name.toLowerCase().contains(q));
      return inCategory && inSearch && _filters.matches(product);
    }).toList()
      ..sort(_filters.compare);

    final pages = [
      HomePage(
        session: widget.session,
        onLogout: widget.onLogout,
        query: _query,
        category: _category,
        products: products,
        allProducts: _products,
        showAllFeatured: _showAllFeatured,
        loading: _catalogLoading,
        message: _catalogMessage,
        categories: {
          for (final product in _products) product.category,
          for (final product in _products) ...product.collectionNames,
        }.toList()
          ..sort(),
        favoriteIds: _favoriteIds,
        onViewAllFeatured: () => setState(() => _showAllFeatured = !_showAllFeatured),
        onQueryChanged: (value) => setState(() => _query = value),
        onCategoryChanged: (value) => setState(() => _category = value),
        filters: _filters,
        filterOptions: MarketplaceFilterOptions.fromProducts(_products),
        onFiltersChanged: (value) => setState(() => _filters = value),
        onOpenProduct: _openProduct,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
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
        onFollowStore: _followShop,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
      SellEntryPage(
        session: widget.session,
        onLogout: widget.onLogout,
        onStartSelling: () => _showSnack('Register as a store from the login screen'),
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
      ActivityPage(
        session: widget.session,
        onLogout: widget.onLogout,
        orders: _orders,
        products: _products,
        favoriteIds: _favoriteIds,
        onChangePassword: _changePassword,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
      ProfilePage(
        session: widget.session,
        onLogout: widget.onLogout,
        favoriteCount: _favoriteIds.length,
        orderCount: _orders.length,
        onChangePassword: _changePassword,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: SoukBottomNav(
        selectedIndex: _tabIndex,
        onSelected: (index) => setState(() => _tabIndex = index),
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

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Shop> _shops = [];
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    if (soukApiUrl.isEmpty) {
      setState(() => _message = 'SOUK_API_URL is required for admin review.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final rows = await SoukApi(baseUrl: soukApiUrl).fetchShops(includeAll: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _shops = rows.map((item) => Shop.fromJson(item as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _message = 'Could not load store requests.';
      });
    }
  }

  Future<void> _reviewShop(Shop shop, bool approved) async {
    try {
      await SoukApi(baseUrl: soukApiUrl).verifyShop(shop.id, {
        'verified': approved,
        'verificationNote': approved ? 'Approved by Scalora admin' : 'Declined by Scalora admin',
      });
      await _loadShops();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '${shop.name} approved' : '${shop.name} declined'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on SoukApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          children: [
            HeaderBar(session: widget.session, onLogout: widget.onLogout),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Admin dashboard', action: 'Store approvals'),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator(minHeight: 6)
            else if (_message != null)
              EmptyState(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin unavailable',
                message: _message!,
              )
            else
              for (final shop in _shops) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: shop.verified ? const Color(0xFF1F7A4D) : const Color(0xFFC8673A),
                      child: Icon(shop.verified ? Icons.verified : Icons.hourglass_top, color: Colors.white),
                    ),
                    title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${shop.category} - ${shop.location} - ${shop.statusLabel}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Approve',
                          onPressed: () => _reviewShop(shop, true),
                          icon: const Icon(Icons.check),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Decline',
                          onPressed: () => _reviewShop(shop, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
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
    required this.allProducts,
    required this.showAllFeatured,
    required this.loading,
    required this.message,
    required this.categories,
    required this.favoriteIds,
    required this.onViewAllFeatured,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.filters,
    required this.filterOptions,
    required this.onFiltersChanged,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String query;
  final String category;
  final List<Product> products;
  final List<Product> allProducts;
  final bool showAllFeatured;
  final bool loading;
  final String? message;
  final List<String> categories;
  final Set<String> favoriteIds;
  final VoidCallback onViewAllFeatured;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final MarketplaceFilters filters;
  final MarketplaceFilterOptions filterOptions;
  final ValueChanged<MarketplaceFilters> onFiltersChanged;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final chosenFeatured = products.where((product) => product.featured).toList();
    final dealSource = chosenFeatured.isEmpty ? products : chosenFeatured;
    final featuredProducts = (showAllFeatured ? dealSource : dealSource.take(8)).toList();
    final popularCategories = categories.isEmpty
        ? ['Home', 'Fashion', 'Electronics', 'Beauty']
        : categories.take(6).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoukShopperTopBar(
                  cartCount: cartCount,
                  onCartTap: onCartTap,
                ),
                const SizedBox(height: 24),
                SoukSearchRow(
                  value: query,
                  filters: filters,
                  options: filterOptions,
                  onChanged: onQueryChanged,
                  onFiltersChanged: onFiltersChanged,
                ),
                const SizedBox(height: 22),
                SoukCategoryBubbles(
                  selected: category,
                  categories: categories,
                  products: allProducts,
                  onSelected: onCategoryChanged,
                ),
                const SizedBox(height: 26),
                SoukPromoBanner(products: allProducts.isEmpty ? products : allProducts),
                const SizedBox(height: 26),
                SoukSectionHeader(
                  title: 'Flash Deals',
                  icon: Icons.bolt,
                  onViewAll: onViewAllFeatured,
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
        else
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    scrollDirection: Axis.horizontal,
                    itemCount: featuredProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final product = featuredProducts[index];
                      return SizedBox(
                        width: 178,
                        child: SoukDealCard(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: SoukSectionHeader(
                    title: 'Popular Categories',
                    onViewAll: () => onCategoryChanged('All'),
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: popularCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final name = popularCategories[index];
                      final categoryProducts = allProducts
                          .where((product) => product.category == name || product.collectionNames.contains(name))
                          .toList();
                      return SizedBox(
                        width: 132,
                        child: SoukPopularCategoryTile(
                          name: name,
                          products: categoryProducts,
                          onTap: () => onCategoryChanged(name),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
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
    required this.onFollowStore,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final Set<String> favoriteIds;
  final List<Shop> shops;
  final List<Product> products;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Shop> onFollowStore;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        SoukShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
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
            onFollow: () => onFollowStore(shop),
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
    required this.onChangePassword,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<Order> orders;
  final List<Product> products;
  final Set<String> favoriteIds;
  final VoidCallback onChangePassword;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final favorites = products
        .where((product) => favoriteIds.contains(product.id))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        SoukShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
        const SizedBox(height: 18),
        AccountSecurityCard(
          session: session,
          onChangePassword: onChangePassword,
        ),
        const SizedBox(height: 16),
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

class AccountSecurityCard extends StatelessWidget {
  const AccountSecurityCard({
    super.key,
    required this.session,
    required this.onChangePassword,
  });

  final AppSession session;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1F7A4D).withValues(alpha: 0.12),
              child: Text(
                session.name.isEmpty ? 'S' : session.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF1F7A4D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Change password',
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_reset),
            ),
          ],
        ),
      ),
    );
  }
}

class SellEntryPage extends StatelessWidget {
  const SellEntryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onStartSelling,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final VoidCallback onStartSelling;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SoukShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF3B2114),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront, color: Colors.white, size: 42),
              const SizedBox(height: 18),
              Text(
                'Sell on Souk',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a store account, get approved by Scalora, then sync Shopify products into the marketplace.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onStartSelling,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Start selling'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const EmptyState(
          icon: Icons.verified_user_outlined,
          title: 'Approval required',
          message: 'Store products sync only after admin approval, so shoppers only see trusted active stores.',
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.favoriteCount,
    required this.orderCount,
    required this.onChangePassword,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int favoriteCount;
  final int orderCount;
  final VoidCallback onChangePassword;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SoukShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
        const SizedBox(height: 24),
        AccountSecurityCard(
          session: session,
          onChangePassword: onChangePassword,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ProfileStatTile(
                icon: Icons.favorite_border,
                value: favoriteCount.toString(),
                label: 'Saved',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ProfileStatTile(
                icon: Icons.receipt_long_outlined,
                value: orderCount.toString(),
                label: 'Orders',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8F552E)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class SoukBottomNav extends StatelessWidget {
  const SoukBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SoukBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
            ),
            Expanded(
              child: SoukBottomNavItem(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view,
                label: 'Categories',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelected(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA8663A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA8663A).withValues(alpha: 0.26),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sell',
                      style: TextStyle(
                        color: selectedIndex == 2 ? const Color(0xFFA8663A) : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SoukBottomNavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Orders',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ),
            Expanded(
              child: SoukBottomNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoukBottomNavItem extends StatelessWidget {
  const SoukBottomNavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFA8663A) : Colors.black54;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
    required this.shopCount,
    required this.onQuantityChanged,
    required this.onCheckout,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<CartLine> cart;
  final double subtotal;
  final int shopCount;
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
    final deliveryTotal = _method == 'Pickup' || widget.cart.isEmpty
        ? 0.0
        : delivery * widget.shopCount;
    final total = widget.cart.isEmpty ? 0.0 : widget.subtotal + deliveryTotal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      children: [
        HeaderBar(session: widget.session, onLogout: widget.onLogout),
        const SizedBox(height: 18),
        SectionTitle(
          title: 'Basket',
          action: widget.shopCount > 1 ? '${widget.shopCount} stores' : 'Direct checkout',
        ),
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
            delivery: deliveryTotal,
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

enum SellerMenuSection {
  settings,
  productSync,
  analytics,
  growth,
  operations,
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
  String? _shopifySyncJobId;
  List<SellerInventoryProduct> _syncedProducts = [];
  List<SellerInventoryCollection> _syncedCollections = [];
  SellerGrowthStats _growthStats = const SellerGrowthStats();
  String? _selectedCollectionId;
  String _collectionQuery = '';
  bool _inventoryLoading = false;
  String? _inventoryMessage;
  SellerMenuSection _sellerSection = SellerMenuSection.settings;
  ShopDraft? _liveStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.session.store?.isActive == true) {
      _sellerSection = SellerMenuSection.productSync;
    }
    _refreshSellerStore();
    _refreshShopifyStatus();
    _loadSellerInventory();
    _loadSellerOrders();
    _loadSellerGrowth();
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
      _refreshSellerStore();
      _refreshShopifyStatus();
    }
  }

  Future<void> _refreshSellerStore() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final rows = await SoukApi(baseUrl: soukApiUrl).fetchShops(includeAll: true);
      final row = firstWhereOrNull(
        rows.whereType<Map<String, dynamic>>(),
        (shop) => shop['id']?.toString() == shopId,
      );
      if (!mounted || row == null) {
        return;
      }
      final refreshedStore = ShopDraft.fromJson(row);
      setState(() {
        _liveStore = refreshedStore;
        if (refreshedStore.isActive && _sellerSection == SellerMenuSection.settings) {
          _sellerSection = SellerMenuSection.productSync;
        }
      });
    } catch (_) {
      // The session store remains usable if status refresh is unavailable.
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
      final jobId = result['jobId'] as String?;
      if (jobId == null) {
        throw const SoukApiException(500, 'Sync job was not created');
      }
      setState(() {
        _shopifySyncJobId = jobId;
        _shopifyMessage = result['message'] as String? ?? 'Shopify sync started';
      });
      _pollShopifySyncJob(jobId);
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
      _shopifySyncProgress = 0.02;
      _shopifyMessage = 'Starting Shopify sync... 2%';
    });
  }

  void _pollShopifySyncJob(String jobId) {
    _shopifySyncTimer?.cancel();
    _shopifySyncTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final job = await SoukApi(baseUrl: soukApiUrl).fetchShopifySyncJob(jobId);
        if (!mounted || _shopifySyncJobId != jobId) {
          return;
        }
        final progress = (parseDouble(job['progress']) / 100).clamp(0.02, 1.0);
        final status = job['status'] as String? ?? 'running';
        final message = job['message'] as String? ?? 'Syncing Shopify catalog';
        setState(() {
          _shopifySyncProgress = progress;
          _shopifyMessage = '$message... ${(progress * 100).round()}%';
        });
        if (status == 'completed') {
          _shopifySyncTimer?.cancel();
          final result = job['result'] as Map<String, dynamic>? ?? const {};
          setState(() {
            _shopifySyncing = false;
            _shopifySyncProgress = 1;
            _shopifySynced = true;
            _shopifySyncJobId = null;
            _shopifyMessage =
                'Synced ${result['products'] ?? 0} products and ${result['collections'] ?? 0} collections.';
          });
          await _loadSellerInventory();
          await _loadSellerGrowth();
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shopify products synced'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (status == 'failed') {
          _shopifySyncTimer?.cancel();
          _stopShopifySyncProgress(message);
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _shopifyMessage = 'Still syncing Shopify. Waiting for status...';
          });
        }
      }
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
      _shopifySyncJobId = null;
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
      await _loadSellerGrowth();
    } catch (_) {
      // Orders can stay empty until the backend has customer checkout activity.
    }
  }

  Future<void> _loadSellerGrowth() async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final data = await SoukApi(baseUrl: soukApiUrl).fetchShopGrowth(shopId);
      if (!mounted) {
        return;
      }
      setState(() {
        _growthStats = SellerGrowthStats.fromJson(data);
      });
    } catch (_) {
      // Growth data is optional until the new backend migration is deployed.
    }
  }

  Future<void> _saveStoreProfile(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before saving store settings.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).updateShopProfile(shopId, payload);
      setState(() => _sellerSection = SellerMenuSection.productSync);
      _showSellerSnack('Store profile saved');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not save store profile');
    }
  }

  void _openSellerMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SellerMenuTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: _sellerSection == SellerMenuSection.settings,
                onTap: () => _selectSellerSection(SellerMenuSection.settings),
              ),
              SellerMenuTile(
                icon: Icons.sync,
                label: 'Product sync',
                selected: _sellerSection == SellerMenuSection.productSync,
                onTap: () => _selectSellerSection(SellerMenuSection.productSync),
              ),
              SellerMenuTile(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                selected: _sellerSection == SellerMenuSection.analytics,
                onTap: () => _selectSellerSection(SellerMenuSection.analytics),
              ),
              SellerMenuTile(
                icon: Icons.rocket_launch_outlined,
                label: 'Growth & monetization',
                selected: _sellerSection == SellerMenuSection.growth,
                onTap: () => _selectSellerSection(SellerMenuSection.growth),
              ),
              SellerMenuTile(
                icon: Icons.tune_outlined,
                label: 'Operations',
                selected: _sellerSection == SellerMenuSection.operations,
                onTap: () => _selectSellerSection(SellerMenuSection.operations),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _selectSellerSection(SellerMenuSection section) {
    Navigator.pop(context);
    setState(() => _sellerSection = section);
  }

  Future<void> _createCampaign(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before creating campaigns.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createCampaign(shopId, payload);
      await _loadSellerGrowth();
      _showSellerSnack('Campaign created');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not create campaign');
    }
  }

  Future<void> _createPlacement(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before creating placements.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createPlacement(shopId, payload);
      await _loadSellerGrowth();
      _showSellerSnack('Featured placement created');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not create placement');
    }
  }

  Future<void> _updateSellerOrderStatus(SellerOrder order, String status) async {
    if (soukApiUrl.isEmpty || order.id.isEmpty) {
      _showSellerSnack('Connect the backend before updating orders.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).updateOrderStatus(order.id, status);
      await _loadSellerOrders();
      _showSellerSnack('Order updated to $status');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not update order');
    }
  }

  Future<void> _generateProductCopy() async {
    final product = _syncedProducts.isEmpty ? null : _syncedProducts.first;
    if (soukApiUrl.isEmpty || product == null) {
      _showSellerSnack('Sync products first, then generate product copy.');
      return;
    }
    try {
      final copy = await SoukApi(baseUrl: soukApiUrl).generateProductCopy({
        'productName': product.name,
        'category': product.category,
        'tone': 'premium and local',
        'keywords': product.collections.join(', '),
      });
      if (!mounted) {
        return;
      }
      await showGeneratedCopyDialog(context, 'Product description', copy);
    } catch (_) {
      _showSellerSnack('Could not generate product copy');
    }
  }

  Future<void> _generateAdCopy() async {
    if (soukApiUrl.isEmpty) {
      _showSellerSnack('Connect the backend before generating ads.');
      return;
    }
    try {
      final copy = await SoukApi(baseUrl: soukApiUrl).generateAdCopy({
        'storeName': widget.session.store?.name ?? 'Your store',
        'offer': 'new arrivals and limited stock',
        'channel': 'instagram',
      });
      if (!mounted) {
        return;
      }
      await showGeneratedCopyDialog(
        context,
        copy['headline'] as String? ?? 'Ad copy',
        copy['caption'] as String? ?? '',
      );
    } catch (_) {
      _showSellerSnack('Could not generate ad copy');
    }
  }

  Future<void> _createDeliveryRegion(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before adding delivery regions.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createDeliveryRegion(shopId, payload);
      _showSellerSnack('Delivery region saved');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not save delivery region');
    }
  }

  Future<void> _createLiveEvent(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before scheduling live selling.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createLiveEvent(shopId, payload);
      _showSellerSnack('Live selling event scheduled');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not schedule live event');
    }
  }

  Future<void> _createAffiliateLink(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before adding affiliates.');
      return;
    }
    try {
      await SoukApi(baseUrl: soukApiUrl).createAffiliateLink(shopId, payload);
      _showSellerSnack('Affiliate link created');
    } on SoukApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not create affiliate link');
    }
  }

  void _showSellerSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleFeaturedProduct(SellerInventoryProduct product) async {
    try {
      await SoukApi(baseUrl: soukApiUrl).setProductFeatured(product.id, !product.featured);
      await _loadSellerInventory();
    } on SoukApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store =
        _liveStore ??
        widget.session.store ??
        const ShopDraft(
          name: 'My Souk Store',
          category: 'Store',
          city: 'Beirut',
          hasDelivery: true,
          status: 'DRAFT',
        );
    final productCount = _syncedProducts.length;
    final orderRevenue = _sellerOrders.fold<double>(
      0,
      (sum, order) => sum + order.total,
    );
    final dashboardRevenue = _growthStats.revenue == 0 ? orderRevenue : _growthStats.revenue;
    final dashboardGrowthStats = _growthStats.copyWith(revenue: dashboardRevenue);
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
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Seller menu',
              onPressed: _openSellerMenu,
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: 10),
            Expanded(child: HeaderBar(session: widget.session, onLogout: widget.onLogout)),
          ],
        ),
        const SizedBox(height: 18),
        const SellerHero(),
        const SizedBox(height: 16),
        SellerStoreCard(store: store, ownerName: widget.session.name),
        const SizedBox(height: 16),
        if (_sellerSection == SellerMenuSection.settings)
          StoreOnboardingPanel(store: store, onSave: _saveStoreProfile),
        if (_sellerSection == SellerMenuSection.productSync) ...[
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
              message: 'Sync Shopify products after Scalora admin approves your store.',
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
              SellerInventoryTile(
                product: product,
                onToggleFeatured: () => _toggleFeaturedProduct(product),
              ),
          ],
        ],
        if (_sellerSection == SellerMenuSection.analytics)
          SellerMetricGrid(
            productCount: productCount,
            collectionCount: _syncedCollections.length,
            orderCount: _sellerOrders.length,
            revenue: dashboardRevenue,
            rating: _growthStats.rating,
          ),
        if (_sellerSection == SellerMenuSection.growth)
          SellerFeatureSuite(
            productCount: productCount,
            orderCount: _sellerOrders.length,
            growthStats: dashboardGrowthStats,
            synced: _shopifySynced,
            products: _syncedProducts,
          onCreateCampaign: _createCampaign,
          onCreatePlacement: _createPlacement,
          onCreateAffiliateLink: _createAffiliateLink,
        ),
        if (_sellerSection == SellerMenuSection.operations) ...[
          DeliveryRulesPanel(onCreateDeliveryRule: _createDeliveryRegion),
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
            for (final order in _sellerOrders)
              SellerOrderTile(
                order: order,
                onStatusChanged: (status) => _updateSellerOrderStatus(order, status),
              ),
        ],
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
    return role == AccountRole.seller
        ? 'Store account'
        : role == AccountRole.admin
        ? 'Admin account'
        : 'Customer account';
  }
}

class ChoiceCardButton extends StatelessWidget {
  const ChoiceCardButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.black.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerMenuTile extends StatelessWidget {
  const SellerMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: selected ? const Icon(Icons.check_circle) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}

class SoukShopperTopBar extends StatelessWidget {
  const SoukShopperTopBar({
    super.key,
    required this.cartCount,
    required this.onCartTap,
  });

  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Souk',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3B2114),
                  letterSpacing: 0,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none, size: 30),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Cart',
          onPressed: onCartTap,
          icon: Badge.count(
            count: cartCount,
            isLabelVisible: cartCount > 0,
            backgroundColor: const Color(0xFFA8663A),
            child: const Icon(Icons.shopping_cart_outlined, size: 30),
          ),
        ),
      ],
    );
  }
}

class SoukSearchRow extends StatelessWidget {
  const SoukSearchRow({
    super.key,
    required this.value,
    required this.filters,
    required this.options,
    required this.onChanged,
    required this.onFiltersChanged,
  });

  final String value;
  final MarketplaceFilters filters;
  final MarketplaceFilterOptions options;
  final ValueChanged<String> onChanged;
  final ValueChanged<MarketplaceFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search for products, brands and more...',
                prefixIcon: Icon(Icons.search, size: 28),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Filters',
            onPressed: () async {
              final nextFilters = await showModalBottomSheet<MarketplaceFilters>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => MarketplaceFilterSheet(
                  initialFilters: filters,
                  options: options,
                ),
              );
              if (nextFilters != null) {
                onFiltersChanged(nextFilters);
              }
            },
            icon: Badge(
              isLabelVisible: filters.hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.tune, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class SoukCategoryBubbles extends StatelessWidget {
  const SoukCategoryBubbles({
    super.key,
    required this.selected,
    required this.categories,
    required this.products,
    required this.onSelected,
  });

  final String selected;
  final List<String> categories;
  final List<Product> products;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = ['All', ...categories.take(4), 'More'];
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final name = visible[index];
          final target = name == 'More' ? 'All' : name;
          final selectedItem = selected == target || (selected == 'All' && name == 'All');
          final product = firstWhereOrNull(
            products,
            (item) => target == 'All' || item.category == target || item.collectionNames.contains(target),
          );
          return SoukCategoryBubble(
            name: shopperCategoryLabel(name),
            selected: selectedItem,
            product: product,
            icon: categoryIcon(name),
            onTap: () => onSelected(target),
          );
        },
      ),
    );
  }
}

class SoukCategoryBubble extends StatelessWidget {
  const SoukCategoryBubble({
    super.key,
    required this.name,
    required this.selected,
    required this.product,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final Product? product;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(34),
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: selected ? 94 : 72,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFA8663A) : Colors.white,
                borderRadius: BorderRadius.circular(selected ? 28 : 999),
                border: Border.all(color: const Color(0xFFA8663A).withValues(alpha: selected ? 1 : 0.08)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipOval(
                  child: Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFF4EEE7),
                    child: productPrimaryImage(product) == null
                        ? Icon(icon, color: const Color(0xFF3B2114), size: 30)
                        : AppNetworkImage(
                            url: productPrimaryImage(product)!,
                            size: 160,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFFA8663A) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoukPromoBanner extends StatelessWidget {
  const SoukPromoBanner({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final image = productPrimaryImage(products.isEmpty ? null : products.first);
    return Container(
      height: 255,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9DED0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            left: 165,
            child: image == null
                ? Container(
                    color: const Color(0xFFD7C2AA),
                    alignment: Alignment.center,
                    child: const Icon(Icons.chair_outlined, size: 88, color: Color(0xFF7A4B2A)),
                  )
                : AppNetworkImage(url: image, size: 640),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'WELCOME TO SOUK',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything you need, in one place.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'serif',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.08,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover quality products from trusted local sellers.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8F552E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {},
                    label: const Text('Shop Now'),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SoukDot(active: true),
                SoukDot(active: false),
                SoukDot(active: false),
                SoukDot(active: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SoukDot extends StatelessWidget {
  const SoukDot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 8 : 7,
      height: active ? 8 : 7,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active ? Colors.black : Colors.black.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SoukSectionHeader extends StatelessWidget {
  const SoukSectionHeader({
    super.key,
    required this.title,
    this.icon,
    required this.onViewAll,
  });

  final String title;
  final IconData? icon;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, color: const Color(0xFFC8673A), size: 22),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onViewAll,
          label: const Text('View all'),
          icon: const Icon(Icons.chevron_right),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF8F552E)),
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
        color: const Color(0xFF17382B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white.withValues(alpha: 0.08),
              size: 86,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HeroPill(icon: Icons.flash_on, label: 'New drops'),
                  HeroPill(icon: Icons.verified, label: 'Verified shops'),
                  HeroPill(icon: Icons.shopping_bag, label: 'One basket'),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Your local marketplace, dressed up for fast discovery.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Search live products, save pieces you love, and checkout from multiple stores without hopping between websites.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ShopperPulseStrip extends StatelessWidget {
  const ShopperPulseStrip({
    super.key,
    required this.shopCount,
    required this.productCount,
    required this.availableCount,
    required this.savedCount,
  });

  final int shopCount;
  final int productCount;
  final int availableCount;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ShopperPulseTile(
            icon: Icons.storefront,
            value: shopCount.toString(),
            label: 'shops',
            color: const Color(0xFF1F7A4D),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShopperPulseTile(
            icon: Icons.inventory_2_outlined,
            value: productCount.toString(),
            label: 'items',
            color: const Color(0xFFC8673A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShopperPulseTile(
            icon: Icons.check_circle_outline,
            value: availableCount.toString(),
            label: 'in stock',
            color: const Color(0xFF357C83),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShopperPulseTile(
            icon: Icons.favorite_border,
            value: savedCount.toString(),
            label: 'saved',
            color: const Color(0xFFE7A72E),
          ),
        ),
      ],
    );
  }
}

class ShopperPulseTile extends StatelessWidget {
  const ShopperPulseTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54),
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
  const SearchField({
    super.key,
    required this.value,
    required this.filters,
    required this.options,
    required this.onChanged,
    required this.onFiltersChanged,
  });

  final String value;
  final MarketplaceFilters filters;
  final MarketplaceFilterOptions options;
  final ValueChanged<String> onChanged;
  final ValueChanged<MarketplaceFilters> onFiltersChanged;

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
          onPressed: () async {
            final nextFilters = await showModalBottomSheet<MarketplaceFilters>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => MarketplaceFilterSheet(
                initialFilters: filters,
                options: options,
              ),
            );
            if (nextFilters != null) {
              onFiltersChanged(nextFilters);
            }
          },
          icon: Badge(
            isLabelVisible: filters.hasActiveFilters,
            smallSize: 8,
            child: const Icon(Icons.tune),
          ),
        ),
      ),
    );
  }
}

class MarketplaceFilterSheet extends StatefulWidget {
  const MarketplaceFilterSheet({
    super.key,
    required this.initialFilters,
    required this.options,
  });

  final MarketplaceFilters initialFilters;
  final MarketplaceFilterOptions options;

  @override
  State<MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<MarketplaceFilterSheet> {
  late MarketplaceFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _filters = const MarketplaceFilters()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductSort>(
                initialValue: _filters.sort,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  prefixIcon: Icon(Icons.sort),
                ),
                items: const [
                  DropdownMenuItem(value: ProductSort.featured, child: Text('Featured first')),
                  DropdownMenuItem(value: ProductSort.newest, child: Text('Newest')),
                  DropdownMenuItem(value: ProductSort.priceLow, child: Text('Price: low to high')),
                  DropdownMenuItem(value: ProductSort.priceHigh, child: Text('Price: high to low')),
                  DropdownMenuItem(value: ProductSort.rating, child: Text('Highest rated')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _filters = _filters.copyWith(sort: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _filters.city,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All locations'),
                  ),
                  for (final city in widget.options.cities)
                    DropdownMenuItem<String?>(value: city, child: Text(city)),
                ],
                onChanged: (value) => setState(
                  () => _filters = _filters.copyWith(
                    city: value,
                    clearCity: value == null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _filters.minPrice?.toStringAsFixed(0),
                      decoration: const InputDecoration(
                        labelText: 'Min price',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        setState(
                          () => _filters = _filters.copyWith(
                            minPrice: parsed,
                            clearMinPrice: value.trim().isEmpty,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _filters.maxPrice?.toStringAsFixed(0),
                      decoration: const InputDecoration(
                        labelText: 'Max price',
                        prefixIcon: Icon(Icons.price_change_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        setState(
                          () => _filters = _filters.copyWith(
                            maxPrice: parsed,
                            clearMaxPrice: value.trim().isEmpty,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In stock only'),
                value: _filters.inStockOnly,
                onChanged: (value) => setState(
                  () => _filters = _filters.copyWith(inStockOnly: value),
                ),
              ),
              FilterWrap(
                title: 'Sizes',
                values: widget.options.sizes,
                selected: _filters.size,
                onSelected: (value) => setState(
                  () => _filters = _filters.copyWith(
                    size: value,
                    clearSize: value == null,
                  ),
                ),
              ),
              FilterWrap(
                title: 'Colors',
                values: widget.options.colors,
                selected: _filters.color,
                onSelected: (value) => setState(
                  () => _filters = _filters.copyWith(
                    color: value,
                    clearColor: value == null,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _filters),
                  icon: const Icon(Icons.check),
                  label: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterWrap extends StatelessWidget {
  const FilterWrap({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: selected == null,
                showCheckmark: false,
                label: const Text('All'),
                onSelected: (_) => onSelected(null),
              ),
              for (final value in values)
                FilterChip(
                  selected: selected == value,
                  showCheckmark: false,
                  label: Text(value),
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
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

class ShopperEditorialBand extends StatelessWidget {
  const ShopperEditorialBand({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final topCategory = products.isEmpty
        ? 'New arrivals'
        : mostCommon(products.map((product) => product.category));
    final topStore = products.isEmpty
        ? 'Verified stores'
        : mostCommon(products.map((product) => product.shop.name));
    final limitedCount = products.where((product) => product.stock > 0 && product.stock <= 5).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7A72E).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF7A4F00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Curated live picks from $topStore',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EditorialMetric(
                  label: 'limited stock',
                  value: limitedCount.toString(),
                  icon: Icons.hourglass_bottom,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EditorialMetric(
                  label: 'price range',
                  value: products.isEmpty ? '\$0' : '${money(lowestPrice(products))}+',
                  icon: Icons.sell_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditorialMetric extends StatelessWidget {
  const EditorialMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1F7A4D)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketplaceDiscoveryPanel extends StatelessWidget {
  const MarketplaceDiscoveryPanel({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final sections = [
      DiscoveryItem('Trending', Icons.trending_up, '${products.where((product) => product.featured).length} featured'),
      DiscoveryItem('New arrivals', Icons.new_releases_outlined, '${products.length} live'),
      DiscoveryItem('Best sellers', Icons.workspace_premium_outlined, 'High intent'),
      DiscoveryItem('Local brands', Icons.location_city_outlined, '${products.map((product) => product.shop.id).toSet().length} stores'),
      const DiscoveryItem('Sneakers', Icons.directions_run, 'Size filters'),
      const DiscoveryItem('Jewelry', Icons.diamond_outlined, 'Gift ready'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Discover', action: 'Social marketplace'),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 142,
              child: DiscoveryCard(item: sections[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class ShopperGrowthPanel extends StatelessWidget {
  const ShopperGrowthPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rewards and social shopping',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FeaturePill(icon: Icons.favorite_border, label: 'Likes'),
                FeaturePill(icon: Icons.bookmark_border, label: 'Save products'),
                FeaturePill(icon: Icons.storefront_outlined, label: 'Follow stores'),
                FeaturePill(icon: Icons.reviews_outlined, label: 'Verified reviews'),
                FeaturePill(icon: Icons.card_giftcard, label: 'Loyalty points'),
                FeaturePill(icon: Icons.notifications_active_outlined, label: 'Drop alerts'),
                FeaturePill(icon: Icons.video_collection_outlined, label: 'Stories and reels'),
                FeaturePill(icon: Icons.verified_outlined, label: 'Trust badges'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({super.key, required this.item});

  final DiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class FeaturePill extends StatelessWidget {
  const FeaturePill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
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
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (product.shop.verified) ...[
                          const Icon(Icons.verified, size: 15, color: Color(0xFF1F7A4D)),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF1F7A4D),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.star,
                          size: 15,
                          color: Color(0xFFE7A72E),
                        ),
                        const SizedBox(width: 4),
                        Text(product.rating.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          product.stock > 0 ? Icons.inventory_2_outlined : Icons.block,
                          size: 15,
                          color: product.stock > 0 ? Colors.black54 : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.stock > 0 ? '${product.stock} left' : 'Out of stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: product.stock > 0 ? Colors.black54 : Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
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
                          onPressed: product.stock <= 0 ? null : onAdd,
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
      aspectRatio: 1,
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
                  : AppNetworkImage(
                      url: product.imageUrl!,
                      size: 360,
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

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.size,
    this.errorBuilder,
  });

  final String url;
  final int size;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      optimizedImageUrl(url, size),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: size,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: const Color(0xFFE7F0EA),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: errorBuilder,
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
    required this.onFollow,
  });

  final Shop shop;
  final List<Product> products;
  final Set<String> favoriteIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;
  final VoidCallback onFollow;

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
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Follow store',
                  onPressed: onFollow,
                  icon: const Icon(Icons.add_alert_outlined),
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
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      product.imageUrl == null
                          ? Container(
                              color: product.color,
                              child: Icon(product.icon, color: Colors.white, size: 34),
                            )
                          : AppNetworkImage(url: product.imageUrl!, size: 260),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton.filledTonal(
                          tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                          onPressed: onFavorite,
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: Text(product.formattedPrice)),
                  IconButton.filledTonal(
                    tooltip: 'Add to basket',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoukDealCard extends StatelessWidget {
  const SoukDealCard({
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
    final oldPrice = product.price * 1.25;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: productPrimaryImage(product) == null
                        ? Container(
                            color: const Color(0xFFF2EAE1),
                            alignment: Alignment.center,
                            child: Icon(product.icon, size: 54, color: const Color(0xFF8F552E)),
                          )
                        : AppNetworkImage(url: productPrimaryImage(product)!, size: 360),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA8663A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '-20%',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                      onPressed: onFavorite,
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              product.formattedPrice,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              money(oldPrice),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black45,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.star, color: Color(0xFFE7A72E), size: 18),
                      const SizedBox(width: 3),
                      Text(product.rating.toStringAsFixed(1)),
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

class SoukPopularCategoryTile extends StatelessWidget {
  const SoukPopularCategoryTile({
    super.key,
    required this.name,
    required this.products,
    required this.onTap,
  });

  final String name;
  final List<Product> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = products.isEmpty ? null : products.first;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF2EAE1),
                child: productPrimaryImage(product) == null
                    ? Icon(categoryIcon(name), color: const Color(0xFF8F552E), size: 42)
                    : AppNetworkImage(url: productPrimaryImage(product)!, size: 260),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  Text(
                    shopperCategoryLabel(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${products.length}+ items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
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

class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAddToCart,
    required this.onReview,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;
  final void Function(int rating, String comment) onReview;

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class TrustAndReviewStrip extends StatelessWidget {
  const TrustAndReviewStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8F4EC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: Color(0xFF1F7A4D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verified purchase reviews, return policy, and dealer badges help shoppers buy with confidence.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  ProductVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = firstWhereOrNull(widget.product.variants, (variant) => variant.stock > 0) ??
        (widget.product.variants.isEmpty ? null : widget.product.variants.first);
  }

  Future<void> _openWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hi ${widget.product.shop.name}, I am interested in ${widget.product.name} on Souk.',
    );
    final url = Uri.parse('https://wa.me/?text=$message');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _openReviewDialog() {
    showReviewDialog(context, widget.onReview);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.product.images.isEmpty
                    ? Container(
                        color: widget.product.color.withValues(alpha: 0.15),
                        child: Icon(widget.product.icon, color: widget.product.color, size: 78),
                      )
                    : PageView(
                        children: [
                          for (final image in widget.product.images)
                            AppNetworkImage(url: image, size: 900),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: widget.isFavorite ? 'Remove favorite' : 'Save favorite',
                  onPressed: widget.onFavorite,
                  icon: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.product.shop.name} - ${widget.product.category}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(widget.product.description),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(label: '${widget.product.rating.toStringAsFixed(1)} rating'),
                Tag(label: '${widget.product.stock} in stock'),
                Tag(label: widget.product.shop.delivery),
                const Tag(label: 'Verified store'),
                const Tag(label: 'Authenticity badge'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const TrustAndReviewStrip(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openReviewDialog,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Review this store'),
              ),
            ),
            if (widget.product.variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Variants', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in widget.product.variants)
                    ChoiceChip(
                      selected: _selectedVariant?.title == variant.title,
                      onSelected: variant.stock == 0 ? null : (_) => setState(() => _selectedVariant = variant),
                      label: Text(
                        '${variant.title} (${variant.stock})',
                        style: TextStyle(
                          decoration: variant.stock == 0 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    money(_selectedVariant?.price ?? widget.product.price),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: (_selectedVariant?.stock ?? widget.product.stock) == 0 ? null : widget.onAddToCart,
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
    final active = store.isActive;
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
                      Tag(label: active ? 'Active store' : store.statusDisplay),
                      if (store.verified) const Tag(label: 'Verified'),
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

class StoreOnboardingPanel extends StatefulWidget {
  const StoreOnboardingPanel({
    super.key,
    required this.store,
    required this.onSave,
  });

  final ShopDraft store;
  final Future<void> Function(Map<String, dynamic> payload) onSave;

  @override
  State<StoreOnboardingPanel> createState() => _StoreOnboardingPanelState();
}

class _StoreOnboardingPanelState extends State<StoreOnboardingPanel> {
  final _primaryColor = TextEditingController(text: '#1F7A4D');
  final _accentColor = TextEditingController(text: '#E7A72E');
  final _instagramUrl = TextEditingController();
  final _whatsappPhone = TextEditingController();
  final _shippingPolicy = TextEditingController(text: 'Delivery available in selected regions.');
  final _returnPolicy = TextEditingController(text: 'Returns accepted according to store policy.');
  String? _logoDataUrl;
  String? _bannerDataUrl;
  bool _logoUploaded = false;
  bool _bannerUploaded = false;
  bool _saved = false;

  @override
  void dispose() {
    _primaryColor.dispose();
    _accentColor.dispose();
    _instagramUrl.dispose();
    _whatsappPhone.dispose();
    _shippingPolicy.dispose();
    _returnPolicy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final whatsapp = normalizeLebanesePhone(_whatsappPhone.text);
    if (_whatsappPhone.text.trim().isNotEmpty && whatsapp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use a Lebanese WhatsApp number, like 03 123 456 or +961 3 123 456'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await widget.onSave({
      'logoUrl': _logoDataUrl,
      'bannerUrl': _bannerDataUrl,
      'primaryColor': nullableText(_primaryColor.text),
      'accentColor': nullableText(_accentColor.text),
      'instagramUrl': nullableText(_instagramUrl.text),
      'whatsappPhone': whatsapp,
      'shippingPolicy': nullableText(_shippingPolicy.text),
      'returnPolicy': nullableText(_returnPolicy.text),
    });
    if (mounted) {
      setState(() => _saved = true);
    }
  }

  Future<void> _pickStoreImage({required bool logo}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: logo ? 512 : 1400,
      imageQuality: 70,
    );
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    setState(() {
      if (logo) {
        _logoDataUrl = dataUrl;
        _logoUploaded = true;
      } else {
        _bannerDataUrl = dataUrl;
        _bannerUploaded = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      OnboardingItem('Logo and banner', Icons.image_outlined, 'Upload brand visuals', _saved && _logoUploaded && _bannerUploaded),
      OnboardingItem('Theme colors', Icons.palette_outlined, 'Choose storefront colors', _saved && _primaryColor.text.trim().isNotEmpty && _accentColor.text.trim().isNotEmpty),
      OnboardingItem('Social links', Icons.link, 'Instagram, TikTok, website', _saved && _instagramUrl.text.trim().isNotEmpty),
      OnboardingItem('Shipping policy', Icons.local_shipping_outlined, widget.store.hasDelivery ? 'Delivery active' : 'Pickup setup', _saved && _shippingPolicy.text.trim().isNotEmpty),
      OnboardingItem('Return policy', Icons.assignment_return_outlined, 'Set clear rules', _saved && _returnPolicy.text.trim().isNotEmpty),
      OnboardingItem('WhatsApp contact', Icons.chat_outlined, 'Support and order chat', _saved && normalizeLebanesePhone(_whatsappPhone.text) != null),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store onboarding',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Build a mini storefront inside Souk without building a separate app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            for (final item in items) SetupRow(item: item),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStoreImage(logo: true),
                    icon: Icon(_logoUploaded ? Icons.check_circle : Icons.upload_file),
                    label: Text(_logoUploaded ? 'Logo uploaded' : 'Upload logo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStoreImage(logo: false),
                    icon: Icon(_bannerUploaded ? Icons.check_circle : Icons.upload_file),
                    label: Text(_bannerUploaded ? 'Banner uploaded' : 'Upload banner'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ColorSwatchPicker(
              label: 'Primary color',
              controller: _primaryColor,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            ColorSwatchPicker(
              label: 'Accent color',
              controller: _accentColor,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instagramUrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Instagram URL',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _whatsappPhone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Lebanese WhatsApp number',
                hintText: '+961 3 123 456',
                prefixIcon: Icon(Icons.chat_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _shippingPolicy,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Shipping policy',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _returnPolicy,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Return policy',
                prefixIcon: Icon(Icons.assignment_return_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save store settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerFeatureSuite extends StatelessWidget {
  const SellerFeatureSuite({
    super.key,
    required this.productCount,
    required this.orderCount,
    required this.growthStats,
    required this.synced,
    required this.products,
    required this.onCreateCampaign,
    required this.onCreatePlacement,
    required this.onCreateAffiliateLink,
  });

  final int productCount;
  final int orderCount;
  final SellerGrowthStats growthStats;
  final bool synced;
  final List<SellerInventoryProduct> products;
  final ValueChanged<Map<String, dynamic>> onCreateCampaign;
  final ValueChanged<Map<String, dynamic>> onCreatePlacement;
  final ValueChanged<Map<String, dynamic>> onCreateAffiliateLink;

  @override
  Widget build(BuildContext context) {
    final conversion = growthStats.views == 0
        ? '0.0%'
        : '${((growthStats.orders / growthStats.views) * 100).toStringAsFixed(1)}%';
    return Column(
      children: [
        SellerDashboardPanel(
          title: 'Growth and monetization',
          icon: Icons.rocket_launch_outlined,
          accent: const Color(0xFFC8673A),
          children: [
            FeaturePill(icon: synced ? Icons.check_circle : Icons.sync, label: synced ? 'Shopify live' : 'Shopify sync'),
            FeaturePill(icon: Icons.star_border, label: '${growthStats.placements} placements'),
            FeaturePill(icon: Icons.ads_click, label: '${growthStats.campaigns} campaigns'),
            const FeaturePill(icon: Icons.workspace_premium_outlined, label: 'Subscriptions'),
            const FeaturePill(icon: Icons.verified_user_outlined, label: 'Store verification'),
            const FeaturePill(icon: Icons.loyalty_outlined, label: 'Coupons and VIP tiers'),
            FeaturePill(icon: Icons.percent, label: 'Conversion $conversion'),
          ],
          actions: [
            OutlinedButton.icon(
              onPressed: () => showCampaignDialog(context, onCreateCampaign),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('New campaign'),
            ),
            OutlinedButton.icon(
              onPressed: () => showAffiliateDialog(context, onCreateAffiliateLink),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Add affiliate'),
            ),
            OutlinedButton.icon(
              onPressed: products.isEmpty
                  ? null
                  : () => showPlacementDialog(
                        context,
                        products,
                        onCreatePlacement,
                      ),
              icon: const Icon(Icons.star_border),
              label: const Text('Buy placement'),
            ),
          ],
        ),
      ],
    );
  }
}

class DeliveryRulesPanel extends StatelessWidget {
  const DeliveryRulesPanel({
    super.key,
    required this.onCreateDeliveryRule,
  });

  final ValueChanged<Map<String, dynamic>> onCreateDeliveryRule;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardPanel(
      title: 'Delivery rules',
      icon: Icons.delivery_dining,
      accent: const Color(0xFF1F7A4D),
      children: const [
        FeaturePill(icon: Icons.place_outlined, label: 'By region'),
        FeaturePill(icon: Icons.price_change_outlined, label: 'By item price'),
        FeaturePill(icon: Icons.add_circle_outline, label: 'Multiple rules'),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: () => showDeliveryRuleDialog(context, onCreateDeliveryRule),
          icon: const Icon(Icons.add),
          label: const Text('Add delivery rule'),
        ),
      ],
    );
  }
}

class SellerDashboardPanel extends StatelessWidget {
  const SellerDashboardPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;
  final List<Widget> actions;

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
                  backgroundColor: accent.withValues(alpha: 0.16),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: children),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class SetupRow extends StatelessWidget {
  const SetupRow({super.key, required this.item});

  final OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            item.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.completed ? const Color(0xFF1F7A4D) : Colors.black38,
          ),
        ],
      ),
    );
  }
}

class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  static const swatches = {
    '#1F7A4D': Color(0xFF1F7A4D),
    '#E7A72E': Color(0xFFE7A72E),
    '#C8673A': Color(0xFFC8673A),
    '#357C83': Color(0xFF357C83),
    '#17211B': Color(0xFF17211B),
    '#8B2F5A': Color(0xFF8B2F5A),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in swatches.entries)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  controller.text = entry.key;
                  onChanged();
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: entry.value,
                  child: controller.text == entry.key
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: '$label number',
            prefixIcon: const Icon(Icons.tag),
          ),
        ),
      ],
    );
  }
}

class MiniMetric extends StatelessWidget {
  const MiniMetric(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 98,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
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
    required this.orderCount,
    required this.revenue,
    required this.rating,
  });

  final int productCount;
  final int collectionCount;
  final int orderCount;
  final double revenue;
  final double rating;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      SellerMetric('Orders', orderCount.toString(), Icons.receipt_long),
      SellerMetric('Products', productCount.toString(), Icons.inventory_2),
      SellerMetric('Collections', collectionCount.toString(), Icons.category),
      SellerMetric('Revenue', money(revenue), Icons.payments_outlined),
      SellerMetric('Rating', rating == 0 ? 'No reviews' : rating.toStringAsFixed(1), Icons.star),
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
  const SellerInventoryTile({
    super.key,
    required this.product,
    required this.onToggleFeatured,
  });

  final SellerInventoryProduct product;
  final VoidCallback onToggleFeatured;

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
                      optimizedImageUrl(product.imageUrl!, 160),
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: product.featured ? 'Remove from featured' : 'Feature product',
                  onPressed: onToggleFeatured,
                  icon: Icon(product.featured ? Icons.star : Icons.star_border),
                ),
                Text(
                  money(product.price),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SellerOrderTile extends StatelessWidget {
  const SellerOrderTile({
    super.key,
    required this.order,
    required this.onStatusChanged,
  });

  final SellerOrder order;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
        title: Text(
          order.customer,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${order.summary} - ${money(order.total)}'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Update status',
          onSelected: onStatusChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'ACCEPTED', child: Text('Accept')),
            PopupMenuItem(value: 'PACKING', child: Text('Packing')),
            PopupMenuItem(value: 'READY', child: Text('Ready')),
            PopupMenuItem(value: 'OUT_FOR_DELIVERY', child: Text('Out for delivery')),
            PopupMenuItem(value: 'DELIVERED', child: Text('Delivered')),
            PopupMenuItem(value: 'CANCELLED', child: Text('Cancel')),
          ],
          child: Chip(label: Text(order.status)),
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
    required this.verified,
    required this.statusLabel,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Store';
    return Shop(
      id: json['id'] as String? ?? '',
      name: name,
      category: json['category'] as String? ?? 'Store',
      location: json['city'] as String? ?? '',
      story: json['story'] as String? ?? 'Shop products directly from this Souk store.',
      rating: parseDouble(json['rating']),
      color: const Color(0xFF1F7A4D),
      icon: Icons.storefront,
      delivery: json['deliveryLabel'] as String? ?? 'Delivery available',
      minimumOrder: parseDouble(json['minimumOrder']),
      orderCount: parseInt(json['orderCount']),
      verified: json['verified'] == true,
      statusLabel: json['status'] as String? ?? 'DRAFT',
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
  final bool verified;
  final String statusLabel;
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
    required this.collectionNames,
    required this.featured,
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
    final collectionNames = productCollectionNames(json);
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Product',
      category: json['category'] as String? ?? 'Shopify',
      price: parseDouble(json['price']),
      shop: Shop.fromJson(shopJson),
      color: const Color(0xFF1F7A4D),
      icon: Icons.inventory_2,
      description: json['description'] as String? ?? '',
      rating: parseDouble(json['rating']),
      stock: parseInt(json['stock']),
      imageUrl: json['imageUrl'] as String?,
      images: images.isEmpty && json['imageUrl'] != null ? [json['imageUrl'] as String] : images,
      variants: variants,
      collectionNames: collectionNames,
      featured: json['featured'] == true,
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
  final List<String> collectionNames;
  final bool featured;

  Set<String> get optionTokens {
    final tokens = <String>{};
    for (final variant in variants) {
      for (final value in variant.searchableOptions) {
        tokens.addAll(
          value
              .toLowerCase()
              .split(RegExp(r'[^a-z0-9]+'))
              .where((token) => token.isNotEmpty),
        );
      }
    }
    return tokens;
  }

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
    this.option1,
    this.option2,
    this.option3,
    this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      title: json['title'] as String? ?? 'Variant',
      price: parseDouble(json['price']),
      stock: parseInt(json['stock']),
      option1: json['option1'] as String?,
      option2: json['option2'] as String?,
      option3: json['option3'] as String?,
      sku: json['sku'] as String?,
    );
  }

  final String title;
  final double price;
  final int stock;
  final String? option1;
  final String? option2;
  final String? option3;
  final String? sku;

  Iterable<String> get searchableOptions sync* {
    for (final value in [title, option1, option2, option3]) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty && normalized.toLowerCase() != 'default title') {
        yield normalized;
      }
    }
  }
}

enum ProductSort { featured, newest, priceLow, priceHigh, rating }

class MarketplaceFilters {
  const MarketplaceFilters({
    this.size,
    this.color,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.sort = ProductSort.featured,
  });

  final String? size;
  final String? color;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final ProductSort sort;

  bool get hasActiveFilters =>
      size != null ||
      color != null ||
      city != null ||
      minPrice != null ||
      maxPrice != null ||
      inStockOnly ||
      sort != ProductSort.featured;

  MarketplaceFilters copyWith({
    String? size,
    String? color,
    String? city,
    double? minPrice,
    double? maxPrice,
    bool? inStockOnly,
    ProductSort? sort,
    bool clearSize = false,
    bool clearColor = false,
    bool clearCity = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return MarketplaceFilters(
      size: clearSize ? null : size ?? this.size,
      color: clearColor ? null : color ?? this.color,
      city: clearCity ? null : city ?? this.city,
      minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      sort: sort ?? this.sort,
    );
  }

  bool matches(Product product) {
    if (city != null && product.shop.location != city) {
      return false;
    }
    if (minPrice != null && product.price < minPrice!) {
      return false;
    }
    if (maxPrice != null && product.price > maxPrice!) {
      return false;
    }
    if (inStockOnly && product.stock <= 0 && !product.variants.any((variant) => variant.stock > 0)) {
      return false;
    }
    if (size != null && !product.optionTokens.any((token) => token == size!.toLowerCase())) {
      return false;
    }
    if (color != null && !product.optionTokens.any((token) => token == color!.toLowerCase())) {
      return false;
    }
    return true;
  }

  int compare(Product a, Product b) {
    switch (sort) {
      case ProductSort.newest:
        return 0;
      case ProductSort.priceLow:
        return a.price.compareTo(b.price);
      case ProductSort.priceHigh:
        return b.price.compareTo(a.price);
      case ProductSort.rating:
        return b.rating.compareTo(a.rating);
      case ProductSort.featured:
        if (a.featured != b.featured) {
          return a.featured ? -1 : 1;
        }
        return b.rating.compareTo(a.rating);
    }
  }
}

class MarketplaceFilterOptions {
  const MarketplaceFilterOptions({
    required this.sizes,
    required this.colors,
    required this.cities,
  });

  factory MarketplaceFilterOptions.fromProducts(List<Product> products) {
    const knownSizes = {
      'xs',
      's',
      'm',
      'l',
      'xl',
      'xxl',
      '36',
      '37',
      '38',
      '39',
      '40',
      '41',
      '42',
      '43',
      '44',
      '45',
    };
    const knownColors = {
      'black',
      'white',
      'red',
      'blue',
      'green',
      'yellow',
      'pink',
      'purple',
      'brown',
      'grey',
      'gray',
      'silver',
      'gold',
      'beige',
      'navy',
    };

    final sizes = <String>{};
    final colors = <String>{};
    final cities = <String>{};
    for (final product in products) {
      if (product.shop.location.isNotEmpty) {
        cities.add(product.shop.location);
      }
      for (final token in product.optionTokens) {
        if (knownSizes.contains(token)) {
          sizes.add(formatFilterLabel(token));
        }
        if (knownColors.contains(token)) {
          colors.add(formatFilterLabel(token));
        }
      }
    }

    return MarketplaceFilterOptions(
      sizes: sizes.toList()..sort(sortSizes),
      colors: colors.toList()..sort(),
      cities: cities.toList()..sort(),
    );
  }

  final List<String> sizes;
  final List<String> colors;
  final List<String> cities;
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
    this.verified = false,
    this.status = 'DRAFT',
  });

  factory ShopDraft.fromJson(Map<String, dynamic> json) {
    return ShopDraft(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'My Souk Store',
      category: json['category']?.toString() ?? 'Store',
      city: json['city']?.toString() ?? 'Beirut',
      hasDelivery: (json['deliveryLabel']?.toString() ?? '').isNotEmpty,
      verified: json['verified'] == true,
      status: json['status']?.toString() ?? 'DRAFT',
    );
  }

  final String? id;
  final String name;
  final String category;
  final String city;
  final bool hasDelivery;
  final bool verified;
  final String status;

  bool get isActive => status.toUpperCase() == 'ACTIVE' && verified;

  String get statusDisplay {
    return switch (status.toUpperCase()) {
      'ACTIVE' => 'Active store',
      'SUSPENDED' => 'Declined store',
      _ => 'Pending approval',
    };
  }
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
    required this.featured,
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
      featured: json['featured'] == true,
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
  final bool featured;
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

class SellerGrowthStats {
  const SellerGrowthStats({
    this.views = 0,
    this.clicks = 0,
    this.addToCarts = 0,
    this.orders = 0,
    this.revenue = 0,
    this.followers = 0,
    this.loyaltyAccounts = 0,
    this.campaigns = 0,
    this.placements = 0,
    this.rating = 0,
    this.topCity = '',
  });

  factory SellerGrowthStats.fromJson(Map<String, dynamic> json) {
    final analyticsRows = json['analytics'] as List<dynamic>? ?? const [];
    var views = 0;
    var clicks = 0;
    var addToCarts = 0;
    var orders = 0;
    var revenue = 0.0;
    var topCity = '';
    for (final row in analyticsRows) {
      final item = row as Map<String, dynamic>;
      views += parseInt(item['views']);
      clicks += parseInt(item['clicks']);
      addToCarts += parseInt(item['addToCarts']);
      orders += parseInt(item['orders']);
      revenue += parseDouble(item['revenue']);
      final city = item['topCity'] as String?;
      if (topCity.isEmpty && city != null && city.isNotEmpty) {
        topCity = city;
      }
    }
    return SellerGrowthStats(
      views: views,
      clicks: clicks,
      addToCarts: addToCarts,
      orders: orders,
      revenue: revenue,
      followers: parseInt(json['followers']),
      loyaltyAccounts: parseInt(json['loyaltyAccounts']),
      campaigns: (json['campaigns'] as List<dynamic>? ?? const []).length,
      placements: (json['placements'] as List<dynamic>? ?? const []).length,
      rating: parseDouble(json['rating']),
      topCity: topCity,
    );
  }

  final int views;
  final int clicks;
  final int addToCarts;
  final int orders;
  final double revenue;
  final int followers;
  final int loyaltyAccounts;
  final int campaigns;
  final int placements;
  final double rating;
  final String topCity;

  SellerGrowthStats copyWith({double? revenue}) {
    return SellerGrowthStats(
      views: views,
      clicks: clicks,
      addToCarts: addToCarts,
      orders: orders,
      revenue: revenue ?? this.revenue,
      followers: followers,
      loyaltyAccounts: loyaltyAccounts,
      campaigns: campaigns,
      placements: placements,
      rating: rating,
      topCity: topCity,
    );
  }
}

class SellerOrder {
  const SellerOrder(this.id, this.customer, this.summary, this.status, this.total);

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
      json['id'] as String? ?? '',
      (customer['name'] as String?) ?? (customer['email'] as String?) ?? 'Customer',
      summary,
      json['status'] as String? ?? 'PLACED',
      parseDouble(json['total']),
    );
  }

  final String id;
  final String customer;
  final String summary;
  final String status;
  final double total;
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

class DiscoveryItem {
  const DiscoveryItem(this.title, this.icon, this.subtitle);

  final String title;
  final IconData icon;
  final String subtitle;
}

class OnboardingItem {
  const OnboardingItem(this.title, this.icon, this.subtitle, this.completed);

  final String title;
  final IconData icon;
  final String subtitle;
  final bool completed;
}

Future<void> showCampaignDialog(
  BuildContext context,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final title = TextEditingController(text: 'New arrivals just dropped');
  final message = TextEditingController(text: 'Shop the latest products before they sell out.');
  var channel = 'PUSH';
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create campaign'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      prefixIcon: Icon(Icons.notifications_active_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PUSH', child: Text('Push')),
                      DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => channel = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: message,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  onSubmit({
                    'channel': channel,
                    'title': title.text.trim(),
                    'message': message.text.trim(),
                    'audience': 'followers',
                  });
                  Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  title.dispose();
  message.dispose();
}

Future<void> showPlacementDialog(
  BuildContext context,
  List<SellerInventoryProduct> products,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final title = TextEditingController(text: 'Featured homepage placement');
  final budget = TextEditingController(text: '25');
  var productId = products.first.id;
  var placement = 'home';
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create placement'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: productId,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      for (final product in products.take(50))
                        DropdownMenuItem(
                          value: product.id,
                          child: Text(product.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => productId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: placement,
                    decoration: const InputDecoration(
                      labelText: 'Placement',
                      prefixIcon: Icon(Icons.ads_click),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'home', child: Text('Homepage')),
                      DropdownMenuItem(value: 'search', child: Text('Search')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => placement = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: budget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  onSubmit({
                    'productId': productId,
                    'title': title.text.trim(),
                    'placement': placement,
                    'budget': double.tryParse(budget.text.trim()) ?? 0,
                    'status': 'ACTIVE',
                  });
                  Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  title.dispose();
  budget.dispose();
}

Future<void> showReviewDialog(
  BuildContext context,
  void Function(int rating, String comment) onSubmit,
) async {
  final comment = TextEditingController();
  var rating = 5;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Review store'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration: const InputDecoration(
                      labelText: 'Rating',
                      prefixIcon: Icon(Icons.star_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 stars')),
                      DropdownMenuItem(value: 4, child: Text('4 stars')),
                      DropdownMenuItem(value: 3, child: Text('3 stars')),
                      DropdownMenuItem(value: 2, child: Text('2 stars')),
                      DropdownMenuItem(value: 1, child: Text('1 star')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => rating = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      prefixIcon: Icon(Icons.rate_review_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  onSubmit(rating, comment.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
  comment.dispose();
}

Future<void> showGeneratedCopyDialog(
  BuildContext context,
  String title,
  String copy,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SelectableText(copy.isEmpty ? 'No copy generated.' : copy),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> showDeliveryRegionDialog(
  BuildContext context,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final name = TextEditingController(text: 'Beirut');
  final fee = TextEditingController(text: '3.5');
  final eta = TextEditingController(text: 'Same day');
  await showSimpleFormDialog(
    context: context,
    title: 'Add delivery region',
    fields: [
      DialogField(controller: name, label: 'Region', icon: Icons.place_outlined),
      DialogField(controller: fee, label: 'Fee', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
      DialogField(controller: eta, label: 'ETA', icon: Icons.schedule),
    ],
    onSubmit: () => onSubmit({
      'name': name.text.trim(),
      'fee': double.tryParse(fee.text.trim()) ?? 0,
      'eta': eta.text.trim(),
      'active': true,
    }),
  );
  name.dispose();
  fee.dispose();
  eta.dispose();
}

Future<void> showDeliveryRuleDialog(
  BuildContext context,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final region = TextEditingController(text: 'Beirut');
  final minPrice = TextEditingController(text: '0');
  final maxPrice = TextEditingController(text: '50');
  final fee = TextEditingController(text: '3.5');
  final eta = TextEditingController(text: 'Same day');
  var ruleType = 'REGION';
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final byPrice = ruleType == 'PRICE';
          return AlertDialog(
            title: const Text('Add delivery rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'REGION', icon: Icon(Icons.place_outlined), label: Text('Region')),
                      ButtonSegment(value: 'PRICE', icon: Icon(Icons.price_change_outlined), label: Text('Item price')),
                    ],
                    selected: {ruleType},
                    onSelectionChanged: (value) => setDialogState(() => ruleType = value.first),
                  ),
                  const SizedBox(height: 10),
                  if (!byPrice)
                    TextField(
                      controller: region,
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'From price'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxPrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'To price'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Delivery fee',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: eta,
                    decoration: const InputDecoration(
                      labelText: 'ETA',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  onSubmit({
                    'ruleType': ruleType,
                    'name': byPrice
                        ? 'Price ${minPrice.text.trim()}-${maxPrice.text.trim()}'
                        : region.text.trim(),
                    'minOrder': byPrice ? double.tryParse(minPrice.text.trim()) ?? 0 : null,
                    'maxOrder': byPrice ? double.tryParse(maxPrice.text.trim()) ?? 0 : null,
                    'fee': double.tryParse(fee.text.trim()) ?? 0,
                    'eta': eta.text.trim(),
                    'active': true,
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  region.dispose();
  minPrice.dispose();
  maxPrice.dispose();
  fee.dispose();
  eta.dispose();
}

Future<void> showLiveEventDialog(
  BuildContext context,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final title = TextEditingController(text: 'New arrivals live');
  final streamUrl = TextEditingController();
  await showSimpleFormDialog(
    context: context,
    title: 'Schedule live selling',
    fields: [
      DialogField(controller: title, label: 'Title', icon: Icons.live_tv_outlined),
      DialogField(controller: streamUrl, label: 'Stream URL', icon: Icons.link, keyboardType: TextInputType.url),
    ],
    onSubmit: () => onSubmit({
      'title': title.text.trim(),
      'startsAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'streamUrl': nullableText(streamUrl.text),
      'active': false,
    }),
  );
  title.dispose();
  streamUrl.dispose();
}

Future<void> showAffiliateDialog(
  BuildContext context,
  ValueChanged<Map<String, dynamic>> onSubmit,
) async {
  final creatorName = TextEditingController();
  final handle = TextEditingController();
  final code = TextEditingController(text: 'SOUK10');
  final commission = TextEditingController(text: '10');
  await showSimpleFormDialog(
    context: context,
    title: 'Add affiliate',
    fields: [
      DialogField(controller: creatorName, label: 'Creator name', icon: Icons.person_outline),
      DialogField(controller: handle, label: 'Handle', icon: Icons.alternate_email),
      DialogField(controller: code, label: 'Code', icon: Icons.confirmation_number_outlined),
      DialogField(controller: commission, label: 'Commission %', icon: Icons.percent, keyboardType: TextInputType.number),
    ],
    onSubmit: () => onSubmit({
      'creatorName': creatorName.text.trim(),
      'creatorHandle': nullableText(handle.text),
      'code': code.text.trim(),
      'commissionRate': double.tryParse(commission.text.trim()) ?? 10,
      'status': 'ACTIVE',
    }),
  );
  creatorName.dispose();
  handle.dispose();
  code.dispose();
  commission.dispose();
}

Future<void> showSimpleFormDialog({
  required BuildContext context,
  required String title,
  required List<DialogField> fields,
  required VoidCallback onSubmit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields) ...[
              TextField(
                controller: field.controller,
                keyboardType: field.keyboardType,
                decoration: InputDecoration(
                  labelText: field.label,
                  prefixIcon: Icon(field.icon),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            onSubmit();
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class DialogField {
  const DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
}

String? nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? normalizeLebanesePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+961')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('961')) {
    digits = '0${digits.substring(3)}';
  }
  digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  final valid = RegExp(r'^0(3[0-9]{6}|(70|71|76|78|79|81)[0-9]{6}|(1|4|5|6|7|8|9)[0-9]{6})$');
  if (!valid.hasMatch(digits)) {
    return null;
  }
  return '+961${digits.substring(1)}';
}

String money(double value) => '\$${value.toStringAsFixed(2)}';

String? productPrimaryImage(Product? product) {
  if (product == null) {
    return null;
  }
  if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
    return product.imageUrl;
  }
  if (product.images.isNotEmpty) {
    return product.images.first;
  }
  return null;
}

IconData categoryIcon(String value) {
  final name = value.toLowerCase();
  if (name.contains('fashion') || name.contains('clothing') || name.contains('apparel')) {
    return Icons.checkroom_outlined;
  }
  if (name.contains('electronic') || name.contains('tech')) {
    return Icons.headphones_outlined;
  }
  if (name.contains('beauty') || name.contains('skin')) {
    return Icons.spa_outlined;
  }
  if (name.contains('home') || name.contains('decor')) {
    return Icons.chair_outlined;
  }
  if (name.contains('bag')) {
    return Icons.work_outline;
  }
  if (name.contains('shoe') || name.contains('sneaker')) {
    return Icons.directions_run;
  }
  if (name.contains('jewel')) {
    return Icons.diamond_outlined;
  }
  if (name.contains('more')) {
    return Icons.grid_view;
  }
  return Icons.category_outlined;
}

String shopperCategoryLabel(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return 'All';
  }
  final lower = cleaned.toLowerCase();
  if (lower == 'all stock') {
    return 'All Stock';
  }
  if (lower.contains('apparel')) {
    return lower.contains('women') ? 'Women' : 'Apparel';
  }
  if (lower.contains('shoe') || lower.contains('sneaker')) {
    return 'Shoes';
  }
  if (lower.contains('electronic')) {
    return 'Electronics';
  }
  if (lower.length > 14) {
    return '${cleaned.substring(0, 13)}...';
  }
  return cleaned
      .split(' ')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String authFriendlyError(SoukApiException error) {
  if (error.statusCode == 404 && error.message.contains('Route not found')) {
    return 'Password reset is not live on the backend yet. Deploy the latest Railway backend, then try again.';
  }
  if (error.message.contains('Password reset email is not configured')) {
    return 'Password reset email is not configured on Railway. Add the SMTP variables first.';
  }
  if (error.message.contains('Could not connect to Gmail SMTP')) {
    return 'Could not connect to Gmail SMTP. In Railway try SMTP_PORT=587 and SMTP_SECURE=false, then redeploy.';
  }
  if (error.message.contains('Gmail rejected the SMTP login')) {
    return 'Gmail rejected the email login. Use the Gmail address as SMTP_USER and a fresh Google App Password as SMTP_PASS.';
  }
  if (error.message.contains('Could not send the password reset email')) {
    return 'Could not send the reset email. Check SMTP_USER, SMTP_PASS, SMTP_FROM, then redeploy.';
  }
  return error.message.replaceFirst(RegExp(r'^HTTP \d+:\s*'), '');
}

String resetFriendlyError(Object error) {
  final message = error.toString();
  if (message.toLowerCase().contains('timeout')) {
    return 'Email request timed out. Redeploy the latest backend and check Railway SMTP variables.';
  }
  return 'Could not reset password. Check the email settings and try again.';
}

String mostCommon(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      counts[trimmed] = (counts[trimmed] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) {
    return 'New arrivals';
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

double lowestPrice(List<Product> products) {
  if (products.isEmpty) {
    return 0;
  }
  return products.map((product) => product.price).reduce((a, b) => a < b ? a : b);
}

String paymentMethodCode(String label) {
  return switch (label) {
    'Card on delivery' => 'CARD_ON_DELIVERY',
    'Wallet later' => 'WALLET',
    _ => 'CASH_ON_DELIVERY',
  };
}

String formatFilterLabel(String value) {
  if (value.length <= 3) {
    return value.toUpperCase();
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

int sortSizes(String a, String b) {
  const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final aIndex = order.indexOf(a);
  final bIndex = order.indexOf(b);
  if (aIndex != -1 || bIndex != -1) {
    return (aIndex == -1 ? 999 : aIndex).compareTo(bIndex == -1 ? 999 : bIndex);
  }
  return a.compareTo(b);
}

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

String optimizedImageUrl(String url, int width) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.host.contains('shopify')) {
    return url;
  }
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    'width': width.toString(),
  }).toString();
}

List<String> productCollectionNames(Map<String, dynamic> json) {
  final rows = json['collections'] as List<dynamic>? ?? const [];
  return rows
      .map((item) => item as Map<String, dynamic>)
      .map((item) => item['collection'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map((collection) => collection['title'] as String? ?? '')
      .where((title) => title.isNotEmpty)
      .toList();
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
