import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String _baseUrl = '';
  static String _oneSignalAppId = '';

  static Future<void> loadEnv() async {
    _baseUrl = dotenv.get('API_BASE_URL');
    _oneSignalAppId = dotenv.get('ONE_SIGNAL_ID');
  }

  static String getBaseUrl() => _baseUrl;
  static String getOneSignalAppId() => _oneSignalAppId;
}
