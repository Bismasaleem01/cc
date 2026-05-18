import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants/app_theme.dart';
import '../models/appointment.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../utils/jwt_storage.dart';
import 'appointments_screen.dart';
import 'billing_screen.dart';
import 'chatbot_screen.dart';
import 'doctor_search_screen.dart';
import 'emergency_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'records_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userEmail = 'User';
  String userRole = 'patient';
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppointments();
  }

  Future<void> _loadUserData() async {
    final token = await JwtStorage.getToken();
    if (token == null) return;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = base64Url.normalize(parts[1]);
        final data = jsonDecode(utf8.decode(base64Url.decode(payload)));
        setState(() {
          userEmail = data['sub'] ?? 'User';
          userRole = data['role'] ?? 'patient';
        });
      }
    } catch (e) {
      print("Error decoding token: $e");
    }
  }

  Future<void> _loadAppointments() async {
    final appointments = await AppointmentService.fetchAppointments();
    appointments.sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    if (!mounted) return;
    setState(() => _appointments = appointments);
  }

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String _getFormattedDate() {
    final now = DateTime.now();
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
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _formatAppointment(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}  $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _appointments
        .where((appointment) {
          return appointment.status == 'scheduled' &&
              appointment.appointmentTime.isAfter(DateTime.now());
        })
        .take(3)
        .toList();

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${userEmail.split('@').first}'),
            Text(
              _getFormattedDate(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Healthcare',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Logged in as ${userRole.toUpperCase()}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Upcoming Appointments',
              action: 'View all',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
              ),
            ),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              _EmptyPanel(
                icon: Icons.event_available,
                text: 'No upcoming appointments scheduled.',
              )
            else
              ...upcoming.map(
                (appointment) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.12),
                      child: Icon(
                        appointment.isVideo
                            ? Icons.videocam
                            : Icons.local_hospital,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      userRole == 'doctor'
                          ? appointment.patientEmail
                          : appointment.doctorEmail,
                    ),
                    subtitle: Text(
                      '${appointment.appointmentType.toUpperCase()} • ${_formatAppointment(appointment.appointmentTime)}',
                    ),
                    trailing: Text(
                      appointment.paymentStatus.toUpperCase(),
                      style: TextStyle(
                        color: appointment.isPaid
                            ? AppTheme.primary
                            : AppTheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 720;
                final count = constraints.maxWidth >= 1100
                    ? 4
                    : isDesktop
                    ? 3
                    : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: count,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isDesktop ? 2.6 : 1.25,
                  children: _buildRoleBasedCards(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryDark),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userRole.toUpperCase(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          _DrawerItem(
            Icons.dashboard,
            'Dashboard',
            () => Navigator.pop(context),
          ),
          _DrawerItem(
            Icons.calendar_month,
            'Appointments',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ),
          ),
          _DrawerItem(
            Icons.receipt_long,
            'Billing',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BillingScreen()),
            ),
          ),
          _DrawerItem(
            Icons.folder_shared,
            'Records',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordsScreen()),
            ),
          ),
          _DrawerItem(
            Icons.account_circle,
            'Profile',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Spacer(),
          _DrawerItem(Icons.logout, 'Logout', () => _logout(context)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _buildRoleBasedCards(BuildContext context) {
    final cards = <Widget>[];

    if (userRole == 'patient') {
      cards.addAll([
        _buildDashboardCard(
          context,
          'Find Doctor',
          Icons.manage_search,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DoctorSearchScreen()),
          ),
        ),
        _buildDashboardCard(
          context,
          'AI Assistant',
          Icons.smart_toy,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          ),
        ),
        _buildDashboardCard(
          context,
          'Emergency SOS',
          Icons.emergency,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmergencyScreen()),
          ),
          danger: true,
        ),
      ]);
    }

    cards.addAll([
      _buildDashboardCard(
        context,
        'Appointments',
        Icons.calendar_month,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        ),
      ),
      _buildDashboardCard(
        context,
        'Billing',
        Icons.receipt_long,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingScreen()),
        ),
      ),
      _buildDashboardCard(
        context,
        userRole == 'doctor' ? 'Patient Records' : 'My Records',
        Icons.folder_shared,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecordsScreen()),
        ),
      ),
    ]);

    return cards;
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? AppTheme.danger : AppTheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: danger ? AppTheme.danger : AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
