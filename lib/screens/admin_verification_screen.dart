import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/academic_task_url.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({Key? key}) : super(key: key);

  @override
  _AdminVerificationScreenState createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _pendingItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _api.getPendingVerifications();
    
    // Fetch pending journals and map them to the same format
    final pendingJournalsRaw = await _api.getAdminJournalReadings('pending');
    final pendingJournals = pendingJournalsRaw.map((j) => {
      'id': j['id'],
      'type_category': 'journal',
      'user_name': j['penulis'] ?? 'Unknown',
      'title': j['judul'] ?? '-',
      'notes': 'Jurnal: ${j['nama_jurnal'] ?? '-'} | Pembimbing: ${j['pembimbing'] ?? '-'}',
      'evidence_url': j['bukti_url'],
    }).toList();

    setState(() {
      _pendingItems = [...items, ...pendingJournals];
      _isLoading = false;
    });
  }

  Future<void> _verifyItem(String typeCategory, int id, String action) async {
    bool success = false;
    if (typeCategory == 'journal') {
      // Backend expects 'approve' or 'reject' as action
      success = await _api.adminReviewJournal(id, action, 'Verifikasi dari Admin Dashboard');
    } else {
      success = await _api.verifyTask(typeCategory, id, action);
    }

    if (success) {
      if (mounted) {
        final msg = action == 'approve' ? 'Berhasil diverifikasi! ✅' : 'Pengajuan ditolak ❌';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        _loadData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal memproses permintaan')));
      }
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'exam': return Icons.quiz;
      case 'academic': return Icons.assignment;
      case 'competency': return Icons.star;
      case 'journal': return Icons.menu_book;
      default: return Icons.task;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'exam': return Colors.purple;
      case 'academic': return Colors.blue;
      case 'competency': return Colors.orange;
      case 'journal': return Colors.indigo;
      default: return AppColors.primaryPurple;
    }
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'exam': return 'Ujian';
      case 'academic': return 'Tugas Akademik';
      case 'competency': return 'Kompetensi';
      case 'journal': return 'Journal Reading';
      default: return category ?? '-';
    }
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    final catColor = _getCategoryColor(item['type_category']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: catColor.withOpacity(0.15),
              radius: 18,
              child: Icon(_getCategoryIcon(item['type_category']), color: catColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Detail Pengajuan',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.person, 'PPDS', item['user_name'] ?? '-'),
            const SizedBox(height: 8),
            _detailRow(Icons.category, 'Kategori', _getCategoryLabel(item['type_category'])),
            const SizedBox(height: 8),
            if (item['title'] != null)
              _detailRow(Icons.title, 'Judul', item['title']),
            if (item['exam_name'] != null)
              _detailRow(Icons.quiz, 'Ujian', item['exam_name']),
            if (item['competency_name'] != null)
              _detailRow(Icons.star, 'Kompetensi', item['competency_name']),
            if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailRow(Icons.notes, 'Catatan', item['notes']),
            ],
            const SizedBox(height: 16),
            if (item['document_proof_url'] != null || item['evidence_url'] != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = (item['document_proof_url'] ?? item['evidence_url']) as String?;
                    if (url == null || !isUsableEvidenceUrl(url)) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Link bukti tidak valid atau belum tersedia.')),
                        );
                      }
                      return;
                    }

                    try {
                      final uri = Uri.parse(url);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Tidak bisa membuka bukti: $url')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Buka Link Lampiran (Drive)'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 6),
                    Text('Tidak ada lampiran bukti', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _verifyItem(item['type_category'], item['id'], 'reject');
            },
            child: const Text('Tolak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _verifyItem(item['type_category'], item['id'], 'approve');
            },
            child: const Text('Setujui ✓'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 72, color: Colors.green.withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text('Semua pengajuan sudah diproses!',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Tidak ada yang menunggu verifikasi',
                          style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingItems.length,
                  itemBuilder: (context, index) {
                    final item = _pendingItems[index];
                    final catColor = _getCategoryColor(item['type_category']);
                    String title = item['title'] ??
                        item['exam_name'] ??
                        item['competency_name'] ??
                        'Item';

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: catColor.withOpacity(0.15),
                              radius: 22,
                              child: Icon(_getCategoryIcon(item['type_category']),
                                  color: catColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                          fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text('PPDS: ${item['user_name'] ?? '-'}',
                                      style: TextStyle(
                                          fontSize: 12, color: AppColors.textGrey)),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getCategoryLabel(item['type_category']),
                                      style: TextStyle(
                                          color: catColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _showDetailsDialog(item),
                              child: const Text('Periksa',
                                  style: TextStyle(fontSize: 13, fontFamily: 'Poppins')),
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
