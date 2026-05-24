import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/souklora_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupPushNotifications();
  runApp(const SoukloraApp());
}

const _soukloraApiUrl = String.fromEnvironment('SOUKLORA_API_URL');
const _selloraApiUrl = String.fromEnvironment('SELLORA_API_URL');
const _legacyApiUrl = String.fromEnvironment('SOUK_API_URL');
const soukloraApiUrl = _soukloraApiUrl == ''
    ? (_selloraApiUrl == '' ? _legacyApiUrl : _selloraApiUrl)
    : _soukloraApiUrl;
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
const appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');
const soukloraNotificationChannel = AndroidNotificationChannel(
  'souklora_campaigns',
  'Store campaigns',
  description: 'Campaign updates from stores you follow',
  importance: Importance.high,
);
final localNotifications = FlutterLocalNotificationsPlugin();
bool pushNotificationsReady = false;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

Future<void> setupPushNotifications() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    if (pushNotificationsReady) {
      return;
    }
    pushNotificationsReady = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final androidNotifications = localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      soukloraNotificationChannel,
    );
    await localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await androidNotifications?.requestNotificationsPermission();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    FirebaseMessaging.onMessage.listen(showForegroundPushNotification);
  } catch (error) {
    debugPrint('Push notification setup skipped: $error');
  }
}

void showForegroundPushNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = notification?.android;
  final title = notification?.title ?? message.data['title']?.toString();
  final body = notification?.body ?? message.data['body']?.toString();
  if (title == null && body == null) {
    return;
  }
  localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        soukloraNotificationChannel.id,
        soukloraNotificationChannel.name,
        channelDescription: soukloraNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: android?.smallIcon,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

class SoukloraApp extends StatelessWidget {
  const SoukloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    const leaf = Color(0xFF1F7A4D);
    const saffron = Color(0xFFE7A72E);
    const clay = Color(0xFFC8673A);
    const paper = Color(0xFFF8F4EC);
    const ink = Color(0xFF17211B);
    final softShadow = Colors.black.withValues(alpha: 0.08);

    final scheme = ColorScheme.fromSeed(
      seedColor: leaf,
      primary: leaf,
      secondary: saffron,
      tertiary: clay,
      surface: paper,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Souklora',
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        primaryTextTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: ink,
          displayColor: ink,
        ),
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
          elevation: 1,
          shadowColor: softShadow,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
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

Future<void> registerNotificationDevice(AppSession session) async {
  if (soukloraApiUrl.isEmpty || !soukloraApiUrl.startsWith('https://')) {
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    final api = SoukloraApi(baseUrl: soukloraApiUrl);
    await api.registerDevice({
      'email': session.email,
      'token': token,
      'platform': notificationPlatformLabel(),
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      api.registerDevice({
        'email': session.email,
        'token': newToken,
        'platform': notificationPlatformLabel(),
      });
    });
  } catch (error) {
    debugPrint('Push notification registration skipped: $error');
    // Firebase config can be added later; login must not depend on push setup.
  }
}

String notificationPlatformLabel() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppSession? _session;

  void _setSession(AppSession nextSession) {
    setState(() => _session = nextSession);
    unawaited(registerNotificationDevice(nextSession));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return AccountEntryPage(
        onAuthenticated: (nextSession) => _setSession(nextSession),
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
  bool _passwordVisible = false;
  String? _socialLoading;
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
        _email.text.trim().toLowerCase() ==
            'scalora.socialmedia.agency@gmail.com' &&
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

    if (soukloraApiUrl.isEmpty) {
      setState(() {
        _authError =
            'Backend is not configured. Run with SOUKLORA_API_URL set to your Railway API URL.';
      });
      return;
    }
    if (!soukloraApiUrl.startsWith('https://')) {
      setState(() {
        _authError =
            'SOUKLORA_API_URL must start with https:// and point to your Railway public domain.';
      });
      return;
    }

    setState(() {
      _authLoading = true;
      _authError = null;
    });

    try {
      final api = SoukloraApi(baseUrl: soukloraApiUrl);
      final response = _signup
          ? await api.signup(_signupPayload())
          : await api.login(_loginPayload());
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(_sessionFromAuthResponse(response));
    } on SoukloraApiException catch (error) {
      setState(() => _authError = error.message);
    } catch (error) {
      setState(() => _authError = 'Could not reach Souklora: $error');
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
        'story': '${_storeName.text.trim()} is selling on Souklora.',
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
      store: shop == null ? null : ShopDraft.fromJson(shop),
    );
  }

  Future<void> _socialLogin(String provider) async {
    if (_role == AccountRole.seller) {
      _showAuthSnack(
        'Store accounts need email login so we can connect the seller dashboard.',
      );
      return;
    }
    if (soukloraApiUrl.isEmpty || !soukloraApiUrl.startsWith('https://')) {
      setState(
        () =>
            _authError = 'SOUKLORA_API_URL must point to your Railway backend.',
      );
      return;
    }
    setState(() {
      _socialLoading = provider;
      _authError = null;
    });
    try {
      final payload = provider == 'GOOGLE'
          ? await _googleAuthPayload()
          : await _appleAuthPayload();
      if (payload == null) {
        return;
      }
      final response = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).socialLogin(payload);
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(_sessionFromAuthResponse(response));
    } on SoukloraApiException catch (error) {
      if (mounted) {
        setState(() => _authError = authFriendlyError(error));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _authError =
              'Could not sign in with ${provider.toLowerCase()}: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _socialLoading = null);
      }
    }
  }

  Future<Map<String, dynamic>?> _googleAuthPayload() async {
    final account = await GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
    ).signIn();
    if (account == null) {
      return null;
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return an identity token.');
    }
    return {
      'provider': 'GOOGLE',
      'idToken': idToken,
      'name': account.displayName,
      'email': account.email,
    };
  }

  Future<Map<String, dynamic>?> _appleAuthPayload() async {
    final webOptions = appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty
        ? WebAuthenticationOptions(
            clientId: appleServiceId,
            redirectUri: Uri.parse(appleRedirectUri),
          )
        : null;
    final available = await SignInWithApple.isAvailable();
    if (!available && webOptions == null) {
      throw Exception(
        'Apple sign-in needs Apple Service ID setup on this device.',
      );
    }
    const scopes = [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ];
    final credential = webOptions == null
        ? await SignInWithApple.getAppleIDCredential(scopes: scopes)
        : await SignInWithApple.getAppleIDCredential(
            scopes: scopes,
            webAuthenticationOptions: webOptions,
          );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple did not return an identity token.');
    }
    final fullName = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return {
      'provider': 'APPLE',
      'idToken': idToken,
      'name': fullName.isEmpty ? null : fullName,
      'email': credential.email,
    };
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
              if (soukloraApiUrl.isEmpty) {
                safeSetDialogState(
                  () => error = 'SOUKLORA_API_URL is required.',
                );
                return;
              }
              safeSetDialogState(() {
                loading = true;
                error = null;
              });
              try {
                final api = SoukloraApi(baseUrl: soukloraApiUrl);
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
                    safeSetDialogState(
                      () => error = 'Use at least 6 characters.',
                    );
                    return;
                  }
                  if (newPasswordController.text !=
                      confirmPasswordController.text) {
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
              } on SoukloraApiException catch (apiError) {
                safeSetDialogState(() => error = authFriendlyError(apiError));
              } on TimeoutException {
                safeSetDialogState(
                  () => error =
                      'Email request timed out. Redeploy the latest backend and check Railway SMTP variables.',
                );
              } catch (submitError) {
                safeSetDialogState(
                  () => error = resetFriendlyError(submitError),
                );
              } finally {
                safeSetDialogState(() => loading = false);
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              title: const Text('Forgot password'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.62,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
        content: const Text(
          'Your new password is filled in. You can login now.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showAuthSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = _role == AccountRole.seller;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const AuthBrandHeader(),
            const SizedBox(height: 24),
            const AuthHeroPanel(),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _signup
                            ? (_role == AccountRole.seller
                                  ? 'Register Store'
                                  : 'Create Account')
                            : 'Login to Souklora',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF164A36),
                              fontFamily: 'serif',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signup
                            ? 'Create your account and continue into Souklora.'
                            : 'Choose where you want to enter Souklora.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceCardButton(
                              icon: Icons.person_outline,
                              label: 'Shopper',
                              selected: _role == AccountRole.customer,
                              onTap: () =>
                                  setState(() => _role = AccountRole.customer),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceCardButton(
                              icon: Icons.storefront_outlined,
                              label: 'Store',
                              selected: _role == AccountRole.seller,
                              onTap: () =>
                                  setState(() => _role = AccountRole.seller),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_signup) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: requiredField,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
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
                            onPressed: _authLoading
                                ? null
                                : _showForgotPasswordDialog,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 14),
                      if (_signup && isSeller) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Store setup',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storeCategory,
                          decoration: const InputDecoration(
                            labelText: 'Store category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          validator: requiredField,
                        ),
                        const SizedBox(height: 12),
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
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1F7A4D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
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
                      if (!_signup) ...[
                        const SizedBox(height: 20),
                        const AuthDivider(),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            AuthSocialButton(
                              label: 'Continue with Google',
                              leading: const GoogleMark(),
                              loading: _socialLoading == 'GOOGLE',
                              onTap: () => _socialLogin('GOOGLE'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F7F3),
                            foregroundColor: const Color(0xFF1F7A4D),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _authLoading
                              ? null
                              : () => setState(() {
                                  _signup = !_signup;
                                  _authError = null;
                                }),
                          icon: Icon(
                            _signup ? Icons.login : Icons.person_add_alt,
                          ),
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
            const SizedBox(height: 24),
            const AuthTrustRow(),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Powered by Souklora • Shopify Sync',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF164A36).withValues(alpha: 0.18),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: const [
              Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFF164A36),
                size: 38,
              ),
              Positioned(
                bottom: 13,
                child: Icon(Icons.eco, color: Color(0xFF164A36), size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Souklora',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFamily: 'serif',
                  color: const Color(0xFF164A36),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                'Shops, makers, and quick checkout',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
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

class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEFE5D8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: 0,
            bottom: 0,
            child: Container(
              width: 190,
              decoration: const BoxDecoration(
                color: Color(0xFFDCCBB6),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(90),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_florist,
                  color: Color(0xFF43572C),
                  size: 96,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 245,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to Souklora',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'serif',
                      color: const Color(0xFF164A36),
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Shop from trusted stores and unique makers across categories. Quality products. Secure checkout. Better shopping experience.',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.68),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      AuthHeroDot(active: true),
                      AuthHeroDot(active: false),
                      AuthHeroDot(active: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHeroDot extends StatelessWidget {
  const AuthHeroDot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF1F7A4D)
            : Colors.black.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
      ],
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.leading,
    this.loading = false,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : leading,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 17,
          height: 1,
        ),
      ),
    );
  }
}

class AuthTrustRow extends StatelessWidget {
  const AuthTrustRow({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      AuthTrustItem(
        Icons.verified_user_outlined,
        'Secure & Safe',
        'Protected data',
      ),
      AuthTrustItem(
        Icons.workspace_premium_outlined,
        'Trusted Stores',
        'Verified sellers',
      ),
      AuthTrustItem(Icons.sync, 'Easy Returns', 'Hassle-free'),
      AuthTrustItem(Icons.support_agent, '24/7 Support', 'We are here'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Expanded(child: item),
          if (item != items.last)
            Container(
              width: 1,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withValues(alpha: 0.08),
            ),
        ],
      ],
    );
  }
}

