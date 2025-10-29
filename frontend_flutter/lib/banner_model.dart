import 'dart:convert';

class ActiveBanner {
  final int id;
  final String? title;
  final String? subtitle;
  final String imageUrl;

  ActiveBanner({
    required this.id,
    this.title,
    this.subtitle,
    required this.imageUrl,
  });

  factory ActiveBanner.fromJson(Map<String, dynamic> json) {
    return ActiveBanner(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      imageUrl: json['image_url'],
    );
  }
}

ActiveBanner parseActiveBanner(String responseBody) {
  final parsed = jsonDecode(responseBody);
  return ActiveBanner.fromJson(parsed);
}