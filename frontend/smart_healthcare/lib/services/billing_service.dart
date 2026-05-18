import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bill.dart';
import '../utils/jwt_storage.dart';
import 'auth_service.dart';

class BillingService {
  static final String baseUrl = AuthService.baseUrl;

  static Future<List<Bill>> fetchBills() async {
    final token = await JwtStorage.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/billing/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Bill.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching bills: $e');
    }
    return [];
  }

  static Future<String?> payBill(int billId) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/billing/$billId/pay'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to pay bill.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