class AuthTrustItem extends StatelessWidget {
  const AuthTrustItem(this.icon, this.title, this.subtitle, {super.key});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF164A36), size: 24),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.black54),
        ),
      ],
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
  String _searchDraft = '';
  Timer? _searchDebounce;
  String _category = 'All';
  MarketplaceFilters _filters = const MarketplaceFilters();
  final List<CartLine> _cart = [];
  final Set<String> _favoriteIds = {};
  final Set<String> _followedShopIds = {};
  final List<Order> _orders = [];
  List<Shop> _shops = [];
  List<Product> _products = [];
  List<StoreStory> _stories = [];
  bool _catalogLoading = false;
  bool _showAllFeatured = false;
  String? _catalogMessage;

  int get _cartCount => _cart.fold(0, (sum, line) => sum + line.quantity);

  double get _subtotal =>
      _cart.fold(0, (sum, line) => sum + (line.product.price * line.quantity));

  int get _cartShopCount =>
      _cart.map((line) => line.product.shop.id).toSet().length;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadCustomerOrders());
      unawaited(_loadCustomerFollows());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _setSearchDraft(String value) {
    setState(() => _searchDraft = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value);
    });
  }

  Future<void> _loadCatalog() async {
    if (soukloraApiUrl.isEmpty) {
      setState(() {
        _catalogMessage =
            'Run the app with SOUKLORA_API_URL to load live stores.';
      });
      return;
    }
    setState(() {
      _catalogLoading = true;
      _catalogMessage = null;
    });
    try {
      final api = SoukloraApi(baseUrl: soukloraApiUrl);
      final shopRows = await api.fetchShops();
      final shops = shopRows
          .map((item) => Shop.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _shops = shops;
        _catalogLoading = false;
      });
      unawaited(_loadStories(api));
      unawaited(_loadHomepageProducts(api));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogLoading = false;
        _catalogMessage = 'Could not load live catalog from Souklora.';
      });
    }
  }

  Future<void> _loadStories(SoukloraApi api) async {
    try {
      final storyRows = await api.fetchStories();
      final stories = storyRows
          .map((item) => StoreStory.fromJson(item as Map<String, dynamic>))
          .where((story) => story.expiresAt.isAfter(DateTime.now()))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() => _stories = stories);
    } catch (_) {
      // Stories are optional; hide the strip if none can be loaded quickly.
    }
  }

  Future<void> _loadHomepageProducts(SoukloraApi api) async {
    try {
      final productRows = await api.fetchProducts(limit: 80);
      final products = productRows
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() => _products = products);
    } catch (_) {
      // Stores are the primary homepage content; products can fill in later.
    }
  }

  Future<void> _loadCustomerOrders() async {
    if (soukloraApiUrl.isEmpty) {
      return;
    }
    try {
      final rows = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchOrders(customerEmail: widget.session.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders
          ..clear()
          ..addAll(
            rows.map((item) => Order.fromJson(item as Map<String, dynamic>)),
          );
      });
    } catch (_) {
      // Keep the local list; checkout errors surface separately.
    }
  }

  Future<void> _loadCustomerFollows() async {
    if (soukloraApiUrl.isEmpty) {
      return;
    }
    try {
      final rows = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchCustomerFollows(widget.session.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _followedShopIds
          ..clear()
          ..addAll(
            rows
                .map((item) => item as Map<String, dynamic>)
                .map((item) => item['shop'] as Map<String, dynamic>?)
                .whereType<Map<String, dynamic>>()
                .map((shop) => shop['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          );
      });
    } catch (_) {
      // Following state will update locally when the user follows a store.
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
    if (soukloraApiUrl.isEmpty || product.id.isEmpty) {
      return;
    }
    try {
      await SoukloraApi(baseUrl: soukloraApiUrl).favoriteProduct(product.id, {
        'customerEmail': widget.session.email,
        'customerName': widget.session.name,
      });
    } catch (_) {
      // Local favorite still works if persistence is temporarily unavailable.
    }
  }

  Future<void> _followShop(Shop shop) async {
    if (soukloraApiUrl.isEmpty || shop.id.isEmpty) {
      _showSnack('SOUKLORA_API_URL is required to follow stores');
      return;
    }
    final wasFollowing = _followedShopIds.contains(shop.id);
    setState(() {
      if (wasFollowing) {
        _followedShopIds.remove(shop.id);
      } else {
        _followedShopIds.add(shop.id);
      }
    });
    try {
      final payload = {
        'email': widget.session.email,
        'name': widget.session.name,
      };
      if (wasFollowing) {
        await SoukloraApi(
          baseUrl: soukloraApiUrl,
        ).unfollowShop(shop.id, payload);
        _showSnack('Unfollowed ${shop.name}');
      } else {
        await SoukloraApi(baseUrl: soukloraApiUrl).followShop(shop.id, payload);
        _showSnack('Following ${shop.name}');
      }
    } on SoukloraApiException catch (error) {
      setState(() {
        if (wasFollowing) {
          _followedShopIds.add(shop.id);
        } else {
          _followedShopIds.remove(shop.id);
        }
      });
      _showSnack(error.message);
    } catch (_) {
      setState(() {
        if (wasFollowing) {
          _followedShopIds.add(shop.id);
        } else {
          _followedShopIds.remove(shop.id);
        }
      });
      _showSnack(
        wasFollowing ? 'Could not unfollow store' : 'Could not follow store',
      );
    }
  }

  void _openFollowingStores() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => FollowingStoresPage(
          shops: _shops,
          followedShopIds: _followedShopIds,
          onOpenShop: _openShop,
          onToggleFollow: _followShop,
        ),
      ),
    );
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
          onReview: (rating, comment) =>
              _createReview(product, rating, comment),
        );
      },
    );
  }

  void _openShop(Shop shop) {
    final shopProducts = _products
        .where((product) => product.shop.id == shop.id)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => StorefrontPage(
          shop: shop,
          products: shopProducts,
          favoriteIds: _favoriteIds,
          isFollowing: _followedShopIds.contains(shop.id),
          onOpenProduct: _openProduct,
          onAddToCart: _addToCart,
          onToggleFavorite: _toggleFavorite,
          onFollowStore: _followShop,
        ),
      ),
    );
  }

  Future<void> _createReview(
    Product product,
    int rating,
    String comment,
  ) async {
    if (soukloraApiUrl.isEmpty || product.shop.id.isEmpty) {
      _showSnack('SOUKLORA_API_URL is required to review stores');
      return;
    }
    try {
      await SoukloraApi(baseUrl: soukloraApiUrl).createReview(product.shop.id, {
        'customerEmail': widget.session.email,
        'customerName': widget.session.name,
        'rating': rating,
        'comment': comment,
      });
      _loadCatalog();
      _showSnack('Review submitted');
    } on SoukloraApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not submit review');
    }
  }

  void _trackShopEvent(Product product, String event) {
    if (soukloraApiUrl.isEmpty || product.shop.id.isEmpty) {
      return;
    }
    SoukloraApi(baseUrl: soukloraApiUrl)
        .trackShopAnalytics(product.shop.id, {
          'event': event,
          'bestProductId': product.id,
          'topCity': product.shop.location,
        })
        .catchError((_) => <String, dynamic>{});
  }

  Future<void> _placeOrder(CheckoutInfo info) async {
    if (_cart.isEmpty) {
      return;
    }
    if (soukloraApiUrl.isEmpty) {
      _showSnack('SOUKLORA_API_URL is required for checkout');
      return;
    }
    try {
      final groupedLines = <String, List<CartLine>>{};
      for (final line in _cart) {
        groupedLines.putIfAbsent(line.product.shop.id, () => []).add(line);
      }
      final placedOrders = <Order>[];
      final api = SoukloraApi(baseUrl: soukloraApiUrl);

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
          'fulfillmentMethod': info.deliveryMethod == 'Pickup'
              ? 'PICKUP'
              : 'DELIVERY',
          'paymentMethod': paymentMethodCode(info.paymentMethod),
          'deliveryAddress': info.address,
          'note': info.note,
        });
        final orderJson = body['order'] as Map<String, dynamic>? ?? body;
        final total = parseDouble(orderJson['total']);
        final id =
            orderJson['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString();
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
            eta: info.deliveryMethod == 'Pickup'
                ? 'Ready in 2 hours'
                : 'Today, 6-8 PM',
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
    } on SoukloraApiException catch (error) {
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
              if (soukloraApiUrl.isEmpty) {
                setDialogState(() => error = 'SOUKLORA_API_URL is required.');
                return;
              }
              setDialogState(() {
                loading = true;
                error = null;
              });
              try {
                await SoukloraApi(baseUrl: soukloraApiUrl).changePassword({
                  'email': widget.session.email,
                  'currentPassword': currentPassword.text,
                  'newPassword': newPassword.text,
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } on SoukloraApiException catch (apiError) {
                setDialogState(() => error = apiError.message);
              } catch (submitError) {
                setDialogState(
                  () => error = 'Could not update password: $submitError',
                );
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
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
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
          _category == 'All' ||
          product.shop.category == _category ||
          product.category == _category;
      final inSearch =
          q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.shop.name.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q) ||
          product.collectionNames.any((name) => name.toLowerCase().contains(q));
      return inCategory && inSearch && _filters.matches(product);
    }).toList()..sort(_filters.compare);

    final pages = [
      HomePage(
        session: widget.session,
        onLogout: widget.onLogout,
        query: _searchDraft,
        category: _category,
        shops: _shops,
        stories: _stories,
        products: products,
        allProducts: _products,
        showAllFeatured: _showAllFeatured,
        loading: _catalogLoading,
        message: _catalogMessage,
        categories: {for (final shop in _shops) shop.category}.toList()..sort(),
        favoriteIds: _favoriteIds,
        followedShopIds: _followedShopIds,
        onViewAllFeatured: () =>
            setState(() => _showAllFeatured = !_showAllFeatured),
        onQueryChanged: _setSearchDraft,
        onCategoryChanged: (value) => setState(() => _category = value),
        filters: _filters,
        filterOptions: MarketplaceFilterOptions.fromProducts(_products),
        onFiltersChanged: (value) => setState(() => _filters = value),
        onOpenProduct: _openProduct,
        onOpenShop: _openShop,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
        onFollowStore: _followShop,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
      StoresPage(
        session: widget.session,
        onLogout: widget.onLogout,
        favoriteIds: _favoriteIds,
        followedShopIds: _followedShopIds,
        shops: _shops,
        products: _products,
        onOpenProduct: _openProduct,
        onOpenShop: _openShop,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
        onFollowStore: _followShop,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
      SellEntryPage(
        session: widget.session,
        onLogout: widget.onLogout,
        onStartSelling: () =>
            _showSnack('Register as a store from the login screen'),
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
        followingCount: _followedShopIds.length,
        orderCount: _orders.length,
        onFollowingTap: _openFollowingStores,
        onChangePassword: _changePassword,
        cartCount: _cartCount,
        onCartTap: _openCartSheet,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: SoukloraBottomNav(
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
    if (soukloraApiUrl.isEmpty) {
      setState(
        () => _message = 'SOUKLORA_API_URL is required for admin review.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final rows = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchShops(includeAll: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _shops = rows
            .map((item) => Shop.fromJson(item as Map<String, dynamic>))
            .toList();
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
      await SoukloraApi(baseUrl: soukloraApiUrl).verifyShop(shop.id, {
        'verified': approved,
        'verificationNote': approved
            ? 'Approved by Scalora admin'
            : 'Declined by Scalora admin',
      });
      await _loadShops();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? '${shop.name} approved' : '${shop.name} declined',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on SoukloraApiException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
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
            const SectionTitle(
              title: 'Admin dashboard',
              action: 'Store approvals',
            ),
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
                      backgroundColor: shop.verified
                          ? const Color(0xFF1F7A4D)
                          : const Color(0xFFC8673A),
                      child: Icon(
                        shop.verified ? Icons.verified : Icons.hourglass_top,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      shop.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${shop.category} - ${shop.location} - ${shop.statusLabel}',
                    ),
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
    required this.shops,
    required this.stories,
    required this.products,
    required this.allProducts,
    required this.showAllFeatured,
    required this.loading,
    required this.message,
    required this.categories,
    required this.favoriteIds,
    required this.followedShopIds,
    required this.onViewAllFeatured,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.filters,
    required this.filterOptions,
    required this.onFiltersChanged,
    required this.onOpenProduct,
    required this.onOpenShop,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.onFollowStore,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String query;
  final String category;
  final List<Shop> shops;
  final List<StoreStory> stories;
  final List<Product> products;
  final List<Product> allProducts;
  final bool showAllFeatured;
  final bool loading;
  final String? message;
  final List<String> categories;
  final Set<String> favoriteIds;
  final Set<String> followedShopIds;
  final VoidCallback onViewAllFeatured;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final MarketplaceFilters filters;
  final MarketplaceFilterOptions filterOptions;
  final ValueChanged<MarketplaceFilters> onFiltersChanged;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Shop> onOpenShop;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Shop> onFollowStore;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visibleShops =
        shops.where((shop) {
          final shopProducts = allProducts
              .where((product) => product.shop.id == shop.id)
              .toList();
          final inCategory = category == 'All' || shop.category == category;
          final inSearch =
              q.isEmpty ||
              shop.name.toLowerCase().contains(q) ||
              shop.category.toLowerCase().contains(q) ||
              shop.location.toLowerCase().contains(q) ||
              shopProducts.any(
                (product) =>
                    product.name.toLowerCase().contains(q) ||
                    product.category.toLowerCase().contains(q) ||
                    product.collectionNames.any(
                      (name) => name.toLowerCase().contains(q),
                    ),
              );
          return inCategory && inSearch;
        }).toList()..sort((a, b) {
          final verified = (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0);
          if (verified != 0) {
            return verified;
          }
          final orders = b.orderCount.compareTo(a.orderCount);
          if (orders != 0) {
            return orders;
          }
          return b.rating.compareTo(a.rating);
        });
    final featuredShops = visibleShops.take(8).toList();
    final nearbyShops = visibleShops.take(showAllFeatured ? 16 : 8).toList();
    final chosenFeatured = products
        .where((product) => product.featured)
        .toList();
    final arrivalSource = chosenFeatured.isEmpty ? products : chosenFeatured;
    final arrivalProducts =
        (showAllFeatured ? arrivalSource : arrivalSource.take(8)).toList();
    final popularCategories = categories.isEmpty
        ? ['Home', 'Fashion', 'Electronics', 'Beauty']
        : categories.take(6).toList();
    final suggestions = searchSuggestions(query, allProducts).take(5).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoukloraShopperTopBar(
                  cartCount: cartCount,
                  onCartTap: onCartTap,
                ),
                const SizedBox(height: 14),
                const SoukloraDeliveryStrip(),
                const SizedBox(height: 18),
                SoukloraSearchRow(
                  value: query,
                  filters: filters,
                  options: filterOptions,
                  onChanged: onQueryChanged,
                  onFiltersChanged: onFiltersChanged,
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SoukloraSearchSuggestions(
                    products: suggestions,
                    onSelected: onOpenProduct,
                  ),
                ],
                if (stories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SoukloraStoryStrip(stories: stories, onOpenShop: onOpenShop),
                ],
                const SizedBox(height: 20),
                SoukloraMarketplaceBanner(
                  shopCount: shops.length,
                  productCount: allProducts.length,
                  verifiedCount: shops.where((shop) => shop.verified).length,
                ).animate().fadeIn(
                  duration: const Duration(milliseconds: 260),
                ).slideY(
                  begin: 0.04,
                  end: 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
        if (loading)
          const SliverToBoxAdapter(
            child: SoukloraHomeSkeleton(),
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
        else if (visibleShops.isEmpty && products.isEmpty)
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: SoukloraSectionHeader(
                    title: 'Shop by Category',
                    onViewAll: () => onCategoryChanged('All'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  child: StaggeredGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final name in popularCategories)
                        StaggeredGridTile.fit(
                          crossAxisCellCount: 1,
                          child: SoukloraServiceTile(
                            name: name,
                            storeCount: shops
                                .where((shop) => shop.category == name)
                                .length,
                            icon: categoryIcon(name),
                            onTap: () => onCategoryChanged(name),
                          ),
                        ),
                    ],
                  ),
                ),
                if (nearbyShops.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                    child: SoukloraSectionHeader(
                      title: category == 'All'
                          ? 'Stores Near You'
                          : '$category Stores',
                      icon: Icons.storefront,
                      onViewAll: onViewAllFeatured,
                    ),
                  ),
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nearbyShops.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final shop = nearbyShops[index];
                      final shopProducts = allProducts
                          .where((product) => product.shop.id == shop.id)
                          .toList();
                      return SoukloraStoreRowCard(
                        shop: shop,
                        productCount: shopProducts.length,
                        isFollowing: followedShopIds.contains(shop.id),
                        onFollow: () => onFollowStore(shop),
                        onOpen: () => onOpenShop(shop),
                      ).animate(delay: Duration(milliseconds: index * 35))
                          .fadeIn(duration: const Duration(milliseconds: 220))
                          .slideY(
                            begin: 0.03,
                            end: 0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                ],
                if (featuredShops.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: SoukloraSectionHeader(
                      title: 'Featured Partners',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                  SizedBox(
                    height: 244,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: featuredShops.take(6).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final shop = featuredShops[index];
                        final shopProducts = allProducts
                            .where((product) => product.shop.id == shop.id)
                            .take(3)
                            .toList();
                        return SizedBox(
                          width: 282,
                          child: SoukloraFeaturedStoreCard(
                            shop: shop,
                            products: shopProducts,
                            isFollowing: followedShopIds.contains(shop.id),
                            onFollow: () => onFollowStore(shop),
                            onOpen: () => onOpenShop(shop),
                            onOpenProduct: onOpenProduct,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (arrivalProducts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: SoukloraSectionHeader(
                      title: 'Fresh Picks',
                      icon: Icons.new_releases_outlined,
                      onViewAll: onViewAllFeatured,
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: arrivalProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final product = arrivalProducts[index];
                        return SizedBox(
                          width: 178,
                          child: SoukloraDealCard(
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
              ],
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
    required this.followedShopIds,
    required this.shops,
    required this.products,
    required this.onOpenProduct,
    required this.onOpenShop,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.onFollowStore,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final Set<String> favoriteIds;
  final Set<String> followedShopIds;
  final List<Shop> shops;
  final List<Product> products;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Shop> onOpenShop;
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
        SoukloraShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Local shops', action: 'Verified sellers'),
        const SizedBox(height: 12),
        if (shops.isEmpty)
          const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No live stores yet',
            message:
                'Stores will appear here after sellers create shops and sync products.',
          )
        else
          for (final shop in shops) ...[
            ShopCard(
              shop: shop,
              isFollowing: followedShopIds.contains(shop.id),
              onOpenShop: () => onOpenShop(shop),
              onFollow: () => onFollowStore(shop),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class StorefrontPage extends StatelessWidget {
  const StorefrontPage({
    super.key,
    required this.shop,
    required this.products,
    required this.favoriteIds,
    required this.isFollowing,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.onFollowStore,
  });

  final Shop shop;
  final List<Product> products;
  final Set<String> favoriteIds;
  final bool isFollowing;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Shop> onFollowStore;

  @override
  Widget build(BuildContext context) {
    final collectionGroups = storefrontCollectionGroups(shop, products);
    final featuredGroups = shop.storefrontCollectionIds.isEmpty
        ? collectionGroups.take(5).toList()
        : collectionGroups
              .where((group) => shop.storefrontCollectionIds.contains(group.id))
              .take(5)
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          if (shop.shopifyMenu.items.isNotEmpty)
            IconButton(
              tooltip: 'Store menu',
              onPressed: () => showStorefrontMenu(
                context,
                shop,
                collectionGroups,
                favoriteIds,
                onOpenProduct,
                onAddToCart,
                onToggleFavorite,
              ),
              icon: const Icon(Icons.menu),
            ),
          IconButton.filledTonal(
            tooltip: isFollowing ? 'Following store' : 'Follow store',
            onPressed: () => onFollowStore(shop),
            icon: Icon(
              isFollowing
                  ? Icons.notifications_active
                  : Icons.add_alert_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Container(
            height: 148,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: shop.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: shop.bannerUrl == null || shop.bannerUrl!.isEmpty
                ? Stack(
                    children: [
                      Positioned(
                        right: 18,
                        bottom: 10,
                        child: Icon(
                          Icons.storefront,
                          size: 92,
                          color: shop.color.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  )
                : AppNetworkImage(url: shop.bannerUrl!, size: 900),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F4EC),
                    shape: BoxShape.circle,
                  ),
                  child: StoreAvatar(shop: shop, size: 78),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (shop.verified)
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF1F7A4D),
                              ),
                          ],
                        ),
                        Text(
                          '${shop.category} in ${shop.location.isEmpty ? 'Souklora' : shop.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          StoreSocialLinks(shop: shop),
          Text(shop.story),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(label: shop.delivery),
              Tag(label: '${shop.orderCount} orders'),
              Tag(label: 'Min ${money(shop.minimumOrder)}'),
              Tag(label: '${products.length} products'),
              if (shop.verified) const Tag(label: 'Verified store'),
            ],
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: 'This store has not synced products yet.',
            )
          else if (featuredGroups.isEmpty)
            StoreProductCarousel(
              title: 'Products',
              products: products.take(5).toList(),
              favoriteIds: favoriteIds,
              onViewAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => StoreCollectionProductsPage(
                      shop: shop,
                      group: StorefrontCollectionGroup(
                        id: 'all',
                        title: 'All products',
                        shopifyCollectionId: null,
                        handle: null,
                        products: products,
                      ),
                      favoriteIds: favoriteIds,
                      onOpenProduct: onOpenProduct,
                      onAddToCart: onAddToCart,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ),
                );
              },
              onOpenProduct: onOpenProduct,
              onAddToCart: onAddToCart,
              onToggleFavorite: onToggleFavorite,
            )
          else
            for (final group in featuredGroups) ...[
              StoreProductCarousel(
                title: group.title,
                products: group.products.take(5).toList(),
                favoriteIds: favoriteIds,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => StoreCollectionProductsPage(
                        shop: shop,
                        group: group,
                        favoriteIds: favoriteIds,
                        onOpenProduct: onOpenProduct,
                        onAddToCart: onAddToCart,
                        onToggleFavorite: onToggleFavorite,
                      ),
                    ),
                  );
                },
                onOpenProduct: onOpenProduct,
                onAddToCart: onAddToCart,
                onToggleFavorite: onToggleFavorite,
              ),
              const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }
}

void showStorefrontMenu(
  BuildContext context,
  Shop shop,
  List<StorefrontCollectionGroup> collectionGroups,
  Set<String> favoriteIds,
  ValueChanged<Product> onOpenProduct,
  ValueChanged<Product> onAddToCart,
  ValueChanged<Product> onToggleFavorite,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            Text(
              shop.shopifyMenu.title.isEmpty
                  ? 'Store menu'
                  : shop.shopifyMenu.title,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final item in shop.shopifyMenu.items)
              StorefrontMenuItemTile(
                item: item,
                depth: 0,
                onTap: (item) {
                  Navigator.pop(sheetContext);
                  openStorefrontMenuItem(
                    context,
                    shop,
                    item,
                    collectionGroups,
                    favoriteIds,
                    onOpenProduct,
                    onAddToCart,
                    onToggleFavorite,
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class StorefrontMenuItemTile extends StatelessWidget {
  const StorefrontMenuItemTile({
    super.key,
    required this.item,
    required this.depth,
    required this.onTap,
  });

  final ShopifyMenuItem item;
  final int depth;
  final ValueChanged<ShopifyMenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    final children = item.items
        .map(
          (child) => StorefrontMenuItemTile(
            item: child,
            depth: depth + 1,
            onTap: onTap,
          ),
        )
        .toList();
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: depth * 18.0, right: 4),
          leading: Icon(menuItemIcon(item.type)),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: item.items.isEmpty ? const Icon(Icons.chevron_right) : null,
          onTap: () => onTap(item),
        ),
        ...children,
      ],
    );
  }
}

IconData menuItemIcon(String type) {
  return switch (type.toUpperCase()) {
    'COLLECTION' => Icons.folder_outlined,
    'PRODUCT' => Icons.shopping_bag_outlined,
    'PAGE' => Icons.description_outlined,
    'SEARCH' => Icons.search,
    'CATALOG' => Icons.storefront,
    _ => Icons.link,
  };
}

void openStorefrontMenuItem(
  BuildContext context,
  Shop shop,
  ShopifyMenuItem item,
  List<StorefrontCollectionGroup> collectionGroups,
  Set<String> favoriteIds,
  ValueChanged<Product> onOpenProduct,
  ValueChanged<Product> onAddToCart,
  ValueChanged<Product> onToggleFavorite,
) {
  final group = matchingMenuCollection(item, collectionGroups);
  if (group != null) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => StoreCollectionProductsPage(
          shop: shop,
          group: group,
          favoriteIds: favoriteIds,
          onOpenProduct: onOpenProduct,
          onAddToCart: onAddToCart,
          onToggleFavorite: onToggleFavorite,
        ),
      ),
    );
    return;
  }
  if (item.type.toUpperCase() == 'COLLECTION') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sync Shopify again to open this collection inside Souklora.',
        ),
      ),
    );
    return;
  }
  final url = storefrontMenuUrl(shop, item);
  if (url != null) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

StorefrontCollectionGroup? matchingMenuCollection(
  ShopifyMenuItem item,
  List<StorefrontCollectionGroup> groups,
) {
  if (item.type.toUpperCase() != 'COLLECTION') {
    return null;
  }
  final itemTitle = comparableMenuText(item.title);
  final handle = menuCollectionHandle(item.url);
  final shopifyCollectionId = shopifyNumericId(item.resourceId);
  return firstWhereOrNull(
    groups,
    (group) =>
        (shopifyCollectionId != null &&
            group.shopifyCollectionId == shopifyCollectionId) ||
        (handle != null && group.handle == handle) ||
        comparableMenuText(group.title) == itemTitle ||
        (handle != null && comparableMenuText(group.title) == handle),
  );
}

String? storefrontMenuUrl(Shop shop, ShopifyMenuItem item) {
  final rawUrl = item.url?.trim();
  if (rawUrl == null || rawUrl.isEmpty || rawUrl == '#') {
    return null;
  }
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    return rawUrl;
  }
  final storeUrl = shop.websiteUrl;
  if (storeUrl == null || storeUrl.isEmpty) {
    return null;
  }
  final base = storeUrl.endsWith('/')
      ? storeUrl.substring(0, storeUrl.length - 1)
      : storeUrl;
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$base$path';
}

String? menuCollectionHandle(String? url) {
  if (url == null) {
    return null;
  }
  final match = RegExp(r'/collections/([^/?#]+)').firstMatch(url);
  return match?.group(1);
}

String? shopifyNumericId(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return RegExp(r'(\d+)$').firstMatch(value)?.group(1);
}

String comparableMenuText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class StoreSocialLinks extends StatelessWidget {
  const StoreSocialLinks({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final links = [
      if (shop.instagramUrl != null && shop.instagramUrl!.isNotEmpty)
        _StoreSocialLink(
          'Instagram',
          Icons.alternate_email,
          shop.instagramUrl!,
        ),
      if (shop.tiktokUrl != null && shop.tiktokUrl!.isNotEmpty)
        _StoreSocialLink('TikTok', Icons.music_note_outlined, shop.tiktokUrl!),
      if (shop.websiteUrl != null && shop.websiteUrl!.isNotEmpty)
        _StoreSocialLink('Website', Icons.language_outlined, shop.websiteUrl!),
    ];
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final link in links)
            IconButton.filledTonal(
              tooltip: link.label,
              onPressed: () => launchUrl(
                Uri.parse(link.url),
                mode: LaunchMode.externalApplication,
              ),
              icon: Icon(link.icon),
            ),
        ],
      ),
    );
  }
}

class _StoreSocialLink {
  const _StoreSocialLink(this.label, this.icon, this.url);

  final String label;
  final IconData icon;
  final String url;
}

class StoreProductCarousel extends StatelessWidget {
  const StoreProductCarousel({
    super.key,
    required this.title,
    required this.products,
    required this.favoriteIds,
    required this.onViewAll,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final String title;
  final List<Product> products;
  final Set<String> favoriteIds;
  final VoidCallback onViewAll;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: title,
          action: '',
          actionButton: TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.chevron_right),
            label: const Text('View all'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 168,
                child: ProductCard(
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
    );
  }
}

class StoreCollectionProductsPage extends StatelessWidget {
  const StoreCollectionProductsPage({
    super.key,
    required this.shop,
    required this.group,
    required this.favoriteIds,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
  });

  final Shop shop;
  final StorefrontCollectionGroup group;
  final Set<String> favoriteIds;
  final ValueChanged<Product> onOpenProduct;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group.title)),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: group.products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final product = group.products[index];
          return ProductCard(
            product: product,
            isFavorite: favoriteIds.contains(product.id),
            onOpen: () => onOpenProduct(product),
            onAdd: () => onAddToCart(product),
            onFavorite: () => onToggleFavorite(product),
          );
        },
      ),
    );
  }
}

