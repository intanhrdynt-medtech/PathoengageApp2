import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});
  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _competencies = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Sesuai 3 fase kompetensi PPDS PA
  final List<String> _phases = ['Semua', 'red', 'yellow', 'green'];
  final Map<String, String> _phaseLabels = {
    'Semua': 'Semua',
    'red': 'Tahap Merah',
    'yellow': 'Tahap Kuning',
    'green': 'Tahap Hijau',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _phases.length, vsync: this);
    _loadCompetencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadCompetencies() async {
    final data = await _api.getCompetencies();
    setState(() {
      _competencies = data;
      _isLoading = false;
    });
  }

  List<dynamic> _filterByPhase(String phase) {
    if (phase == 'Semua') return _competencies;
    return _competencies.where((c) => c['phase_category'] == phase).toList();
  }

  Color _getPhaseColor(String? phase) {
    switch (phase) {
      case 'red': return Colors.red.shade600;
      case 'yellow': return Colors.orange.shade600;
      case 'green': return Colors.green.shade600;
      default: return AppColors.textGrey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return AppColors.successGreen;
      case 'pending_verification': return AppColors.warningOrange;
      default: return AppColors.textGrey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'completed': return 'Selesai';
      case 'pending_verification': return 'Sedang Verifikasi';
      default: return 'Upload Bukti';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'pending_verification': return Icons.hourglass_top;
      default: return Icons.upload_file;
    }
  }

  Future<void> _handleCompetencyTap(Map<String, dynamic> item) async {
    final currentStatus = item['status'] ?? 'not_started';
    
    if (currentStatus == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kompetensi ini sudah diverifikasi selesai.')));
      return;
    }
    
    if (currentStatus == 'pending_verification') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menunggu verifikasi admin.')));
      return;
    }

    final TextEditingController _urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Kirim Bukti Kompetensi', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
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
              final success = await _api.updateCompetencyEvidence(item['id'], 'pending_verification', _urlController.text.trim());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti berhasil dikirim. Menunggu verifikasi admin.')));
                _loadCompetencies();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Logbook Kompetensi', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accentRed,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12),
          tabs: _phases.map((p) => Tab(text: _phaseLabels[p]!)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: TabBarView(
                controller: _tabController,
                children: _phases.map((phase) {
                  final items = _filterByPhase(phase);
                  final completed = items.where((c) => c['status'] == 'completed').length;

                  return Column(
                    children: [
                      // Progress banner
                      if (items.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryPurple, AppColors.darkMagenta],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Progres Kompetensi',
                                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('$completed / ${items.length} selesai',
                                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: items.isEmpty ? 0 : completed / items.length,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      
                      // List items
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.book_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.4)),
                                    const SizedBox(height: 12),
                                    Text('Tidak ada kompetensi di tahap ini',
                                        style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: items.length,
                                itemBuilder: (ctx, i) => InkWell(
                                  onTap: () => _handleCompetencyTap(items[i]),
                                  child: _buildCompetencyCard(items[i]),
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildCompetencyCard(Map<String, dynamic> item) {
    final phaseColor = _getPhaseColor(item['phase_category']);
    final statusColor = _getStatusColor(item['status']);
    final statusIcon = _getStatusIcon(item['status']);
    final statusLabel = _getStatusLabel(item['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(color: phaseColor, borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(item['competency_name'] ?? '-',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(item['organ_system'] ?? '',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey)),
        trailing: GestureDetector(
          onTap: () => _handleCompetencyTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
