import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

const sessionStorage = FlutterSecureStorage();
const sessionStorageKey = 'souklora_session_v1';

Map<String, dynamic> encodeSession(AppSession session) {
  return {
    'name': session.name,
    'email': session.email,
    'role': switch (session.role) {
      AccountRole.seller => 'SELLER',
      AccountRole.admin => 'ADMIN',
      AccountRole.customer => 'CUSTOMER',
    },
    'token': session.token,
    'store': session.store == null
        ? null
        : {
            'id': session.store!.id,
            'name': session.store!.name,
            'category': session.store!.category,
            'city': session.store!.city,
            'deliveryLabel': session.store!.hasDelivery
                ? 'Delivery available'
                : '',
            'verified': session.store!.verified,
            'status': session.store!.status,
            'logoUrl': session.store!.logoUrl,
            'bannerUrl': session.store!.bannerUrl,
            'instagramUrl': session.store!.instagramUrl,
            'tiktokUrl': session.store!.tiktokUrl,
            'websiteUrl': session.store!.websiteUrl,
            'storefrontCollectionIds': session.store!.storefrontCollectionIds,
          },
  };
}

AppSession? decodeSession(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final token = json['token']?.toString() ?? '';
    if (token.isEmpty) {
      return null;
    }
    final role = switch (json['role']?.toString()) {
      'SELLER' => AccountRole.seller,
      'ADMIN' => AccountRole.admin,
      _ => AccountRole.customer,
    };
    final storeJson = json['store'] as Map<String, dynamic>?;
    return AppSession(
      name: json['name']?.toString() ?? 'Souklora user',
      email: json['email']?.toString() ?? '',
      role: role,
      token: token,
      store: storeJson == null ? null : ShopDraft.fromJson(storeJson),
    );
  } catch (_) {
    return null;
  }
}

Future<void> saveSession(AppSession session) {
  return sessionStorage.write(
    key: sessionStorageKey,
    value: jsonEncode(encodeSession(session)),
  );
}

Future<AppSession?> restoreSession() async {
  return decodeSession(await sessionStorage.read(key: sessionStorageKey));
}

Future<void> clearSession() {
  return sessionStorage.delete(key: sessionStorageKey);
}
