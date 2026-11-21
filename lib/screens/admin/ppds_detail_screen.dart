import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/screens/admin/ppds_forms.dart';
import 'package:fp_pemrograman/screens/admin/user_forms.dart';
import 'package:fp_pemrograman/screens/admin_progress_screen.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Admin: semua data dan pengaturan satu PPDS dalam satu halaman bertab.
/// Mengembalikan true (lewat Navigator.pop) bila PPDS dihapus.
class PpdsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PpdsDetailScreen({super.key, required this.user});

  @override
  State<PpdsDetailScreen> createState() => _PpdsDetailScreenState();
}

const _tabs = ['Ringkasan', 'Pembimbing', 'Kompetensi', 'Ujian', 'Tugas', 'Ujian Organ', 'Penilaian', 'Stase'];

class _PpdsDetailScreenState extends State<PpdsDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _progress;
  List<dynamic>? _penilaian;
  List<dynamic>? _penilai;
  bool _loading = true;
  String? _error;

  int get _uid => widget.user['id'] as int;

  Map<String, dynamic> get _user {
    final u = _progress?['user'];
    return u is Map ? Map<String, dynamic>.from(u) : widget.user;
  }

  String get _name => textOf(_user['full_name']).isEmpty ? 'PPDS' : textOf(_user['full_name']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _progress == null;
      _error = null;
    });
    final penilaianApi = ApiService();
    final penilaiApi = ApiService();
    final results = await Future.wait<dynamic>([
      _api.adminGetProgress(_uid),
      penilaianApi.adminGetPenilaian(_uid),
      penilaiApi.getPenilaiList(),
    ]);
    if (!mounted) return;
    final progress = results[0] as Map<String, dynamic>?;
    setState(() {
      _loading = false;
      if (progress == null) {
        _error = _api.lastError ?? 'Gagal memuat data PPDS.';
      } else {
        _progress = progress;
      }
      _penilaian = results[1] as List<dynamic>?;
      _penilai = results[2] as List<dynamic>?;
    });
    if (progress == null && _progress != null && mounted) {
      showSnack(context, _error!, error: true);
    }
  }

  Future<void> _edit() async {
    final saved = await showEditPpdsDialog(context, _user);
    if (saved && mounted) _load();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus PPDS?',
      message: 'Akun $_name beserta seluruh datanya (kompetensi, ujian, tugas, stase, ujian organ, penilaian, '
          'journal, penelitian) akan dihapus permanen dan tidak dapat dikembalikan.',
      confirmText: 'Hapus permanen',
      danger: true,
    );
    if (!ok || !mounted) return;
    final deleted = await _api.deleteUser(_uid);
    if (!mounted) return;
    if (deleted) {
      showSnack(context, 'PPDS $_name dihapus');
      Navigator.pop(context, true);
    } else {
      showSnack(context, 'Gagal menghapus PPDS. Coba lagi.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Lainnya',
              onSelected: (v) {
                if (v == 'hapus') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'hapus',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: AppColors.errorRed),
                    SizedBox(width: 8),
                    Text('Hapus PPDS', style: TextStyle(color: AppColors.errorRed)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : _progress == null
                ? ErrorState(message: _error ?? 'Gagal memuat data PPDS.', onRetry: _load)
                : Column(children: [
                    _Header(user: _user, onEdit: _edit),
                    Material(
                      color: Colors.white,
                      child: MaxWidth(
                        maxWidth: 1100,
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppColors.primaryPurple,
                          unselectedLabelColor: AppColors.textGrey,
                          indicatorColor: AppColors.primaryPurple,
                          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: const TextStyle(fontSize: 14),
                          tabs: [for (final t in _tabs) Tab(text: t)],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    Expanded(
                      child: TabBarView(children: [
                        _SummaryTab(
                          user: _user,
                          progress: _progress!,
                          onRefresh: _load,
                          onChanged: _load,
                          onDelete: _delete,
                        ),
                        _PembimbingTab(
                          key: ValueKey('pembimbing-${[
                            for (final p in peranPembimbingLabel.keys) _user['${p}_id']
                          ].join('-')}-${_penilai?.length}'),
                          user: _user,
                          penilai: _penilai,
                          onRefresh: _load,
                          onSaved: _load,
                        ),
                        AdminCompetencyTab(
                          progress: _progress!,
                          ppdsName: _name,
                          currentPhase: _user['phase'] as String?,
                          onRefresh: _load,
                          onChanged: _load,
                        ),
                        AdminExamTab(progress: _progress!, ppdsName: _name, onRefresh: _load, onChanged: _load),
                        AdminTaskTab(
                            progress: _progress!, ppdsId: _uid, ppdsName: _name, onRefresh: _load, onChanged: _load),
                        _OrganExamTab(
                          ppdsId: _uid,
                          exams: (_progress!['organ_exams'] as List?) ?? const [],
                          penilai: _penilai,
                          onRefresh: _load,
                          onChanged: _load,
                        ),
                        _PenilaianTab(penilaian: _penilaian, onRefresh: _load),
                        _RotationTab(
                          ppdsId: _uid,
                          rotations: ((_progress!['rotations'] as Map?)?['items'] as List?) ?? const [],
                          onRefresh: _load,
                          onChanged: _load,
                        ),
                      ]),
                    ),
                  ]),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  const _Header({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final meta = [
      'NIM ${textOf(user['nim']).isEmpty ? '-' : textOf(user['nim'])}',
      if (textOf(user['angkatan']).isNotEmpty) 'Angkatan ${textOf(user['angkatan'])}',
      'Semester ${user['current_semester'] ?? '-'}',
    ];
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: MaxWidth(
        maxWidth: 1100,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            PersonAvatar(name: user['full_name'] as String?, color: phaseColor(user['phase'] as String?), radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(textOf(user['full_name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(meta.join(' · '), style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  PhaseBadge(user['phase'] as String?),
                  if (user['warning_active'] == true)
                    const TagChip('SP aktif', color: AppColors.errorRed, icon: Icons.warning_amber),
                ]),
              ]),
            ),
            IconButton(tooltip: 'Edit data PPDS', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          ]),
        ),
      ),
    );
  }
}

