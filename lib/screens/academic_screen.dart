import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:intl/intl.dart';

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

  Color _getTaskColor(String? type) {
    switch (type) {
      case 'Textbook Reading': return const Color(0xFF2980B9);
      case 'Journal Reading': return const Color(0xFF8E44AD);
      case 'Tugas Ilmiah': return const Color(0xFFF39C12);
      case 'Penelitian': return const Color(0xFF16A085);
      case 'Etik': return const Color(0xFFC0392B);
      case 'Publikasi': return const Color(0xFFD35400);
      default: return AppColors.primaryPurple;
    }
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
          : TabBarView(
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
                  itemBuilder: (ctx, i) => _buildTaskCard(tasks[i]),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isDone = task['is_completed'] == true;
    final color = _getTaskColor(task['task_type']);
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
