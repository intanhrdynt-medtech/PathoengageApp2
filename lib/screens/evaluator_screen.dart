import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';

class EvaluatorScreen extends StatefulWidget {
  const EvaluatorScreen({Key? key}) : super(key: key);

  @override
  State<EvaluatorScreen> createState() => _EvaluatorScreenState();
}

class _EvaluatorScreenState extends State<EvaluatorScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = true;

  List<dynamic> _pendingJournals = [];
  List<dynamic> _pendingPenelitian = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final journals = await _api.getAdminJournalReadings('pending');
      final penelitian = await _api.getAllPenelitian('');
      setState(() {
        _pendingJournals = journals;
        _pendingPenelitian =
            penelitian.where((p) => p['status'] == 'submitted').toList();
      });
    } catch (e) {
      debugPrint('Error loading evaluator data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'submitted': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'approved': return 'Disetujui';
      case 'pending': return 'Menunggu';
      case 'rejected': return 'Ditolak';
      case 'submitted': return 'Diajukan';
      default: return s ?? '-';
    }
  }

  void _showJournalReviewDialog(Map<String, dynamic> journal) {
    final catatanCtrl = TextEditingController(text: journal['catatan_admin'] ?? '');
    String selectedStatus = journal['status'] ?? 'pending';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Review Journal Reading',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Judul', journal['judul'] ?? '-'),
                _infoRow('Pengaju', journal['user_name'] ?? '-'),
                _infoRow('Pembimbing', journal['pembimbing'] ?? '-'),
                const SizedBox(height: 14),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusChip('approved', 'Setujui', Colors.green, selectedStatus, (v) => setDlg(() => selectedStatus = v)),
                    const SizedBox(width: 8),
                    _statusChip('rejected', 'Tolak', Colors.red, selectedStatus, (v) => setDlg(() => selectedStatus = v)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catatanCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: selectedStatus == 'approved' ? Colors.green : Colors.red,
                  foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDlg(() => isLoading = true);
                      final ok = await _api.adminReviewJournal(
                          journal['id'], selectedStatus, catatanCtrl.text.trim());
                      if (ok && mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Journal berhasil di-${selectedStatus == 'approved' ? 'setujui' : 'tolak'}!')));
                      } else {
                        setDlg(() => isLoading = false);
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(const SnackBar(content: Text('Gagal update status')));
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label, Color color, String current, void Function(String) onSelect) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }

  Widget _buildJournalTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_pendingJournals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('Tidak ada Journal Reading yang perlu direview',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingJournals.length,
      itemBuilder: (ctx, i) {
        final j = _pendingJournals[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.article, color: Colors.orange, size: 24),
            ),
            title: Text(j['judul'] ?? '-',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Pengaju: ${j['user_name'] ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Pembimbing: ${j['pembimbing'] ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _statusColor(j['status']).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_statusLabel(j['status']),
                      style: TextStyle(color: _statusColor(j['status']), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showJournalReviewDialog(j),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: const Text('Review', style: TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPenelitianTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_pendingPenelitian.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('Tidak ada Penelitian yang perlu direview',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingPenelitian.length,
      itemBuilder: (ctx, i) {
        final p = _pendingPenelitian[i];
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.science, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['judul'] ?? '-',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text('${p['jenis'] ?? '-'} • ${p['user_name'] ?? '-'}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _statusColor(p['status']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_statusLabel(p['status']),
                          style: TextStyle(
                              color: _statusColor(p['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (p['pembimbing_1'] != null)
                  Text('Pembimbing: ${p['pembimbing_1']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text(
                    '⚠️ Hubungi admin untuk mengubah status penelitian ini.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
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
        title: const Text('Panel Evaluator',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.article, size: 16),
                const SizedBox(width: 6),
                Text('Journal (${_pendingJournals.length})'),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.science, size: 16),
                const SizedBox(width: 6),
                Text('Penelitian (${_pendingPenelitian.length})'),
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJournalTab(),
          _buildPenelitianTab(),
        ],
      ),
    );
  }
}
