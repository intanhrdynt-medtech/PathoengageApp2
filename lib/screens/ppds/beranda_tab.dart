import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/journal_screen.dart';
import 'package:fp_pemrograman/screens/penelitian_screen.dart';
import 'package:fp_pemrograman/screens/pengabdian_screen.dart';
import 'package:fp_pemrograman/screens/penilaian_saya_screen.dart';
import 'package:fp_pemrograman/screens/prestasi_screen.dart';
import 'package:fp_pemrograman/screens/rotations_screen.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Indeks tab di DashboardScreen yang bisa dibuka dari Beranda.
class PpdsTab {
  static const int beranda = 0;
  static const int logbook = 1;
  static const int ujian = 2;
  static const int akademik = 3;
  static const int profil = 4;
}

/// Isi tab Beranda PPDS. Data dimuat dari /me (termasuk progres kalung) dan
/// daftar kompetensi, ujian, tugas, journal, penelitian, serta survey aktif.
class BerandaTab extends StatefulWidget {
  /// Dipanggil untuk pindah ke tab lain di DashboardScreen (lihat [PpdsTab]).
  final ValueChanged<int> onOpenTab;

  /// Dipanggil setiap selesai memuat ulang (mis. untuk menyegarkan lonceng notifikasi).
  final VoidCallback? onReloaded;

  const BerandaTab({super.key, required this.onOpenTab, this.onReloaded});

  @override
  State<BerandaTab> createState() => BerandaTabState();
}

class BerandaTabState extends State<BerandaTab> {
  static const String _surveyDonePrefix = 'survey_done_';

  final ApiService _api = ApiService();
  bool _loading = true;
  bool _reloading = false;
  String? _error;

  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _competencies = [];
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _penelitian = [];
  List<Map<String, dynamic>> _surveys = [];
  Set<String> _surveyDone = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  List<Map<String, dynamic>> _maps(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  /// Memuat ulang semua data. [silent]: tanpa indikator memuat penuh
  /// (dipakai saat kembali dari halaman lain / pindah tab).
  Future<void> reload({bool silent = false}) async {
    if (_reloading) return;
    _reloading = true;
    if (!silent && _me == null) setState(() => _loading = true);

    final results = await Future.wait<Object?>([
      _api.getMe(),
      _api.getCompetencies(),
      _api.getExams(),
      _api.getAcademicTasks(),
      _api.getMyJournalReadings(),
      _api.getMyPenelitian(),
      _api.getActiveSurveys(),
      _loadSurveyDone(),
    ]);
    _reloading = false;
    if (!mounted) return;

    final me = results[0];
    if (me is! Map) {
      final message = _api.lastError ?? 'Gagal memuat data. Periksa koneksi internet.';
      if (_me != null) {
        // Data lama tetap ditampilkan; beri tahu bahwa pembaruan gagal.
        setState(() => _loading = false);
        showSnack(context, message, error: true);
      } else {
        setState(() {
          _loading = false;
          _error = message;
        });
      }
      return;
    }

    setState(() {
      _loading = false;
      _error = null;
      _me = Map<String, dynamic>.from(me);
      _competencies = _maps(results[1]);
      _exams = _maps(results[2]);
      _tasks = _maps(results[3]);
      _journals = _maps(results[4]);
      _penelitian = _maps(results[5]);
      _surveys = _maps(results[6]);
      _surveyDone = results[7] as Set<String>? ?? {};
    });
    widget.onReloaded?.call();
  }

  Future<Set<String>> _loadSurveyDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .where((k) => k.startsWith(_surveyDonePrefix) && prefs.getBool(k) == true)
          .map((k) => k.substring(_surveyDonePrefix.length))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _markSurveyDone(Map<String, dynamic> survey) async {
    final id = '${survey['id']}';
    setState(() => _surveyDone = {..._surveyDone, id});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_surveyDonePrefix$id', true);
    } catch (_) {}
    if (!mounted) return;
    showSnack(context, 'Survey ditandai sudah diisi.');
  }

