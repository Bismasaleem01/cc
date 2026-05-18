import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../utils/jwt_storage.dart';

class AuthService {
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/$'), '');
    }

    final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
    final scheme = Uri.base.scheme == 'http' ? 'http' : 'https';
    final backendPort = Uri.base.port == 8080 ? '8000' : '8443';
    return '$scheme://$host:$backendPort';
  }

  /// Login user
  static Future<String?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];

      // Save token securely
      await JwtStorage.saveToken(token);
      return token;
    } else {
      return null;
    }
  }

  /// Register user
  static Future<String?> register(
    String name,
    String email,
    String password, {
    String role = 'patient',
    String? specialty,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          if (role == 'doctor') 'specialty': specialty,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success (null means no error)
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Registration failed';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  /// Logout user
  static Future<void> logout() async {
    await JwtStorage.deleteToken();
  }

  static Future<Map<String, dynamic>?> fetchProfile() async {
    final token = await JwtStorage.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }

    return null;
  }

  static Future<String?> updateProfile({
    required String name,
    required String role,
    String? specialty,
  }) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'role': role,
          if (specialty != null) 'specialty': specialty,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        if (token is String && token.isNotEmpty) {
          await JwtStorage.saveToken(token);
        }
        return null;
      }
      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to update profile.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  static Future<List<DoctorProfile>> fetchDoctors() async {
    final token = await JwtStorage.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/doctors'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => DoctorProfile.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching doctors: $e');
    }

    return [];
  }

  static Future<String?> updateSpecialty(String specialty) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/auth/me/specialty'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'specialty': specialty}),
      );

      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to update specialty.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
