import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/screens/admin_progress_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getUsers(); // fetch all PPDS users
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Color _phaseColor(String? phase) {
    switch (phase) {
      case 'red': return const Color(0xFFE53935);
      case 'yellow': return const Color(0xFFFDD835);
      case 'green': return const Color(0xFF43A047);
      default: return AppColors.primaryPurple;
    }
  }

  String _phaseLabel(String? phase) {
    switch (phase) {
      case 'red': return 'Merah';
      case 'yellow': return 'Kuning';
      case 'green': return 'Hijau';
      default: return 'MKDU';
    }
  }

  void _showAddUserDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final nimCtrl = TextEditingController();
    String errorMsg = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah PPDS Baru',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(errorMsg,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                _dialogField(nameCtrl, 'Nama Lengkap', Icons.person),
                const SizedBox(height: 10),
                _dialogField(nimCtrl, 'NIM', Icons.badge),
                const SizedBox(height: 10),
                _dialogField(emailCtrl, 'Email', Icons.email),
                const SizedBox(height: 10),
                _dialogField(passCtrl, 'Password (min. 6 karakter)', Icons.lock, isPassword: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty ||
                          emailCtrl.text.isEmpty ||
                          passCtrl.text.isEmpty) {
                        setDialogState(() => errorMsg = 'Semua field wajib diisi');
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = '';
                      });
                      final result = await _api.createPpdsUser(
                        emailCtrl.text.trim(),
                        passCtrl.text,
                        nameCtrl.text.trim(),
                        nimCtrl.text.trim(),
                      );
                      setDialogState(() => isLoading = false);
                      if (result != null && result['error'] == null) {
                        if (mounted) Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PPDS berhasil ditambahkan!')));
                      } else {
                        setDialogState(() =>
                            errorMsg = result?['error'] ?? 'Gagal menambahkan user');
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {bool isPassword = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    final nimCtrl = TextEditingController(text: user['nim'] ?? '');
    final semCtrl = TextEditingController(text: user['current_semester']?.toString() ?? '1');
    String selectedPhase = user['phase'] ?? 'MKDU';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Data PPDS',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Nama Lengkap', Icons.person),
                const SizedBox(height: 10),
                _dialogField(nimCtrl, 'NIM', Icons.badge),
                const SizedBox(height: 10),
                _dialogField(semCtrl, 'Semester', Icons.school),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPhase,
                  decoration: InputDecoration(
                    labelText: 'Fase',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MKDU', child: Text('MKDU')),
                    DropdownMenuItem(value: 'red', child: Text('Kalung Merah')),
                    DropdownMenuItem(value: 'yellow', child: Text('Kalung Kuning')),
                    DropdownMenuItem(value: 'green', child: Text('Kalung Hijau')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedPhase = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await _api.updateUser(user['id'], {
                  'full_name': nameCtrl.text.trim(),
                  'nim': nimCtrl.text.trim(),
                  'current_semester': int.tryParse(semCtrl.text) ?? 1,
                  'phase': selectedPhase,
                });
                if (mounted) Navigator.pop(ctx);
                if (ok) {
                  _loadData();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Data PPDS diperbarui!')));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAcademicProfileDialog(Map<String, dynamic> user) {
    final dosenWaliCtrl = TextEditingController(text: user['dosen_wali'] ?? '');
    final pembimbing1Ctrl = TextEditingController(text: user['pembimbing_1'] ?? '');
    final pembimbing2Ctrl = TextEditingController(text: user['pembimbing_2'] ?? '');
    final retrospektifCtrl = TextEditingController(text: user['pembimbing_retrospektif'] ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Profil Akademik: ${user['full_name']}',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(dosenWaliCtrl, 'Dosen Wali', Icons.person),
                const SizedBox(height: 10),
                _dialogField(pembimbing1Ctrl, 'Pembimbing 1', Icons.person_outline),
                const SizedBox(height: 10),
                _dialogField(pembimbing2Ctrl, 'Pembimbing 2', Icons.person_outline),
                const SizedBox(height: 10),
                _dialogField(retrospektifCtrl, 'Pembimbing Retrospektif', Icons.history),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: () async {
                setDialogState(() => isLoading = true);
                final ok = await _api.adminUpdateUserProfile(user['id'], {
                  'dosen_wali': dosenWaliCtrl.text.trim(),
                  'pembimbing_1': pembimbing1Ctrl.text.trim(),
                  'pembimbing_2': pembimbing2Ctrl.text.trim(),
                  'pembimbing_retrospektif': retrospektifCtrl.text.trim(),
                });
                if (mounted) Navigator.pop(ctx);
                if (ok) {
                  _loadData();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Profil Akademik PPDS diperbarui!')));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Gagal memperbarui Profil Akademik.')));
                }
              },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(Map<String, dynamic> user) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final semCtrl = TextEditingController();
    String taskType = 'Tugas Ilmiah';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tambah Tugas untuk ${user['full_name']}',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: taskType,
                  decoration: InputDecoration(
                    labelText: 'Jenis Tugas',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tugas Ilmiah', child: Text('Tugas Ilmiah')),
                    DropdownMenuItem(value: 'Textbook Reading', child: Text('Textbook Reading')),
                    DropdownMenuItem(value: 'Journal Reading', child: Text('Journal Reading')),
                    DropdownMenuItem(value: 'Penelitian', child: Text('Penelitian')),
                    DropdownMenuItem(value: 'Publikasi', child: Text('Publikasi')),
                    DropdownMenuItem(value: 'Etik', child: Text('Etik')),
                  ],
                  onChanged: (val) => setDialogState(() => taskType = val!),
                ),
                const SizedBox(height: 10),
                _dialogField(titleCtrl, 'Judul / Nama Tugas', Icons.title),
                const SizedBox(height: 10),
                _dialogField(descCtrl, 'Deskripsi (opsional)', Icons.description),
                const SizedBox(height: 10),
                _dialogField(semCtrl, 'Target Semester', Icons.school),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (titleCtrl.text.isEmpty) return;
                      setDialogState(() => isLoading = true);
                      final ok = await _api.adminAddTask({
                        'user_id': user['id'],
                        'task_type': taskType,
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'target_semester': int.tryParse(semCtrl.text) ?? 1,
                      });
                      setDialogState(() => isLoading = false);
                      if (mounted) Navigator.pop(ctx);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tugas berhasil ditambahkan!')));
                      }
                    },
              child: const Text('Tambah Tugas'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRotationsDialog(Map<String, dynamic> user) async {
    // Navigate to progress screen on rotations tab
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdminRotationEditScreen(user: user),
      ),
    ).then((_) => _loadData());
  }

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengguna',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Text('Yakin hapus ${user['full_name']}? Semua data terkait akan ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _api.deleteUser(user['id']);
              if (ok && mounted) {
                _loadData();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Pengguna dihapus')));
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddAdminDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String errorMsg = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade50,
                radius: 18,
                child: const Icon(Icons.admin_panel_settings, color: Colors.red, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Tambah Admin Baru',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Admin memiliki akses penuh ke semua data',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (errorMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(errorMsg,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                _dialogField(nameCtrl, 'Nama Lengkap', Icons.person),
                const SizedBox(height: 10),
                _dialogField(emailCtrl, 'Email', Icons.email),
                const SizedBox(height: 10),
                _dialogField(passCtrl, 'Password (min. 6 karakter)', Icons.lock, isPassword: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty ||
                          emailCtrl.text.isEmpty ||
                          passCtrl.text.isEmpty) {
                        setDialogState(() => errorMsg = 'Semua field wajib diisi');
                        return;
                      }
                      if (passCtrl.text.length < 6) {
                        setDialogState(() => errorMsg = 'Password minimal 6 karakter');
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = '';
                      });
                      final token = await _api.getAdminToken();
                      if (token == null) {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = 'Gagal autentikasi';
                        });
                        return;
                      }
                      final result = await _api.createAdminUser(
                        emailCtrl.text.trim(),
                        passCtrl.text,
                        nameCtrl.text.trim(),
                        '-',
                      );
                      setDialogState(() => isLoading = false);
                      if (result != null && result['error'] == null) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Admin baru berhasil ditambahkan! ✅')));
                      } else {
                        setDialogState(() =>
                            errorMsg = result?['error']?.toString() ?? 'Gagal menambahkan admin');
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Tambah Admin'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEvaluatorDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String errorMsg = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal.shade50,
                radius: 18,
                child: const Icon(Icons.rate_review, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Tambah Evaluator',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Evaluator dapat mereview Journal Reading & Penelitian PPDS',
                          style: TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (errorMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(errorMsg,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                _dialogField(nameCtrl, 'Nama Lengkap (misal: Dr. X, Sp.PA)', Icons.person),
                const SizedBox(height: 10),
                _dialogField(emailCtrl, 'Email', Icons.email),
                const SizedBox(height: 10),
                _dialogField(passCtrl, 'Password (min. 6 karakter)', Icons.lock, isPassword: true),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty ||
                          emailCtrl.text.isEmpty ||
                          passCtrl.text.isEmpty) {
                        setDialogState(() => errorMsg = 'Semua field wajib diisi');
                        return;
                      }
                      if (passCtrl.text.length < 6) {
                        setDialogState(() => errorMsg = 'Password minimal 6 karakter');
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = '';
                      });
                      final result = await _api.createUserWithRole(
                        emailCtrl.text.trim(),
                        passCtrl.text,
                        nameCtrl.text.trim(),
                        'penilai',
                      );
                      setDialogState(() => isLoading = false);
                      if (result != null && result['error'] == null) {
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Evaluator baru berhasil ditambahkan! ✅')));
                        _loadData();
                      } else {
                        setDialogState(() =>
                            errorMsg = result?['error']?.toString() ?? 'Gagal menambahkan evaluator');
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Tambah Evaluator'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'admin',
            onPressed: _showAddAdminDialog,
            backgroundColor: Colors.red.shade700,
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
            label: const Text('Tambah Admin', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'evaluator',
            onPressed: _showAddEvaluatorDialog,
            backgroundColor: Colors.teal,
            icon: const Icon(Icons.rate_review, color: Colors.white, size: 18),
            label: const Text('Tambah Evaluator', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'ppds',
            onPressed: _showAddUserDialog,
            backgroundColor: AppColors.primaryPurple,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Tambah PPDS', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: AppColors.textGrey.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('Belum ada PPDS terdaftar',
                          style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _users.length,
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _phaseColor(u['phase']),
                                  radius: 22,
                                  child: Text(
                                    (u['full_name'] as String? ?? '?').isNotEmpty
                                        ? (u['full_name'] as String)[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u['full_name'] ?? '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Poppins',
                                              fontSize: 15)),
                                      Text('NIM: ${u['nim'] ?? '-'} • Sem ${u['current_semester'] ?? '-'}',
                                          style: TextStyle(
                                              fontSize: 12, color: AppColors.textGrey)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _phaseColor(u['phase']).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _phaseLabel(u['phase']),
                                    style: TextStyle(
                                        color: _phaseColor(u['phase']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(u['email'] ?? '-',
                                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                            const SizedBox(height: 10),
                            // Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _actionButton(Icons.bar_chart, 'Progress', Colors.blue,
                                    () => Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => AdminProgressScreen(user: u)))),
                                _actionButton(Icons.assignment_add, 'Tambah Tugas',
                                    Colors.green, () => _showAddTaskDialog(u)),
                                _actionButton(Icons.local_hospital, 'Stase',
                                    Colors.orange, () => _showRotationsDialog(u)),
                                _actionButton(Icons.warning_amber, 'Warning',
                                    Colors.deepOrange, () => _showWarningDialog(u)),
                                _actionButton(Icons.medical_services_outlined, 'Ujian Organ',
                                    Colors.teal, () => _showAddOrganExamDialog(u)),
                                _actionButton(Icons.school, 'Profil Akademik',
                                    Colors.indigo, () => _showEditAcademicProfileDialog(u)),
                                _actionButton(Icons.edit, 'Edit', AppColors.primaryPurple,
                                    () => _showEditUserDialog(u)),
                                _actionButton(Icons.delete_outline, 'Hapus', Colors.red,
                                    () => _confirmDelete(u)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
  // --- Dialog methods ---
  void _showWarningDialog(Map<String, dynamic> user) {
    bool warningActive = user['warning_active'] == true;
    final msgCtrl = TextEditingController(text: user['warning_message'] ?? '');
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set Warning / SP', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Warning Active'),
                value: warningActive,
                activeColor: Colors.red,
                onChanged: (val) => setDialogState(() => warningActive = val),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Pesan Peringatan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                final ok = await _api.adminSetWarning(user['id'], warningActive, msgCtrl.text.trim());
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warning berhasil diupdate!')));
                } else {
                  setDialogState(() => isLoading = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gagal update warning')));
                }
              },
              child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrganExamDialog(Map<String, dynamic> user) {
    final namaUjianCtrl = TextEditingController();
    final organCtrl = TextEditingController();
    final pengujiCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Jadwal Ujian Organ', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(namaUjianCtrl, 'Nama Ujian', Icons.medical_services),
                const SizedBox(height: 10),
                _dialogField(organCtrl, 'Organ (opsional)', Icons.visibility),
                const SizedBox(height: 10),
                _dialogField(pengujiCtrl, 'Penguji', Icons.person_search),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                final ok = await _api.adminAddOrganExam({
                  'user_id': user['id'],
                  'nama_ujian': namaUjianCtrl.text.trim(),
                  'organ': organCtrl.text.trim(),
                  'penguji': pengujiCtrl.text.trim(),
                  'hasil': 'terjadwal',
                });
                if (ok && mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ujian organ berhasil ditambahkan!')));
                } else {
                  setDialogState(() => isLoading = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gagal menambah ujian organ')));
                }
              },
              child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Inline Rotation Edit Screen ───────────────────────────────────────────────

class AdminRotationEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminRotationEditScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AdminRotationEditScreenState createState() => _AdminRotationEditScreenState();
}

class _AdminRotationEditScreenState extends State<AdminRotationEditScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _rotations = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  // Helper method used in dialogs below
  Widget _dialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final data = await _api.getUserProgress(widget.user['id']);
    setState(() {
      _rotations = data?['rotations']?['items'] ?? [];
      _isLoading = false;
    });
  }

  void _showEditRotationDialog(Map<String, dynamic> rot) {
    final hospitalCtrl = TextEditingController(text: rot['hospital_name'] ?? '');
    final deptCtrl = TextEditingController(text: rot['department'] ?? '');
    final cityCtrl = TextEditingController(text: rot['city'] ?? '');
    final supCtrl = TextEditingController(text: rot['supervisor'] ?? '');
    String selectedStatus = rot['status'] ?? 'terjadwal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Stase Luar',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hospitalCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama RS',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deptCtrl,
                  decoration: InputDecoration(
                    labelText: 'Departemen',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityCtrl,
                  decoration: InputDecoration(
                    labelText: 'Kota',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: supCtrl,
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'terjadwal', child: Text('Terjadwal')),
                    DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                    DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedStatus = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await _api.adminUpdateRotation(rot['id'], {
                  'hospital_name': hospitalCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'supervisor': supCtrl.text.trim(),
                  'status': selectedStatus,
                });
                if (mounted) Navigator.pop(ctx);
                if (ok) {
                  _loadProgress();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Stase diperbarui!')));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'selesai': return Colors.green;
      case 'aktif': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: Text(
          'Stase: ${widget.user['full_name']}',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rotations.isEmpty
              ? const Center(child: Text('Tidak ada data stase'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rotations.length,
                  itemBuilder: (ctx, i) {
                    final r = _rotations[i];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(r['status']).withOpacity(0.15),
                          child: Icon(Icons.local_hospital, color: _statusColor(r['status'])),
                        ),
                        title: Text(r['hospital_name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['department'] ?? '-'),
                            if (r['supervisor'] != null)
                              Text('Supervisor: ${r['supervisor']}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(r['status']).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(r['status'] ?? '-',
                                  style: TextStyle(
                                      color: _statusColor(r['status']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showEditRotationDialog(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Edit',
                                    style: TextStyle(
                                        color: AppColors.primaryPurple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

