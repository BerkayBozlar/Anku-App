/// `GET /api/clubs` öğesi.
class Club {
  const Club({
    required this.id,
    required this.name,
    this.description,
    this.socialMediaUrl,
    this.authorizedUserName,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      socialMediaUrl: json['socialMediaUrl'] as String?,
      authorizedUserName: json['authorizedUserName'] as String?,
    );
  }

  final int id;
  final String name;
  final String? description;
  final String? socialMediaUrl;
  final String? authorizedUserName;
}
