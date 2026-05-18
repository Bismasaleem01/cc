import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../constants/app_theme.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../utils/jwt_storage.dart';
import '../widgets/appointment_card.dart';
import 'billing_screen.dart';
import 'video_call_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final DoctorProfile? selectedDoctor;

  const AppointmentsScreen({super.key, this.selectedDoctor});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment> _appointments = [];
  List<DoctorProfile> _doctors = [];
  bool _isLoading = true;
  bool _openedSelectedDoctor = false;
  String _userEmail = '';
  String _userRole = 'patient';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAppointments();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    await _loadUserFromToken();
    final appointments = await AppointmentService.fetchAppointments();
    final doctors = await AuthService.fetchDoctors();
    appointments.sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _doctors = doctors;
      _isLoading = false;
    });

    if (widget.selectedDoctor != null && !_openedSelectedDoctor) {
      _openedSelectedDoctor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBookingDialog());
    }
  }

  Future<void> _loadUserFromToken() async {
    final token = await JwtStorage.getToken();
    if (token == null) return;

    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = base64Url.normalize(parts[1]);
        final data = jsonDecode(utf8.decode(base64Url.decode(payload)));
        _userEmail = data['sub'] ?? '';
        _userRole = data['role'] ?? 'patient';
      }
    } catch (e) {
      print('Error reading user token: $e');
    }
  }

  Future<void> _showBookingDialog() async {
    final patientController = TextEditingController(text: _userEmail);
    DoctorProfile? selectedDoctor = widget.selectedDoctor;
    final notesController = TextEditingController();
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));
    String selectedType = 'video';
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDateTime() async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDateTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return;

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              );
              if (time == null) return;

              setDialogState(() {
                selectedDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            return AlertDialog(
              title: const Text('Book Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_userRole == 'doctor')
                      TextField(
                        controller: patientController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Patient email',
                        ),
                      ),
                    if (_doctors.isEmpty)
                      const Text(
                        'No doctor profiles are available yet. Ask doctors to register and set their specialty.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedDoctor?.email,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Doctor'),
                        items: _doctors.map((doctor) {
                          return DropdownMenuItem(
                            value: doctor.email,
                            child: Text('${doctor.name} - ${doctor.specialty}'),
                          );
                        }).toList(),
                        onChanged: (email) {
                          setDialogState(() {
                            selectedDoctor = _doctors.firstWhere(
                              (doctor) => doctor.email == email,
                            );
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'video',
                          label: Text('Video'),
                          icon: Icon(Icons.videocam),
                        ),
                        ButtonSegment(
                          value: 'physical',
                          label: Text('Physical'),
                          icon: Icon(Icons.local_hospital),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (selection) {
                        setDialogState(() => selectedType = selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Estimated bill: \$${selectedType == 'video' ? 30 : 50}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(_formatDate(selectedDateTime)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: pickDateTime,
                    ),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (patientController.text.trim().isEmpty ||
                              selectedDoctor == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Patient and doctor are required.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final error =
                              await AppointmentService.createAppointment(
                                patientEmail: patientController.text.trim(),
                                doctorEmail: selectedDoctor!.email,
                                appointmentTime: selectedDateTime,
                                appointmentType: selectedType,
                                notes: notesController.text.trim(),
                              );

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          if (error == null) {
                            _showBookedConfirmation(
                              doctor: selectedDoctor!,
                              patientEmail: patientController.text.trim(),
                              appointmentTime: selectedDateTime,
                              appointmentType: selectedType,
                              notes: notesController.text.trim(),
                            );
                            _loadAppointments();
                          } else {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
                            if (error.toLowerCase().contains('pending bill')) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BillingScreen(),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBookedConfirmation({
    required DoctorProfile doctor,
    required String patientEmail,
    required DateTime appointmentTime,
    required String appointmentType,
    required String notes,
  }) {
    final amount = appointmentType == 'video' ? 30 : 50;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Appointment Booked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookedLine(
              label: 'Doctor',
              value: '${doctor.name} (${doctor.specialty})',
            ),
            _BookedLine(label: 'Patient', value: patientEmail),
            _BookedLine(
              label: 'Type',
              value: appointmentType == 'video'
                  ? 'Video consultation'
                  : 'Physical visit',
            ),
            _BookedLine(
              label: 'Date & time',
              value: _formatDate(appointmentTime),
            ),
            _BookedLine(label: 'Bill', value: '\$$amount'),
            if (notes.isNotEmpty) _BookedLine(label: 'Notes', value: notes),
            const SizedBox(height: 10),
            const Text(
              'Please clear the bill from Billing before booking another appointment.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingScreen()),
              );
            },
            child: const Text('Go to Billing'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(Appointment appointment) async {
    final notesController = TextEditingController(text: appointment.notes);
    DateTime selectedDateTime = appointment.appointmentTime;
    String selectedType = appointment.appointmentType;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDateTime() async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDateTime,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              );
              if (time == null) return;
              setDialogState(() {
                selectedDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            return AlertDialog(
              title: const Text('Edit Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'video',
                          label: Text('Video'),
                          icon: Icon(Icons.videocam),
                        ),
                        ButtonSegment(
                          value: 'physical',
                          label: Text('Physical'),
                          icon: Icon(Icons.local_hospital),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (selection) {
                        setDialogState(() => selectedType = selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Bill: \$${selectedType == 'video' ? 30 : 50}'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(_formatDate(selectedDateTime)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: pickDateTime,
                    ),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final error =
                              await AppointmentService.updateAppointment(
                                id: appointment.id,
                                appointmentTime: selectedDateTime,
                                appointmentType: selectedType,
                                notes: notesController.text.trim(),
                              );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? 'Appointment updated.'),
                            ),
                          );
                          _loadAppointments();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setStatus(Appointment appointment, String status) async {
    final error = await AppointmentService.updateAppointment(
      id: appointment.id,
      status: status,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Appointment $status.')));
    _loadAppointments();
  }

  void _joinVideo(Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          roomId: 'appointment-${appointment.id}',
          appointmentId: appointment.id,
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          _userRole == 'doctor' ? 'Patient Appointments' : 'My Appointments',
        ),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              child: _appointments.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.22,
                        ),
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'No appointments scheduled.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        return AppointmentCard(
                          appointment: _appointments[index],
                          currentUserRole: _userRole,
                          onEdit: () => _showEditDialog(_appointments[index]),
                          onJoinVideo: _appointments[index].isVideo
                              ? () => _joinVideo(_appointments[index])
                              : null,
                          onComplete: _appointments[index].isScheduled
                              ? () => _setStatus(
                                  _appointments[index],
                                  'completed',
                                )
                              : null,
                          onCancel: _appointments[index].isScheduled
                              ? () =>
                                    _setStatus(_appointments[index], 'canceled')
                              : null,
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBookingDialog,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book'),
      ),
    );
  }
}

class _BookedLine extends StatelessWidget {
  final String label;
  final String value;

  const _BookedLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