class _TabScroll extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  const _TabScroll({required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AdminListView(maxWidth: 1000, children: children),
    );
  }
}

// ── Ringkasan ─────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> progress;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _SummaryTab({required this.user, required this.progress, required this.onRefresh, required this.onChanged,
      required this.onDelete});

  int _n(String section, String key) => ((progress[section] as Map?)?[key] as num?)?.toInt() ?? 0;

  Future<void> _confirmMkdu(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Konfirmasi MKDU selesai?',
      message: '${textOf(user['full_name'])} akan naik dari MKDU ke Kalung Merah. '
          'Kenaikan ini ditetapkan manual oleh admin.',
      confirmText: 'Naikkan ke Kalung Merah',
    );
    if (!ok || !context.mounted) return;
    final api = ApiService();
    final saved = await api.adminSaveProfile(user['id'] as int, {'phase': 'red'});
    if (!context.mounted) return;
    if (saved) {
      showSnack(context, 'Kalung diperbarui ke Kalung Merah');
      onChanged();
    } else {
      showSnack(context, api.lastError ?? 'Gagal memperbarui kalung.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kalung = (progress['kalung'] as Map?) ?? const {};
    final phase = (kalung['phase'] ?? user['phase']) as String?;
    final kompetensi = (kalung['kompetensi_tahap_ini'] as Map?) ?? const {};
    final syarat = (kalung['syarat'] as List?) ?? const [];
    final peringatan = textOf(kalung['peringatan_otomatis']);

    return _TabScroll(onRefresh: onRefresh, children: [
      const SectionTitle('Progres kalung'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PhaseBadge(phase),
            const SizedBox(width: 8),
            if (textOf(kalung['next_label']).isNotEmpty) ...[
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.textGrey),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Berikutnya: ${textOf(kalung['next_label'])}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
              ),
            ] else
              const Text('Tahap akhir', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ]),
          const SizedBox(height: 14),
          if (((kompetensi['total'] as num?) ?? 0) > 0)
            ProgressLine(
              label: 'Kompetensi tahap ini',
              done: (kompetensi['selesai'] as num?)?.toInt() ?? 0,
              total: (kompetensi['total'] as num?)?.toInt() ?? 0,
              color: phaseColor(phase),
            ),
          if (syarat.isNotEmpty) ...[
            const Text('Syarat naik kalung',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            for (final s in syarat)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(
                    (s as Map)['selesai'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: s['selesai'] == true ? AppColors.successGreen : AppColors.neutralGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(textOf(s['label']), style: const TextStyle(fontSize: 14))),
                ]),
              ),
          ],
          if (kalung['siap_naik'] == true)
            const NoteBox(
              title: 'Syarat terpenuhi',
              text: 'Kalung naik otomatis saat data PPDS diperbarui berikutnya.',
              color: AppColors.successGreen,
              icon: Icons.verified,
            ),
          if (phase == 'MKDU' || phase == null) ...[
            const SizedBox(height: 8),
            const Text('Kenaikan dari MKDU ke Kalung Merah ditetapkan manual oleh admin.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmMkdu(context),
              icon: const Icon(Icons.military_tech_outlined),
              label: const Text('Konfirmasi MKDU selesai'),
            ),
          ],
          if (peringatan.isNotEmpty)
            NoteBox(title: 'Peringatan otomatis', text: peringatan, color: AppColors.warningOrange, icon: Icons.warning_amber),
        ]),
      ),
      const SectionTitle('Progres keseluruhan'),
      AppCard(
        child: Column(children: [
          ProgressLine(
              label: 'Kompetensi',
              done: _n('competencies', 'completed'),
              total: _n('competencies', 'total'),
              color: AppColors.secondaryMagenta),
          ProgressLine(label: 'Ujian lulus', done: _n('exams', 'passed'), total: _n('exams', 'total'), color: AppColors.infoBlue),
          ProgressLine(
              label: 'Tugas akademik',
              done: _n('academic_tasks', 'completed'),
              total: _n('academic_tasks', 'total'),
              color: AppColors.primaryPurple),
          ProgressLine(
              label: 'Stase selesai', done: _n('rotations', 'completed'), total: _n('rotations', 'total'), color: AppColors.successGreen),
        ]),
      ),
      const SectionTitle('Surat Peringatan (SP)'),
      _WarningCard(
        key: ValueKey('sp-${user['warning_active']}-${user['warning_message']}'),
        user: user,
        onSaved: onChanged,
      ),
      const SectionTitle('Zona berbahaya'),
      AppCard(
        borderColor: AppColors.errorRed.withValues(alpha: 0.4),
        child: Row(children: [
          const Expanded(
            child: Text('Hapus akun PPDS beserta seluruh datanya. Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.errorRed),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus PPDS'),
          ),
        ]),
      ),
    ]);
  }
}

