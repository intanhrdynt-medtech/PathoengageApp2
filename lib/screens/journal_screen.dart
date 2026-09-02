import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Journal Data Model ───────────────────────────────────────────────────────

class JournalData {
  final String title;
  final String? accessUrl;
  final String description;
  final String category;

  const JournalData({
    required this.title,
    this.accessUrl,
    required this.description,
    required this.category,
  });
}

// Starter journals — admin bisa tambah lebih via dashboard
const List<JournalData> kFeaturedJournals = [
  JournalData(
    title: 'Modern Pathology',
    accessUrl: 'https://www.nature.com/modpathol/',
    description: 'Jurnal resmi United States and Canadian Academy of Pathology (USCAP). Fokus pada patologi bedah dan molekuler.',
    category: 'Patologi Bedah',
  ),
  JournalData(
    title: 'American Journal of Surgical Pathology',
    accessUrl: 'https://journals.lww.com/ajsp/pages/default.aspx',
    description: 'Jurnal patologi bedah terkemuka yang memuat artikel diagnostik, ulasan, dan laporan kasus.',
    category: 'Patologi Bedah',
  ),
  JournalData(
    title: 'Human Pathology',
    accessUrl: 'https://www.sciencedirect.com/journal/human-pathology',
    description: 'Jurnal multidisiplin yang mencakup patologi diagnostik dan investigatif pada penyakit manusia.',
    category: 'Patologi Umum',
  ),
  JournalData(
    title: 'Histopathology',
    accessUrl: 'https://onlinelibrary.wiley.com/journal/13652559',
    description: 'Jurnal internasional yang dipublikasikan oleh British Division of the International Academy of Pathology.',
    category: 'Histopatologi',
  ),
  JournalData(
    title: 'Cancer Cytopathology',
    accessUrl: 'https://acsjournals.onlinelibrary.wiley.com/journal/19342640',
    description: 'Jurnal resmi American Society of Cytopathology — fokus pada sitologi kanker.',
    category: 'Sitologi',
  ),
  JournalData(
    title: 'Virchows Archiv',
    accessUrl: 'https://link.springer.com/journal/428',
    description: 'Salah satu jurnal patologi tertua (sejak 1847) yang mencakup patologi diagnostik Eropa.',
    category: 'Patologi Umum',
  ),
];

// ─── Journal Reading Screen ───────────────────────────────────────────────────

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _journalTasks = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final data = await _api.getAcademicTasks();
    setState(() {
      _journalTasks = data.where((t) => t['task_type'] == 'Journal Reading').toList();
      _isLoading = false;
    });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending_verification': return Colors.orange;
      default: return AppColors.textGrey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'completed': return 'Selesai ✓';
      case 'pending_verification': return 'Menunggu Verifikasi';
      default: return 'Belum Dibaca';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'pending_verification': return Icons.hourglass_top;
      default: return Icons.article_outlined;
    }
  }

  void _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak bisa membuka link: $url')),
        );
      }
    }
  }

  // ── Dialog Submit / Edit Resume untuk task Journal ─────────────────────────

  void _showTaskDialog(Map<String, dynamic> task) {
    final status = task['status'] as String?;
    final isDone = task['is_completed'] == true || status == 'completed';
    final isPending = status == 'pending_verification';

    final notesCtrl = TextEditingController(text: task['notes'] ?? '');
    final linkCtrl = TextEditingController(text: task['link_url'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.article, color: AppColors.primaryPurple, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] ?? 'Journal Reading',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (task['description'] != null && task['description'].toString().isNotEmpty)
                              Text(
                                task['description'],
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                                maxLines: 2,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open link if exists
                  if (task['link_url'] != null && task['link_url'].toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(task['link_url']),
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Buka Link Jurnal',
                            style: TextStyle(fontFamily: 'Poppins')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryPurple,
                          side: const BorderSide(color: AppColors.primaryPurple),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],

                  // Show existing notes (read-only when done/pending)
                  if (isDone && task['notes'] != null && task['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Resume Bacaan:',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        task['notes'],
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],

                  // Edit form — show if NOT done (pending or not_started)
                  if (!isDone) ...[
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    if (isPending)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sudah disubmit, menunggu verifikasi admin. Kamu masih bisa edit dan submit ulang.',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Text('Link Jurnal (opsional):',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: linkCtrl,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 12),
                        prefixIcon: const Icon(Icons.link, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text('Resume / Ringkasan Bacaan *',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 4,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tulis poin penting / ringkasan jurnal yang sudah kamu baca...',
                        hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (notesCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Resume tidak boleh kosong!')),
                                  );
                                  return;
                                }
                                setDlg(() => isSubmitting = true);
                                // Update notes
                                final okNotes = await _api.updateAcademicNotes(
                                  task['id'],
                                  'pending_verification',
                                  notesCtrl.text.trim(),
                                );
                                // Update link if provided
                                if (linkCtrl.text.trim().isNotEmpty) {
                                  await _api.updateAcademicEvidence(
                                    task['id'],
                                    'pending_verification',
                                    linkCtrl.text.trim(),
                                  );
                                }
                                setDlg(() => isSubmitting = false);
                                if (mounted) Navigator.pop(ctx);
                                if (okNotes) {
                                  _loadTasks();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Resume berhasil disubmit! Menunggu verifikasi.')),
                                  );
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(isPending ? Icons.refresh : Icons.send, size: 18),
                        label: Text(
                          isPending ? 'Submit Ulang' : 'Submit Resume',
                          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPending ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Featured Journals tab ──────────────────────────────────────────────────

  Widget _buildFeaturedJournals() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kFeaturedJournals.length,
      itemBuilder: (ctx, i) {
        final j = kFeaturedJournals[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.article, color: AppColors.primaryPurple, size: 22),
            ),
            title: Text(
              j.title,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(j.description,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(j.category,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_browser, color: AppColors.primaryPurple),
              tooltip: 'Buka Jurnal',
              onPressed: j.accessUrl != null ? () => _openUrl(j.accessUrl!) : null,
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // ── My Journal Tasks tab ───────────────────────────────────────────────────

  Widget _buildMyTasks() {
    if (_journalTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('Belum ada tugas Journal Reading',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Admin akan menambahkan tugas jurnal untukmu',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textGrey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _journalTasks.length,
      itemBuilder: (ctx, i) {
        final task = _journalTasks[i];
        final status = task['status'] as String?;
        final isDone = task['is_completed'] == true || status == 'completed';
        final isPending = status == 'pending_verification';

        return GestureDetector(
          onTap: () => _showTaskDialog(task),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isDone
                  ? Border.all(color: Colors.green.shade300, width: 1.5)
                  : isPending
                      ? Border.all(color: Colors.orange.shade300, width: 1.5)
                      : null,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_statusIcon(status), color: _statusColor(status), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task['title'] ?? '-',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            )),
                        if (task['description'] != null && task['description'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(task['description'],
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_statusLabel(status),
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            // Edit hint
                            if (!isDone)
                              Text(
                                isPending ? 'Tap untuk edit' : 'Tap untuk submit',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textGrey),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textGrey.withOpacity(0.5),
                  ),
                ],
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
        title: const Text(
          'Journal Reading',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.library_books, size: 18), text: 'Jurnal Unggulan'),
            Tab(icon: Icon(Icons.assignment, size: 18), text: 'Tugas Saya'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFeaturedJournals(),
                  _buildMyTasks(),
                ],
              ),
            ),
    );
  }
}
