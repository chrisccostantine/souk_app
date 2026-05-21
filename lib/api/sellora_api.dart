import 'dart:convert';
import 'dart:io';

class SelloraApi {
  SelloraApi({required String baseUrl, HttpClient? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? (HttpClient()..connectionTimeout = _requestTimeout);

  final String baseUrl;
  final HttpClient _client;
  static const _requestTimeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null && entry.value!.isNotEmpty) entry.key: entry.value!,
      },
    );
  }

  Future<List<dynamic>> fetchShops({bool includeAll = false}) async {
    final body = await _get('/api/shops', {'includeAll': includeAll ? 'true' : null});
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

  Future<Map<String, dynamic>> socialLogin(Map<String, dynamic> payload) async {
    return _post('/api/auth/social', payload);
  }

  Future<Map<String, dynamic>> registerDevice(Map<String, dynamic> payload) async {
    return _post('/api/devices/register', payload);
  }

  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> payload) async {
    return _post('/api/auth/change-password', payload);
  }

  Future<Map<String, dynamic>> forgotPassword(Map<String, dynamic> payload) async {
    try {
      return await _post('/api/auth/forgot-password', payload);
    } on SelloraApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      return _post('/api/auth/reset-password', payload);
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(Map<String, dynamic> payload) async {
    return _post('/api/auth/reset-password/confirm', payload);
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

  Future<Map<String, dynamic>> unfollowShop(String shopId, Map<String, dynamic> payload) async {
    return _delete('/api/shops/$shopId/follow', payload);
  }

  Future<List<dynamic>> fetchCustomerFollows(String email) async {
    final body = await _get('/api/customers/${Uri.encodeComponent(email)}/follows');
    return body['follows'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> trackShopAnalytics(String shopId, Map<String, dynamic> payload) async {
    return _post('/api/shops/$shopId/analytics', payload);
  }

  Future<Map<String, dynamic>> createCampaign(String shopId, Map<String, dynamic> payload) async {
    return _post('/api/shops/$shopId/campaigns', payload);
  }

  Future<Map<String, dynamic>> createPlacement(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/placements', payload);
    return body['placement'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createDeliveryRegion(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/delivery-regions', payload);
    return body['region'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLiveEvent(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/live-events', payload);
    return body['event'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAffiliateLink(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/affiliate-links', payload);
    return body['link'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyShop(String shopId, Map<String, dynamic> payload) async {
    final body = await _patch('/api/admin/shops/$shopId/verification', payload);
    return body['shop'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createReview(String shopId, Map<String, dynamic> payload) async {
    final body = await _post('/api/shops/$shopId/reviews', payload);
    return body['review'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchReviews(String shopId) async {
    final body = await _get('/api/shops/$shopId/reviews');
    return body['reviews'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> favoriteProduct(String productId, Map<String, dynamic> payload) async {
    final body = await _post('/api/products/$productId/favorite', payload);
    return body['favorite'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    final body = await _patch('/api/orders/$orderId/status', {'status': status});
    return body['order'] as Map<String, dynamic>;
  }

  Future<String> generateProductCopy(Map<String, dynamic> payload) async {
    final body = await _post('/api/ai/product-copy', payload);
    return body['description'] as String? ?? '';
  }

  Future<Map<String, dynamic>> generateAdCopy(Map<String, dynamic> payload) async {
    return _post('/api/ai/ad-copy', payload);
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
    final response = await request.close().timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final request = await _client.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> payload) async {
    final request = await _client.patchUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _delete(String path, Map<String, dynamic> payload) async {
    final request = await _client.deleteUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _decode(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final Map<String, dynamic> body;
    try {
      body = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw SelloraApiException(
        response.statusCode,
        'HTTP ${response.statusCode}: ${text.isEmpty ? response.reasonPhrase : text}',
      );
    }
    if (response.statusCode >= 400) {
      final details = body['details'];
      final detailMessage = _formatErrorDetails(details);
      final errorMessage = body['error']?.toString();
      final message =
          (errorMessage == 'Validation failed' ? detailMessage : null) ??
          errorMessage ??
          body['message'] ??
          detailMessage ??
          response.reasonPhrase;
      throw SelloraApiException(response.statusCode, 'HTTP ${response.statusCode}: $message');
    }
    return body;
  }

  String? _formatErrorDetails(dynamic details) {
    if (details is Map) {
      final fieldErrors = details['fieldErrors'];
      if (fieldErrors is Map) {
        final rows = fieldErrors.entries
            .where(
              (entry) =>
                  entry.value is List && (entry.value as List).isNotEmpty,
            )
            .map((entry) => '${entry.key}: ${(entry.value as List).join(', ')}')
            .toList();
        if (rows.isNotEmpty) {
          return rows.join('; ');
        }
      }
      final formErrors = details['formErrors'];
      if (formErrors is List && formErrors.isNotEmpty) {
        return formErrors.join(', ');
      }
      return details.toString();
    }
    if (details is List && details.isNotEmpty) {
      return details.join(', ');
    }
    if (details is String && details.isNotEmpty) {
      return details;
    }
    return null;
  }
}

class SelloraApiException implements Exception {
  const SelloraApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'SelloraApiException($statusCode): $message';
}
