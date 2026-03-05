class AppModel {
  final String name;
  final String icon;
  final String version;
  final String size;
  final String downloadUrl;
  final String description;
  final String? bundleId;
  final String? developer;
  final String? category;

  AppModel({
    required this.name,
    required this.icon,
    required this.version,
    required this.size,
    required this.downloadUrl,
    this.description = '',
    this.bundleId,
    this.developer,
    this.category,
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      name: json['name']?.toString() ?? 'Unknown App',
      icon: json['icon']?.toString() ?? json['iconURL']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0',
      size: json['size']?.toString() ?? 'Unknown',
      downloadUrl: json['downloadURL']?.toString() ??
          json['download_url']?.toString() ??
          json['url']?.toString() ??
          '',
      description: json['description']?.toString() ??
          json['subtitle']?.toString() ??
          '',
      bundleId: json['bundleIdentifier']?.toString() ??
          json['bundle_id']?.toString(),
      developer: json['developerName']?.toString() ??
          json['developer']?.toString(),
      category: json['category']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'version': version,
        'size': size,
        'downloadURL': downloadUrl,
        'description': description,
        'bundleIdentifier': bundleId,
        'developerName': developer,
        'category': category,
      };
}
