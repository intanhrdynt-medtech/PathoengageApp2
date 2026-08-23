import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
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
    setState(() {
      _pendingItems = items;
      _isLoading = false;
    });
  }

  Future<void> _verifyTask(String typeCategory, int id) async {
    final success = await _api.verifyTask(typeCategory, id, 'completed');
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diverifikasi!')));
        _loadData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memverifikasi')));
      }
    }
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Detail Tugas', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oleh: ${item['user_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Kategori: ${item['type_category']}'),
            if (item['title'] != null) Text('Judul: ${item['title']}'),
            if (item['exam_name'] != null) Text('Ujian: ${item['exam_name']}'),
            if (item['competency_name'] != null) Text('Kompetensi: ${item['competency_name']}'),
            if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(item['notes']),
            ],
            const SizedBox(height: 16),
            if (item['document_proof_url'] != null || item['evidence_url'] != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final url = item['document_proof_url'] ?? item['evidence_url'];
                  if (url != null) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Lihat Bukti Lampiran'),
              )
            else
              const Text('Tidak ada lampiran', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _verifyTask(item['type_category'], item['id']);
            },
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ResponsiveWrapper(
            child: _pendingItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: AppColors.textGrey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Semua tugas sudah diverifikasi', style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingItems.length,
                    itemBuilder: (context, index) {
                      final item = _pendingItems[index];
                      String title = item['title'] ?? item['exam_name'] ?? item['competency_name'] ?? 'Task';
                      
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('PPDS: ${item['user_name']}'),
                              Text('Tipe: ${item['type_category']}'),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                            onPressed: () => _showDetailsDialog(item),
                            child: const Text('Periksa'),
                          ),
                        ),
                      );
                    },
                  ),
          );
  }
}
