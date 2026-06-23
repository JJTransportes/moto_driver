import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String _baseUrl = '';

  static Future<void> loadEnv() async {
    _baseUrl = dotenv.get('API_BASE_URL');
  }

  static String getBaseUrl() => _baseUrl;
}
