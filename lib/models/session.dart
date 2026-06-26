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
