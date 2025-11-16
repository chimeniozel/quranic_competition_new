class AboutUs {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? whatsappUrl;
  final String? email;
  final String? address;
  final String? website;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? tiktokUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  AboutUs({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.whatsappUrl,
    this.email,
    this.address,
    this.website,
    this.facebookUrl,
    this.instagramUrl,
    this.youtubeUrl,
    this.tiktokUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AboutUs.fromMap(Map<String, dynamic> map) {
    return AboutUs(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      imageUrl: map['image_url'] as String?,
      whatsappUrl: map['whatsapp_url'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      website: map['website'] as String?,
      facebookUrl: map['facebook_url'] as String?,
      instagramUrl: map['instagram_url'] as String?,
      youtubeUrl: map['youtube_url'] as String?,
      tiktokUrl: map['tiktok_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'whatsapp_url': whatsappUrl,
      'email': email,
      'address': address,
      'website': website,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'youtube_url': youtubeUrl,
      'tiktok_url': tiktokUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AboutUs copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    String? whatsappUrl,
    String? email,
    String? address,
    String? website,
    String? facebookUrl,
    String? instagramUrl,
    String? youtubeUrl,
    String? tiktokUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AboutUs(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      whatsappUrl: whatsappUrl ?? this.whatsappUrl,
      email: email ?? this.email,
      address: address ?? this.address,
      website: website ?? this.website,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

