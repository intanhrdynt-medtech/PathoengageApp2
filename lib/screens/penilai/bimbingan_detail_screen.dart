import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilai/penilai_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Detail satu PPDS bimbingan: progres + penilaian dari penilai ini.
class BimbinganDetailScreen extends StatefulWidget {
  /// Satu item dari GET /penilai/bimbingan.
  final Map<String, dynamic> ppds;
  const BimbinganDetailScreen({super.key, required this.ppds});

  @override
  State<BimbinganDetailScreen> createState() => _BimbinganDetailScreenState();
}

class _BimbinganDetailScreenState extends State<BimbinganDetailScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _formSectionKey = GlobalKey();
  final _nilaiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _progress;
  int? _myId;

  String? _peran;
  int? _semester;
  double? _nilai;
  bool _saving = false;

  int? get _ppdsId => asInt(widget.ppds['id']);

  Map<String, dynamic> get _user {
    final u = _progress?['user'];
    return u is Map<String, dynamic> ? u : widget.ppds;
  }

  int get _currentSemester => asInt(_user['current_semester']) ?? asInt(widget.ppds['current_semester']) ?? 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _ppdsId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Data PPDS tidak valid.';
      });
      return;
    }
    final meApi = ApiService();
    final results = await Future.wait<dynamic>([_api.getBimbinganProgress(id), meApi.getMe()]);
    if (!mounted) return;
    final progress = results[0] as Map<String, dynamic>?;
    final me = results[1] as Map<String, dynamic>?;
    setState(() {
      _loading = false;
      if (progress == null) {
        _error = _api.lastError ?? 'Gagal memuat progres PPDS.';
        return;
      }
      _error = null;
      _progress = progress;
      _myId = asInt(me?['id']) ?? _myId;
      final roles = _myRoles;
      if (_peran == null || !roles.contains(_peran)) _peran = roles.length == 1 ? roles.first : null;
      _semester ??= _currentSemester;
    });
  }

  /// Peran saya terhadap PPDS ini (urut sesuai daftar peran).
  List<String> get _myRoles {
    final myId = _myId;
    if (myId != null && _progress?['user'] is Map) {
      final u = _progress!['user'] as Map;
      final roles = peranPembimbingLabel.keys.where((p) => asInt(u['${p}_id']) == myId).toList();
      if (roles.isNotEmpty) return roles;
    }
    final fromList = (widget.ppds['peran_saya'] as List?)?.whereType<Map>() ?? const [];
    return fromList.map((r) => r['peran']?.toString()).whereType<String>().toList();
  }

  /// Semua penilaian saya untuk PPDS ini, terbaru dulu.
  List<Map<String, dynamic>> get _myPenilaian {
    List<Map<String, dynamic>> list;
    final all = (_progress?['penilaian'] as List?)?.whereType<Map<String, dynamic>>().toList();
    if (all != null && _myId != null) {
      list = all.where((n) => asInt(n['penilai_id']) == _myId).toList();
    } else {
      list = (widget.ppds['penilaian_saya'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    }
    list.sort((a, b) {
      final s = (asInt(b['semester']) ?? 0).compareTo(asInt(a['semester']) ?? 0);
      if (s != 0) return s;
      return (a['peran'] ?? '').toString().compareTo((b['peran'] ?? '').toString());
    });
    return list;
  }

  Map<String, dynamic>? get _existingForSelection {
    if (_peran == null || _semester == null) return null;
    for (final n in _myPenilaian) {
      if (n['peran'] == _peran && asInt(n['semester']) == _semester) return n;
    }
    return null;
  }

  // ── Form penilaian ────────────────────────────────────────────────────────

  void _setNilaiFromSlider(double v) {
    final rounded = v.roundToDouble();
    setState(() => _nilai = rounded);
    _nilaiCtrl.text = formatNilai(rounded);
  }

  void _setNilaiFromText(String v) {
    final parsed = double.tryParse(v.replaceAll(',', '.').trim());
    setState(() => _nilai = (parsed != null && parsed >= 0 && parsed <= 100) ? parsed : null);
  }

  void _prefill(Map<String, dynamic> n) {
    final peran = n['peran']?.toString();
    if (!_myRoles.contains(peran)) {
      showSnack(context, 'Anda tidak lagi memegang peran ${n['peran_label'] ?? peran} untuk PPDS ini.', error: true);
      return;
    }
    final nilai = asDouble(n['nilai']);
    setState(() {
      _peran = peran;
      _semester = asInt(n['semester']) ?? _semester;
      _nilai = nilai;
    });
    _nilaiCtrl.text = nilai == null ? '' : formatNilai(nilai);
    _catatanCtrl.text = n['catatan']?.toString() ?? '';
    final ctx = _formSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  }

  void _resetForm() {
    setState(() {
      _nilai = null;
      _semester = _currentSemester;
      final roles = _myRoles;
      _peran = roles.length == 1 ? roles.first : null;
    });
    _nilaiCtrl.clear();
    _catatanCtrl.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _save() async {
    final id = _ppdsId;
    if (id == null || !_formKey.currentState!.validate()) return;
    final peran = _peran!;
    final semester = _semester ?? _currentSemester;
    final nilai = _nilai!;
    final peranLabel = peranPembimbingLabel[peran] ?? peran;
    final existing = _existingForSelection;
    final ok = await confirmDialog(
      context,
      title: existing == null ? 'Simpan penilaian?' : 'Perbarui penilaian?',
      message: 'Nilai ${formatNilai(nilai)} (${nilaiLabel(nilai)}) untuk ${_user['full_name'] ?? 'PPDS'}, '
          'semester $semester, sebagai $peranLabel.'
          '${existing == null ? '' : ' Nilai sebelumnya (${formatNilai(asDouble(existing['nilai']))}) akan diganti.'}'
          ' PPDS akan menerima notifikasi.',
      confirmText: existing == null ? 'Simpan' : 'Perbarui',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final success = await _api.beriPenilaian(id, peran, nilai, _catatanCtrl.text.trim(), semester: semester);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      showSnack(context, _api.lastError ?? 'Gagal menyimpan penilaian.', error: true);
      return;
    }
    showSnack(context, 'Penilaian tersimpan');
    _resetForm();
    await _load();
  }

  // ── Tampilan ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ppds['full_name']?.toString() ?? 'Detail PPDS',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return RefreshableState(onRefresh: _load, child: ErrorState(message: _error!, onRetry: _load));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(),
              const SectionTitle('Progres'),
              _progressCard(),
              _organExamsCard(),
              SectionTitle('Penilaian Saya', key: _formSectionKey),
              _formCard(),
              _historySection(),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final u = _user;
    final kalung = _progress?['kalung'] is Map ? _progress!['kalung'] as Map : const {};
    final peringatan = textOrNull(kalung['peringatan_otomatis']);
    final sp = u['warning_active'] == true;
    final spMessage = textOrNull(u['warning_message']);
    final syarat = (kalung['syarat'] as List?)?.whereType<Map>().toList() ?? const [];
    final nextLabel = textOrNull(kalung['next_label']);
    final meta = <String>[
      if (textOrNull(u['nim']) != null) 'NIM ${u['nim']}',
      if (textOrNull(u['angkatan']) != null) 'Angkatan ${u['angkatan']}',
      if (textOrNull(u['email']) != null) u['email'].toString(),
    ];
    final roleLabels = _myRoles.map((r) => peranPembimbingLabel[r] ?? r).toList();

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u['full_name']?.toString() ?? '-',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        if (meta.isNotEmpty) Text(meta.join(' · '), style: kCaption),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PhaseBadge(u['phase']?.toString()),
          SmallTag('Semester $_currentSemester', icon: Icons.calendar_today_outlined, color: AppColors.infoBlue),
          for (final r in roleLabels) SmallTag('Anda: $r', icon: Icons.badge_outlined),
        ]),
        if (nextLabel != null && syarat.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Syarat naik ke $nextLabel', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          for (final s in syarat)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(s['selesai'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18, color: s['selesai'] == true ? AppColors.successGreen : AppColors.neutralGrey),
                const SizedBox(width: 6),
                Expanded(child: Text(s['label']?.toString() ?? '-', style: kBody)),
              ]),
            ),
        ],
        if (sp)
          NoteBox(
            title: 'Surat Peringatan (SP) aktif',
            text: spMessage ?? 'PPDS ini sedang mendapat surat peringatan dari admin.',
            color: AppColors.errorRed,
            icon: Icons.warning_amber,
          ),
        if (peringatan != null)
          NoteBox(title: 'Peringatan otomatis', text: peringatan, color: AppColors.warningOrange, icon: Icons.schedule),
      ]),
    );
  }

  Map<String, dynamic> _section(String key) {
    final v = _progress?[key];
    return v is Map<String, dynamic> ? v : const {};
  }

  Widget _progressCard() {
    final comps = _section('competencies');
    final compItems = (comps['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final exams = _section('exams');
    final examItems = (exams['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final tasks = _section('academic_tasks');
    final rotations = _section('rotations');
    final currentPhase = _user['phase']?.toString();

    // Kompetensi per kalung.
    final phases = <String>[
      ...phaseOrder.where((ph) => compItems.any((c) => c['phase_category'] == ph)),
      ...compItems.map((c) => c['phase_category']?.toString() ?? '-').toSet().where((ph) => !phaseOrder.contains(ph)),
    ];
    final currentItems = compItems.where((c) => c['phase_category'] == currentPhase).toList();

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kompetensi per kalung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        if (phases.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Belum ada data kompetensi.', style: kCaption)),
        for (final ph in phases)
          Builder(builder: (_) {
            final list = compItems.where((c) => (c['phase_category']?.toString() ?? '-') == ph).toList();
            final done = list.where((c) => c['status'] == 'completed').length;
            final pending = list.where((c) => c['status'] == 'pending_verification').length;
            return ProgressRow(
              label: phaseLabel(ph) + (ph == currentPhase ? ' (tahap saat ini)' : ''),
              done: done,
              total: list.length,
              color: phaseColor(ph),
              extra: pending > 0 ? '$pending menunggu verifikasi admin' : null,
            );
          }),
        if (currentItems.isNotEmpty)
          _expandable(
            'Rincian kompetensi ${phaseLabel(currentPhase)}',
            currentItems
                .map((c) => _itemRow(
                      c['competency_name']?.toString() ?? '-',
                      textOrNull(c['organ_system']),
                      StatusChip(progressStatus(c['status']?.toString(), alasanTolak: c['alasan_tolak']?.toString())),
                    ))
                .toList(),
          ),
        const Divider(height: 24),
        ProgressRow(
          label: 'Ujian lokal & nasional lulus',
          done: asInt(exams['passed']) ?? 0,
          total: asInt(exams['total']) ?? examItems.length,
          color: AppColors.successGreen,
        ),
        if (examItems.isNotEmpty)
          _expandable(
            'Rincian ujian',
            examItems
                .map((e) => _itemRow(
                      e['exam_name']?.toString() ?? '-',
                      [
                        if (textOrNull(e['exam_type']) != null) e['exam_type'].toString(),
                        if (textOrNull(e['scheduled_date']) != null) formatTanggal(e['scheduled_date']),
                        if (asDouble(e['score']) != null) 'Nilai ${formatNilai(asDouble(e['score']))}',
                      ].join(' · '),
                      StatusChip(examStatus(e['result']?.toString(), alasanTolak: e['alasan_tolak']?.toString())),
                    ))
                .toList(),
          ),
        ProgressRow(
          label: 'Tugas akademik selesai',
          done: asInt(tasks['completed']) ?? 0,
          total: asInt(tasks['total']) ?? 0,
          color: AppColors.infoBlue,
          extra: (asInt(tasks['pending']) ?? 0) > 0 ? '${tasks['pending']} menunggu verifikasi admin' : null,
        ),
        ProgressRow(
          label: 'Stase luar selesai',
          done: asInt(rotations['completed']) ?? 0,
          total: asInt(rotations['total']) ?? 0,
          color: AppColors.secondaryMagenta,
        ),
      ]),
    );
  }

  Widget _organExamsCard() {
    final organ = (_progress?['organ_exams'] as List?)?.whereType<Map>().toList() ?? const [];
    final passed = organ.where((e) => e['hasil'] == 'lulus').length;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Ujian organ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          if (organ.isNotEmpty) Text('$passed / ${organ.length} lulus', style: kBody),
        ]),
        if (organ.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Belum ada ujian organ terjadwal.', style: kCaption)),
        for (final e in organ)
          _itemRow(
            e['nama_ujian']?.toString() ?? '-',
            [
              if (textOrNull(e['organ']) != null) e['organ'].toString(),
              if (textOrNull(e['tanggal']) != null) formatTanggal(e['tanggal']),
              if (textOrNull(e['penguji']) != null) 'Penguji: ${e['penguji']}',
              if (asDouble(e['nilai']) != null) 'Nilai ${formatNilai(asDouble(e['nilai']))}',
            ].join(' · '),
            StatusChip(examStatus(e['hasil']?.toString())),
          ),
      ]),
    );
  }

  Widget _expandable(String title, List<Widget> children) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
        children: children,
      ),
    );
  }

  Widget _itemRow(String title, String? subtitle, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: kBody),
            if (subtitle != null && subtitle.isNotEmpty) Text(subtitle, style: kCaption),
          ]),
        ),
        const SizedBox(width: 8),
        Flexible(child: Align(alignment: Alignment.topRight, child: trailing)),
      ]),
    );
  }

  Widget _formCard() {
    final roles = _myRoles;
    if (roles.isEmpty) {
      return const AppCard(
        child: Text('Anda tidak lagi tercatat sebagai pembimbing PPDS ini, sehingga tidak bisa memberi penilaian. '
            'Hubungi admin bila ini keliru.', style: kBody),
      );
    }
    final maxHistory = _myPenilaian.map((n) => asInt(n['semester']) ?? 1).fold<int>(1, (a, b) => a > b ? a : b);
    final maxSemester = [_currentSemester, maxHistory, _semester ?? 1].reduce((a, b) => a > b ? a : b).clamp(1, 20);
    final existing = _existingForSelection;
    final nilai = _nilai;

    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Beri atau perbarui nilai (0–100) untuk PPDS ini. Satu nilai per peran per semester.',
              style: kCaption),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final peranField = DropdownButtonFormField<String>(
              // Key berubah saat form diisi dari riwayat supaya pilihan ikut berganti.
              key: ValueKey('peran-$_peran'),
              initialValue: _peran,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Peran Anda'),
              items: roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(peranPembimbingLabel[r] ?? r, style: kBody)))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _peran = v),
              validator: (v) => v == null ? 'Pilih peran' : null,
            );
            final semesterField = DropdownButtonFormField<int>(
              key: ValueKey('semester-$_semester'),
              initialValue: _semester ?? _currentSemester,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Semester'),
              items: [
                for (var s = 1; s <= maxSemester; s++)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s == _currentSemester ? 'Semester $s (saat ini)' : 'Semester $s', style: kBody),
                  ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _semester = v),
            );
            if (c.maxWidth < 480) {
              return Column(children: [peranField, const SizedBox(height: 12), semesterField]);
            }
            return Row(children: [
              Expanded(child: peranField),
              const SizedBox(width: 12),
              Expanded(child: semesterField),
            ]);
          }),
          if (existing != null)
            NoteBox(
              title: 'Sudah ada nilai untuk pilihan ini',
              text: 'Nilai ${formatNilai(asDouble(existing['nilai']))} diberikan '
                  '${formatTanggal(existing['updated_at'] ?? existing['created_at'], serverTimestamp: true)}. '
                  'Menyimpan akan memperbarui nilai tersebut.',
              icon: Icons.edit_note,
            ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Slider(
                value: (nilai ?? 0).clamp(0, 100).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: nilai == null ? null : formatNilai(nilai),
                activeColor: nilai == null ? AppColors.neutralGrey : nilaiColor(nilai),
                onChanged: _saving ? null : _setNilaiFromSlider,
              ),
            ),
            SizedBox(
              width: 92,
              child: TextFormField(
                controller: _nilaiCtrl,
                enabled: !_saving,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'Nilai'),
                onChanged: _setNilaiFromText,
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.').trim());
                  if ((v ?? '').trim().isEmpty) return 'Wajib';
                  if (parsed == null || parsed < 0 || parsed > 100) return '0–100';
                  return null;
                },
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: nilai == null
                ? const Text('Geser atau ketik nilai 0–100.', style: kCaption)
                : Row(children: [
                    Icon(Icons.circle, size: 10, color: nilaiColor(nilai)),
                    const SizedBox(width: 6),
                    Text('${formatNilai(nilai)} — ${nilaiLabel(nilai)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: nilaiColor(nilai))),
                  ]),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 4),
            child: Text('Skala: 85 ke atas Sangat baik · 70–84 Baik · 60–69 Cukup · di bawah 60 Perlu perbaikan',
                style: kCaption),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _catatanCtrl,
            enabled: !_saving,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Catatan untuk PPDS (wajib)',
              hintText: 'Kekuatan, hal yang perlu ditingkatkan, dan saran',
              alignLabelWithHint: true,
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Catatan wajib diisi' : null,
          ),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
            TextButton(onPressed: _saving ? null : _resetForm, child: const Text('Kosongkan')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(existing == null ? 'Simpan penilaian' : 'Perbarui penilaian'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _historySection() {
    final list = _myPenilaian;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Riwayat penilaian saya (${list.length})'),
      if (list.isEmpty)
        const AppCard(child: Text('Anda belum pernah memberi nilai untuk PPDS ini.', style: kBody))
      else ...[
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Ketuk salah satu untuk mengubahnya.', style: kCaption),
        ),
        for (final n in list) _historyCard(n),
      ],
    ]);
  }

  Widget _historyCard(Map<String, dynamic> n) {
    final nilai = asDouble(n['nilai']);
    final catatan = textOrNull(n['catatan']);
    return AppCard(
      onTap: _saving ? null : () => _prefill(n),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (nilai != null) NilaiBadge(nilai) else const SizedBox(width: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Semester ${n['semester'] ?? '-'} · ${n['peran_label'] ?? peranPembimbingLabel[n['peran']] ?? '-'}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (nilai != null)
              Text(nilaiLabel(nilai),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: nilaiColor(nilai))),
            if (catatan != null) ...[
              const SizedBox(height: 4),
              Text(catatan, style: kBody),
            ],
            const SizedBox(height: 4),
            Text('Diperbarui ${formatTanggal(n['updated_at'] ?? n['created_at'], withTime: true, serverTimestamp: true)}',
                style: kCaption),
          ]),
        ),
        const Icon(Icons.edit_outlined, size: 18, color: AppColors.textGrey),
      ]),
    );
  }
}
