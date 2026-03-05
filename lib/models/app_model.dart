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

  AppModel({
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
    return AppModel(
      id: json['bundleIdentifier']?.toString() ??
          json['bundle_id']?.toString() ??
          '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().microsecondsSinceEpoch}',
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
}
