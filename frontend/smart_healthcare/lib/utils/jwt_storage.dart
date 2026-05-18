class JwtStorage {
  static String? _token;

  static Future<void> saveToken(String token) async {
    _token = token;
  }

  static Future<String?> getToken() async {
    return _token;
  }

  static Future<void> deleteToken() async {
    _token = null;
  }
}