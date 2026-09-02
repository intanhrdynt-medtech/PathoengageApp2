import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────

class TextbookData {
  final String title;
  final String assetImage;
  final String accessUrl;
  final String description;

  const TextbookData({
    required this.title,
    required this.assetImage,
    required this.accessUrl,
    required this.description,
  });
}

const List<TextbookData> kTextbooks = [
  TextbookData(
    title: 'Classification of Tumours',
    assetImage: 'assets/images/classification of tumor.png',
    accessUrl: 'https://tumourclassification.iarc.who.int/home',
    description: 'WHO Classification of Tumours — panduan standar internasional klasifikasi tumor oleh IARC.',
  ),
  TextbookData(
    title: 'Pathologic Basis of Disease',
    assetImage: 'assets/images/Pathologic Basic of Disease.jpg',
    accessUrl: 'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-5',
    description: 'Robbins, Cotran & Kumar — referensi utama patologi penyakit berbasis mekanisme.',
  ),
  TextbookData(
    title: 'Basic Pathology',
    assetImage: 'assets/images/Basic Patology.jpg',
    accessUrl: 'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5',
    description: 'Robbins & Kumar Basic Pathology — edisi ringkas untuk pemahaman konsep dasar patologi.',
  ),
  TextbookData(
    title: "Enzinger and Weiss's Soft Tissue Tumors",
    assetImage: "assets/images/Enzinger and Weiss's Soft Tissue Tumors.jpg",
    accessUrl: 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4',
    description: 'Goldblum — referensi komprehensif tumor jaringan lunak untuk patologi bedah.',
  ),
  TextbookData(
    title: "Cibas and Ducatman's Cytology",
    assetImage: "assets/images/Cibas and Ducatman's Cytology.jpg",
    accessUrl: 'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3',
    description: 'Teks standar sitologi diagnostik — mencakup seluruh organ dan spesimen sitologi.',
  ),
  TextbookData(
    title: 'Pathology (Harsh Mohan)',
    assetImage: 'assets/images/Pathology.png',
    accessUrl: 'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf',
    description: "Harsh Mohan's Textbook of Pathology — teks patologi populer edisi ke-6.",
  ),
  TextbookData(
    title: "Silva's Diagnostic Renal Pathology",
    assetImage: "assets/images/Silva's Diagnostic Renal Pathology.jpg",
    accessUrl: 'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984',
    description: 'Panduan diagnostik patologi ginjal — referensi khusus nefrologi dan patologi ginjal.',
  ),
  TextbookData(
    title: "Weedon's Skin Pathology",
    assetImage: "assets/images/Weedon's Skin Pathology.jpg",
    accessUrl: 'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology',
    description: "Weedon's — referensi utama dermatopatologi, mencakup seluruh kelainan kulit.",
  ),
];

// ─── Main Screen ──────────────────────────────────────────────────────────────

class TextbookScreen extends StatefulWidget {
  const TextbookScreen({Key? key}) : super(key: key);

  @override
  State<TextbookScreen> createState() => _TextbookScreenState();
}

class _TextbookScreenState extends State<TextbookScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final data = await _api.getAcademicTasks();
    setState(() {
      _tasks = data.where((t) => t['task_type'] == 'Textbook Reading').toList();
      _isLoading = false;
    });
  }

  // Match buku ke task berdasarkan judul
  Map<String, dynamic>? _taskForBook(TextbookData book) {
    try {
      return _tasks.firstWhere(
        (t) => (t['title'] as String?)?.toLowerCase().contains(
              book.title.toLowerCase().split(' ').first.toLowerCase(),
            ) ?? false,
      );
    } catch (_) {
      return null;
    }
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

  void _openBook(TextbookData book) async {
    try {
      final uri = Uri.parse(book.accessUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak bisa membuka link: ${book.accessUrl}')),
        );
      }
    }
  }

  void _showDetailDialog(TextbookData book) {
    final task = _taskForBook(book);
    final status = task?['status'] as String?;
    final isDone = task?['is_completed'] == true || status == 'completed';
    final isPending = status == 'pending_verification';

    final notesCtrl = TextEditingController(text: task?['notes'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover Image Header
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: Image.asset(
                      book.assetImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryPurple.withOpacity(0.15),
                        child: const Icon(Icons.menu_book, size: 80, color: AppColors.primaryPurple),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ),
                  // Title on image
                  Positioned(
                    bottom: 14,
                    left: 16,
                    right: 16,
                    child: Text(
                      book.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      book.description,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status badge
                    if (task != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Access button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openBook(book),
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Akses Buku Online',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    // Notes / submit section
                    if (task != null && !isDone && !isPending) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Submit Resume Bacaan',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tulis ringkasan / resume bacaan...',
                          hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (notesCtrl.text.trim().isEmpty) return;
                                  setState(() => isSubmitting = true);
                                  final ok = await _api.updateAcademicNotes(
                                    task['id'],
                                    'pending_verification',
                                    notesCtrl.text.trim(),
                                  );
                                  setState(() => isSubmitting = false);
                                  if (mounted) Navigator.pop(ctx);
                                  if (ok) {
                                    _loadTasks();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Resume berhasil disubmit! Menunggu verifikasi.')),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Resume',
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (isDone) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task?['notes'] ?? 'Sudah selesai dibaca.',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ]),
                      ),
                    ],

                    if (isPending) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(children: [
                          Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('Resume sedang diverifikasi admin.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.orange)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text(
          'Textbook Reading',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: kTextbooks.length,
                itemBuilder: (ctx, i) {
                  final book = kTextbooks[i];
                  final task = _taskForBook(book);
                  final status = task?['status'] as String?;
                  final isDone = task?['is_completed'] == true || status == 'completed';
                  final isPending = status == 'pending_verification';

                  return GestureDetector(
                    onTap: () => _showDetailDialog(book),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isDone
                            ? Border.all(color: Colors.green.shade300, width: 2)
                            : isPending
                                ? Border.all(color: Colors.orange.shade300, width: 2)
                                : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Book Cover
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    book.assetImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.primaryPurple.withOpacity(0.1),
                                      child: const Icon(Icons.menu_book,
                                          size: 48, color: AppColors.primaryPurple),
                                    ),
                                  ),
                                  // Status overlay
                                  if (isDone)
                                    Container(
                                      color: Colors.green.withOpacity(0.25),
                                      child: const Center(
                                        child: Icon(Icons.check_circle,
                                            color: Colors.white, size: 40),
                                      ),
                                    ),
                                  if (isPending)
                                    Container(
                                      color: Colors.orange.withOpacity(0.25),
                                      child: const Center(
                                        child: Icon(Icons.hourglass_top,
                                            color: Colors.white, size: 36),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Book info
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontFamily: 'Poppins',
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