class _WarningCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  const _WarningCard({super.key, required this.user, required this.onSaved});

  @override
  State<_WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends State<_WarningCard> {
  final ApiService _api = ApiService();
  late bool _active = widget.user['warning_active'] == true;
  late final TextEditingController _msg = TextEditingController(text: textOf(widget.user['warning_message']));
  bool _busy = false;
  String? _msgError;

  bool get _dirty =>
      _active != (widget.user['warning_active'] == true) || _msg.text.trim() != textOf(widget.user['warning_message']);

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_active && _msg.text.trim().isEmpty) {
      setState(() => _msgError = 'Isi pesan SP untuk PPDS');
      return;
    }
    final wasActive = widget.user['warning_active'] == true;
    if (_active != wasActive) {
      final ok = await confirmDialog(
        context,
        title: _active ? 'Aktifkan SP?' : 'Cabut SP?',
        message: _active
            ? '${textOf(widget.user['full_name'])} akan menerima notifikasi Surat Peringatan beserta pesannya.'
            : 'Status SP ${textOf(widget.user['full_name'])} akan dinonaktifkan.',
        confirmText: _active ? 'Aktifkan SP' : 'Cabut SP',
        danger: _active,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final ok = await _api.adminSetWarning(widget.user['id'] as int, _active, _msg.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showSnack(context, 'Status SP disimpan');
      widget.onSaved();
    } else {
      showSnack(context, 'Gagal menyimpan status SP. Coba lagi.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: _active ? AppColors.errorRed.withValues(alpha: 0.5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('SP aktif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('PPDS melihat pesan SP di dashboard-nya.', style: TextStyle(fontSize: 13)),
          value: _active,
          onChanged: _busy ? null : (v) => setState(() => _active = v),
        ),
        TextField(
          controller: _msg,
          maxLines: 3,
          minLines: 2,
          enabled: !_busy,
          onChanged: (_) => setState(() => _msgError = null),
          decoration: InputDecoration(
            labelText: 'Pesan SP',
            hintText: 'Mis. Segera lengkapi tugas semester 2 sebelum tanggal ...',
            alignLabelWithHint: true,
            errorText: _msgError,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            onPressed: _busy || !_dirty ? null : _save,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Simpan SP'),
          ),
        ),
      ]),
    );
  }
}

