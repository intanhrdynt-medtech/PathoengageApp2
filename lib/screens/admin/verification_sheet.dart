import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Kategori pengajuan yang diverifikasi admin.
class VerifCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const VerifCategory(this.key, this.label, this.icon, this.color);

  static const competency = VerifCategory('competency', 'Kompetensi', Icons.star_outline, AppColors.secondaryMagenta);
  static const exam = VerifCategory('exam', 'Ujian', Icons.assignment_turned_in_outlined, AppColors.infoBlue);
  static const academic = VerifCategory('academic', 'Tugas', Icons.task_outlined, AppColors.primaryPurple);
  static const journal = VerifCategory('journal', 'Journal', Icons.article_outlined, AppColors.accentDarkRed);

  static const all = [competency, exam, academic, journal];

  static VerifCategory of(String key) => all.firstWhere((c) => c.key == key, orElse: () => academic);
}

/// Satu pengajuan yang menunggu tindakan admin (bentuk seragam untuk semua jenis).
class VerifItem {
  final VerifCategory category;
  final int id;
  final String userName;
  final String title;
  final List<String> meta;
  final String? evidenceUrl;

  /// Resume / catatan yang ditulis PPDS (tugas akademik, kompetensi).
  final String? resume;

  /// Syarat ujian (teks bawaan kurikulum, bukan tulisan PPDS).
  final String? syarat;
  final String? alasanTolak;
  final Map<String, dynamic> raw;

  const VerifItem({
    required this.category,
    required this.id,
    required this.userName,
    required this.title,
    this.meta = const [],
    this.evidenceUrl,
    this.resume,
    this.syarat,
    this.alasanTolak,
    this.raw = const {},
  });

  String get key => '${category.key}-$id';

  static String? _nz(dynamic v) => textOf(v).isEmpty ? null : textOf(v);

  /// Dari GET /admin/pending_verifications atau item progres PPDS (+ type_category).
  factory VerifItem.fromPending(Map<String, dynamic> m, {String? userName}) {
    final cat = VerifCategory.of(textOf(m['type_category']));
    final name = userName ?? _nz(m['user_name']) ?? '-';
    switch (cat.key) {
      case 'exam':
        return VerifItem(
          category: cat,
          id: m['id'] as int,
          userName: name,
          title: _nz(m['exam_name']) ?? 'Ujian',
          meta: [
            if (_nz(m['exam_type']) != null) _nz(m['exam_type'])!,
            if (_nz(m['phase_category']) != null) phaseLabel(m['phase_category']),
            if (_nz(m['scheduled_date']) != null) 'Jadwal ${formatTanggal(m['scheduled_date'])}',
          ],
          evidenceUrl: _nz(m['evidence_url']),
          syarat: _stripSyarat(_nz(m['notes'])),
          alasanTolak: _nz(m['alasan_tolak']),
          raw: m,
        );
      case 'competency':
        return VerifItem(
          category: cat,
          id: m['id'] as int,
          userName: name,
          title: _nz(m['competency_name']) ?? 'Kompetensi',
          meta: [
            if (_nz(m['organ_system']) != null) _nz(m['organ_system'])!,
            if (_nz(m['phase_category']) != null) phaseLabel(m['phase_category']),
          ],
          evidenceUrl: _nz(m['evidence_url']),
          resume: _nz(m['notes']),
          alasanTolak: _nz(m['alasan_tolak']),
          raw: m,
        );
      default:
        return VerifItem(
          category: VerifCategory.academic,
          id: m['id'] as int,
          userName: name,
          title: _nz(m['title']) ?? 'Tugas akademik',
          meta: [
            if (_nz(m['task_type']) != null) _nz(m['task_type'])!,
            if (m['target_semester'] != null) 'Semester ${m['target_semester']}',
          ],
          evidenceUrl: _nz(m['document_proof_url']),
          resume: _nz(m['notes']),
          alasanTolak: _nz(m['alasan_tolak']),
          raw: m,
        );
    }
  }