class StorefrontCollectionGroup {
  const StorefrontCollectionGroup({
    required this.id,
    required this.title,
    required this.shopifyCollectionId,
    required this.handle,
    required this.products,
  });

  final String id;
  final String title;
  final String? shopifyCollectionId;
  final String? handle;
  final List<Product> products;
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
        SoukloraShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
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
                session.name.isEmpty
                    ? 'S'
                    : session.name.substring(0, 1).toUpperCase(),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
        SoukloraShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF3B2114),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront, color: Colors.white, size: 42),
              const SizedBox(height: 18),
              Text(
                'Sell on Souklora',
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
          message:
              'Store products sync only after admin approval, so shoppers only see trusted active stores.',
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
    required this.followingCount,
    required this.orderCount,
    required this.onChangePassword,
    required this.onFollowingTap,
    required this.cartCount,
    required this.onCartTap,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int favoriteCount;
  final int followingCount;
  final int orderCount;
  final VoidCallback onChangePassword;
  final VoidCallback onFollowingTap;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SoukloraShopperTopBar(cartCount: cartCount, onCartTap: onCartTap),
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
                icon: Icons.notifications_active_outlined,
                value: followingCount.toString(),
                label: 'Following',
                onTap: onFollowingTap,
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
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
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
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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

class FollowingStoresPage extends StatelessWidget {
  const FollowingStoresPage({
    super.key,
    required this.shops,
    required this.followedShopIds,
    required this.onOpenShop,
    required this.onToggleFollow,
  });

  final List<Shop> shops;
  final Set<String> followedShopIds;
  final ValueChanged<Shop> onOpenShop;
  final ValueChanged<Shop> onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final followedShops = shops
        .where((shop) => followedShopIds.contains(shop.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: followedShops.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No followed stores yet',
              message: 'Follow stores to see them here and receive updates.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemCount: followedShops.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final shop = followedShops[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: StoreAvatar(shop: shop, size: 42),
                  title: Text(
                    shop.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(shop.category),
                  trailing: IconButton(
                    tooltip: 'Unfollow store',
                    onPressed: () => onToggleFollow(shop),
                    icon: const Icon(Icons.notifications_active),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenShop(shop);
                  },
                );
              },
            ),
    );
  }
}