// ── Pembimbing ────────────────────────────────────────────────────────────────

class _PembimbingTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<dynamic>? penilai;
  final Future<void> Function() onRefresh;
  final VoidCallback onSaved;
  const _PembimbingTab({super.key, required this.user, required this.penilai, required this.onRefresh,
      required this.onSaved});

  @override
  State<_PembimbingTab> createState() => _PembimbingTabState();
}

class _PembimbingTabState extends State<_PembimbingTab> {
  final ApiService _api = ApiService();
  late final Map<String, int?> _initial = {
    for (final p in peranPembimbingLabel.keys) p: _validId(widget.user['${p}_id']),
  };
  late final Map<String, int?> _values = Map.of(_initial);
  bool _busy = false;

  int? _validId(dynamic id) {
    final ids = (widget.penilai ?? const []).map((p) => p['id']).toSet();
    return ids.contains(id) ? id as int : null;
  }

  Map<String, int?> get _changes => {
        for (final p in peranPembimbingLabel.keys)
          if (_values[p] != _initial[p]) '${p}_id': _values[p],
      };

  Future<void> _save() async {
    final changes = _changes;
    if (changes.isEmpty) return;
    setState(() => _busy = true);
    final ok = await _api.adminSaveProfile(widget.user['id'] as int, changes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showSnack(context, 'Pembimbing disimpan');
      widget.onSaved();
    } else {
      showSnack(context, _api.lastError ?? 'Gagal menyimpan pembimbing.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.penilai == null) {
      return _TabScroll(onRefresh: widget.onRefresh, children: [
        ErrorState(message: 'Daftar penilai gagal dimuat.', onRetry: widget.onRefresh),
      ]);
    }
    final penilai = widget.penilai!;
    return _TabScroll(onRefresh: widget.onRefresh, children: [
      const SectionTitle('Dosen wali & pembimbing'),
      const Text(
        'Pilih akun penilai untuk tiap peran. Penilai yang ditugaskan dapat memantau progres dan memberi penilaian per semester.',
        style: TextStyle(fontSize: 14, color: AppColors.textGrey),
      ),
      const SizedBox(height: 12),
      if (penilai.isEmpty)
        const NoteBox(
          title: 'Belum ada akun penilai',
          text: 'Tambahkan akun Penilai / Dosen dari menu Pengguna terlebih dahulu.',
          color: AppColors.warningOrange,
          icon: Icons.person_off_outlined,
        ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in peranPembimbingLabel.entries) ...[
            PenilaiDropdown(
              label: e.value,
              value: _values[e.key],
              penilai: penilai,
              icon: e.key == 'dosen_wali' ? Icons.school_outlined : Icons.supervisor_account_outlined,
              onChanged: _busy ? (_) {} : (v) => setState(() => _values[e.key] = v),
            ),
            if (_initial[e.key] == null && textOf(widget.user[e.key]).isNotEmpty)
              NoteBox(
                title: 'Tercatat sebagai teks',
                text: '${textOf(widget.user[e.key])} belum terhubung ke akun penilai. '
                    'Pilih akunnya agar dosen dapat memberi penilaian.',
              ),
            const SizedBox(height: 14),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              onPressed: _busy || _changes.isEmpty ? null : _save,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Simpan pembimbing'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Ujian organ ───────────────────────────────────────────────────────────────

class _OrganExamTab extends StatelessWidget {
  final int ppdsId;
  final List<dynamic> exams;
  final List<dynamic>? penilai;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  const _OrganExamTab({required this.ppdsId, required this.exams, required this.penilai, required this.onRefresh,
      required this.onChanged});

  Future<void> _open(BuildContext context, [Map<String, dynamic>? exam]) async {
    if (penilai == null) {
      showSnack(context, 'Daftar penilai belum termuat. Tarik ke bawah untuk memuat ulang.', error: true);
      return;
    }
    final saved = await showOrganExamForm(context, userId: ppdsId, exam: exam, penilai: penilai!);
    if (saved) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return _TabScroll(onRefresh: onRefresh, children: [
      SectionTitle(
        'Ujian organ',
        trailing: FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah ujian'),
        ),
      ),
      if (exams.isEmpty)
        const EmptyState(
          icon: Icons.medical_services_outlined,
          title: 'Belum ada ujian organ',
          message: 'Tambahkan jadwal ujian organ dan pilih pengujinya.',
        )
      else
        for (final raw in exams) _card(context, Map<String, dynamic>.from(raw as Map)),
    ]);
  }

  Widget _card(BuildContext context, Map<String, dynamic> e) {
    final hasPengujiAccount = e['penguji_id'] != null;
    final penguji = textOf(e['penguji']);
    final meta = [
      if (textOf(e['organ']).isNotEmpty) 'Organ ${textOf(e['organ'])}',
      if (textOf(e['tanggal']).isNotEmpty) formatTanggal(e['tanggal']),
      if (e['nilai'] != null) 'Nilai ${formatNilai(e['nilai'])}',
    ];
    return AppCard(
      onTap: () => _open(context, e),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(e['nama_ujian']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (meta.isNotEmpty) Text(meta.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(examStatus(e['hasil'] as String?)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(hasPengujiAccount ? Icons.how_to_reg_outlined : Icons.person_off_outlined,
              size: 18, color: hasPengujiAccount ? AppColors.textDark : AppColors.warningOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              penguji.isEmpty
                  ? 'Penguji belum ditentukan'
                  : hasPengujiAccount
                      ? 'Penguji: $penguji'
                      : 'Penguji: $penguji (belum terhubung ke akun)',
              style: TextStyle(fontSize: 14, color: penguji.isEmpty ? AppColors.warningOrange : AppColors.textDark),
            ),
          ),
          TextButton.icon(
            onPressed: () => _open(context, e),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ]),
        if (textOf(e['catatan']).isNotEmpty) NoteBox(title: 'Catatan', text: textOf(e['catatan']), icon: Icons.notes),
      ]),
    );
  }
}

// ── Penilaian ─────────────────────────────────────────────────────────────────

class _PenilaianTab extends StatelessWidget {
  final List<dynamic>? penilaian;
  final Future<void> Function() onRefresh;
  const _PenilaianTab({required this.penilaian, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (penilaian == null) {
      return _TabScroll(onRefresh: onRefresh, children: [
        ErrorState(message: 'Penilaian gagal dimuat.', onRetry: onRefresh),
      ]);
    }
    final bySemester = <int, List<Map<String, dynamic>>>{};
    for (final raw in penilaian!) {
      final n = Map<String, dynamic>.from(raw as Map);
      bySemester.putIfAbsent((n['semester'] as num?)?.toInt() ?? 0, () => []).add(n);
    }
    final semesters = bySemester.keys.toList()..sort((a, b) => b.compareTo(a));

    return _TabScroll(onRefresh: onRefresh, children: [
      const SectionTitle('Penilaian dari dosen'),
      if (semesters.isEmpty)
        const EmptyState(
          icon: Icons.grade_outlined,
          title: 'Belum ada penilaian',
          message: 'Nilai diisi oleh dosen wali / pembimbing yang ditugaskan ke PPDS ini.',
        )
      else
        for (final s in semesters) _semesterCard(s, bySemester[s]!),
    ]);
  }

  Widget _semesterCard(int semester, List<Map<String, dynamic>> items) {
    final nums = items.map((n) => n['nilai']).whereType<num>().toList();
    final avg = nums.isEmpty ? null : nums.reduce((a, b) => a + b) / nums.length;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(semester == 0 ? 'Tanpa semester' : 'Semester $semester',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (avg != null) TagChip('Rata-rata ${formatNilai(avg)}', color: AppColors.primaryPurple),
        ]),
        for (final n in items) ...[
          const Divider(height: 20, color: AppColors.cardBorder),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(textOf(n['peran_label']).isEmpty ? textOf(n['peran']) : textOf(n['peran_label']),
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                Text(textOf(n['penilai_nama']).isEmpty ? '-' : textOf(n['penilai_nama']),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (textOf(n['updated_at'] ?? n['created_at']).isNotEmpty)
                  Text('Diperbarui ${formatTanggal(n['updated_at'] ?? n['created_at'], serverTimestamp: true)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ]),
            ),
            Text(formatNilai(n['nilai']),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)),
          ]),
          if (textOf(n['catatan']).isNotEmpty) NoteBox(title: 'Catatan', text: textOf(n['catatan']), icon: Icons.notes),
        ],
      ]),
    );
  }
}

