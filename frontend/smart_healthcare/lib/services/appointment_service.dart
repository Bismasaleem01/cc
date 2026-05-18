import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/appointment.dart';
import '../utils/jwt_storage.dart';
import 'auth_service.dart';

class AppointmentService {
  static final String baseUrl = AuthService.baseUrl;

  static Future<List<Appointment>> fetchAppointments() async {
    final token = await JwtStorage.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Appointment.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching appointments: $e');
    }

    return [];
  }

  static Future<String?> createAppointment({
    required String patientEmail,
    required String doctorEmail,
    required DateTime appointmentTime,
    required String appointmentType,
    required String notes,
  }) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patient_email': patientEmail,
          'doctor_email': doctorEmail,
          'appointment_time': appointmentTime.toIso8601String(),
          'appointment_type': appointmentType,
          'notes': notes.isEmpty ? null : notes,
        }),
      );

      if (response.statusCode == 200) return null;

      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to book appointment.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  static Future<String?> updateAppointment({
    required int id,
    DateTime? appointmentTime,
    String? appointmentType,
    String? status,
    String? notes,
  }) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    final body = <String, dynamic>{};
    if (appointmentTime != null) {
      body['appointment_time'] = appointmentTime.toIso8601String();
    }
    if (appointmentType != null) body['appointment_type'] = appointmentType;
    if (status != null) body['status'] = status;
    if (notes != null) body['notes'] = notes;

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/appointments/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) return null;

      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Unable to update appointment.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
