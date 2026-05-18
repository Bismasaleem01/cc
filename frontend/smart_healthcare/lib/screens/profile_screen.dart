import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  String _email = '';
  String _role = 'patient';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.fetchProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?['name'] ?? '';
      _specialtyController.text = profile?['specialty'] ?? '';
      _email = profile?['email'] ?? '';
      _role = profile?['role'] ?? 'patient';
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final specialty = _specialtyController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    if (_role == 'doctor' && specialty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specialty is required for doctors.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final error = await AuthService.updateProfile(
      name: name,
      role: _role,
      specialty: _role == 'doctor' ? specialty : null,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Profile updated.')));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    size: 34,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: _email),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'patient', child: Text('Patient')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _role = value);
                  },
                ),
                if (_role == 'doctor') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _specialtyController,
                    decoration: const InputDecoration(
                      labelText: 'Specialty',
                      hintText: 'e.g. Cardiologist',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
    );
  }
}
