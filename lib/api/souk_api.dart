import 'dart:convert';
import 'dart:io';

class SoukApi {
  SoukApi({required String baseUrl, HttpClient? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? HttpClient();

  final String baseUrl;
  final HttpClient _client;

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null && entry.value!.isNotEmpty) entry.key: entry.value!,
      },
    );
  }

  Future<List<dynamic>> fetchShops() async {
    final body = await _get('/api/shops');
    return body['shops'] as List<dynamic>;
  }

  Future<List<dynamic>> fetchProducts({String? query, String? category, String? shopId}) async {
    final body = await _get(
      '/api/products',
      {
        'q': query,
        'category': category,
        'shopId': shopId,
      },
    );
    return body['products'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> signup(Map<String, dynamic> payload) async {
    return _post('/api/auth/signup', payload);
  }

  Future<Map<String, dynamic>> login(Map<String, dynamic> payload) async {
    return _post('/api/auth/login', payload);
  }

  Future<Map<String, dynamic>> createShop(Map<String, dynamic> payload) async {
    final body = await _post('/api/shops', payload);
    return body['shop'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateShopProfile(String shopId, Map<String, dynamic> payload) async {
    final body = await _patch('/api/shops/$shopId/profile', payload);
    return body['shop'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchShopGrowth(String shopId) async {
    return _get('/api/shops/$shopId/growth');
  }

  Future<Map<String, dynamic>> followShop(String shopId, Map<String, dynamic> payload) async {
    return _post('/api/shops/$shopId/follow', payload);
  }

  Future<Map<String, dynamic>> trackShopAnalytics(String shopId, Map<String, dynamic> payload) async {
    return _post('/api/shops/$shopId/analytics', payload);
  }

  Future<Map<String, dynamic>> createCampaign(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/campaigns', payload);
    return body['campaign'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPlacement(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/placements', payload);
    return body['placement'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchShopInventory(String shopId) async {
    return _get('/api/shops/$shopId/inventory');
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) async {
    final body = await _post('/api/products', payload);
    return body['product'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setProductFeatured(String productId, bool featured) async {
    final body = await _patch('/api/products/$productId/featured', {'featured': featured});
    return body['product'] as Map<String, dynamic>;
  }

  Future<String> startShopifyOAuth(Map<String, dynamic> payload) async {
    final body = await _post('/api/shopify/oauth/start', payload);
    return body['installUrl'] as String;
  }

  Future<Map<String, dynamic>> fetchShopifyStatus(String shopId) async {
    return _get('/api/shopify/status', {'shopId': shopId});
  }

  Future<Map<String, dynamic>> syncShopify(String shopId) async {
    return _post('/api/shopify/sync', {'shopId': shopId});
  }

  Future<Map<String, dynamic>> fetchShopifySyncJob(String jobId) async {
    return _get('/api/shopify/sync/$jobId');
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    final body = await _post('/api/orders', payload);
    return body['order'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchOrders({String? customerEmail, String? shopId}) async {
    final body = await _get('/api/orders', {
      'customerEmail': customerEmail,
      'shopId': shopId,
    });
    return body['orders'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String?> query = const {}]) async {
    final request = await _client.getUrl(_uri(path, query));
    final response = await request.close();
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final request = await _client.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> payload) async {
    final request = await _client.patchUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    return _decode(response);
  }

  Future<Map<String, dynamic>> _decode(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final Map<String, dynamic> body;
    try {
      body = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw SoukApiException(
        response.statusCode,
        'HTTP ${response.statusCode}: ${text.isEmpty ? response.reasonPhrase : text}',
      );
    }
    if (response.statusCode >= 400) {
      final message = body['error'] ?? body['message'] ?? body['details'] ?? response.reasonPhrase;
      throw SoukApiException(response.statusCode, 'HTTP ${response.statusCode}: $message');
    }
    return body;
  }
}

class SoukApiException implements Exception {
  const SoukApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'SoukApiException($statusCode): $message';
}