  Future<void> _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    reload(silent: true);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null || _me == null) {
      return RefreshIndicator(
        onRefresh: reload,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: ErrorState(
                message: _error ?? 'Gagal memuat data. Periksa koneksi internet.',
                onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  reload();
                },
              ),
            ),
          ),
        ),
      );
    }

    final me = _me!;
    final kalung = me['kalung'] is Map ? Map<String, dynamic>.from(me['kalung']) : <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _greeting(me),
                const SizedBox(height: 12),
                if (me['warning_active'] == true) _spBanner(me),
                _kalungCard(me, kalung),
                _actionsSection(),
                _statsSection(kalung),
                _menuSection(),
                _tentangKalung(me['phase']?.toString() ?? kalung['phase']?.toString()),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Sapaan ───────────────────────────────────────────────────────────

  Widget _greeting(Map<String, dynamic> me) {
    final name = (me['full_name'] ?? '').toString().trim();
    final semester = me['current_semester'];
    final angkatan = (me['angkatan'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.darkMagenta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selamat datang,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(name.isEmpty ? '-' : name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PhaseBadge(me['phase']?.toString(), onDark: true),
                    _pill('Semester ${semester ?? '-'}'),
                    if (angkatan.isNotEmpty && angkatan != '-') _pill('Angkatan $angkatan'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  // ── 2. Surat Peringatan ─────────────────────────────────────────────────

  Widget _spBanner(Map<String, dynamic> me) {
    final msg = (me['warning_message'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_maybe_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Surat Peringatan (SP)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  msg.isEmpty ? 'Anda sedang menerima Surat Peringatan dari program studi.' : msg,
                  style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 6),
                const Text('Segera hubungi koordinator program studi.',
                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Progres Kalung ───────────────────────────────────────────────────

  Widget _kalungCard(Map<String, dynamic> me, Map<String, dynamic> kalung) {
    final phase = (kalung['phase'] ?? me['phase'])?.toString();
    final nextPhase = kalung['next_phase']?.toString();
    final syarat = _maps(kalung['syarat']);
    final komp = kalung['kompetensi_tahap_ini'] is Map ? kalung['kompetensi_tahap_ini'] as Map : const {};
    final total = (komp['total'] as num?)?.toInt() ?? 0;
    final selesai = (komp['selesai'] as num?)?.toInt() ?? 0;
    final peringatan = (kalung['peringatan_otomatis'] ?? '').toString().trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progres Kalung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PhaseBadge(phase),
              if (nextPhase != null) ...[
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.textGrey),
                PhaseBadge(nextPhase),
              ] else
                const Text('Tahap akhir', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
            ],
          ),
          if (syarat.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              nextPhase == null ? 'Syarat' : 'Syarat naik ke ${kalung['next_label'] ?? phaseLabel(nextPhase)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            for (final s in syarat)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      s['selesai'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: s['selesai'] == true ? AppColors.successGreen : AppColors.neutralGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text((s['label'] ?? '-').toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                            decoration: s['selesai'] == true ? TextDecoration.lineThrough : null,
                          )),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          Text(
            phase == 'MKDU'
                ? 'Kenaikan dari MKDU ke Kalung Merah dikonfirmasi admin setelah MKDU selesai.'
                : nextPhase != null
                    ? 'Kalung naik otomatis setelah hasil ujian diverifikasi lulus.'
                    : 'Anda sudah berada di kalung tertinggi.',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          if (kalung['siap_naik'] == true)
            const NoteBox(
              title: 'Syarat terpenuhi',
              text: 'Kalung Anda akan dinaikkan otomatis. Tarik layar ke bawah untuk memperbarui.',
              color: AppColors.successGreen,
              icon: Icons.celebration_outlined,
            ),
          const Divider(height: 24),
          InkWell(
            onTap: () => widget.onOpenTab(PpdsTab.logbook),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text('Kompetensi tahap ini',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                  Text('$selesai/$total',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (selesai / total).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.lightPurpleAccent,
                    color: phaseColor(phase),
                  ),
                ),
                if (total == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Belum ada kompetensi untuk tahap ini.',
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ),
              ],
            ),
          ),
          if (peringatan.isNotEmpty)
            NoteBox(
              title: 'Peringatan',
              text: peringatan,
              color: AppColors.warningOrange,
              icon: Icons.warning_amber_rounded,
            ),
        ],
      ),
    );
  }

  // ── 4. Perlu tindakan ──────────────────────────────────────────────────

  bool _hasText(Object? v) => (v ?? '').toString().trim().isNotEmpty;

  List<_ActionItem> _buildActions() {
    final items = <_ActionItem>[];

    for (final c in _competencies) {
      final status = c['status']?.toString();
      if (_hasText(c['alasan_tolak']) && status != 'completed' && status != 'pending_verification') {
        items.add(_ActionItem(
          icon: Icons.book_outlined,
          title: 'Perlu diperbaiki: ${c['competency_name'] ?? 'Kompetensi'}',
          subtitle: c['alasan_tolak'].toString(),
          onTap: () => widget.onOpenTab(PpdsTab.logbook),
        ));
      }
    }
    for (final e in _exams) {
      final result = e['result']?.toString();
      if (_hasText(e['alasan_tolak']) &&
          result != 'lulus' &&
          result != 'tidak_lulus' &&
          result != 'pending_verification') {
        items.add(_ActionItem(
          icon: Icons.school_outlined,
          title: 'Perlu diperbaiki: ${e['exam_name'] ?? 'Ujian'}',
          subtitle: e['alasan_tolak'].toString(),
          onTap: () => widget.onOpenTab(PpdsTab.ujian),
        ));
      }
    }
    for (final t in _tasks) {
      final status = t['status']?.toString();
      if (_hasText(t['alasan_tolak']) &&
          t['is_completed'] != true &&
          status != 'completed' &&
          status != 'pending_verification') {
        items.add(_ActionItem(
          icon: Icons.article_outlined,
          title: 'Perlu diperbaiki: ${t['title'] ?? 'Tugas akademik'}',
          subtitle: t['alasan_tolak'].toString(),
          onTap: () => widget.onOpenTab(PpdsTab.akademik),
        ));
      }
    }
    for (final j in _journals) {
      if (j['status'] == 'approved' && j['bukti_submitted'] != true) {
        items.add(_ActionItem(
          icon: Icons.upload_file,
          color: AppColors.infoBlue,
          title: 'Unggah bukti journal: ${j['judul'] ?? '-'}',
          subtitle: 'Journal sudah disetujui. Unggah bukti presentasi untuk menyelesaikannya.',
          onTap: () => _push(const JournalScreen()),
        ));
      }
    }
    for (final p in _penelitian) {
      final status = p['status']?.toString();
      if ((status == 'revisi_1' || status == 'revisi_2') && p['perlu_review'] != true) {
        final n = status == 'revisi_1' ? 1 : 2;
        final catatan = (p['catatan_revisi$n'] ?? '').toString().trim();
        items.add(_ActionItem(
          icon: Icons.edit_document,
          color: AppColors.warningOrange,
          title: 'Unggah Revisi $n: ${p['judul'] ?? '-'}',
          subtitle: catatan.isEmpty ? 'Penilai meminta revisi penelitian Anda.' : catatan,
          onTap: () => _push(const PenelitianScreen()),
        ));
      }
    }
    return items;
  }

  Widget _actionsSection() {
    final actions = _buildActions();
    final surveys = _surveys.where((s) => !_surveyDone.contains('${s['id']}')).toList();
    final count = actions.length + surveys.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Perlu tindakan',
          trailing: count == 0
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(20)),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
        ),
        if (count == 0)
          const AppCard(
            child: Row(children: [
              Icon(Icons.task_alt, color: AppColors.successGreen),
              SizedBox(width: 10),
              Expanded(
                child: Text('Tidak ada yang perlu ditindaklanjuti saat ini.',
                    style: TextStyle(fontSize: 14, color: AppColors.textDark)),
              ),
            ]),
          ),
        if (actions.isNotEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _actionTile(actions[i]),
                ],
              ],
            ),
          ),
        for (final s in surveys) _surveyCard(s),
      ],
    );
  }

  Widget _actionTile(_ActionItem a) {
    return ListTile(
      onTap: a.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: a.color.withValues(alpha: 0.12),
        child: Icon(a.icon, color: a.color, size: 20),
      ),
      title: Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      subtitle: a.subtitle == null
          ? null
          : Text(a.subtitle!,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
    );
  }

  Widget _surveyCard(Map<String, dynamic> s) {
    final link = (s['link_survey'] ?? '').toString();
    return AppCard(
      color: AppColors.warningOrange.withValues(alpha: 0.06),
      borderColor: AppColors.warningOrange.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.warningOrange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((s['judul'] ?? 'Survey semester').toString(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    const Text('Mohon isi survey evaluasi semester ini.',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _markSurveyDone(s),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Sudah diisi', style: TextStyle(fontSize: 14)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: link.isEmpty ? null : () => openLink(context, link),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Isi Sekarang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Ringkasan ────────────────────────────────────────────────────────

  Widget _statsSection(Map<String, dynamic> kalung) {
    final komp = kalung['kompetensi_tahap_ini'] is Map ? kalung['kompetensi_tahap_ini'] as Map : const {};
    final kTotal = (komp['total'] as num?)?.toInt() ?? 0;
    final kDone = (komp['selesai'] as num?)?.toInt() ?? 0;
    final examsPassed = _exams.where((e) => e['result'] == 'lulus').length;
    final tasksPending = _tasks.where((t) => t['status'] == 'pending_verification').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Ringkasan'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _statCard('$kDone/$kTotal', 'Kompetensi tahap ini', Icons.book_outlined, AppColors.primaryPurple,
                    () => widget.onOpenTab(PpdsTab.logbook)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard('$examsPassed/${_exams.length}', 'Ujian lulus', Icons.school_outlined,
                    AppColors.infoBlue, () => widget.onOpenTab(PpdsTab.ujian)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard('$tasksPending', 'Tugas menunggu verifikasi', Icons.hourglass_top,
                    AppColors.warningOrange, () => widget.onOpenTab(PpdsTab.akademik)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  // ── 6. Menu ─────────────────────────────────────────────────────────────

  Widget _menuSection() {
    final menus = <_MenuItem>[
      _MenuItem(Icons.menu_book, 'Journal Reading', 'Bacaan & presentasi jurnal', const Color(0xFF3949AB),
          () => _push(const JournalScreen())),
      _MenuItem(Icons.science_outlined, 'Penelitian', 'Proposal hingga publikasi', const Color(0xFF00897B),
          () => _push(const PenelitianScreen())),
      _MenuItem(Icons.volunteer_activism_outlined, 'Pengabdian Masyarakat', 'Kegiatan pengabdian',
          AppColors.warningOrange, () => _push(const PengabdianScreen())),
      _MenuItem(Icons.emoji_events_outlined, 'Prestasi', 'Penghargaan & lomba', AppColors.phaseYellow,
          () => _push(const PrestasiScreen())),
      _MenuItem(Icons.local_hospital_outlined, 'Stase', 'Jadwal rotasi luar', AppColors.successGreen,
          () => _push(const RotationsScreen())),
      _MenuItem(Icons.grade_outlined, 'Nilai Saya', 'Nilai dari pembimbing', AppColors.primaryPurple,
          () => _push(const PenilaianSayaScreen())),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Menu'),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 640 ? 3 : 2;
          final rows = <Widget>[];
          for (var i = 0; i < menus.length; i += cols) {
            final chunk = menus.sublist(i, (i + cols).clamp(0, menus.length));
            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(child: j < chunk.length ? _menuCard(chunk[j]) : const SizedBox()),
                  ],
                ],
              ),
            ));
          }
          return Column(children: rows);
        }),
      ],
    );
  }

  Widget _menuCard(_MenuItem m) {
    return AppCard(
      onTap: m.onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: m.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(m.icon, color: m.color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(m.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  // ── 7. Tentang kalung ───────────────────────────────────────────────────

  Widget _tentangKalung(String? phase) {
    final info = _kalungInfo(phase);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(Icons.military_tech_outlined, color: phaseColor(phase)),
          title: const Text('Tentang kalung Anda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(phaseLabel(phase), style: const TextStyle(fontSize: 12)),
          children: [
            _infoRow('Status', info.$1),
            _infoRow('Kewenangan', info.$2),
            _infoRow('Syarat naik', info.$3),
            const NoteBox(
              title: 'Kalung dan Surat Peringatan berbeda',
              text: 'Warna kalung menunjukkan tahap kewenangan Anda. Surat Peringatan (SP) adalah status terpisah '
                  'yang diberikan admin program studi.',
            ),
          ],
        ),
      ),
    );
  }

  (String, String, String) _kalungInfo(String? phase) {
    switch (phase) {
      case 'MKDU':
        return (
          'Observer / mahasiswa baru',
          'Mengikuti perkuliahan umum (MKDU) bersama seluruh PPDS baru lintas departemen.',
          'Menyelesaikan MKDU. Kenaikan ke Kalung Merah dikonfirmasi admin.',
        );
      case 'red':
        return (
          'Junior PPDS',
          'Belum diperbolehkan melakukan tindakan medis apa pun secara mandiri tanpa pengawasan penuh. '
              'Fokus pada keilmuan dasar dan metodologi.',
          'Lulus Ujian Organ I. Kalung naik otomatis ke Kalung Kuning setelah hasil ujian diverifikasi lulus. '
              'Target paling lambat semester 2.',
        );
      case 'yellow':
        return (
          'Intermediate PPDS',
          'Boleh melakukan tindakan medis/pelayanan diagnostik di bawah pengawasan senior atau dokter spesialis '
              'penanggung jawab.',
          'Lulus Ujian Organ II. Kalung naik otomatis ke Kalung Hijau setelah hasil ujian diverifikasi lulus.',
        );
      case 'green':
        return (
          'Senior PPDS',
          'Kompeten secara mandiri melakukan tindakan level Sp.PA (Spesialis Patologi Anatomi) tanpa pengawasan. '
              'Menjalani stase luar.',
          'Kalung tertinggi. Persiapan Ujian Nasional Tahap 1, tesis, dan Ujian Board Sp.PA.',
        );
      default:
        return ('Belum ditentukan', 'Data kewenangan belum tersedia.', 'Hubungi admin program studi.');
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.4)),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.errorRed,
  });
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
}
