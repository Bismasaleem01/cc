import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/jwt_storage.dart';
import 'auth_service.dart';

class WaitingCall {
  final int appointmentId;
  final String patientEmail;
  final String doctorEmail;
  final DateTime appointmentTime;

  WaitingCall({
    required this.appointmentId,
    required this.patientEmail,
    required this.doctorEmail,
    required this.appointmentTime,
  });

  factory WaitingCall.fromJson(Map<String, dynamic> json) {
    return WaitingCall(
      appointmentId: json['appointment_id'] ?? 0,
      patientEmail: json['patient_email'] ?? '',
      doctorEmail: json['doctor_email'] ?? '',
      appointmentTime:
          DateTime.tryParse(json['appointment_time'] ?? '') ?? DateTime.now(),
    );
  }
}

class VideoService {
  static final String baseUrl = AuthService.baseUrl;

  static Future<String?> markPatientWaiting(int appointmentId) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/video/waiting/$appointmentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to start waiting room.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  static Future<List<WaitingCall>> fetchWaitingCalls() async {
    final token = await JwtStorage.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/video/waiting'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => WaitingCall.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching waiting calls: $e');
    }
    return [];
  }

  static Future<void> clearWaitingCall(int appointmentId) async {
    final token = await JwtStorage.getToken();
    if (token == null) return;

    try {
      await http.delete(
        Uri.parse('$baseUrl/video/waiting/$appointmentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print('Error clearing waiting call: $e');
    }
  }
}
