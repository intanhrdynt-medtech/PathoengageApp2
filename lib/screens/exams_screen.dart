import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:intl/intl.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _exams = [];
  bool _isLoading = true;
  late TabController _tabController;

  final List<String> _tabs = ['Semua', 'Lokal', 'Nasional Tahap 1', 'Board/Tahap 2'];

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
    setState(() {
      _exams = data;
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
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((type) {
                final exams = _filterExams(type);
                if (exams.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined, size: 64, color: AppColors.textGrey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Belum ada data ujian', style: TextStyle(color: AppColors.textGrey, fontFamily: 'Poppins')),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (ctx, i) => _buildExamCard(exams[i]),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final isPassed = exam['result'] == 'lulus';
    final isFailed = exam['result'] == 'tidak_lulus';
    final scheduledDate = exam['scheduled_date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(exam['scheduled_date']))
        : null;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;
    String statusLabel = 'Terjadwal';
    if (isPassed) {
      statusColor = AppColors.successGreen;
      statusIcon = Icons.check_circle;
      statusLabel = 'Lulus';
    } else if (isFailed) {
      statusColor = AppColors.accentRed;
      statusIcon = Icons.cancel;
      statusLabel = 'Tidak Lulus';
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
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
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
}
