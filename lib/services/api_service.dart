import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_model.dart';

class ApiService {
  static const _url =
      'https://raw.githubusercontent.com/illyassvvv/MyApps/refs/heads/main/apps.json';

  Future<List<AppModel>> fetchApps() async {
    final res = await http
        .get(Uri.parse(_url))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return _parse(json.decode(res.body));
  }

  List<AppModel> _parse(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(AppModel.fromJson).toList();
    }
    if (data is Map<String, dynamic>) {
      for (final key in ['apps', 'items', 'data', 'results']) {
        if (data[key] is List) {
          return (data[key] as List)
              .whereType<Map<String, dynamic>>()
              .map(AppModel.fromJson)
              .toList();
        }
      }
      if (data.containsKey('name')) return [AppModel.fromJson(data)];
    }
    return [];
  }
}
