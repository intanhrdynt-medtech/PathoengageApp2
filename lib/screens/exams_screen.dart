import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Ujian lokal & nasional (bukti dikirim PPDS, diverifikasi admin) serta
/// ujian organ (hasil diisi penguji).
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final ModuleApi _api = ModuleApi();
  List<dynamic> _exams = [];
  List<dynamic> _organ = [];
  bool _loading = true;
  String? _error;
  String? _organError;

  static const List<String> _tabs = ['Semua', 'Lokal', 'Nasional', 'Organ'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exams = await _api.list('/exams');
    final examErr = exams == null ? _api.errorMessage : null;
    final organ = await _api.list('/organ-exams');
    final organErr = organ == null ? _api.errorMessage : null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = examErr;
      _organError = organErr;
      if (exams != null) _exams = exams;
      if (organ != null) _organ = organ;
    });
  }

  /// Teks syarat dari `notes` (diisi saat kurikulum dibuat), tanpa awalan "Syarat:".
  String _syarat(dynamic notes) {
    final s = str(notes);
    // Teks bawaan diawali "Syarat ..." / "Syarat: ..." — label "Syarat" sudah ditampilkan.
    final cleaned = s.replaceFirst(RegExp(r'^syarat\b\s*:?\s*', caseSensitive: false), '');
    return cleaned.isEmpty ? s : '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  Future<void> _open(Map<String, dynamic> e) async {
    final result = str(e['result']);
    if (result == 'lulus') {
      showSnack(context, 'Ujian ini sudah dinyatakan lulus dan tidak bisa diubah lagi.');
      return;
    }
    final pending = result == 'pending_verification';
    final failed = result == 'tidak_lulus';
    final rejected = str(e['alasan_tolak']).isNotEmpty && !failed;
    final name = str(e['exam_name']);
    final res = await showSubmitLinkDialog(
      context,
      title: pending
          ? 'Ubah link bukti ujian'
          : failed
              ? 'Kirim bukti ujian remedial'
              : rejected
                  ? 'Kirim ulang bukti ujian'
                  : 'Kirim bukti hasil ujian',
      description: pending
          ? '$name\n\nBukti sedang menunggu verifikasi admin. Anda masih bisa mengganti link-nya.'
          : failed
              ? '$name\n\nSetelah mengikuti ujian ulang/remedial, kirim bukti hasilnya untuk diverifikasi kembali.'
              : rejected
                  ? '$name\n\nPerbaiki bukti sesuai alasan penolakan, lalu kirim ulang.'
                  : '$name\n\nUnggah bukti hasil ujian (mis. berita acara atau sertifikat) ke Google Drive, lalu tempel link-nya.',
      initialLink: failed ? '' : str(e['evidence_url']),
      submitText: pending ? 'Simpan perubahan' : 'Kirim untuk diverifikasi',
    );
    if (res == null || !mounted) return;
    final ok = await _api.ok('PUT', '/exams/${e['id']}',
        body: {'result': 'pending_verification', 'evidence_url': res['link']});
    if (!mounted) return;
    if (ok) {
      showSnack(context, pending ? 'Link bukti diperbarui.' : 'Bukti ujian terkirim. Menunggu verifikasi admin.');
      _load();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        // Ditampilkan sebagai tab di dalam DashboardScreen yang sudah punya
        // AppBar (judul, notifikasi, akun) — di sini cukup baris tab-nya.
        appBar: AppBar(
          primary: false,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          bottom: moduleTabBar(_tabs, scrollable: true),
        ),
        body: TabBarView(children: _tabs.map(_buildTab).toList()),
      ),
    );
  }

  Widget _buildTab(String tab) {
    if (tab == 'Organ') {
      return moduleBody(
        loading: _loading,
        error: _organError,
        onRefresh: _load,
        builder: () => [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Jadwal dan hasil ujian organ diisi oleh admin dan dosen penguji.', style: kCaption),
          ),
          if (_organ.isEmpty)
            const EmptyState(
              icon: Icons.medical_services_outlined,
              title: 'Belum ada ujian organ',
              message: 'Ujian organ akan muncul di sini setelah dijadwalkan admin.',
            )
          else
            ..._organ.map((o) => _organCard(o as Map<String, dynamic>)),
        ],
      );
    }
    return moduleBody(
      loading: _loading,
      error: _error,
      onRefresh: _load,
      builder: () {
        final items = tab == 'Semua' ? _exams : _exams.where((e) => e['exam_type'] == tab).toList();
        final lulus = items.where((e) => e['result'] == 'lulus').length;
        return [
          ModuleProgressCard(
            title: tab == 'Semua' ? 'Ujian lokal & nasional' : 'Ujian $tab',
            done: lulus,
            total: items.length,
            doneLabel: 'lulus',
            caption: 'Ketuk ujian untuk mengirim bukti hasil ujian.',
          ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.school_outlined, title: 'Belum ada data ujian')
          else
            ...items.map((e) => _examCard(e as Map<String, dynamic>)),
        ];
      },
    );
  }

  Widget _examCard(Map<String, dynamic> e) {
    final result = str(e['result']);
    final alasan = str(e['alasan_tolak']);
    final lulus = result == 'lulus';
    final pending = result == 'pending_verification';
    final failed = result == 'tidak_lulus';
    final color = phaseColor(e['phase_category']);
    final syarat = _syarat(e['notes']);

    String? actionLabel;
    IconData actionIcon = Icons.upload;
    if (pending) {
      actionLabel = 'Ubah link bukti';
      actionIcon = Icons.edit;
    } else if (failed) {
      actionLabel = 'Kirim bukti remedial';
      actionIcon = Icons.replay;
    } else if (!lulus && alasan.isNotEmpty) {
      actionLabel = 'Kirim ulang bukti';
      actionIcon = Icons.refresh;
    } else if (!lulus) {
      actionLabel = 'Kirim bukti hasil ujian';
    }

    return AppCard(
      onTap: () => _open(e),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.school, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(e['exam_name']).isEmpty ? '-' : str(e['exam_name']), style: kCardTitle),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusChip(examStatus(result, alasanTolak: alasan)),
                if (str(e['phase_category']).isNotEmpty) PhaseBadge(e['phase_category']),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        MetaRow(icon: Icons.category_outlined, label: 'Jenis', value: str(e['exam_type'])),
        if (str(e['scheduled_date']).isNotEmpty)
          MetaRow(icon: Icons.event, label: 'Jadwal', value: formatTanggal(e['scheduled_date'])),
        MetaRow(icon: Icons.rule, label: 'Syarat', value: syarat),
        if (e['score'] != null) MetaRow(icon: Icons.grade_outlined, label: 'Nilai', value: '${e['score']}'),
        if (alasan.isNotEmpty && !pending)
          NoteBox(
            title: failed ? 'Keterangan admin' : 'Alasan bukti ditolak',
            text: alasan,
            color: AppColors.errorRed,
            icon: Icons.error_outline,
          ),
        if (failed)
          const NoteBox(
            title: 'Ujian remedial',
            text: 'Anda dinyatakan belum lulus. Setelah mengikuti ujian ulang, kirim bukti hasilnya untuk diverifikasi.',
            color: AppColors.warningOrange,
            icon: Icons.info_outline,
          ),
        if (str(e['evidence_url']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinkButton(label: 'Lihat bukti', url: str(e['evidence_url'])),
          ),
        if (actionLabel != null)
          CardActionButton(label: actionLabel, icon: actionIcon, outlined: pending, onPressed: () => _open(e))
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Sudah lulus — tidak bisa diubah lagi.', style: kCaption),
          ),
      ]),
    );
  }

  Widget _organCard(Map<String, dynamic> o) {
    final hasil = str(o['hasil']);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.medical_services, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(o['nama_ujian']).isEmpty ? 'Ujian Organ' : str(o['nama_ujian']), style: kCardTitle),
              const SizedBox(height: 6),
              StatusChip(examStatus(hasil.isEmpty ? 'terjadwal' : hasil)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        MetaRow(icon: Icons.biotech_outlined, label: 'Organ', value: str(o['organ'])),
        MetaRow(icon: Icons.person_outline, label: 'Penguji', value: str(o['penguji'])),
        if (str(o['tanggal']).isNotEmpty) MetaRow(icon: Icons.event, label: 'Tanggal', value: formatTanggal(o['tanggal'])),
        if (o['nilai'] != null) MetaRow(icon: Icons.grade_outlined, label: 'Nilai', value: '${o['nilai']}'),
        if (str(o['catatan']).isNotEmpty) NoteBox(title: 'Catatan penguji', text: str(o['catatan'])),
      ]),
    );
  }
}
