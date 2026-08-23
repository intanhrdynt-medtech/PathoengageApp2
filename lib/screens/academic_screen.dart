import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class AcademicScreen extends StatefulWidget {
  const AcademicScreen({super.key});
  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Sesuai requirement: 3 pilar tugas akademik + tugas tambahan
  final List<String> _categories = ['Semua', 'Textbook Reading', 'Journal Reading', 'Tugas Ilmiah', 'Penelitian', 'Publikasi', 'Etik'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTasks() async {
    final data = await _api.getAcademicTasks();
    setState(() {
      _tasks = data;
      _isLoading = false;
    });
  }

  List<dynamic> _filterTasks(String category) {
    if (category == 'Semua') return _tasks;
    return _tasks.where((t) => t['task_type'] == category).toList();
  }

  Color _getTaskColor(int? semester) {
    if (semester == 1) return Colors.red.shade600;
    if (semester == 4) return Colors.orange.shade600;
    if (semester == 7 || semester == 8) return Colors.green.shade600;
    return AppColors.primaryPurple;
  }

  IconData _getTaskIcon(String? type) {
    switch (type) {
      case 'Textbook Reading': return Icons.menu_book;
      case 'Journal Reading': return Icons.article;
      case 'Tugas Ilmiah': return Icons.assignment_ind;
      case 'Penelitian': return Icons.science;
      case 'Etik': return Icons.gavel;
      case 'Publikasi': return Icons.publish;
      default: return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Tugas Akademik', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accentRed,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: TabBarView(
                controller: _tabController,
                children: _categories.map((cat) {
                  final tasks = _filterTasks(cat);
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text('Tidak ada tugas di kategori ini',
                              style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (ctx, i) => InkWell(
                        onTap: () => _handleTaskTap(tasks[i]),
                        child: _buildTaskCard(tasks[i])),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _handleTaskTap(Map<String, dynamic> task) async {
    final currentStatus = task['status'] ?? 'not_started';
    final isDone = task['is_completed'] == true;
    
    if (isDone || currentStatus == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas ini sudah selesai.')));
      return;
    }
    if (currentStatus == 'pending_verification') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menunggu verifikasi admin.')));
      return;
    }

    if (task['task_type'] == 'Textbook Reading' || task['task_type'] == 'Journal Reading') {
      _showNotesDialog(task);
    } else {
      _showFileUpload(task);
    }
  }

  Future<void> _showFileUpload(Map<String, dynamic> task) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final mockUrl = 'https://storage.pathoengage.com/evidence/${file.name}';
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunggah dokumen...')));
        
        final success = await _api.updateAcademicEvidence(task['id'], 'pending_verification', mockUrl);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen diunggah. Menunggu verifikasi.')));
          _loadTasks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengunggah dokumen.')));
        }
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
  }

  Future<void> _showNotesDialog(Map<String, dynamic> task) async {
    final TextEditingController _notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Submit Notes', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22)),
        contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (task['link_url'] != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(task['link_url']);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Buka Referensi Jurnal/Buku', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            if (task['link_url'] != null) const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis ringkasan / resume bacaan di sini...',
                hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: Text('Batal', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textGrey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_notesController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyimpan notes...')));
              final success = await _api.updateAcademicNotes(task['id'], 'pending_verification', _notesController.text.trim());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes berhasil disubmit.')));
                _loadTasks();
              }
            },
            child: const Text('Submit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isDone = task['is_completed'] == true;
    final color = _getTaskColor(task['target_semester']);
    final icon = _getTaskIcon(task['task_type']);
    final deadline = task['deadline'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(task['deadline']))
        : null;
    final isOverdue = deadline != null &&
        !isDone &&
        DateTime.parse(task['deadline']).isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOverdue ? AppColors.accentRed.withOpacity(0.5) : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(task['title'] ?? '-',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: isDone ? TextDecoration.lineThrough : null)),
                      ),
                      if (isDone)
                        const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 20),
                    ],
                  ),
                  if (task['description'] != null && task['description'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(task['description'],
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(task['task_type'] ?? '-',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      ),
                      if (deadline != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 11,
                            color: isOverdue ? AppColors.accentRed : AppColors.textGrey),
                        const SizedBox(width: 3),
                        Text(deadline,
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: isOverdue ? AppColors.accentRed : AppColors.textGrey,
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ],
                  ),
                  if (task['status'] == 'pending_verification') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top, size: 12, color: AppColors.warningOrange),
                          const SizedBox(width: 4),
                          Text('Sedang Verifikasi', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.warningOrange, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
