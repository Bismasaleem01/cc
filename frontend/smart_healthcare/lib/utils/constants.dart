class API {
  static String get BASE_URL {
    final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
    final scheme = Uri.base.scheme == 'http' ? 'http' : 'https';
    final backendPort = Uri.base.port == 8080 ? '8000' : '8443';
    return '$scheme://$host:$backendPort';
  }
}
