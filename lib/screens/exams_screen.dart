import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _exams = [];
  List<dynamic> _organExams = [];
  bool _isLoading = true;
  late TabController _tabController;

  final List<String> _tabs = ['Semua', 'Lokal', 'Nasional', 'Organ'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadExams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadExams() async {
    final data = await _api.getExams();
    final organData = await _api.getMyOrganExams();
    setState(() {
      _exams = data;
      _organExams = organData;
      _isLoading = false;
    });
  }

  List<dynamic> _filterExams(String type) {
    if (type == 'Semua') return _exams;
    return _exams.where((e) => e['exam_type'] == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Ujian PPDS', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
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
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: TabBarView(
                controller: _tabController,
                children: _tabs.map((type) {
                  final bool isOrganTab = type == 'Organ';
                  final list = isOrganTab ? _organExams : _filterExams(type);
                  
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(isOrganTab ? 'Belum ada ujian organ' : 'Belum ada data ujian', style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => isOrganTab
                        ? _buildOrganExamCard(list[i])
                        : InkWell(
                            onTap: () => _handleExamTap(list[i]),
                            child: _buildExamCard(list[i])),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _handleExamTap(Map<String, dynamic> exam) async {
    final currentStatus = exam['result'] ?? 'terjadwal';
    
    if (currentStatus == 'lulus' || currentStatus == 'tidak_lulus') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ujian ini sudah selesai dinilai.')));
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
        title: const Text('Kirim Bukti Ujian', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
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
              final success = await _api.updateExamEvidence(exam['id'], 'pending_verification', _urlController.text.trim());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti berhasil dikirim. Menunggu verifikasi admin.')));
                _loadExams();
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

  Widget _buildExamCard(Map<String, dynamic> exam) {
    bool isPassed = exam['result'] == 'lulus';
    bool isFailed = exam['result'] == 'tidak_lulus';
    bool isPending = exam['result'] == 'pending_verification';

    String? scheduledDate = exam['scheduled_date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(exam['scheduled_date']).toLocal())
        : null;

    Color statusColor = Colors.grey;
    String statusLabel = 'Upload Bukti';
    if (isPassed) {
      statusColor = AppColors.successGreen;
      statusLabel = 'Lulus';
    } else if (isFailed) {
      statusColor = AppColors.accentRed;
      statusLabel = 'Tidak Lulus';
    } else if (isPending) {
      statusColor = AppColors.warningOrange;
      statusLabel = 'Sedang Verifikasi';
    }

    Color phaseColor = AppColors.textGrey;
    switch (exam['phase_category']?.toString().toLowerCase()) {
      case 'red': phaseColor = Colors.red.shade600; break;
      case 'yellow': phaseColor = Colors.orange.shade600; break;
      case 'green': phaseColor = Colors.green.shade600; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school, color: phaseColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam['exam_name'] ?? '-',
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(exam['exam_type'] ?? '-',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
                  if (scheduledDate != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(scheduledDate,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                  if (exam['score'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Nilai: ${exam['score']}',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ],
                  if (exam['notes'] != null && exam['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        exam['notes'],
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganExamCard(Map<String, dynamic> exam) {
    Color statusColor = Colors.grey;
    String statusLabel = exam['status'] ?? 'terjadwal';
    if (statusLabel == 'lulus') {
      statusColor = AppColors.successGreen;
      statusLabel = 'Lulus';
    } else if (statusLabel == 'tidak_lulus') {
      statusColor = AppColors.accentRed;
      statusLabel = 'Tidak Lulus';
    } else {
      statusColor = AppColors.warningOrange;
      statusLabel = 'Terjadwal';
    }

    String? scheduledDate = exam['tanggal'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(exam['tanggal']).toLocal())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services, color: AppColors.primaryPurple, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam['nama_ujian'] ?? 'Ujian Organ',
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Organ: ${exam['organ'] ?? '-'}',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
                  Text('Penguji: ${exam['penguji'] ?? '-'}',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey)),
                  if (scheduledDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(scheduledDate,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}
