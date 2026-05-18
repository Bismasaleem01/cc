class DoctorProfile {
  final String name;
  final String email;
  final String specialty;

  DoctorProfile({
    required this.name,
    required this.email,
    required this.specialty,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      name: json['name'] ?? 'Doctor',
      email: json['email'] ?? '',
      specialty: json['specialty'] ?? 'General Practitioner',
    );
  }

  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'DR';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
