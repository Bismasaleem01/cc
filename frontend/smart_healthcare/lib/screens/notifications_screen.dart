import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../services/video_service.dart';
import 'video_call_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Appointment> _appointments = [];
  List<WaitingCall> _waitingCalls = [];
  bool _isLoading = true;
  String _userRole = 'patient';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await AuthService.fetchProfile();
    final appointments = await AppointmentService.fetchAppointments();
    final waitingCalls = await VideoService.fetchWaitingCalls();
    appointments.sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _waitingCalls = waitingCalls;
      _userRole = profile?['role'] ?? 'patient';
      _isLoading = false;
    });
  }

  void _joinWaitingCall(WaitingCall call) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          roomId: 'appointment-${call.appointmentId}',
          appointmentId: call.appointmentId,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _declineWaitingCall(WaitingCall call) async {
    await VideoService.clearWaitingCall(call.appointmentId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Call declined.')));
    _load();
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final completed = _appointments
        .where((a) => a.status == 'completed')
        .toList();
    final upcoming = _appointments.where((a) {
      return a.status == 'scheduled' &&
          a.appointmentTime.isAfter(DateTime.now());
    }).toList();
    final missed = _appointments.where((a) {
      return a.status == 'scheduled' &&
          a.isVideo &&
          a.appointmentTime.isBefore(DateTime.now());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 30,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Clinical updates and appointment alerts',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._waitingCalls.map((call) {
                    final isDoctor = _userRole == 'doctor';
                    return _NotificationTile(
                      icon: Icons.ring_volume,
                      color: Colors.red,
                      title: isDoctor
                          ? 'Incoming video consultation'
                          : 'Doctor is ready for video consultation',
                      subtitle: isDoctor
                          ? '${call.patientEmail} is waiting for the appointment scheduled on ${_formatDate(call.appointmentTime)}.'
                          : '${call.doctorEmail} is waiting for your appointment scheduled on ${_formatDate(call.appointmentTime)}.',
                      acceptLabel: 'Accept',
                      onAccept: () => _joinWaitingCall(call),
                      declineLabel: 'Decline',
                      onDecline: () => _declineWaitingCall(call),
                    );
                  }),
                  if (upcoming.isNotEmpty)
                    _NotificationTile(
                      icon: Icons.event_available,
                      color: const Color(0xFF0F766E),
                      title: 'Next appointment',
                      subtitle:
                          'Your next ${upcoming.first.appointmentType} appointment is on ${_formatDate(upcoming.first.appointmentTime)}.',
                    ),
                  ...completed.take(5).map((appointment) {
                    return _NotificationTile(
                      icon: Icons.check_circle,
                      color: Colors.blue,
                      title: 'Appointment done',
                      subtitle:
                          'Completed appointment on ${_formatDate(appointment.appointmentTime)}.',
                    );
                  }),
                  ...missed.take(5).map((appointment) {
                    return _NotificationTile(
                      icon: Icons.phone_missed,
                      color: Colors.red,
                      title: 'Missed video consultation',
                      subtitle:
                          'Video appointment scheduled on ${_formatDate(appointment.appointmentTime)} was missed.',
                    );
                  }),
                  if (_waitingCalls.isEmpty &&
                      upcoming.isEmpty &&
                      completed.isEmpty &&
                      missed.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? acceptLabel;
  final VoidCallback? onAccept;
  final String? declineLabel;
  final VoidCallback? onDecline;

  const _NotificationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.acceptLabel,
    this.onAccept,
    this.declineLabel,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  if (acceptLabel != null || declineLabel != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (declineLabel != null)
                          OutlinedButton(
                            onPressed: onDecline,
                            child: Text(declineLabel!),
                          ),
                        if (acceptLabel != null)
                          ElevatedButton(
                            onPressed: onAccept,
                            child: Text(acceptLabel!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