class SoukloraBottomNav extends StatelessWidget {
  const SoukloraBottomNav({
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
              child: SoukloraBottomNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
            ),
            Expanded(
              child: SoukloraBottomNavItem(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view,
                label: 'Stores',
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
                            color: const Color(
                              0xFFA8663A,
                            ).withValues(alpha: 0.26),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sell',
                      style: TextStyle(
                        color: selectedIndex == 2
                            ? const Color(0xFFA8663A)
                            : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SoukloraBottomNavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Orders',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ),
            Expanded(
              child: SoukloraBottomNavItem(
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

class SoukloraBottomNavItem extends StatelessWidget {
  const SoukloraBottomNavItem({
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
          action: widget.shopCount > 1
              ? '${widget.shopCount} stores'
              : 'Direct checkout',
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

enum SellerMenuSection { settings, productSync, analytics, growth, operations }

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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final rows = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchShops(includeAll: true);
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
      });
    } catch (_) {
      // The session store remains usable if status refresh is unavailable.
    }
  }

  Future<void> _connectShopify() async {
    final shopId = widget.session.store?.id;
    if (soukloraApiUrl.isEmpty || shopId == null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Shopify connection is not configured'),
            content: const Text(
              'Login with a real store account and run the app with SOUKLORA_API_URL set to your Railway API URL.',
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
      final api = SoukloraApi(baseUrl: soukloraApiUrl);
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
    } on SoukloraApiException catch (error) {
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
          'Opening Shopify login. Approve access there, then return to Souklora.';
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final status = await SoukloraApi(
        baseUrl: soukloraApiUrl,
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    _startShopifySyncProgress();
    try {
      final result = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).syncShopify(shopId);
      if (!mounted) {
        return;
      }
      final jobId = result['jobId'] as String?;
      if (jobId == null) {
        throw const SoukloraApiException(500, 'Sync job was not created');
      }
      setState(() {
        _shopifySyncJobId = jobId;
        _shopifyMessage =
            result['message'] as String? ?? 'Shopify sync started';
      });
      _pollShopifySyncJob(jobId);
    } on SoukloraApiException catch (error) {
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
        final job = await SoukloraApi(
          baseUrl: soukloraApiUrl,
        ).fetchShopifySyncJob(jobId);
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    setState(() {
      _inventoryLoading = true;
      _inventoryMessage = null;
    });
    try {
      final data = await SoukloraApi(
        baseUrl: soukloraApiUrl,
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
            !collections.any(
              (collection) => collection.id == _selectedCollectionId,
            )) {
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final rows = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchOrders(shopId: shopId);
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      return;
    }
    try {
      final data = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).fetchShopGrowth(shopId);
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before saving store settings.');
      return;
    }
    try {
      final shop = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).updateShopProfile(shopId, payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _liveStore = ShopDraft.fromJson(shop);
      });
      _showSellerSnack('Store profile saved');
    } on SoukloraApiException catch (error) {
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
                onTap: () =>
                    _selectSellerSection(SellerMenuSection.productSync),
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before creating campaigns.');
      return;
    }
    try {
      final result = await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createCampaign(shopId, payload);
      await _loadSellerGrowth();
      if (!mounted) {
        return;
      }
      final delivery = result['delivery'] as Map<String, dynamic>?;
      _showSellerSnack(campaignDeliveryMessage(delivery));
    } on SoukloraApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSellerSnack(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSellerSnack('Could not create campaign');
    }
  }

  Future<void> _createStoreStory(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before posting a story.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createStoreStory(shopId, payload);
      _showSellerSnack('Story posted for 24 hours');
    } on SoukloraApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not post story');
    }
  }

  Future<void> _createPlacement(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before creating placements.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createPlacement(shopId, payload);
      await _loadSellerGrowth();
      _showSellerSnack('Featured placement created');
    } on SoukloraApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not create placement');
    }
  }

  Future<void> _updateSellerOrderStatus(
    SellerOrder order,
    String status,
  ) async {
    if (soukloraApiUrl.isEmpty || order.id.isEmpty) {
      _showSellerSnack('Connect the backend before updating orders.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).updateOrderStatus(order.id, status);
      await _loadSellerOrders();
      _showSellerSnack('Order updated to $status');
    } on SoukloraApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not update order');
    }
  }

  Future<void> _generateProductCopy() async {
    final product = _syncedProducts.isEmpty ? null : _syncedProducts.first;
    if (soukloraApiUrl.isEmpty || product == null) {
      _showSellerSnack('Sync products first, then generate product copy.');
      return;
    }
    try {
      final copy = await SoukloraApi(baseUrl: soukloraApiUrl)
          .generateProductCopy({
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
    if (soukloraApiUrl.isEmpty) {
      _showSellerSnack('Connect the backend before generating ads.');
      return;
    }
    try {
      final copy = await SoukloraApi(baseUrl: soukloraApiUrl).generateAdCopy({
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
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before adding delivery regions.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createDeliveryRegion(shopId, payload);
      _showSellerSnack('Delivery region saved');
    } on SoukloraApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not save delivery region');
    }
  }

  Future<void> _createLiveEvent(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before scheduling live selling.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createLiveEvent(shopId, payload);
      _showSellerSnack('Live selling event scheduled');
    } on SoukloraApiException catch (error) {
      _showSellerSnack(error.message);
    } catch (_) {
      _showSellerSnack('Could not schedule live event');
    }
  }

  Future<void> _createAffiliateLink(Map<String, dynamic> payload) async {
    final shopId = widget.session.store?.id;
    if (soukloraApiUrl.isEmpty || shopId == null) {
      _showSellerSnack('Connect the backend before adding affiliates.');
      return;
    }
    try {
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).createAffiliateLink(shopId, payload);
      _showSellerSnack('Affiliate link created');
    } on SoukloraApiException catch (error) {
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
      await SoukloraApi(
        baseUrl: soukloraApiUrl,
      ).setProductFeatured(product.id, !product.featured);
      await _loadSellerInventory();
    } on SoukloraApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store =
        _liveStore ??
        widget.session.store ??
        const ShopDraft(
          name: 'My Souklora Store',
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
    final dashboardRevenue = _growthStats.revenue == 0
        ? orderRevenue
        : _growthStats.revenue;
    final dashboardGrowthStats = _growthStats.copyWith(
      revenue: dashboardRevenue,
    );
    final visibleSyncedProducts = _selectedCollectionId == null
        ? <SellerInventoryProduct>[]
        : _syncedProducts
              .where(
                (product) =>
                    product.collectionIds.contains(_selectedCollectionId),
              )
              .toList();
    final selectedCollection = _selectedCollectionId == null
        ? null
        : firstWhereOrNull(
            _syncedCollections,
            (collection) => collection.id == _selectedCollectionId,
          );
    final visibleCollections = _syncedCollections
        .where(
          (collection) => collection.title.toLowerCase().contains(
            _collectionQuery.toLowerCase(),
          ),
        )
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
            Expanded(
              child: HeaderBar(
                session: widget.session,
                onLogout: widget.onLogout,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SellerHero(),
        const SizedBox(height: 16),
        SellerStoreCard(store: store, ownerName: widget.session.name),
        const SizedBox(height: 16),
        if (_sellerSection == SellerMenuSection.settings)
          StoreOnboardingPanel(
            store: store,
            collections: _syncedCollections,
            onSave: _saveStoreProfile,
          ),
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
              message:
                  'Sync Shopify products after Scalora admin approves your store.',
            )
          else
            CollectionBrowser(
              collections: visibleCollections,
              selectedId: _selectedCollectionId,
              query: _collectionQuery,
              onQueryChanged: (value) =>
                  setState(() => _collectionQuery = value),
              onSelected: (collectionId) {
                setState(() {
                  _selectedCollectionId = _selectedCollectionId == collectionId
                      ? null
                      : collectionId;
                });
              },
            ),
          const SizedBox(height: 16),
          SectionTitle(
            title: selectedCollection?.title ?? 'Products by collection',
            action: _selectedCollectionId == null
                ? 'Choose a collection'
                : '${visibleSyncedProducts.length} products',
          ),
          const SizedBox(height: 10),
          if (_inventoryMessage != null)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Inventory unavailable',
              message: _inventoryMessage!,
            )
          else if (_selectedCollectionId == null)
            const EmptyState(
              icon: Icons.touch_app_outlined,
              title: 'Choose a collection',
              message:
                  'Products are shown after selecting a collection, keeping this page fast even with large catalogs.',
            )
          else if (visibleSyncedProducts.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message: 'Choose another collection or sync Shopify again.',
            )
          else ...[
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
            onCreateStory: _createStoreStory,
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
                onStatusChanged: (status) =>
                    _updateSellerOrderStatus(order, status),
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
                'Souklora',
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.black.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.black54, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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

class SoukloraShopperTopBar extends StatelessWidget {
  const SoukloraShopperTopBar({
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
          child: Row(
            children: [
              const SoukloraLogoMark(size: 38),
              const Gap(10),
              Text(
                'Souklora',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF17211B),
                  letterSpacing: 0,
                ),
              ),
            ],
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

class SoukloraLogoMark extends StatelessWidget {
  const SoukloraLogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1F7A4D),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F7A4D).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.string(
        '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M7.2 9.6h9.6l-.7 8.2a2.2 2.2 0 0 1-2.2 2H10a2.2 2.2 0 0 1-2.2-2L7.2 9.6Z" fill="white"/>
  <path d="M9 9.6V8a3 3 0 0 1 6 0v1.6" fill="none" stroke="#1F7A4D" stroke-width="1.7" stroke-linecap="round"/>
  <path d="M9.2 13h5.6" stroke="#1F7A4D" stroke-width="1.7" stroke-linecap="round"/>
</svg>
''',
        width: size * 0.64,
        height: size * 0.64,
      ),
    );
  }
}

class SoukloraDeliveryStrip extends StatelessWidget {
  const SoukloraDeliveryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F3EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: Color(0xFF1F7A4D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivering to',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Your current area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('Now'),
        ),
      ],
    );
  }
}

class SoukloraSearchRow extends StatefulWidget {
  const SoukloraSearchRow({
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
  State<SoukloraSearchRow> createState() => _SoukloraSearchRowState();
}

class SoukloraServiceTile extends StatelessWidget {
  const SoukloraServiceTile({
    super.key,
    required this.name,
    required this.storeCount,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final int storeCount;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 116,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1F7A4D)),
              ),
              const Gap(14),
              Text(
                shopperCategoryLabel(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                storeCount == 1 ? '1 store' : '$storeCount stores',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoukloraSearchRowState extends State<SoukloraSearchRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant SoukloraSearchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search for products, brands and more...',
                prefixIcon: const Icon(Icons.search, size: 28),
                suffixIcon: widget.value.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
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
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Filters',
            onPressed: () async {
              final nextFilters =
                  await showModalBottomSheet<MarketplaceFilters>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) => MarketplaceFilterSheet(
                      initialFilters: widget.filters,
                      options: widget.options,
                    ),
                  );
              if (nextFilters != null) {
                widget.onFiltersChanged(nextFilters);
              }
            },
            icon: Badge(
              isLabelVisible: widget.filters.hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.tune, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class SoukloraSearchSuggestions extends StatelessWidget {
  const SoukloraSearchSuggestions({
    super.key,
    required this.products,
    required this.onSelected,
  });

  final List<Product> products;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final image = productPrimaryImage(product);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(product),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFF4EEE7),
                      child: image == null
                          ? Icon(
                              categoryIcon(product.category),
                              color: const Color(0xFF8F552E),
                            )
                          : AppNetworkImage(url: image, size: 120),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${product.shop.name} - ${money(product.price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SoukloraCategoryBubbles extends StatelessWidget {
  const SoukloraCategoryBubbles({
    super.key,
    required this.selected,
    required this.categories,
    required this.shops,
    required this.onSelected,
  });

  final String selected;
  final List<String> categories;
  final List<Shop> shops;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = ['All', ...categories.take(4), 'More'];
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final name = visible[index];
          final target = name == 'More' ? 'All' : name;
          final selectedItem =
              selected == target || (selected == 'All' && name == 'All');
          final shop = firstWhereOrNull(
            shops,
            (item) => target == 'All' || item.category == target,
          );
          return SoukloraCategoryBubble(
            name: shopperCategoryLabel(name),
            selected: selectedItem,
            shop: shop,
            icon: categoryIcon(name),
            onTap: () => onSelected(target),
          );
        },
      ),
    );
  }
}

class SoukloraStoryStrip extends StatelessWidget {
  const SoukloraStoryStrip({
    super.key,
    required this.stories,
    required this.onOpenShop,
  });

  final List<StoreStory> stories;
  final ValueChanged<Shop> onOpenShop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = stories[index];
          return SoukloraStoryBubble(
            story: story,
            onTap: () => showStoreStorySheet(context, story, onOpenShop),
          );
        },
      ),
    );
  }
}

class SoukloraStoryBubble extends StatelessWidget {
  const SoukloraStoryBubble({
    super.key,
    required this.story,
    required this.onTap,
  });

  final StoreStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF1F7A4D), width: 2),
              ),
              child: StoreAvatar(shop: story.shop, size: 68),
            ),
            const SizedBox(height: 7),
            Text(
              story.shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

void showStoreStorySheet(
  BuildContext context,
  StoreStory story,
  ValueChanged<Shop> onOpenShop,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoreAvatar(shop: story.shop, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          story.expiresInLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      story.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF8F4EC),
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
                const SizedBox(height: 16),
              Text(
                story.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (story.caption != null && story.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(story.caption!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenShop(story.shop);
                  },
                  icon: const Icon(Icons.storefront),
                  label: const Text('Open store'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SoukloraCategoryBubble extends StatelessWidget {
  const SoukloraCategoryBubble({
    super.key,
    required this.name,
    required this.selected,
    required this.shop,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final Shop? shop;
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
                border: Border.all(
                  color: const Color(
                    0xFFA8663A,
                  ).withValues(alpha: selected ? 1 : 0.08),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ClipOval(
                  child: Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFF4EEE7),
                    child: StoreAvatar(
                      shop: shop,
                      size: 60,
                      fallbackIcon: icon,
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

class SoukloraPromoBanner extends StatelessWidget {
  const SoukloraPromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 238,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9DED0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -20,
            top: 20,
            bottom: 0,
            child: _SoukloraBannerIllustration(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE9DED0),
                    Color(0xFFE9DED0),
                    Color(0xFFE9DED0).withValues(alpha: 0.84),
                  ],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 150, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 265),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'WELCOME TO SOUKLORA',
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
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.04,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover quality products from trusted local sellers.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8F552E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                SoukloraDot(active: true),
                SoukloraDot(active: false),
                SoukloraDot(active: false),
                SoukloraDot(active: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SoukloraMarketplaceBanner extends StatefulWidget {
  const SoukloraMarketplaceBanner({
    super.key,
    required this.shopCount,
    required this.productCount,
    required this.verifiedCount,
  });

  final int shopCount;
  final int productCount;
  final int verifiedCount;

  @override
  State<SoukloraMarketplaceBanner> createState() =>
      _SoukloraMarketplaceBannerState();
}

class _SoukloraMarketplaceBannerState extends State<SoukloraMarketplaceBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final slides = [
      _MarketplaceSlide(
        icon: Icons.bolt,
        title: 'One basket, many local stores',
        subtitle: 'Browse stores first, then shop their collections.',
        value: '${widget.shopCount}',
        label: 'stores',
      ),
      _MarketplaceSlide(
        icon: Icons.verified_outlined,
        title: 'Verified partners',
        subtitle: 'Shop from approved local businesses with live storefronts.',
        value: '${widget.verifiedCount}',
        label: 'verified',
      ),
      _MarketplaceSlide(
        icon: Icons.inventory_2_outlined,
        title: 'Fresh products synced in',
        subtitle: 'Collections, prices, and inventory stay connected.',
        value: '${widget.productCount}',
        label: 'items',
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarouselSlider.builder(
            itemCount: slides.length,
            itemBuilder: (context, index, realIndex) {
              return _MarketplaceBannerSlide(slide: slides[index]);
            },
            options: CarouselOptions(
              height: 104,
              viewportFraction: 1,
              enableInfiniteScroll: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 420),
              onPageChanged: (index, reason) {
                if (mounted) {
                  setState(() => _index = index);
                }
              },
            ),
          ),
          const Gap(10),
          Row(
            children: [
              AnimatedSmoothIndicator(
                activeIndex: _index,
                count: slides.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  spacing: 5,
                  expansionFactor: 2.4,
                  activeDotColor: Theme.of(context).colorScheme.primary,
                  dotColor: Colors.black.withValues(alpha: 0.14),
                ),
              ),
              const Spacer(),
              Text(
                '${_index + 1}/${slides.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black54,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSlide {
  const _MarketplaceSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String label;
}

class _MarketplaceBannerSlide extends StatelessWidget {
  const _MarketplaceBannerSlide({required this.slide});

  final _MarketplaceSlide slide;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1F7A4D),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(slide.icon, color: Colors.white),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Gap(3),
              Text(
                slide.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              const Spacer(),
              _MarketplaceMetric(
                value: slide.value,
                label: slide.label,
                icon: slide.icon,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketplaceMetric extends StatelessWidget {
  const _MarketplaceMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1F7A4D)),
        const Gap(7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SoukloraStoreRowCard extends StatelessWidget {
  const SoukloraStoreRowCard({
    super.key,
    required this.shop,
    required this.productCount,
    required this.isFollowing,
    required this.onFollow,
    required this.onOpen,
  });

  final Shop shop;
  final int productCount;
  final bool isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.black54);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  StoreAvatar(shop: shop, size: 68),
                  if (shop.verified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Color(0xFF1F7A4D),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isFollowing
                              ? 'Following store'
                              : 'Follow store',
                          onPressed: onFollow,
                          icon: Icon(
                            isFollowing
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            color: isFollowing
                                ? const Color(0xFF1F7A4D)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        shop.category,
                        if (shop.location.isNotEmpty) shop.location,
                      ].join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StoreStat(
                          icon: Icons.star,
                          label: shop.rating.toStringAsFixed(1),
                        ),
                        _StoreStat(
                          icon: Icons.inventory_2_outlined,
                          label: productCount == 1
                              ? '1 item'
                              : '$productCount items',
                        ),
                        _StoreStat(
                          icon: Icons.delivery_dining,
                          label: shop.delivery,
                        ),
                      ],
                    ),
                    if (shop.story.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        shop.story,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoukloraFeaturedStoreCard extends StatelessWidget {
  const SoukloraFeaturedStoreCard({
    super.key,
    required this.shop,
    required this.products,
    required this.isFollowing,
    required this.onFollow,
    required this.onOpen,
    required this.onOpenProduct,
  });

  final Shop shop;
  final List<Product> products;
  final bool isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onOpen;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoreAvatar(shop: shop, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (shop.verified)
                              const Icon(
                                Icons.verified,
                                size: 17,
                                color: Color(0xFF1F7A4D),
                              ),
                          ],
                        ),
                        Text(
                          '${shop.category} in ${shop.location.isEmpty ? 'Souklora' : shop.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: isFollowing ? 'Following store' : 'Follow store',
                    onPressed: onFollow,
                    icon: Icon(
                      isFollowing
                          ? Icons.notifications_active
                          : Icons.add_alert_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                shop.story,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StoreStat(
                    icon: Icons.star,
                    label: shop.rating.toStringAsFixed(1),
                  ),
                  const SizedBox(width: 8),
                  _StoreStat(
                    icon: Icons.shopping_bag_outlined,
                    label: '${shop.orderCount} orders',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < 3; index += 1) ...[
                      Expanded(
                        child: _StoreProductPreview(
                          product: index < products.length
                              ? products[index]
                              : null,
                        ),
                      ),
                      if (index < 2) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreStat extends StatelessWidget {
  const _StoreStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFE7A72E)),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreProductPreview extends StatelessWidget {
  const _StoreProductPreview({required this.product});

  final Product? product;

  @override
  Widget build(BuildContext context) {
    final current = product;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: (current?.color ?? const Color(0xFF1F7A4D)).withValues(
          alpha: 0.12,
        ),
        child: current == null
            ? const Icon(Icons.inventory_2_outlined, color: Color(0xFF1F7A4D))
            : productPrimaryImage(current) == null
            ? Icon(current.icon, color: current.color, size: 32)
            : AppNetworkImage(url: productPrimaryImage(current)!, size: 180),
      ),
    );
  }
}

class _SoukloraBannerIllustration extends StatelessWidget {
  const _SoukloraBannerIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            child: Container(
              width: 142,
              decoration: const BoxDecoration(
                color: Color(0xFFD7C2AA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(80)),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            child: Container(
              width: 128,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFB78B62),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const Positioned(
            bottom: 42,
            child: Icon(
              Icons.local_florist_outlined,
              size: 98,
              color: Color(0xFF35523A),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFC8A47E),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                  bottom: Radius.circular(18),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.34),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SoukloraDot extends StatelessWidget {
  const SoukloraDot({super.key, required this.active});

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

class SoukloraSectionHeader extends StatelessWidget {
  const SoukloraSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.onViewAll,
  });

  final String title;
  final IconData? icon;
  final VoidCallback? onViewAll;

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, color: const Color(0xFFC8673A), size: 22),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            label: const Text('View all'),
            icon: const Icon(Icons.chevron_right),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8F552E),
            ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.black54),
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
                    onPressed: () =>
                        setState(() => _filters = const MarketplaceFilters()),
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
                  DropdownMenuItem(
                    value: ProductSort.featured,
                    child: Text('Featured first'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.newest,
                    child: Text('Newest'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.priceLow,
                    child: Text('Price: low to high'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.priceHigh,
                    child: Text('Price: high to low'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.rating,
                    child: Text('Highest rated'),
                  ),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    final limitedCount = products
        .where(
          (product) =>
              product.effectiveStock > 0 && product.effectiveStock <= 5,
        )
        .length;

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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Curated live picks from $topStore',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
                  value: products.isEmpty
                      ? '\$0'
                      : '${money(lowestPrice(products))}+',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.black54),
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
      DiscoveryItem(
        'Trending',
        Icons.trending_up,
        '${products.where((product) => product.featured).length} featured',
      ),
      DiscoveryItem(
        'New arrivals',
        Icons.new_releases_outlined,
        '${products.length} live',
      ),
      DiscoveryItem(
        'Best sellers',
        Icons.workspace_premium_outlined,
        'High intent',
      ),
      DiscoveryItem(
        'Local brands',
        Icons.location_city_outlined,
        '${products.map((product) => product.shop.id).toSet().length} stores',
      ),
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
            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FeaturePill(icon: Icons.favorite_border, label: 'Likes'),
                FeaturePill(
                  icon: Icons.bookmark_border,
                  label: 'Save products',
                ),
                FeaturePill(
                  icon: Icons.storefront_outlined,
                  label: 'Follow stores',
                ),
                FeaturePill(
                  icon: Icons.reviews_outlined,
                  label: 'Verified reviews',
                ),
                FeaturePill(icon: Icons.card_giftcard, label: 'Loyalty points'),
                FeaturePill(
                  icon: Icons.notifications_active_outlined,
                  label: 'Drop alerts',
                ),
                FeaturePill(
                  icon: Icons.video_collection_outlined,
                  label: 'Stories and reels',
                ),
                FeaturePill(
                  icon: Icons.verified_outlined,
                  label: 'Trust badges',
                ),
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
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
    final stock = product.effectiveStock;
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
                          const Icon(
                            Icons.verified,
                            size: 15,
                            color: Color(0xFF1F7A4D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
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
                          stock > 0 ? Icons.inventory_2_outlined : Icons.block,
                          size: 15,
                          color: stock > 0
                              ? Colors.black54
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stock > 0 ? '$stock left' : 'Out of stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: stock > 0
                                      ? Colors.black54
                                      : Theme.of(context).colorScheme.error,
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
                          onPressed: stock <= 0 ? null : onAdd,
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
                      errorBuilder: (_, _, _) {
                        return Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: product.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            product.icon,
                            color: Colors.white,
                            size: 38,
                          ),
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
    final outline = Border.all(color: Colors.black.withValues(alpha: 0.10));
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      if (commaIndex != -1) {
        try {
          final bytes = base64Decode(url.substring(commaIndex + 1));
          return Container(
            foregroundDecoration: BoxDecoration(border: outline),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: size,
              errorBuilder: errorBuilder,
            ),
          );
        } catch (error, stackTrace) {
          return errorBuilder?.call(context, error, stackTrace) ??
              Container(color: const Color(0xFFE7F0EA));
        }
      }
    }
    return Container(
      foregroundDecoration: BoxDecoration(border: outline),
      child: CachedNetworkImage(
        imageUrl: optimizedImageUrl(url, size),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: size,
        placeholder: (context, url) => const SoukloraImageShimmer(),
        errorWidget: (context, url, error) =>
            errorBuilder?.call(context, error, StackTrace.current) ??
            Container(color: const Color(0xFFE7F0EA)),
      ),
    );
  }
}

class SoukloraImageShimmer extends StatelessWidget {
  const SoukloraImageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E0D5),
      highlightColor: const Color(0xFFF9F5ED),
      child: Container(color: Colors.white),
    );
  }
}

class SoukloraHomeSkeleton extends StatelessWidget {
  const SoukloraHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E0D5),
      highlightColor: const Color(0xFFF9F5ED),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          children: [
            _SkeletonBlock(height: 116),
            const Gap(14),
            Row(
              children: const [
                Expanded(child: _SkeletonBlock(height: 104)),
                Gap(12),
                Expanded(child: _SkeletonBlock(height: 104)),
              ],
            ),
            const Gap(18),
            for (var index = 0; index < 4; index += 1) ...[
              const _SkeletonBlock(height: 118),
              if (index < 3) const Gap(12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class StoreAvatar extends StatelessWidget {
  const StoreAvatar({
    super.key,
    required this.shop,
    required this.size,
    this.fallbackIcon,
  });

  final Shop? shop;
  final double size;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final current = shop;
    final logoUrl = current?.logoUrl;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        ),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: current?.color ?? const Color(0xFFF4EEE7),
        ),
        child: logoUrl == null || logoUrl.isEmpty
            ? Icon(
                fallbackIcon ?? current?.icon ?? Icons.storefront,
                color: current == null ? const Color(0xFF3B2114) : Colors.white,
                size: size * 0.48,
              )
            : AppNetworkImage(url: logoUrl, size: size.round() * 3),
      ),
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.shop,
    required this.isFollowing,
    required this.onOpenShop,
    required this.onFollow,
  });

  final Shop shop;
  final bool isFollowing;
  final VoidCallback onOpenShop;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenShop,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoreAvatar(shop: shop, size: 42),
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
                          shop.category,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
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
                    tooltip: isFollowing ? 'Following store' : 'Follow store',
                    onPressed: onFollow,
                    icon: Icon(
                      isFollowing
                          ? Icons.notifications_active
                          : Icons.add_alert_outlined,
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
                              child: Icon(
                                product.icon,
                                color: Colors.white,
                                size: 34,
                              ),
                            )
                          : AppNetworkImage(url: product.imageUrl!, size: 260),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton.filledTonal(
                          tooltip: isFavorite
                              ? 'Remove favorite'
                              : 'Save favorite',
                          onPressed: onFavorite,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                          ),
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

class SoukloraDealCard extends StatelessWidget {
  const SoukloraDealCard({
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
    final compareAtPrice = product.compareAtPrice;
    final discountPercent = product.discountPercent;
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
                            child: Icon(
                              product.icon,
                              size: 54,
                              color: const Color(0xFF8F552E),
                            ),
                          )
                        : AppNetworkImage(
                            url: productPrimaryImage(product)!,
                            size: 360,
                          ),
                  ),
                  if (discountPercent != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA8663A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            if (compareAtPrice != null)
                              Text(
                                money(compareAtPrice),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.black45,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFE7A72E),
                        size: 18,
                      ),
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

class SoukloraPopularCategoryTile extends StatelessWidget {
  const SoukloraPopularCategoryTile({
    super.key,
    required this.name,
    required this.shops,
    required this.onTap,
  });

  final String name;
  final List<Shop> shops;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shop = shops.isEmpty ? null : shops.first;
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
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF2EAE1),
                child: Center(
                  child: StoreAvatar(
                    shop: shop,
                    size: 72,
                    fallbackIcon: categoryIcon(name),
                  ),
                ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${shops.length} stores',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
    _selectedVariant =
        firstWhereOrNull(
          widget.product.variants,
          (variant) => variant.stock > 0,
        ) ??
        (widget.product.variants.isEmpty
            ? null
            : widget.product.variants.first);
  }

  void _openReviewDialog() {
    showReviewDialog(context, widget.onReview);
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.product.effectiveStock;
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
                        child: Icon(
                          widget.product.icon,
                          color: widget.product.color,
                          size: 78,
                        ),
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
                  tooltip: widget.isFavorite
                      ? 'Remove favorite'
                      : 'Save favorite',
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
                Tag(
                  label: '${widget.product.rating.toStringAsFixed(1)} rating',
                ),
                Tag(label: '$stock in stock'),
                Tag(label: widget.product.shop.delivery),
                const Tag(label: 'Verified store'),
                const Tag(label: 'Authenticity badge'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
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
              Text(
                'Variants',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in widget.product.variants)
                    ChoiceChip(
                      selected: _selectedVariant?.title == variant.title,
                      onSelected: variant.stock == 0
                          ? null
                          : (_) => setState(() => _selectedVariant = variant),
                      label: Text(
                        '${variant.title} (${variant.stock})',
                        style: TextStyle(
                          decoration: variant.stock == 0
                              ? TextDecoration.lineThrough
                              : null,
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
                  onPressed: (_selectedVariant?.stock ?? stock) == 0
                      ? null
                      : widget.onAddToCart,
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
    required this.collections,
    required this.onSave,
  });

  final ShopDraft store;
  final List<SellerInventoryCollection> collections;
  final Future<void> Function(Map<String, dynamic> payload) onSave;

  @override
  State<StoreOnboardingPanel> createState() => _StoreOnboardingPanelState();
}

class _StoreOnboardingPanelState extends State<StoreOnboardingPanel> {
  final _instagramUrl = TextEditingController();
  final _tiktokUrl = TextEditingController();
  final _websiteUrl = TextEditingController();
  final _shippingPolicy = TextEditingController(
    text: 'Delivery available in selected regions.',
  );
  final _returnPolicy = TextEditingController(
    text: 'Returns accepted according to store policy.',
  );
  String? _logoDataUrl;
  String? _bannerDataUrl;
  bool _logoUploaded = false;
  bool _bannerUploaded = false;
  bool _saved = false;
  late Set<String> _storefrontCollectionIds;

  @override
  void initState() {
    super.initState();
    _logoDataUrl = widget.store.logoUrl;
    _bannerDataUrl = widget.store.bannerUrl;
    _logoUploaded = _logoDataUrl != null && _logoDataUrl!.isNotEmpty;
    _bannerUploaded = _bannerDataUrl != null && _bannerDataUrl!.isNotEmpty;
    _instagramUrl.text = widget.store.instagramUrl ?? '';
    _tiktokUrl.text = widget.store.tiktokUrl ?? '';
    _websiteUrl.text = widget.store.websiteUrl ?? '';
    _storefrontCollectionIds = widget.store.storefrontCollectionIds.toSet();
  }

  @override
  void dispose() {
    _instagramUrl.dispose();
    _tiktokUrl.dispose();
    _websiteUrl.dispose();
    _shippingPolicy.dispose();
    _returnPolicy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave({
      'logoUrl': _logoDataUrl,
      'bannerUrl': _bannerDataUrl,
      'instagramUrl': normalizeSocialUrl(
        _instagramUrl.text,
        SocialPlatform.instagram,
      ),
      'tiktokUrl': normalizeSocialUrl(_tiktokUrl.text, SocialPlatform.tiktok),
      'websiteUrl': normalizeSocialUrl(
        _websiteUrl.text,
        SocialPlatform.website,
      ),
      'storefrontCollectionIds': _storefrontCollectionIds.toList(),
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
      maxWidth: logo ? 384 : 960,
      imageQuality: logo ? 70 : 58,
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
      OnboardingItem(
        'Logo and banner',
        Icons.image_outlined,
        'Upload brand visuals',
        _saved && _logoUploaded && _bannerUploaded,
      ),
      OnboardingItem(
        'Social links',
        Icons.link,
        'Instagram, TikTok, website',
        _saved &&
            (_instagramUrl.text.trim().isNotEmpty ||
                _tiktokUrl.text.trim().isNotEmpty ||
                _websiteUrl.text.trim().isNotEmpty),
      ),
      OnboardingItem(
        'Storefront collections',
        Icons.view_carousel_outlined,
        'Choose up to 5 sections',
        _saved && _storefrontCollectionIds.isNotEmpty,
      ),
      OnboardingItem(
        'Shipping policy',
        Icons.local_shipping_outlined,
        widget.store.hasDelivery ? 'Delivery active' : 'Pickup setup',
        _saved && _shippingPolicy.text.trim().isNotEmpty,
      ),
      OnboardingItem(
        'Return policy',
        Icons.assignment_return_outlined,
        'Set clear rules',
        _saved && _returnPolicy.text.trim().isNotEmpty,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store onboarding',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Build a mini storefront inside Souklora without building a separate app.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            for (final item in items) SetupRow(item: item),
            const SizedBox(height: 8),
            if (_logoDataUrl != null || _bannerDataUrl != null) ...[
              Row(
                children: [
                  StoreMediaPreview(
                    label: 'Logo',
                    imageUrl: _logoDataUrl,
                    icon: Icons.storefront,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StoreMediaPreview(
                      label: 'Banner',
                      imageUrl: _bannerDataUrl,
                      icon: Icons.image_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStoreImage(logo: true),
                    icon: Icon(
                      _logoUploaded ? Icons.check_circle : Icons.upload_file,
                    ),
                    label: Text(
                      _logoUploaded ? 'Logo uploaded' : 'Upload logo',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStoreImage(logo: false),
                    icon: Icon(
                      _bannerUploaded ? Icons.check_circle : Icons.upload_file,
                    ),
                    label: Text(
                      _bannerUploaded ? 'Banner uploaded' : 'Upload banner',
                    ),
                  ),
                ),
              ],
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
              controller: _tiktokUrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'TikTok URL',
                prefixIcon: Icon(Icons.music_note_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _websiteUrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Website URL',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
            if (widget.collections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Storefront collections',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final collection in widget.collections)
                    FilterChip(
                      selected: _storefrontCollectionIds.contains(
                        collection.id,
                      ),
                      showCheckmark: false,
                      label: Text(collection.title),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (_storefrontCollectionIds.length < 5) {
                              _storefrontCollectionIds.add(collection.id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Choose up to 5 storefront collections.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            _storefrontCollectionIds.remove(collection.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
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
    required this.onCreateStory,
    required this.onCreatePlacement,
    required this.onCreateAffiliateLink,
  });

  final int productCount;
  final int orderCount;
  final SellerGrowthStats growthStats;
  final bool synced;
  final List<SellerInventoryProduct> products;
  final Future<void> Function(Map<String, dynamic>) onCreateCampaign;
  final Future<void> Function(Map<String, dynamic>) onCreateStory;
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
          actions: [
            OutlinedButton.icon(
              onPressed: () => showStoreStoryDialog(context, onCreateStory),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('New story'),
            ),
            OutlinedButton.icon(
              onPressed: () => showCampaignDialog(context, onCreateCampaign),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('New campaign'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  showAffiliateDialog(context, onCreateAffiliateLink),
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
          children: [
            FeaturePill(
              icon: synced ? Icons.check_circle : Icons.sync,
              label: synced ? 'Shopify live' : 'Shopify sync',
            ),
            FeaturePill(
              icon: Icons.star_border,
              label: '${growthStats.placements} placements',
            ),
            FeaturePill(
              icon: Icons.ads_click,
              label: '${growthStats.campaigns} campaigns',
            ),
            const FeaturePill(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscriptions',
            ),
            const FeaturePill(
              icon: Icons.verified_user_outlined,
              label: 'Store verification',
            ),
            const FeaturePill(
              icon: Icons.loyalty_outlined,
              label: 'Coupons and VIP tiers',
            ),
            FeaturePill(icon: Icons.percent, label: 'Conversion $conversion'),
          ],
        ),
      ],
    );
  }
}

class DeliveryRulesPanel extends StatelessWidget {
  const DeliveryRulesPanel({super.key, required this.onCreateDeliveryRule});

  final ValueChanged<Map<String, dynamic>> onCreateDeliveryRule;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardPanel(
      title: 'Delivery rules',
      icon: Icons.delivery_dining,
      accent: const Color(0xFF1F7A4D),
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              showDeliveryRuleDialog(context, onCreateDeliveryRule),
          icon: const Icon(Icons.add),
          label: const Text('Add delivery rule'),
        ),
      ],
      children: const [
        FeaturePill(icon: Icons.place_outlined, label: 'By region'),
        FeaturePill(icon: Icons.price_change_outlined, label: 'By item price'),
        FeaturePill(icon: Icons.add_circle_outline, label: 'Multiple rules'),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

class StoreMediaPreview extends StatelessWidget {
  const StoreMediaPreview({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final String? imageUrl;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.0 : 96.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 999 : 8),
          child: SizedBox(
            width: compact ? size : double.infinity,
            height: compact ? size : 96,
            child: imageUrl == null || imageUrl!.isEmpty
                ? Container(
                    color: const Color(0xFFE7F0EA),
                    child: Icon(icon, color: const Color(0xFF1F7A4D)),
                  )
                : AppNetworkImage(url: imageUrl!, size: 360),
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
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
      SellerMetric(
        'Rating',
        rating == 0 ? 'No reviews' : rating.toStringAsFixed(1),
        Icons.star,
      ),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final selected = selectedId == collection.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      selected: selected,
                      leading: Icon(
                        selected ? Icons.folder_open : Icons.folder_outlined,
                      ),
                      title: Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
    final stock = product.effectiveStock;
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
                      errorBuilder: (_, _, _) {
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
                    '$stock in stock - ${product.category}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (product.variants.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final variant in product.variants.take(3))
                          Tag(label: '${variant.title}: ${variant.stock}'),
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
                  tooltip: product.featured
                      ? 'Remove from featured'
                      : 'Feature product',
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
            PopupMenuItem(
              value: 'OUT_FOR_DELIVERY',
              child: Text('Out for delivery'),
            ),
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
    this.logoUrl,
    this.bannerUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.websiteUrl,
    this.storefrontCollectionIds = const [],
    this.shopifyMenu = const ShopifyMenu(),
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Store';
    return Shop(
      id: json['id'] as String? ?? '',
      name: name,
      category: json['category'] as String? ?? 'Store',
      location: json['city'] as String? ?? '',
      story:
          json['story'] as String? ??
          'Shop products directly from this Souklora store.',
      rating: parseDouble(json['rating']),
      color: const Color(0xFF1F7A4D),
      icon: Icons.storefront,
      delivery: json['deliveryLabel'] as String? ?? 'Delivery available',
      minimumOrder: parseDouble(json['minimumOrder']),
      orderCount: parseInt(json['orderCount']),
      verified: json['verified'] == true,
      statusLabel: json['status'] as String? ?? 'DRAFT',
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      instagramUrl: json['instagramUrl'] as String?,
      tiktokUrl: json['tiktokUrl'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      storefrontCollectionIds:
          (json['storefrontCollectionIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(),
      shopifyMenu: ShopifyMenu.fromJson(
        json['shopifyMenu'] as Map<String, dynamic>?,
      ),
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
  final String? logoUrl;
  final String? bannerUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? websiteUrl;
  final List<String> storefrontCollectionIds;
  final ShopifyMenu shopifyMenu;
}

class StoreStory {
  const StoreStory({
    required this.id,
    required this.shop,
    required this.title,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.imageUrl,
  });

  factory StoreStory.fromJson(Map<String, dynamic> json) {
    return StoreStory(
      id: json['id']?.toString() ?? '',
      shop: Shop.fromJson(json['shop'] as Map<String, dynamic>? ?? const {}),
      title: json['title']?.toString() ?? 'New story',
      caption: json['caption']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final Shop shop;
  final String title;
  final String? caption;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  String get expiresInLabel {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inMinutes <= 0) {
      return 'Expiring now';
    }
    if (remaining.inHours < 1) {
      return '${remaining.inMinutes} min left';
    }
    return '${remaining.inHours}h left';
  }
}

class ShopifyMenu {
  const ShopifyMenu({
    this.id = '',
    this.title = '',
    this.handle = '',
    this.items = const [],
  });

  factory ShopifyMenu.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ShopifyMenu();
    }
    return ShopifyMenu(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopifyMenuItem.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String handle;
  final List<ShopifyMenuItem> items;
}

class ShopifyMenuItem {
  const ShopifyMenuItem({
    required this.id,
    required this.title,
    required this.type,
    this.url,
    this.resourceId,
    this.items = const [],
  });

  factory ShopifyMenuItem.fromJson(Map<String, dynamic> json) {
    return ShopifyMenuItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Menu item',
      type: json['type']?.toString() ?? 'HTTP',
      url: json['url']?.toString(),
      resourceId: json['resourceId']?.toString(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopifyMenuItem.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String type;
  final String? url;
  final String? resourceId;
  final List<ShopifyMenuItem> items;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.compareAtPrice,
    required this.shop,
    required this.color,
    required this.icon,
    required this.description,
    required this.rating,
    required this.stock,
    required this.images,
    required this.variants,
    required this.collectionNames,
    required this.collectionIds,
    required this.collectionShopifyIds,
    required this.featured,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final shopJson =
        json['shop'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final images = (json['images'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['url'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    final variants = (json['variants'] as List<dynamic>? ?? [])
        .map((item) => ProductVariant.fromJson(item as Map<String, dynamic>))
        .toList();
    final collectionNames = productCollectionNames(json);
    final collectionIds = productCollectionIds(json);
    final collectionShopifyIds = productCollectionShopifyIds(json);
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Product',
      category: json['category'] as String? ?? 'Shopify',
      price: parseDouble(json['price']),
      compareAtPrice: nullableDouble(json['compareAtPrice']),
      shop: Shop.fromJson(shopJson),
      color: const Color(0xFF1F7A4D),
      icon: Icons.inventory_2,
      description: json['description'] as String? ?? '',
      rating: parseDouble(json['rating']),
      stock: parseInt(json['stock']),
      imageUrl: json['imageUrl'] as String?,
      images: images.isEmpty && json['imageUrl'] != null
          ? [json['imageUrl'] as String]
          : images,
      variants: variants,
      collectionNames: collectionNames,
      collectionIds: collectionIds,
      collectionShopifyIds: collectionShopifyIds,
      featured: json['featured'] == true,
    );
  }

  final String id;
  final String name;
  final String category;
  final double price;
  final double? compareAtPrice;
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
  final List<String> collectionIds;
  final List<String> collectionShopifyIds;
  final bool featured;

  int get effectiveStock {
    if (variants.isEmpty) {
      return stock;
    }
    final variantTotal = variants.fold<int>(
      0,
      (sum, variant) => sum + variant.stock,
    );
    return variantTotal > 0 ? variantTotal : stock;
  }

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

  int? get discountPercent {
    final compareAt = compareAtPrice;
    if (compareAt == null || compareAt <= price || compareAt <= 0) {
      return null;
    }
    return (((compareAt - price) / compareAt) * 100).round();
  }
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
    this.compareAtPrice,
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
      compareAtPrice: nullableDouble(json['compareAtPrice']),
      stock: parseInt(json['stock']),
      option1: json['option1'] as String?,
      option2: json['option2'] as String?,
      option3: json['option3'] as String?,
      sku: json['sku'] as String?,
    );
  }

  final String title;
  final double price;
  final double? compareAtPrice;
  final int stock;
  final String? option1;
  final String? option2;
  final String? option3;
  final String? sku;

  Iterable<String> get searchableOptions sync* {
    for (final value in [title, option1, option2, option3]) {
      final normalized = value?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          normalized.toLowerCase() != 'default title') {
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
    if (inStockOnly && product.effectiveStock <= 0) {
      return false;
    }
    if (size != null &&
        !product.optionTokens.any((token) => token == size!.toLowerCase())) {
      return false;
    }
    if (color != null &&
        !product.optionTokens.any((token) => token == color!.toLowerCase())) {
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
    final shop =
        json['shop'] as Map<String, dynamic>? ?? const <String, dynamic>{};
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
    this.logoUrl,
    this.bannerUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.websiteUrl,
    this.storefrontCollectionIds = const [],
  });

  factory ShopDraft.fromJson(Map<String, dynamic> json) {
    return ShopDraft(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'My Souklora Store',
      category: json['category']?.toString() ?? 'Store',
      city: json['city']?.toString() ?? 'Beirut',
      hasDelivery: (json['deliveryLabel']?.toString() ?? '').isNotEmpty,
      verified: json['verified'] == true,
      status: json['status']?.toString() ?? 'DRAFT',
      logoUrl: json['logoUrl']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      instagramUrl: json['instagramUrl']?.toString(),
      tiktokUrl: json['tiktokUrl']?.toString(),
      websiteUrl: json['websiteUrl']?.toString(),
      storefrontCollectionIds:
          (json['storefrontCollectionIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(),
    );
  }

  final String? id;
  final String name;
  final String category;
  final String city;
  final bool hasDelivery;
  final bool verified;
  final String status;
  final String? logoUrl;
  final String? bannerUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? websiteUrl;
  final List<String> storefrontCollectionIds;

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
    this.compareAtPrice,
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
      compareAtPrice: nullableDouble(json['compareAtPrice']),
      stock: parseInt(json['stock']),
      imageUrl: json['imageUrl'] as String?,
      images: imageRows.isEmpty && json['imageUrl'] != null
          ? [json['imageUrl'] as String]
          : imageRows,
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
  final double? compareAtPrice;
  final int stock;
  final String? imageUrl;
  final List<String> images;
  final List<ProductVariant> variants;
  final bool featured;
  final List<String> collections;
  final List<String> collectionIds;

  int get effectiveStock {
    if (variants.isEmpty) {
      return stock;
    }
    final variantTotal = variants.fold<int>(
      0,
      (sum, variant) => sum + variant.stock,
    );
    return variantTotal > 0 ? variantTotal : stock;
  }
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
  const SellerOrder(
    this.id,
    this.customer,
    this.summary,
    this.status,
    this.total,
  );

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final customer =
        json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final items = json['items'] as List<dynamic>? ?? const [];
    final summary = items.isEmpty
        ? 'No items'
        : items
              .map((item) {
                final row = item as Map<String, dynamic>;
                final product =
                    row['product'] as Map<String, dynamic>? ??
                    const <String, dynamic>{};
                return '${row['quantity'] ?? 1} x ${product['name'] ?? 'Product'}';
              })
              .join(', ');
    return SellerOrder(
      json['id'] as String? ?? '',
      (customer['name'] as String?) ??
          (customer['email'] as String?) ??
          'Customer',
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
  Future<void> Function(Map<String, dynamic>) onSubmit,
) async {
  final title = TextEditingController(text: 'New arrivals just dropped');
  final message = TextEditingController(
    text: 'Shop the latest products before they sell out.',
  );
  var channel = 'PUSH';
  final payload = await showDialog<Map<String, dynamic>>(
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
                  Navigator.pop(context, {
                    'channel': channel,
                    'title': title.text.trim(),
                    'message': message.text.trim(),
                    'audience': 'followers',
                  });
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
  if (payload != null) {
    await onSubmit(payload);
  }
}

Future<void> showStoreStoryDialog(
  BuildContext context,
  Future<void> Function(Map<String, dynamic>) onSubmit,
) async {
  final title = TextEditingController(text: 'Today at our store');
  final caption = TextEditingController();
  final imageUrl = TextEditingController();
  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Post store story'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Story title',
                  prefixIcon: Icon(Icons.auto_stories_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: caption,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Image URL optional',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Stories appear on the shopper homepage for 24 hours.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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
              Navigator.pop(context, {
                'title': title.text.trim(),
                'caption': caption.text.trim().isEmpty
                    ? null
                    : caption.text.trim(),
                'imageUrl': imageUrl.text.trim().isEmpty
                    ? null
                    : imageUrl.text.trim(),
              });
            },
            child: const Text('Post'),
          ),
        ],
      );
    },
  );
  title.dispose();
  caption.dispose();
  imageUrl.dispose();
  if (payload != null) {
    await onSubmit(payload);
  }
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
                          child: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      DropdownMenuItem(
                        value: 'category',
                        child: Text('Category'),
                      ),
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
      DialogField(
        controller: name,
        label: 'Region',
        icon: Icons.place_outlined,
      ),
      DialogField(
        controller: fee,
        label: 'Fee',
        icon: Icons.payments_outlined,
        keyboardType: TextInputType.number,
      ),
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
                      ButtonSegment(
                        value: 'REGION',
                        icon: Icon(Icons.place_outlined),
                        label: Text('Region'),
                      ),
                      ButtonSegment(
                        value: 'PRICE',
                        icon: Icon(Icons.price_change_outlined),
                        label: Text('Item price'),
                      ),
                    ],
                    selected: {ruleType},
                    onSelectionChanged: (value) =>
                        setDialogState(() => ruleType = value.first),
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
                            decoration: const InputDecoration(
                              labelText: 'From price',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxPrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'To price',
                            ),
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
                    'minOrder': byPrice
                        ? double.tryParse(minPrice.text.trim()) ?? 0
                        : null,
                    'maxOrder': byPrice
                        ? double.tryParse(maxPrice.text.trim()) ?? 0
                        : null,
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
      DialogField(
        controller: title,
        label: 'Title',
        icon: Icons.live_tv_outlined,
      ),
      DialogField(
        controller: streamUrl,
        label: 'Stream URL',
        icon: Icons.link,
        keyboardType: TextInputType.url,
      ),
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
  final code = TextEditingController(text: 'SOUKLORA10');
  final commission = TextEditingController(text: '10');
  await showSimpleFormDialog(
    context: context,
    title: 'Add affiliate',
    fields: [
      DialogField(
        controller: creatorName,
        label: 'Creator name',
        icon: Icons.person_outline,
      ),
      DialogField(
        controller: handle,
        label: 'Handle',
        icon: Icons.alternate_email,
      ),
      DialogField(
        controller: code,
        label: 'Code',
        icon: Icons.confirmation_number_outlined,
      ),
      DialogField(
        controller: commission,
        label: 'Commission %',
        icon: Icons.percent,
        keyboardType: TextInputType.number,
      ),
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

String campaignDeliveryMessage(Map<String, dynamic>? delivery) {
  if (delivery == null) {
    return 'Campaign created';
  }
  final followers = parseInt(delivery['followerCount']);
  final devices = parseInt(delivery['deviceCount']);
  final delivered = parseInt(delivery['delivered']);
  if (followers == 0) {
    return 'Campaign created, but this store has no followers yet';
  }
  if (devices == 0) {
    return 'Campaign created for $followers followers, but none have notifications enabled yet';
  }
  return 'Campaign sent to $delivered of $devices follower devices';
}

enum SocialPlatform { instagram, tiktok, website }

String? normalizeSocialUrl(String value, SocialPlatform platform) {
  var trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('@')) {
    trimmed = trimmed.substring(1);
  }
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  if (platform == SocialPlatform.instagram &&
      !lower.contains('.') &&
      !lower.contains('/')) {
    return 'https://instagram.com/$trimmed';
  }
  if (platform == SocialPlatform.tiktok &&
      !lower.contains('.') &&
      !lower.contains('/')) {
    return 'https://www.tiktok.com/@$trimmed';
  }
  return 'https://$trimmed';
}

String? normalizeLebanesePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+961')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('961')) {
    digits = '0${digits.substring(3)}';
  }
  digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  final valid = RegExp(
    r'^0(3[0-9]{6}|(70|71|76|78|79|81)[0-9]{6}|(1|4|5|6|7|8|9)[0-9]{6})$',
  );
  if (!valid.hasMatch(digits)) {
    return null;
  }
  return '+961${digits.substring(1)}';
}

String money(double value) => '\$${value.toStringAsFixed(2)}';

List<Product> searchSuggestions(String query, List<Product> products) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) {
    return const [];
  }

  final scored = <({Product product, int score})>[];
  for (final product in products) {
    var score = 0;
    final name = product.name.toLowerCase();
    final shop = product.shop.name.toLowerCase();
    final category = product.category.toLowerCase();
    final collections = product.collectionNames.map(
      (value) => value.toLowerCase(),
    );

    if (name.startsWith(q)) {
      score += 100;
    } else if (name.contains(q)) {
      score += 70;
    }
    if (shop.startsWith(q)) {
      score += 55;
    } else if (shop.contains(q)) {
      score += 35;
    }
    if (category.startsWith(q)) {
      score += 40;
    } else if (category.contains(q)) {
      score += 24;
    }
    if (collections.any((value) => value.startsWith(q))) {
      score += 34;
    } else if (collections.any((value) => value.contains(q))) {
      score += 18;
    }

    if (score > 0) {
      scored.add((product: product, score: score));
    }
  }

  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return a.product.name.compareTo(b.product.name);
  });

  return scored.map((entry) => entry.product).toList(growable: false);
}

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
  if (name.contains('fashion') ||
      name.contains('clothing') ||
      name.contains('apparel')) {
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
  if (name.contains('food') ||
      name.contains('grocery') ||
      name.contains('bakery')) {
    return Icons.restaurant_outlined;
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
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String authFriendlyError(SoukloraApiException error) {
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
    return 'Gmail rejected the email login. Use the exact Gmail as SMTP_USER and paste SMTP_PASS without spaces.';
  }
  if (error.message.contains('Could not send the password reset email')) {
    return error.message.replaceFirst(RegExp(r'^HTTP \d+:\s*'), '');
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
  return products
      .map((product) => product.price)
      .reduce((a, b) => a < b ? a : b);
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

double? nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text);
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
  return uri
      .replace(
        queryParameters: {...uri.queryParameters, 'width': width.toString()},
      )
      .toString();
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

List<String> productCollectionIds(Map<String, dynamic> json) {
  final rows = json['collections'] as List<dynamic>? ?? const [];
  return rows
      .map((item) => item as Map<String, dynamic>)
      .map((item) => item['collection'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map((collection) => collection['id'] as String? ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
}

List<String> productCollectionShopifyIds(Map<String, dynamic> json) {
  final rows = json['collections'] as List<dynamic>? ?? const [];
  return rows
      .map((item) => item as Map<String, dynamic>)
      .map((item) => item['collection'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .map((collection) => collection['shopifyCollectionId']?.toString() ?? '')
      .toList();
}

List<StorefrontCollectionGroup> storefrontCollectionGroups(
  Shop shop,
  List<Product> products,
) {
  final byId = <String, StorefrontCollectionGroup>{};
  for (final product in products) {
    for (var index = 0; index < product.collectionIds.length; index += 1) {
      final id = product.collectionIds[index];
      final title = index < product.collectionNames.length
          ? product.collectionNames[index]
          : 'Collection';
      final shopifyCollectionId = index < product.collectionShopifyIds.length
          ? product.collectionShopifyIds[index]
          : null;
      final existing = byId[id];
      byId[id] = StorefrontCollectionGroup(
        id: id,
        title: existing?.title ?? title,
        shopifyCollectionId:
            existing?.shopifyCollectionId ??
            (shopifyCollectionId?.isEmpty == true ? null : shopifyCollectionId),
        handle: existing?.handle ?? comparableMenuText(title),
        products: [...?existing?.products, product],
      );
    }
  }
  final allGroups = byId.values.toList()
    ..sort((a, b) => a.title.compareTo(b.title));
  final preferred = <StorefrontCollectionGroup>[];
  for (final id in shop.storefrontCollectionIds.take(5)) {
    final group = byId[id];
    if (group != null) {
      preferred.add(group);
    }
  }
  final remaining = allGroups
      .where((group) => !preferred.any((item) => item.id == group.id))
      .toList();
  return [...preferred, ...remaining];
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