// ── Stase ─────────────────────────────────────────────────────────────────────

class _RotationTab extends StatelessWidget {
  final int ppdsId;
  final List<dynamic> rotations;
  final Future<void> Function() onRefresh;
  final VoidCallback onChanged;
  const _RotationTab({required this.ppdsId, required this.rotations, required this.onRefresh, required this.onChanged});

  Future<void> _open(BuildContext context, [Map<String, dynamic>? rotation]) async {
    final saved = await showRotationForm(context, userId: ppdsId, rotation: rotation);
    if (saved) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = [for (final r in rotations) Map<String, dynamic>.from(r as Map)]
      ..sort((a, b) => textOf(a['start_date']).compareTo(textOf(b['start_date'])));
    return _TabScroll(onRefresh: onRefresh, children: [
      SectionTitle(
        'Stase / rotasi luar',
        trailing: FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah stase'),
        ),
      ),
      if (items.isEmpty)
        const EmptyState(icon: Icons.local_hospital_outlined, title: 'Belum ada stase')
      else
        for (final r in items) _card(context, r),
    ]);
  }

  Widget _card(BuildContext context, Map<String, dynamic> r) {
    final place = [textOf(r['department']), textOf(r['city'])].where((s) => s.isNotEmpty).join(' · ');
    final start = textOf(r['start_date']);
    final end = textOf(r['end_date']);
    final period = start.isEmpty && end.isEmpty
        ? ''
        : '${start.isEmpty ? '?' : formatTanggal(start)} - ${end.isEmpty ? '?' : formatTanggal(end)}';
    return AppCard(
      onTap: () => _open(context, r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(textOf(r['hospital_name']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (place.isNotEmpty) Text(place, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(rotationStatus(r['status'] as String?)),
        ]),
        const SizedBox(height: 6),
        if (period.isNotEmpty)
          Row(children: [
            const Icon(Icons.date_range, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 6),
            Text(period, style: const TextStyle(fontSize: 14)),
          ]),
        if (textOf(r['supervisor']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.supervisor_account_outlined, size: 18, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Expanded(child: Text('Supervisor: ${textOf(r['supervisor'])}', style: const TextStyle(fontSize: 14))),
            ]),
          ),
        if (textOf(r['notes']).isNotEmpty) NoteBox(title: 'Catatan', text: textOf(r['notes']), icon: Icons.notes),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _open(context, r),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ),
      ]),
    );
  }
}
