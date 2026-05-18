class Appointment {
  final int id;
  final String patientEmail;
  final String doctorEmail;
  final DateTime appointmentTime;
  final String status;
  final String appointmentType;
  final int billingAmount;
  final String paymentStatus;
  final bool canJoinVideo;
  final String notes;

  Appointment({
    required this.id,
    required this.patientEmail,
    required this.doctorEmail,
    required this.appointmentTime,
    required this.status,
    required this.appointmentType,
    required this.billingAmount,
    required this.paymentStatus,
    required this.canJoinVideo,
    required this.notes,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? 0,
      patientEmail: json['patient_email'] ?? '',
      doctorEmail: json['doctor_email'] ?? '',
      appointmentTime:
          DateTime.tryParse(json['appointment_time'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'scheduled',
      appointmentType: json['appointment_type'] ?? 'video',
      billingAmount: json['billing_amount'] ?? 30,
      paymentStatus: json['payment_status'] ?? 'unpaid',
      canJoinVideo: json['can_join_video'] ?? false,
      notes: json['notes'] ?? '',
    );
  }

  bool get isVideo => appointmentType == 'video';
  bool get isScheduled => status == 'scheduled';
  bool get isPaid => paymentStatus == 'paid';
}
