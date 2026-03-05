class AppModel {
  final String id;
  final String name;
  final String icon;
  final String version;
  final String size;
  final String downloadUrl;
  final String description;
  final String developer;
  final String category;

  const AppModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.version,
    required this.size,
    required this.downloadUrl,
    this.description = '',
    this.developer = '',
    this.category = '',
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Unknown';
    final rawId = json['bundleIdentifier']?.toString() ??
        json['bundle_id']?.toString() ??
        '';
    final id = rawId.isNotEmpty
        ? rawId
        : '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${name.hashCode.abs()}';
    return AppModel(
      id: id,
      name: name,
      icon: json['icon']?.toString() ??
          json['iconURL']?.toString() ??
          json['icon_url']?.toString() ??
          '',
      version: json['version']?.toString() ?? '1.0',
      size: json['size']?.toString() ?? '–',
      downloadUrl: json['downloadURL']?.toString() ??
          json['download_url']?.toString() ??
          json['url']?.toString() ??
          '',
      description: json['description']?.toString() ??
          json['subtitle']?.toString() ??
          '',
      developer: json['developerName']?.toString() ??
          json['developer']?.toString() ??
          '',
      category: json['category']?.toString() ?? 'App',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'version': version,
        'size': size,
        'downloadURL': downloadUrl,
        'description': description,
        'developerName': developer,
        'category': category,
      };
}