  /// Dari GET /admin/journal-readings?status=pending. `user_name` = PPDS,
  /// `penulis` = penulis artikel.
  factory VerifItem.fromJournal(Map<String, dynamic> j) {
    return VerifItem(
      category: VerifCategory.journal,
      id: j['id'] as int,
      userName: _nz(j['user_name']) ?? '-',
      title: _nz(j['judul']) ?? 'Journal reading',
      meta: [
        if (_nz(j['jenis']) != null) _nz(j['jenis'])!,
        if (_nz(j['nama_jurnal']) != null) _nz(j['nama_jurnal'])!,
        if (_nz(j['created_at']) != null) 'Diajukan ${formatTanggal(j['created_at'], serverTimestamp: true)}',
      ],
      evidenceUrl: _nz(j['bukti_url']),
      raw: j,
    );
  }

  /// Ujian yang otomatis menaikkan kalung bila disetujui.
  bool get promotesPhase =>
      category.key == 'exam' && (title.trim() == 'Ujian Organ I' || title.trim() == 'Ujian Organ II');
}

/// Membuka detail pengajuan + tombol aksi. Mengembalikan pesan sukses bila
/// pengajuan berhasil diproses (item boleh dihapus dari daftar), atau null.
Future<String?> showVerificationSheet(BuildContext context, VerifItem item) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (_) => _VerificationSheet(item: item),
  );
}

class _VerificationSheet extends StatefulWidget {
  final VerifItem item;
  const _VerificationSheet({required this.item});

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  final ApiService _api = ApiService();
  bool _busy = false;
  String? _error;

  VerifItem get item => widget.item;
  bool get _isJournal => item.category.key == 'journal';
  bool get _isExam => item.category.key == 'exam';

