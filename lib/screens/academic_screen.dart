import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Tugas akademik PPDS: buku teks, journal reading, tugas ilmiah, penelitian,
/// publikasi, dan etik.
class AcademicScreen extends StatefulWidget {
  const AcademicScreen({super.key});
  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

/// Normalisasi judul untuk mencocokkan sampul buku: huruf kecil, apostrof
/// lengkung (’ ‘ `) disamakan dengan apostrof lurus, spasi dirapikan.
String _normTitle(String s) =>
    s.toLowerCase().replaceAll(RegExp('[‘’ʼ`]'), "'").replaceAll(RegExp(r'\s+'), ' ').trim();

/// Sampul buku teks (kunci = judul yang sudah dinormalisasi).
final Map<String, String> _covers = {
  _normTitle('Classification of Tumor'): 'assets/images/classification of tumor.png',
  _normTitle('Pathologic Basic of Disease'): 'assets/images/Pathologic Basic of Disease.jpg',
  _normTitle('Basic Pathology'): 'assets/images/Basic Patology.jpg',
  _normTitle('Robbins Basic Pathology'): 'assets/images/Basic Patology.jpg',
  _normTitle("Enzinger and Weiss's Soft Tissue Tumors"): "assets/images/Enzinger and Weiss's Soft Tissue Tumors.jpg",
  // Nama file aset memakai apostrof lengkung.
  _normTitle("Cibas and Ducatman's Cytology"): 'assets/images/Cibas and Ducatman’s Cytology.jpg',
  _normTitle('Pathology'): 'assets/images/Pathology.png',
  _normTitle("Silva's Diagnostic Renal Pathology"): "assets/images/Silva's Diagnostic Renal Pathology.jpg",
  _normTitle("Weedon's Skin Pathology"): "assets/images/Weedon's Skin Pathology.jpg",
};

/// Kategori (nilai task_type di server) → label tab.
const List<MapEntry<String?, String>> _categories = [
  MapEntry(null, 'Semua'),
  MapEntry('Textbook Reading', 'Buku Teks'),
  MapEntry('Journal Reading', 'Journal Reading'),
  MapEntry('Tugas Ilmiah', 'Tugas Ilmiah'),
  MapEntry('Penelitian', 'Penelitian'),
  MapEntry('Publikasi', 'Publikasi'),
  MapEntry('Etik', 'Etik'),
];

String _typeLabel(String type) {
  for (final c in _categories) {
    if (c.key == type) return c.value;
  }
  return type.isEmpty ? 'Tugas' : type;
}

class _AcademicScreenState extends State<AcademicScreen> {
  final ModuleApi _api = ModuleApi();
  List<dynamic> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.list('/academic-tasks');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? _api.errorMessage : null;
      if (data != null) _tasks = data;
    });
  }

  bool _isDone(dynamic t) => t['is_completed'] == true || t['status'] == 'completed';

  /// Buku teks & journal reading dikerjakan dengan resume (+ link opsional).
  bool _needsResume(dynamic t) => t['task_type'] == 'Textbook Reading' || t['task_type'] == 'Journal Reading';

  Future<void> _open(Map<String, dynamic> t) async {
    if (_isDone(t)) {
      showSnack(context, 'Tugas ini sudah diverifikasi admin dan tidak bisa diubah lagi.');
      return;
    }
    final pending = t['status'] == 'pending_verification';
    final rejected = str(t['alasan_tolak']).isNotEmpty && !pending;
    final title = str(t['title']);
    final resume = _needsResume(t);
    final note = pending
        ? '\n\nSedang menunggu verifikasi admin. Anda masih bisa mengubahnya.'
        : rejected
            ? '\n\nPerbaiki sesuai alasan penolakan, lalu kirim ulang.'
            : '';

    final res = await showSubmitLinkDialog(
      context,
      title: resume
          ? (pending ? 'Ubah resume' : rejected ? 'Kirim ulang resume' : 'Kirim resume bacaan')
          : (pending ? 'Ubah link bukti' : rejected ? 'Kirim ulang bukti' : 'Kirim bukti tugas'),
      description: resume
          ? '$title\n\nTulis resume dari bacaan Anda. Link bukti (mis. catatan atau slide) boleh dikosongkan.$note'
          : '$title\n\nUnggah dokumen tugas ke Google Drive, lalu tempel link-nya.$note',
      withNotes: resume,
      notesRequired: resume,
      notesLabel: 'Resume bacaan',
      initialNotes: resume ? str(t['notes']) : null,
      linkLabel: resume ? 'Link bukti (opsional)' : 'Link bukti tugas',
      // Bukti tidak pernah diisi otomatis dengan link referensi (link_url).
      initialLink: str(t['document_proof_url']),
      submitText: pending ? 'Simpan perubahan' : 'Kirim untuk diverifikasi',
    );
    if (res == null || !mounted) return;
    final body = <String, dynamic>{
      'status': 'pending_verification',
      'document_proof_url': res['link'] ?? '',
      if (resume) 'notes': res['catatan'] ?? '',
    };
    final ok = await _api.ok('PUT', '/academic-tasks/${t['id']}', body: body);
    if (!mounted) return;
    if (ok) {
      showSnack(context, pending ? 'Perubahan tersimpan.' : 'Terkirim. Menunggu verifikasi admin.');
      _load();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        // Ditampilkan sebagai tab di dalam DashboardScreen yang sudah punya
        // AppBar (judul, notifikasi, akun) — di sini cukup baris tab-nya.
        appBar: AppBar(
          primary: false,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          bottom: moduleTabBar(_categories.map((c) => c.value).toList(), scrollable: true),
        ),
        body: TabBarView(children: _categories.map((c) => _buildTab(c.key)).toList()),
      ),
    );
  }

  Widget _buildTab(String? type) {
    return moduleBody(
      loading: _loading,
      error: _error,
      onRefresh: _load,
      builder: () {
        final items = type == null ? _tasks : _tasks.where((t) => t['task_type'] == type).toList();
        final done = items.where(_isDone).length;
        return [
          ModuleProgressCard(
            title: type == null ? 'Semua tugas akademik' : _typeLabel(type),
            done: done,
            total: items.length,
            caption: type == 'Textbook Reading' || type == 'Journal Reading'
                ? 'Baca referensinya, lalu kirim resume untuk diverifikasi.'
                : 'Ketuk tugas untuk mengirim bukti.',
          ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.inbox_outlined, title: 'Tidak ada tugas di kategori ini')
          else
            ...items.map((t) => _card(t as Map<String, dynamic>, showType: type == null)),
        ];
      },
    );
  }

  Widget _leading(Map<String, dynamic> t, Color color) {
    final cover = _covers[_normTitle(str(t['title']))];
    final icon = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(_typeIcon(str(t['task_type'])), color: color, size: 26),
    );
    if (cover == null || t['task_type'] != 'Textbook Reading') return icon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(cover, width: 52, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => icon),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Textbook Reading':
        return Icons.menu_book;
      case 'Journal Reading':
        return Icons.article;
      case 'Tugas Ilmiah':
        return Icons.assignment;
      case 'Penelitian':
        return Icons.science;
      case 'Etik':
        return Icons.gavel;
      case 'Publikasi':
        return Icons.publish;
      default:
        return Icons.task_alt;
    }
  }

  Widget _card(Map<String, dynamic> t, {required bool showType}) {
    final status = str(t['status']);
    final alasan = str(t['alasan_tolak']);
    final done = _isDone(t);
    final pending = status == 'pending_verification';
    final resume = _needsResume(t);
    final notes = str(t['notes']);
    final proof = str(t['document_proof_url']);
    final reference = str(t['link_url']);
    final deadline = parseDate(t['deadline']);
    final overdue = deadline != null && !done && deadline.isBefore(DateTime.now());
    const color = AppColors.primaryPurple;

    String? actionLabel;
    IconData actionIcon = resume ? Icons.edit_note : Icons.upload;
    if (pending) {
      actionLabel = resume ? 'Ubah resume' : 'Ubah link bukti';
      actionIcon = Icons.edit;
    } else if (!done && alasan.isNotEmpty) {
      actionLabel = resume ? 'Kirim ulang resume' : 'Kirim ulang bukti';
      actionIcon = Icons.refresh;
    } else if (!done) {
      actionLabel = resume ? 'Tulis resume' : 'Kirim bukti';
    }

    return AppCard(
      onTap: () => _open(t),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _leading(t, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(t['title']).isEmpty ? '-' : str(t['title']), style: kCardTitle),
              if (str(t['description']).isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(str(t['description']), style: kCaption),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusChip(progressStatus(status, isCompleted: t['is_completed'] == true, alasanTolak: alasan)),
                if (showType) _tag(_typeLabel(str(t['task_type']))),
                if (t['target_semester'] != null) _tag('Semester ${t['target_semester']}'),
              ]),
            ]),
          ),
        ]),
        if (deadline != null)
          MetaRow(
            icon: Icons.event,
            label: overdue ? 'Tenggat (terlewat)' : 'Tenggat',
            value: formatTanggal(t['deadline']),
            valueColor: overdue ? AppColors.errorRed : null,
          ),
        if (alasan.isNotEmpty && !pending && !done)
          NoteBox(title: 'Alasan ditolak admin', text: alasan, color: AppColors.errorRed, icon: Icons.error_outline),
        if (reference.isNotEmpty) ...[
          const CardSectionLabel('Referensi'),
          Align(alignment: Alignment.centerLeft, child: LinkButton(label: 'Buka referensi', url: reference)),
        ],
        if ((resume && notes.isNotEmpty) || proof.isNotEmpty) ...[
          CardSectionLabel(resume ? 'Resume & bukti saya' : 'Bukti saya'),
          if (resume && notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(notes, style: kBody, maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          if (proof.isNotEmpty) Align(alignment: Alignment.centerLeft, child: LinkButton(label: 'Lihat bukti', url: proof)),
        ],
        if (actionLabel != null)
          CardActionButton(label: actionLabel, icon: actionIcon, outlined: pending, onPressed: () => _open(t))
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Sudah selesai — tidak bisa diubah lagi.', style: kCaption),
          ),
      ]),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightPurpleAccent.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
    );
  }
}
