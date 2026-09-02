import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';

class AdminProgressScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminProgressScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AdminProgressScreenState createState() => _AdminProgressScreenState();
}

class _AdminProgressScreenState extends State<AdminProgressScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _progress;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final data = await _api.getUserProgress(widget.user['id']);
    setState(() {
      _progress = data;
      _isLoading = false;
    });
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
      case 'red': return 'Kalung Merah';
      case 'yellow': return 'Kalung Kuning';
      case 'green': return 'Kalung Hijau';
      default: return 'MKDU';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed': case 'lulus': return Colors.green;
      case 'pending_verification': return Colors.orange;
      case 'not_started': return Colors.grey;
      default: return Colors.blue;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'completed': return 'Selesai';
      case 'lulus': return 'Lulus';
      case 'pending_verification': return 'Menunggu Verifikasi';
      case 'not_started': return 'Belum Dimulai';
      case 'terjadwal': return 'Terjadwal';
      case 'tidak_lulus': return 'Tidak Lulus';
      default: return status ?? '-';
    }
  }

  Widget _buildProgressBar(int done, int total, Color color) {
    final pct = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$done / $total', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final user = _progress!['user'];
    final comp = _progress!['competencies'];
    final exam = _progress!['exams'];
    final task = _progress!['academic_tasks'];
    final rot = _progress!['rotations'];

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _phaseColor(user['phase']),
                  radius: 24,
                  child: Text(
                    (user['full_name'] as String).isNotEmpty
                        ? (user['full_name'] as String)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['full_name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
                      Text('NIM: ${user['nim'] ?? '-'}',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13, fontFamily: 'Poppins')),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _phaseColor(user['phase']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _phaseLabel(user['phase']),
                          style: TextStyle(
                              color: _phaseColor(user['phase']),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            const Text('Kompetensi', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            _buildProgressBar(comp['completed'], comp['total'], Colors.blue),
            const SizedBox(height: 16),
            const Text('Ujian Lulus', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            _buildProgressBar(exam['passed'], exam['total'], Colors.purple),
            const SizedBox(height: 16),
            const Text('Tugas Akademik', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            _buildProgressBar(task['completed'], task['total'], Colors.green),
            const SizedBox(height: 16),
            const Text('Stase Selesai', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            _buildProgressBar(rot['completed'], rot['total'], Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyTab() {
    final items = (_progress!['competencies']['items'] as List<dynamic>);
    final grouped = <String, List<dynamic>>{};
    for (final c in items) {
      final ph = c['phase_category'] as String? ?? 'other';
      grouped.putIfAbsent(ph, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final phase in ['red', 'yellow', 'green'])
          if (grouped.containsKey(phase)) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _phaseColor(phase).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _phaseLabel(phase),
                style: TextStyle(
                    color: _phaseColor(phase),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins'),
              ),
            ),
            for (final c in grouped[phase]!)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.circle,
                      size: 14, color: _statusColor(c['status'])),
                  title: Text(c['competency_name'] ?? '-',
                      style: const TextStyle(fontSize: 13, fontFamily: 'Poppins')),
                  subtitle: Text(c['organ_system'] ?? '',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(c['status']).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(c['status']),
                      style: TextStyle(
                          color: _statusColor(c['status']),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }

  Widget _buildExamTab() {
    final items = (_progress!['exams']['items'] as List<dynamic>);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final e = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(e['result']).withOpacity(0.15),
              child: Icon(
                e['result'] == 'lulus' ? Icons.check_circle : Icons.schedule,
                color: _statusColor(e['result']),
                size: 20,
              ),
            ),
            title: Text(e['exam_name'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['exam_type'] ?? '-'} • ${_phaseLabel(e['phase_category'])}',
                    style: const TextStyle(fontSize: 12)),
                if (e['score'] != null)
                  Text('Nilai: ${e['score']}',
                      style: const TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(e['result']).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(e['result']),
                style: TextStyle(
                    color: _statusColor(e['result']),
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final titleCtrl = TextEditingController(text: task['title'] ?? '');
    final descCtrl = TextEditingController(text: task['description'] ?? '');
    final semCtrl = TextEditingController(text: (task['target_semester'] ?? '').toString());
    final linkCtrl = TextEditingController(text: task['link_url'] ?? '');
    final notesCtrl = TextEditingController(text: task['notes'] ?? '');
    String selectedType = task['task_type'] ?? 'Tugas Ilmiah';
    String selectedStatus = task['status'] ?? 'not_started';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Tugas Akademik',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
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
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: semCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Semester',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkCtrl,
                  decoration: InputDecoration(
                    labelText: 'Link Referensi (opsional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Catatan / Resume',
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
                    DropdownMenuItem(value: 'not_started', child: Text('Belum Dimulai')),
                    DropdownMenuItem(value: 'pending_verification', child: Text('Menunggu Verifikasi')),
                    DropdownMenuItem(value: 'completed', child: Text('Selesai')),
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
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final ok = await _api.adminUpdateAcademicTask(task['id'], {
                  'task_type': selectedType,
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'target_semester': int.tryParse(semCtrl.text) ?? task['target_semester'],
                  'link_url': linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'status': selectedStatus,
                  'is_completed': selectedStatus == 'completed',
                });

                if (mounted) Navigator.pop(ctx);
                if (ok) {
                  _loadProgress();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tugas akademik berhasil diperbarui!')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTab() {
    final items = (_progress!['academic_tasks']['items'] as List<dynamic>);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final t = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(t['status']).withOpacity(0.15),
              child: Icon(
                t['is_completed'] == true ? Icons.check : Icons.assignment,
                color: _statusColor(t['status']),
                size: 18,
              ),
            ),
            title: Text(t['title'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 13)),
            subtitle: Text('${t['task_type'] ?? '-'} • Sem ${t['target_semester'] ?? '-'}',
                style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(t['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(t['status']),
                    style: TextStyle(
                        color: _statusColor(t['status']),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _showEditTaskDialog(t),
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
    );
  }

  Widget _buildRotationTab() {
    final items = (_progress!['rotations']['items'] as List<dynamic>);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final r = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(r['status']).withOpacity(0.15),
              child: Icon(Icons.local_hospital, color: _statusColor(r['status']), size: 20),
            ),
            title: Text(r['hospital_name'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['department'] ?? '-', style: const TextStyle(fontSize: 12)),
                if (r['supervisor'] != null)
                  Text('Supervisor: ${r['supervisor']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(r['status']).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                r['status'] ?? '-',
                style: TextStyle(
                    color: _statusColor(r['status']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: Text(
          'Progress: ${widget.user['full_name'] ?? '-'}',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Kompetensi'),
            Tab(text: 'Ujian'),
            Tab(text: 'Tugas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _progress == null
              ? const Center(child: Text('Gagal memuat data'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(child: _buildSummaryCard()),
                    _buildCompetencyTab(),
                    _buildExamTab(),
                    _buildTaskTab(),
                  ],
                ),
    );
  }
}
