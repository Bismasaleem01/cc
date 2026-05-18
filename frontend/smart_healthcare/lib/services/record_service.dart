import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/jwt_storage.dart';
import 'auth_service.dart';

class Record {
  final int id;
  final String patientName;
  final String patientEmail;
  final String title;
  final String description;
  final String fileUrl;
  final String downloadUrl;
  final String date;

  Record({
    required this.id,
    required this.patientName,
    required this.patientEmail,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.downloadUrl,
    required this.date,
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'] ?? 0,
      patientName: json['patient_name'] ?? '',
      patientEmail: json['patient_email'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      fileUrl: json['file_url'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      date: json['uploaded_at'] ?? '',
    );
  }
}

class RecordService {
  static final String baseUrl = AuthService.baseUrl;

  static Future<List<Record>> fetchRecords() async {
    final token = await JwtStorage.getToken();
    if (token == null) return [];

    final url = Uri.parse('$baseUrl/records/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Record.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching records: $e');
    }
    return [];
  }

  static Future<bool> uploadRecord(
    String title,
    String description,
    String fileUrl,
    String patientEmail,
  ) async {
    final token = await JwtStorage.getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/records/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patient_email': patientEmail,
          'title': title,
          'description': description,
          'file_url': fileUrl,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error creating record: $e');
      return false;
    }
  }

  static Future<String?> uploadRecordFile({
    required String title,
    required String description,
    required String patientEmail,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final token = await JwtStorage.getToken();
    if (token == null) return 'You are not logged in.';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/records/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['patient_email'] = patientEmail;
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) return null;
      final data = jsonDecode(body);
      return data['detail']?.toString() ?? 'Upload failed.';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  static Future<String?> fetchDownloadLink(int recordId) async {
    final token = await JwtStorage.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/records/$recordId/download'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['download_url']?.toString();
      }
    } catch (e) {
      print('Error fetching record link: $e');
    }
    return null;
  }
}
