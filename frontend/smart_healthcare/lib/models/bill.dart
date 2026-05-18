class Bill {
  final int id;
  final int appointmentId;
  final String patientEmail;
  final String doctorEmail;
  final int amount;
  final String status;
  final String description;
  final DateTime createdAt;
  final DateTime? paidAt;

  Bill({
    required this.id,
    required this.appointmentId,
    required this.patientEmail,
    required this.doctorEmail,
    required this.amount,
    required this.status,
    required this.description,
    required this.createdAt,
    this.paidAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? 0,
      appointmentId: json['appointment_id'] ?? 0,
      patientEmail: json['patient_email'] ?? '',
      doctorEmail: json['doctor_email'] ?? '',
      amount: json['amount'] ?? 0,
      status: json['status'] ?? 'unpaid',
      description: json['description'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.tryParse(json['paid_at']),
    );
  }
}
