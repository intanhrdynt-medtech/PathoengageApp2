import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  // Reminder data model
  final List<ReminderItem> reminders = [
    ReminderItem(
      id: 1,
      title: 'PIT/KONAS Pertama',
      description: 'Membawakan case report di forum nasional/regional',
      category: ReminderCategory.event,
      priority: ReminderPriority.high,
      dueDate: null,
      isCompleted: false,
      details:
          'Persiapkan case report untuk dipresentasikan di PIT/KONAS pertama',
    ),
    ReminderItem(
      id: 2,
      title: 'PIT/KONAS Kedua',
      description: 'Membawakan proposal/hasil KA di forum nasional/regional',
      category: ReminderCategory.event,
      priority: ReminderPriority.high,
      dueDate: null,
      isCompleted: false,
      details:
          'Siapkan proposal atau hasil Karya Akhir untuk dipresentasikan di PIT/KONAS kedua',
    ),
    ReminderItem(
      id: 3,
      title: 'Iuran PDS PA',
      description: 'Bayar iuran bulanan Rp50.000 (syarat ujian board)',
      category: ReminderCategory.payment,
      priority: ReminderPriority.high,
      dueDate: null,
      isCompleted: false,
      details:
          'Pembayaran iuran PDS PA Rp50.000 per bulan adalah wajib sebagai syarat untuk mengikuti ujian board',
      recurring: ReminderRecurrence.monthly,
    ),
    ReminderItem(
      id: 4,
      title: 'Ujian Nasional 1 (Semester 4)',
      description: 'Ujian kelulusan PPDS PA pertama',
      category: ReminderCategory.exam,
      priority: ReminderPriority.critical,
      dueDate: null,
      isCompleted: false,
      details: 'Target: Semester 4 - Ujian Nasional pertama',
      semesterTarget: 4,
    ),
    ReminderItem(
      id: 5,
      title: 'Ujian Nasional 2 (Semester 8)',
      description: 'Ujian kelulusan PPDS PA kedua (final)',
      category: ReminderCategory.exam,
      priority: ReminderPriority.critical,
      dueDate: null,
      isCompleted: false,
      details: 'Target: Semester 8 - Ujian Nasional kedua (kelulusan)',
      semesterTarget: 8,
    ),
    ReminderItem(
      id: 6,
      title: 'Kelayakan Etik - Proposal KA',
      description: 'Urus izin etik penelitian sebelum memulai KA',
      category: ReminderCategory.ethics,
      priority: ReminderPriority.high,
      dueDate: null,
      isCompleted: false,
      details: 'Kirimkan proposal KA ke komisi etik untuk mendapatkan kelayakan etik sebelum memulai penelitian',
    ),
    ReminderItem(
      id: 7,
      title: 'Kelayakan Etik - Penelitian Retrospektif',
      description: 'Urus izin etik penelitian retrospektif',
      category: ReminderCategory.ethics,
      priority: ReminderPriority.high,
      dueDate: null,
      isCompleted: false,
      details: 'Ajukan penelitian retrospektif Anda ke komisi etik untuk mendapatkan persetujuan',
    ),
    ReminderItem(
      id: 8,
      title: 'Penutupan Etik - Hasil KA',
      description: 'Urus penutupan etik setelah presentasi hasil KA',
      category: ReminderCategory.ethics,
      priority: ReminderPriority.medium,
      dueDate: null,
      isCompleted: false,
      details: 'Lakukan penutupan etik ke komisi setelah menyelesaikan presentasi hasil Karya Akhir',
    ),
    ReminderItem(
      id: 9,
      title: 'Penutupan Etik - Retrospektif',
      description: 'Urus penutupan etik setelah presentasi penelitian retrospektif',
      category: ReminderCategory.ethics,
      priority: ReminderPriority.medium,
      dueDate: null,
      isCompleted: false,
      details: 'Ajukan penutupan etik ke komisi setelah menyelesaikan presentasi penelitian retrospektif',
    ),
    ReminderItem(
      id: 10,
      title: 'Publish Jurnal - KA',
      description: 'Segera publish jurnal setelah seminar hasil KA',
      category: ReminderCategory.publication,
      priority: ReminderPriority.medium,
      dueDate: null,
      isCompleted: false,
      details: 'Siapkan dan submit jurnal dari hasil Karya Akhir Anda ke jurnal terpilih',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pengingat Akademik',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondaryPink,
              AppColors.secondaryMagenta,
              AppColors.darkMagenta,
              AppColors.primaryDark,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary Cards
              _buildSummarySection(),
              const SizedBox(height: 24),

              // Reminders by Category
              Text(
                'Semua Pengingat',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Reminder Items
              ...reminders.map((reminder) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildReminderCard(reminder),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final totalReminders = reminders.length;
    final completedReminders = reminders.where((r) => r.isCompleted).length;
    final criticalReminders =
        reminders.where((r) => r.priority == ReminderPriority.critical).length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total',
            value: totalReminders.toString(),
            icon: Icons.checklist,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Selesai',
            value: completedReminders.toString(),
            icon: Icons.check_circle,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Penting',
            value: criticalReminders.toString(),
            icon: Icons.priority_high,
            color: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ReminderItem reminder) {
    final (bgColor, categoryText) = _getCategoryInfo(reminder.category);
    final (priorityColor, priorityText) = _getPriorityInfo(reminder.priority);

    return GestureDetector(
      onTap: () => _showReminderDetails(reminder),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        reminder.isCompleted = !reminder.isCompleted;
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: reminder.isCompleted
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        color: reminder.isCompleted
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: reminder.isCompleted
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.green)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: reminder.isCompleted
                                ? Colors.grey.shade500
                                : AppColors.primaryDark,
                            decoration: reminder.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Priority Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priorityText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      categoryText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: bgColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (reminder.semesterTarget != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Semester ${reminder.semesterTarget}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  if (reminder.recurring != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Berulang',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showReminderDetails(ReminderItem reminder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reminder.details,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Tutup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          reminder.isCompleted = !reminder.isCompleted;
                        });
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        reminder.isCompleted
                            ? Icons.undo
                            : Icons.check_circle,
                      ),
                      label: Text(
                        reminder.isCompleted ? 'Batal Selesai' : 'Tandai Selesai',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: reminder.isCompleted
                            ? Colors.orange
                            : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  (Color, String) _getCategoryInfo(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.event:
        return (const Color(0xFF6366F1), 'Event');
      case ReminderCategory.payment:
        return (const Color(0xFFFBBF24), 'Pembayaran');
      case ReminderCategory.exam:
        return (const Color(0xFFEF4444), 'Ujian');
      case ReminderCategory.ethics:
        return (const Color(0xFF10B981), 'Etik');
      case ReminderCategory.publication:
        return (const Color(0xFF8B5CF6), 'Publikasi');
    }
  }

  (Color, String) _getPriorityInfo(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.critical:
        return (const Color(0xFFEF4444), 'PENTING');
      case ReminderPriority.high:
        return (const Color(0xFFFBBF24), 'TINGGI');
      case ReminderPriority.medium:
        return (const Color(0xFF3B82F6), 'SEDANG');
      case ReminderPriority.low:
        return (const Color(0xFF6B7280), 'RENDAH');
    }
  }
}

// ===== DATA MODELS =====
class ReminderItem {
  final int id;
  final String title;
  final String description;
  final String details;
  final ReminderCategory category;
  final ReminderPriority priority;
  final DateTime? dueDate;
  final int? semesterTarget;
  final ReminderRecurrence? recurring;
  bool isCompleted;

  ReminderItem({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    required this.category,
    required this.priority,
    required this.dueDate,
    required this.isCompleted,
    this.semesterTarget,
    this.recurring,
  });
}

enum ReminderCategory { event, payment, exam, ethics, publication }
enum ReminderPriority { critical, high, medium, low }
enum ReminderRecurrence { daily, weekly, monthly, yearly }
