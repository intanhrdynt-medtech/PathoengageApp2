import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin: kelola link survey per semester. Survey yang aktif muncul sebagai
/// pengingat di dashboard PPDS yang semesternya sesuai (atau semua semester).
class AdminSurveyScreen extends StatefulWidget {
  const AdminSurveyScreen({Key? key}) : super(key: key);

  @override
  State<AdminSurveyScreen> createState() => _AdminSurveyScreenState();
}

class _AdminSurveyScreenState extends State<AdminSurveyScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _surveys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _api.adminGetSurveys();
    if (!mounted) return;
    setState(() {
      _surveys = data;
      _isLoading = false;
    });
  }

  String _semesterLabel(dynamic sem) => sem == null ? 'Semua semester' : 'Semester $sem';

  Future<void> _showForm([Map<String, dynamic>? survey]) async {
    final judulCtrl = TextEditingController(text: survey?['judul'] ?? '');
    final linkCtrl = TextEditingController(text: survey?['link_survey'] ?? '');
    int? semester = survey?['semester_target'];
    if (semester != null && (semester < 1 || semester > 20)) semester = null;
    bool aktif = survey?['is_active'] ?? true;
    bool isSaving = false;
    String errorMsg = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(survey == null ? 'Tambah Survey' : 'Edit Survey',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judulCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul (mis. Survey Evaluasi Semester 3)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkCtrl,
                  decoration: InputDecoration(
                    labelText: 'Link survey (Google Form, dll.)',
                    hintText: 'https://forms.gle/...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: semester,
                  decoration: InputDecoration(
                    labelText: 'Untuk semester',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua semester')),
                    for (int i = 1; i <= 20; i++)
                      DropdownMenuItem<int?>(value: i, child: Text('Semester $i')),
                  ],
                  onChanged: (v) => setDlg(() => semester = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif (tampil di dashboard PPDS)'),
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
                ),
                if (errorMsg.isNotEmpty)
                  Text(errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (judulCtrl.text.trim().isEmpty || linkCtrl.text.trim().isEmpty) {
                        setDlg(() => errorMsg = 'Judul dan link wajib diisi');
                        return;
                      }
                      setDlg(() {
                        isSaving = true;
                        errorMsg = '';
                      });
                      final error = await _api.adminSaveSurvey(survey?['id'], {
                        'judul': judulCtrl.text.trim(),
                        'link_survey': linkCtrl.text.trim(),
                        'semester_target': semester,
                        'is_active': aktif,
                      });
                      if (error == null) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setDlg(() {
                          isSaving = false;
                          errorMsg = error;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey tersimpan ✅')));
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> s, bool value) async {
    final error = await _api.adminSaveSurvey(s['id'], {'is_active': value});
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Survey'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _surveys.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Belum ada survey.\nTambahkan link survey per semester; survey yang aktif muncul sebagai pengingat di dashboard PPDS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
                          ),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _surveys.length,
                      itemBuilder: (ctx, i) {
                        final s = _surveys[i] as Map<String, dynamic>;
                        final aktif = s['is_active'] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            leading: Icon(Icons.assignment, color: aktif ? Colors.orange : Colors.grey),
                            title: Text(s['judul'] ?? '-',
                                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_semesterLabel(s['semester_target']), style: const TextStyle(fontSize: 12)),
                                InkWell(
                                  onTap: () => launchUrl(Uri.parse(s['link_survey']), mode: LaunchMode.externalApplication),
                                  child: Text(s['link_survey'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline)),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(value: aktif, onChanged: (v) => _toggleActive(s, v)),
                                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(s)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