  Future<void> _run(Future<bool> Function() action, String successMsg, String fallbackError) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, successMsg);
      return;
    }
    setState(() {
      _busy = false;
      _error = _api.lastError ?? fallbackError;
    });
  }

  Future<void> _approve() async {
    if (_isJournal) {
      final res = await promptReason(
        context,
        title: 'Setujui journal reading?',
        message: 'PPDS ${item.userName} dapat melanjutkan presentasi lalu mengunggah bukti.',
        label: 'Catatan untuk PPDS (opsional)',
        required: false,
        confirmText: 'Setujui',
      );
      if (res == null || !mounted) return;
      // Catatan kosong diabaikan server, jadi catatan lama tidak terhapus.
      await _run(() => _api.adminReviewJournal(item.id, 'approve', res.text), 'Journal reading disetujui',
          'Gagal menyetujui journal reading. Coba lagi.');
      return;
    }
    final msg = StringBuffer('Bukti "${item.title}" milik ${item.userName} akan dinyatakan diterima.');
    if (_isExam) msg.write(' Ujian akan tercatat lulus.');
    if (item.promotesPhase) msg.write('\n\nMenyetujui ${item.title} otomatis menaikkan kalung PPDS ke tahap berikutnya.');
    final ok = await confirmDialog(context, title: 'Setujui pengajuan?', message: msg.toString(), confirmText: 'Setujui');
    if (!ok || !mounted) return;
    await _run(() => _api.verifyItem(item.category.key, item.id, 'approve'), 'Pengajuan disetujui',
        'Gagal menyetujui pengajuan.');
  }

  Future<void> _reject() async {
    if (_isJournal) {
      final res = await promptReason(
        context,
        title: 'Tolak journal reading?',
        message: 'PPDS akan diminta memperbaiki lalu mengajukan ulang.',
        label: 'Alasan penolakan',
        confirmText: 'Tolak',
        danger: true,
      );
      if (res == null || !mounted) return;
      await _run(() => _api.adminReviewJournal(item.id, 'reject', res.text), 'Journal reading ditolak',
          'Gagal menolak journal reading. Coba lagi.');
      return;
    }
    final res = await promptReason(
      context,
      title: 'Tolak bukti?',
      message: 'Bukti belum dapat diterima. PPDS akan menerima alasan ini dan diminta mengirim ulang.',
      label: 'Alasan penolakan',
      hint: 'Mis. link tidak bisa dibuka, dokumen belum lengkap',
      confirmText: 'Tolak bukti',
      danger: true,
    );
    if (res == null || !mounted) return;
    await _run(() => _api.verifyItem(item.category.key, item.id, 'reject', alasan: res.text),
        'Bukti ditolak, PPDS diminta mengirim ulang', 'Gagal menolak bukti.');
  }

  Future<void> _fail() async {
    final res = await promptReason(
      context,
      title: 'Nyatakan tidak lulus?',
      message: '${item.userName} akan tercatat tidak lulus ${item.title}.',
      label: 'Alasan / keterangan',
      withScore: true,
      confirmText: 'Tidak lulus',
      danger: true,
    );
    if (res == null || !mounted) return;
    await _run(() => _api.verifyItem('exam', item.id, 'fail', alasan: res.text, score: res.score),
        'Ujian dicatat tidak lulus', 'Gagal menyimpan hasil ujian.');
  }

  List<Widget> _journalDetails() {
    final j = item.raw;
    return [
      InfoRow(icon: Icons.person_outline, label: 'Penulis artikel', value: textOf(j['penulis'])),
      InfoRow(icon: Icons.menu_book_outlined, label: 'Nama jurnal', value: textOf(j['nama_jurnal'])),
      InfoRow(icon: Icons.category_outlined, label: 'Jenis', value: textOf(j['jenis'])),
      InfoRow(icon: Icons.supervisor_account_outlined, label: 'Pembimbing', value: textOf(j['pembimbing'])),
      InfoRow(icon: Icons.how_to_reg_outlined, label: 'Penguji', value: textOf(j['penguji'])),
      InfoRow(
          icon: Icons.event_outlined,
          label: 'Tgl. presentasi',
          value: textOf(j['tanggal_presentasi']).isEmpty ? '' : formatTanggal(j['tanggal_presentasi'])),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cat = item.category;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cat.color.withValues(alpha: 0.12),
                  child: Icon(cat.icon, color: cat.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.label, style: TextStyle(fontSize: 12, color: cat.color, fontWeight: FontWeight.w700)),
                    Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              InfoRow(icon: Icons.badge_outlined, label: 'PPDS', value: item.userName),
              if (_isJournal)
                ..._journalDetails()
              else if (item.meta.isNotEmpty)
                InfoRow(icon: Icons.info_outline, label: 'Keterangan', value: item.meta.join(' · ')),
              if (item.syarat != null)
                NoteBox(title: 'Syarat', text: item.syarat!, icon: Icons.rule),
              if (item.resume != null)
                NoteBox(
                  title: item.category.key == 'academic' ? 'Resume PPDS' : 'Catatan PPDS',
                  text: item.resume!,
                  color: AppColors.primaryPurple,
                  icon: Icons.notes,
                ),
              if (item.alasanTolak != null)
                NoteBox(
                  title: 'Alasan penolakan sebelumnya',
                  text: item.alasanTolak!,
                  color: AppColors.warningOrange,
                  icon: Icons.history,
                ),
              if (_isJournal && textOf(item.raw['catatan_admin']).isNotEmpty)
                NoteBox(title: 'Catatan sebelumnya', text: textOf(item.raw['catatan_admin']), icon: Icons.history),
              const SizedBox(height: 12),
              if (item.evidenceUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => openLink(context, item.evidenceUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Buka link bukti'),
                  ),
                )
              else if (!_isJournal)
                const NoteBox(
                  title: 'Tanpa link bukti',
                  text: 'PPDS tidak melampirkan link. Periksa resume/catatan sebelum memutuskan.',
                  color: AppColors.warningOrange,
                  icon: Icons.link_off,
                ),
              if (_error != null)
                NoteBox(title: 'Gagal memproses', text: _error!, color: AppColors.errorRed, icon: Icons.error_outline),
              const SizedBox(height: 20),
              if (_busy)
                const Padding(padding: EdgeInsets.all(12), child: LoadingView())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (_isExam)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed, padding: const EdgeInsets.all(14)),
                        onPressed: _fail,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Tidak lulus'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorRed, padding: const EdgeInsets.all(14)),
                      onPressed: _reject,
                      icon: const Icon(Icons.undo),
                      label: Text(_isJournal ? 'Tolak' : 'Tolak bukti'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen, padding: const EdgeInsets.all(14)),
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('Setujui'),
                    ),
                  ],
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Teks syarat bawaan diawali "Syarat ..." — label "Syarat" sudah ditampilkan.
String? _stripSyarat(String? s) {
  if (s == null) return null;
  final cleaned = s.replaceFirst(RegExp(r'^syarat\b\s*:?\s*', caseSensitive: false), '');
  if (cleaned.isEmpty) return s;
  return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
}
