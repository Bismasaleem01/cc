import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/appointment.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String currentUserRole;
  final VoidCallback? onEdit;
  final VoidCallback? onJoinVideo;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.currentUserRole,
    this.onEdit,
    this.onJoinVideo,
    this.onComplete,
    this.onCancel,
  });

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
    final otherPerson = currentUserRole == 'doctor'
        ? appointment.patientEmail
        : appointment.doctorEmail;

    final statusColor = appointment.status == 'completed'
        ? Colors.blue
        : appointment.status == 'canceled'
        ? Colors.red
        : const Color(0xFF0F766E);
    final canJoinVideo =
        appointment.isVideo &&
        appointment.isScheduled &&
        (appointment.canJoinVideo ||
            !DateTime.now().isBefore(appointment.appointmentTime));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: Icon(
                    currentUserRole == 'doctor'
                        ? Icons.person
                        : Icons.medical_services,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherPerson,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(appointment.appointmentTime),
                        style: const TextStyle(color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _ChipLabel(
                            icon: appointment.isVideo
                                ? Icons.videocam
                                : Icons.local_hospital,
                            text: appointment.isVideo
                                ? 'Video call'
                                : 'Physical visit',
                          ),
                          _ChipLabel(
                            icon: Icons.payments,
                            text: '\$${appointment.billingAmount}',
                          ),
                          _ChipLabel(
                            icon: appointment.isPaid
                                ? Icons.verified
                                : Icons.pending,
                            text: appointment.isPaid ? 'Paid' : 'Unpaid',
                          ),
                        ],
                      ),
                      if (appointment.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          appointment.notes,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onJoinVideo != null && appointment.isScheduled)
                  OutlinedButton.icon(
                    onPressed: canJoinVideo ? onJoinVideo : null,
                    icon: const Icon(Icons.video_call),
                    label: Text(canJoinVideo ? 'Join' : 'Join locked'),
                  ),
                if (appointment.isScheduled)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Edit'),
                  ),
                if (onComplete != null)
                  OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                if (onCancel != null)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChipLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
