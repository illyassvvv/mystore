import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_model.dart';

class ApiService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/illyassvvv/MyApps/refs/heads/main/apps.json';

  Future<List<AppModel>> fetchApps() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        return _parseResponse(decoded);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load apps: $e');
    }
  }

  List<AppModel> _parseResponse(dynamic data) {
    if (data is List) {
      return data
          .map((item) => AppModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (data is Map<String, dynamic>) {
      // Try common wrapper keys used in AltStore-style sources
      for (final key in ['apps', 'items', 'data', 'results']) {
        if (data[key] is List) {
          return (data[key] as List)
              .map((item) => AppModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      // If it's a single app object
      if (data.containsKey('name')) {
        return [AppModel.fromJson(data)];
      }
    }
    return [];
  }
}
