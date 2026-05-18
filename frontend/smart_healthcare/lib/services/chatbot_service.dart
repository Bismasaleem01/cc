import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/jwt_storage.dart';
import 'auth_service.dart';

class ChatbotService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<String?> sendMessage(String message) async {
    final token = await JwtStorage.getToken();
    if (token == null) return "Error: Not authenticated.";

    final url = Uri.parse('$baseUrl/chatbot/message');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        return "Error: Could not reach the health assistant. (Status: ${response.statusCode})";
      }
    } catch (e) {
      return "Error: Connection failed. $e";
    }
  }
}
