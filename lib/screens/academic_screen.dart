import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
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

  final List<Map<String, String>> _textbooks = [
    {
      'title': 'Classification of Tumor',
      'url': 'https://tumourclassification.iarc.who.int/home',
      'image': 'assets/images/classification of tumor.png'
    },
    {
      'title': 'Pathologic Basic of Disease',
      'url': 'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-',
      'image': 'assets/images/Pathologic Basic of Disease.jpg'
    },
    {
      'title': 'Basic Pathology',
      'url': 'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5',
      'image': 'assets/images/Basic Patology.jpg'
    },
    {
      'title': "Enzinger and Weiss's Soft Tissue Tumors",
      'url': 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4',
      'image': 'assets/images/Enzinger and Weiss\'s Soft Tissue Tumors.jpg'
    },
    {
      'title': 'Cibas and Ducatman’s Cytology',
      'url': 'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3',
      'image': 'assets/images/Cibas and Ducatman\'s Cytology.jpg'
    },
    {
      'title': 'Pathology',
      'url': 'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf',
      'image': 'assets/images/Pathology.png'
    },
    {
      'title': "Silva's Diagnostic Renal Pathology",
      'url': 'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984',
      'image': 'assets/images/Silva\'s Diagnostic Renal Pathology.jpg'
    },
    {
      'title': "Weedon's Skin Pathology",
      'url': 'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology',
      'image': 'assets/images/Weedon\'s Skin Pathology.jpg'
    },
  ];

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
                  // Standard Task View Fallback for all categories
                  final tasks = _filterTasks(cat);
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text('Tidak ada tugas di kategori ini',
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
    // Remove the early return for pending_verification so they can edit it


    if (task['task_type'] == 'Textbook Reading' || task['task_type'] == 'Journal Reading') {
      _showNotesDialog(task);
    } else {
      _showFileUpload(task);
    }
  }

  Future<void> _showFileUpload(Map<String, dynamic> task) async {
    final TextEditingController _urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Kirim Bukti Tugas', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
        contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tempel link Google Drive di sini...',
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
              if (_urlController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengirim bukti...')));
              final success = await _api.updateAcademicEvidence(task['id'], 'pending_verification', _urlController.text.trim());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti terkirim. Menunggu verifikasi.')));
                _loadTasks();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim bukti.')));
              }
            },
            child: const Text('Kirim', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotesDialog(Map<String, dynamic> task) async {
    final currentStatus = task['status'] ?? 'not_started';
    final isPending = currentStatus == 'pending_verification';

    final TextEditingController _notesController = TextEditingController(text: task['notes'] ?? '');
    final TextEditingController _urlController = TextEditingController(text: task['link_url'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isPending ? 'Edit Submit' : 'Submit Tugas', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22)),
          contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPending)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Menunggu verifikasi admin. Anda masih bisa mengubah data jika ada revisi.',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.orange)),
                  ),
                const Text('Link Referensi (opsional):', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.link, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (task['link_url'] != null && task['link_url'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(task['link_url']);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Buka Referensi Saat Ini'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple.withOpacity(0.1), foregroundColor: AppColors.primaryPurple, elevation: 0),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Ringkasan / Resume *:', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tulis ringkasan bacaan di sini...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text('Batal', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textGrey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? Colors.orange : AppColors.primaryPurple, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting ? null : () async {
                if (_notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Resume tidak boleh kosong!')));
                  return;
                }
                setDlg(() => isSubmitting = true);
                
                bool successNotes = await _api.updateAcademicNotes(task['id'], 'pending_verification', _notesController.text.trim());
                if (_urlController.text.trim().isNotEmpty) {
                  await _api.updateAcademicEvidence(task['id'], 'pending_verification', _urlController.text.trim());
                }
                
                setDlg(() => isSubmitting = false);
                if (mounted) Navigator.pop(ctx);
                
                if (successNotes) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas berhasil disubmit/diubah!')));
                  _loadTasks();
                }
              },
              child: isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isPending ? 'Simpan Edit' : 'Submit', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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

    final book = _textbooks.firstWhere(
      (b) => b['title'] == task['title'],
      orElse: () => <String, String>{},
    );
    final hasBookImage = book.isNotEmpty && book['image'] != null;

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
              width: 48,
              height: 48,
              padding: hasBookImage ? EdgeInsets.zero : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                image: hasBookImage ? DecorationImage(image: AssetImage(book['image']!), fit: BoxFit.cover) : null,
                boxShadow: hasBookImage ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
              ),
              child: hasBookImage ? null : Icon(icon, color: color, size: 24),
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
