import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import '../constants/app_theme.dart';
import '../services/record_service.dart';
import '../utils/jwt_storage.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<Record> _records = [];
  bool _isLoading = true;
  String _userEmail = '';
  String _userRole = 'patient';

  @override
  void initState() {
    super.initState();
    _loadUserAndRecords();
  }

  Future<void> _loadUserAndRecords() async {
    final token = await JwtStorage.getToken();
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          String normalized = base64Url.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final data = jsonDecode(resp);
          _userEmail = data['sub'] ?? '';
          _userRole = data['role'] ?? 'patient';
        }
      } catch (_) {}
    }

    await _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    final records = await RecordService.fetchRecords();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  void _showUploadDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedFileName;
    Uint8List? selectedFileBytes;
    bool isReadingFile = false;
    bool isUploading = false;
    double uploadProgress = 0.0;

    Future<void> pickFile(StateSetter setDialogState) async {
      final input = html.FileUploadInputElement()
        ..accept = '.pdf,.png,.jpg,.jpeg,.doc,.docx'
        ..style.display = 'none';
      html.document.body?.append(input);
      final change = input.onChange.first;
      input.click();
      await change;
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      input.remove();
      if (file == null) {
        setDialogState(() {
          selectedFileName = null;
          selectedFileBytes = null;
          isReadingFile = false;
        });
        return;
      }
      setDialogState(() {
        selectedFileName = file.name;
        selectedFileBytes = null;
        isReadingFile = true;
      });

      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String && result.contains(',')) {
          final base64Payload = result.split(',').last;
          completer.complete(base64Decode(base64Payload));
        } else {
          completer.completeError('Could not read selected file.');
        }
      });
      reader.onError.listen(
        (_) => completer.completeError('File read failed.'),
      );
      reader.readAsDataUrl(file);

      try {
        final bytes = await completer.future;
        setDialogState(() {
          selectedFileName = file.name;
          selectedFileBytes = bytes;
          isReadingFile = false;
        });
      } catch (e) {
        setDialogState(() {
          selectedFileBytes = null;
          isReadingFile = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Upload to Supabase Storage'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Files will be securely stored in your private Supabase Storage bucket.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Record Title (e.g. Blood Test)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isUploading || isReadingFile
                        ? null
                        : () => pickFile(setDialogState),
                    icon: Icon(
                      selectedFileName == null
                          ? Icons.attach_file
                          : Icons.check_circle,
                    ),
                    label: Text(
                      selectedFileName == null
                          ? 'Choose medical file'
                          : selectedFileName!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isReadingFile
                            ? 'Reading file: $selectedFileName'
                            : 'Selected file: $selectedFileName',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isUploading)
                    Column(
                      children: [
                        LinearProgressIndicator(value: uploadProgress),
                        const SizedBox(height: 8),
                        Text(
                          'Uploading to Supabase Storage... ${(uploadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                if (!isUploading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                if (!isUploading)
                  ElevatedButton(
                    onPressed: isReadingFile
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a record title.'),
                                ),
                              );
                              return;
                            }
                            if (selectedFileName == null ||
                                selectedFileBytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please choose a file and wait until it is ready.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isUploading = true);
                            setDialogState(() => uploadProgress = 0.35);
                            final error = await RecordService.uploadRecordFile(
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              patientEmail: _userEmail,
                              fileName: selectedFileName!,
                              bytes: selectedFileBytes!,
                            );
                            setDialogState(() => uploadProgress = 1.0);

                            Navigator.pop(context);

                            if (error == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Uploaded to Supabase Storage.',
                                  ),
                                ),
                              );
                              _fetchRecords();
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                    child: Text(isReadingFile ? 'Preparing...' : 'Upload'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSecureLink(Record record) {
    final visibleLink = record.downloadUrl.isNotEmpty
        ? record.downloadUrl
        : record.fileUrl;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Secure Record Link'),
        content: SelectableText(visibleLink),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: visibleLink));
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Secure link copied.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
          ),
          if (record.downloadUrl.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                html.window.open(record.downloadUrl, '_blank');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_userRole == 'doctor' ? 'Patient Records' : 'My Records'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No records found in Supabase Storage.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final r = _records[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.cloud_done,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_userRole == 'doctor') ...[
                          Text(
                            'Patient: ${r.patientName.isEmpty ? r.patientEmail : r.patientName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          Text(
                            r.patientEmail,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(r.description),
                        const SizedBox(height: 4),
                        Text(
                          'Storage path: ${r.fileUrl}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: () => _showSecureLink(r),
                      icon: const Icon(Icons.lock, size: 16),
                      label: const Text('View Link'),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: _userRole == 'patient'
          ? FloatingActionButton.extended(
              onPressed: _showUploadDialog,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload'),
            )
          : null,
    );
  }
}
