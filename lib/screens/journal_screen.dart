import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Journal Reading: pengajuan topik → direview dosen pembimbing/penilai →
/// presentasi → unggah bukti. Target: 5 journal selesai.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

const int _kTargetJournal = 5;

bool _buktiDone(dynamic j) => j['bukti_submitted'] == true || str(j['bukti_url']).isNotEmpty;

class _JournalScreenState extends State<JournalScreen> {
  final ModuleApi _api = ModuleApi();

  List<dynamic> _mine = [];
  bool _loadingMine = true;
  String? _errorMine;

  List<dynamic> _all = [];
  bool _loadingAll = true;
  String? _errorAll;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadMine();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    final data = await _api.list('/journal-readings');
    if (!mounted) return;
    setState(() {
      _loadingMine = false;
      _errorMine = data == null ? _api.errorMessage : null;
      if (data != null) _mine = data;
    });
  }

  Future<void> _loadAll() async {
    final q = _searchCtrl.text.trim();
    final data = await _api.list('/journal-readings/all?q=${Uri.encodeQueryComponent(q)}');
    if (!mounted) return;
    setState(() {
      _loadingAll = false;
      _errorAll = data == null ? _api.errorMessage : null;
      if (data != null) _all = data;
    });
  }

  void _onSearch(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadAll);
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final msg = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => _JournalFormPage(existing: existing)),
    );
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _loadMine();
    _loadAll();
  }

  Future<void> _uploadBukti(Map<String, dynamic> j) async {
    final replacing = _buktiDone(j);
    final res = await showSubmitLinkDialog(
      context,
      title: replacing ? 'Ganti bukti presentasi' : 'Unggah bukti presentasi',
      description: '${str(j['judul'])}\n\nUnggah bukti presentasi (mis. foto, daftar hadir, atau slide) '
          'ke Google Drive, lalu tempel link-nya.',
      linkLabel: 'Link bukti presentasi',
      initialLink: str(j['bukti_url']),
      submitText: replacing ? 'Simpan' : 'Unggah bukti',
    );
    if (res == null || !mounted) return;
    final ok = await _api.ok('PATCH', '/journal-readings/${j['id']}/bukti', body: {'bukti_url': res['link']});
    if (!mounted) return;
    if (ok) {
      showSnack(context, replacing ? 'Link bukti diperbarui.' : 'Bukti terunggah. Journal ini tercatat selesai.');
      _loadMine();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journal Reading', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: moduleTabBar(const ['Jurnal Saya', 'Semua PPDS']),
        ),
        body: TabBarView(children: [_buildMine(), _buildAll()]),
      ),
    );
  }

  // ── Tab: Jurnal Saya ──────────────────────────────────────────────────────

  Widget _buildMine() {
    return moduleBody(
      loading: _loadingMine,
      error: _errorMine,
      onRefresh: _loadMine,
      builder: () {
        final selesai = _mine.where((j) => j['status'] == 'approved' && _buktiDone(j)).length;
        final perluBukti = _mine.where((j) => j['status'] == 'approved' && !_buktiDone(j)).length;
        final menunggu = _mine.where((j) => j['status'] == 'pending').length;
        final ditolak = _mine.where((j) => j['status'] == 'rejected').length;
        final parts = <String>[
          if (menunggu > 0) '$menunggu menunggu persetujuan',
          if (perluBukti > 0) '$perluBukti perlu unggah bukti',
          if (ditolak > 0) '$ditolak perlu diperbaiki',
        ];
        return [
          ModuleProgressCard(
            title: 'Journal Reading',
            done: selesai,
            total: _kTargetJournal,
            caption: selesai >= _kTargetJournal
                ? 'Target $_kTargetJournal journal sudah tercapai.'
                : 'Selesai = disetujui penilai dan bukti presentasi sudah diunggah.'
                    '${parts.isEmpty ? '' : '\n${parts.join(' · ')}'}',
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Ajukan Journal'),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Pengajuan saya'),
          if (_mine.isEmpty)
            const EmptyState(
              icon: Icons.article_outlined,
              title: 'Belum ada pengajuan Journal Reading',
              message: 'Ajukan judul journal yang akan Anda presentasikan. Pengajuan akan direview dosen pembimbing/penilai.',
            )
          else
            ..._mine.map((j) => _myCard(j as Map<String, dynamic>)),
        ];
      },
    );
  }

  Widget _myCard(Map<String, dynamic> j) {
    final status = str(j['status']);
    final bukti = _buktiDone(j);
    final catatan = str(j['catatan_admin']);

    Widget? action;
    if (status == 'rejected') {
      action = CardActionButton(label: 'Perbaiki & ajukan ulang', icon: Icons.refresh, onPressed: () => _openForm(j));
    } else if (status == 'pending') {
      action = CardActionButton(
          label: 'Perbaiki pengajuan', icon: Icons.edit, outlined: true, onPressed: () => _openForm(j));
    } else if (status == 'approved' && !bukti) {
      action = CardActionButton(label: 'Unggah bukti', icon: Icons.upload, onPressed: () => _uploadBukti(j));
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(str(j['judul']).isEmpty ? '-' : str(j['judul']), style: kCardTitle),
        const SizedBox(height: 8),
        StatusChip(journalStatus(status, buktiSubmitted: bukti)),
        const SizedBox(height: 4),
        MetaRow(icon: Icons.people_outline, label: 'Penulis', value: str(j['penulis'])),
        MetaRow(icon: Icons.menu_book_outlined, label: 'Jurnal', value: str(j['nama_jurnal'])),
        MetaRow(icon: Icons.school_outlined, label: 'Pembimbing', value: str(j['pembimbing'])),
        MetaRow(icon: Icons.record_voice_over_outlined, label: 'Penguji', value: str(j['penguji'])),
        if (str(j['tanggal_presentasi']).isNotEmpty)
          MetaRow(icon: Icons.event, label: 'Presentasi', value: formatTanggal(j['tanggal_presentasi'])),
        if (str(j['created_at']).isNotEmpty)
          MetaRow(
              icon: Icons.schedule,
              label: 'Diajukan',
              value: formatTanggal(j['created_at'], serverTimestamp: true)),
        if (catatan.isNotEmpty)
          NoteBox(
            title: status == 'rejected' ? 'Alasan penolakan dari penilai' : 'Catatan penilai',
            text: catatan,
            color: status == 'rejected' ? AppColors.errorRed : AppColors.infoBlue,
            icon: status == 'rejected' ? Icons.error_outline : Icons.comment_outlined,
          ),
        if (status == 'pending')
          const NoteBox(
            title: 'Menunggu persetujuan',
            text: 'Pengajuan sedang direview dosen pembimbing/penilai. Anda masih bisa memperbaikinya.',
          ),
        if (status == 'approved' && !bukti)
          const NoteBox(
            title: 'Langkah berikutnya',
            text: 'Setelah presentasi, unggah link bukti agar journal ini tercatat selesai.',
            color: AppColors.successGreen,
            icon: Icons.upload_file,
          ),
        if (status == 'approved' && bukti)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 4, children: [
              LinkButton(label: 'Lihat bukti presentasi', url: str(j['bukti_url'])),
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                onPressed: () => _uploadBukti(j),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Ganti link'),
              ),
            ]),
          ),
        if (action != null) action,
      ]),
    );
  }

  // ── Tab: Semua PPDS ───────────────────────────────────────────────────────

  Widget _buildAll() {
    return moduleBody(
      loading: _loadingAll,
      error: _errorAll,
      onRefresh: _loadAll,
      builder: () => [
        ModuleSearchField(controller: _searchCtrl, hint: 'Cari judul journal...', onChanged: _onSearch),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Journal yang sudah disetujui. Cek daftar ini agar topik Anda tidak sama dengan PPDS lain.',
              style: kCaption),
        ),
        if (_all.isEmpty)
          EmptyState(
            icon: Icons.search_off,
            title: _searchCtrl.text.trim().isEmpty ? 'Belum ada journal yang disetujui' : 'Tidak ada judul yang cocok',
          )
        else
          ..._all.map((j) => _publicCard(j as Map<String, dynamic>)),
      ],
    );
  }

  Widget _publicCard(Map<String, dynamic> j) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(str(j['judul']).isEmpty ? '-' : str(j['judul']), style: kCardTitle),
        const SizedBox(height: 8),
        StatusChip(journalStatus(str(j['status']).isEmpty ? 'approved' : str(j['status']), buktiSubmitted: _buktiDone(j))),
        const SizedBox(height: 4),
        MetaRow(icon: Icons.person_outline, label: 'PPDS', value: str(j['user_name'])),
        MetaRow(icon: Icons.people_outline, label: 'Penulis', value: str(j['penulis'])),
        MetaRow(icon: Icons.menu_book_outlined, label: 'Jurnal', value: str(j['nama_jurnal'])),
        if (str(j['tanggal_presentasi']).isNotEmpty)
          MetaRow(icon: Icons.event, label: 'Presentasi', value: formatTanggal(j['tanggal_presentasi'])),
      ]),
    );
  }
}

// ── Formulir pengajuan / perbaikan ──────────────────────────────────────────

class _JournalFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _JournalFormPage({this.existing});

  @override
  State<_JournalFormPage> createState() => _JournalFormPageState();
}

class _JournalFormPageState extends State<_JournalFormPage> {
  final ModuleApi _api = ModuleApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judul;
  late final TextEditingController _penulis;
  late final TextEditingController _jurnal;
  late final TextEditingController _pembimbing;
  late final TextEditingController _penguji;
  DateTime? _tanggal;
  bool _saving = false;

  Map<String, dynamic>? get _e => widget.existing;
  bool get _isEdit => _e != null;
  bool get _isRejected => _e?['status'] == 'rejected';

  @override
  void initState() {
    super.initState();
    _judul = TextEditingController(text: str(_e?['judul']));
    _penulis = TextEditingController(text: str(_e?['penulis']));
    _jurnal = TextEditingController(text: str(_e?['nama_jurnal']));
    _pembimbing = TextEditingController(text: str(_e?['pembimbing']));
    _penguji = TextEditingController(text: str(_e?['penguji']));
    _tanggal = parseDate(_e?['tanggal_presentasi']);
    if (!_isEdit) _prefillPembimbing();
  }

  Future<void> _prefillPembimbing() async {
    final me = await _api.me();
    if (!mounted || me == null) return;
    if (_pembimbing.text.trim().isEmpty && str(me['pembimbing_1']).isNotEmpty) {
      setState(() => _pembimbing.text = str(me['pembimbing_1']));
    }
  }

  @override
  void dispose() {
    for (final c in [_judul, _penulis, _jurnal, _pembimbing, _penguji]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final judul = _judul.text.trim();
    setState(() => _saving = true);

    // Cek judul yang sama (hanya bila judul baru / diubah).
    final titleChanged = !_isEdit || judul.toLowerCase() != str(_e?['judul']).toLowerCase();
    if (titleChanged) {
      final dup = await _api.checkTopic(judul, 'journal');
      if (!mounted) return;
      if (dup['exists'] == true) {
        final go = await confirmDialog(
          context,
          title: 'Judul sudah pernah diajukan',
          message: '${str(dup['message']).isEmpty ? 'Judul ini sudah diajukan PPDS lain.' : str(dup['message'])}\n\n'
              'Sebaiknya pilih journal lain. Tetap ajukan judul ini?',
          confirmText: 'Tetap ajukan',
        );
        if (!mounted) return;
        if (!go) {
          setState(() => _saving = false);
          return;
        }
      }
    }

    final data = <String, dynamic>{
      'judul': judul,
      'penulis': _penulis.text.trim(),
      'nama_jurnal': _jurnal.text.trim(),
      'pembimbing': _pembimbing.text.trim(),
      'penguji': _penguji.text.trim(),
      'tanggal_presentasi': _tanggal == null ? '' : isoDate(_tanggal!),
    };
    final ok = _isEdit
        ? await _api.ok('PATCH', '/journal-readings/${_e!['id']}', body: data)
        : await _api.ok('POST', '/journal-readings', body: {...data, 'jenis': 'Journal Reading'});
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, _api.errorMessage, error: true);
      return;
    }
    Navigator.pop(
      context,
      !_isEdit
          ? 'Journal berhasil diajukan. Menunggu persetujuan penilai.'
          : _isRejected
              ? 'Perbaikan terkirim. Journal diajukan ulang ke penilai.'
              : 'Perubahan pengajuan tersimpan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catatan = str(_e?['catatan_admin']);
    return FormPageScaffold(
      title: !_isEdit
          ? 'Ajukan Journal'
          : _isRejected
              ? 'Perbaiki & Ajukan Ulang'
              : 'Perbaiki Pengajuan',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitLabel: !_isEdit
          ? 'Ajukan ke penilai'
          : _isRejected
              ? 'Ajukan ulang'
              : 'Simpan perubahan',
      children: [
        if (_isRejected && catatan.isNotEmpty)
          NoteBox(
              title: 'Alasan penolakan dari penilai',
              text: catatan,
              color: AppColors.errorRed,
              icon: Icons.error_outline),
        NoteBox(
          title: 'Alur Journal Reading',
          text: _isRejected
              ? 'Setelah diperbaiki, pengajuan otomatis dikirim ulang ke dosen pembimbing/penilai.'
              : '1. Ajukan judul journal.  2. Dosen pembimbing/penilai meninjau.  '
                  '3. Setelah disetujui dan presentasi selesai, unggah bukti.',
        ),
        const SizedBox(height: 16),
        moduleField(_judul, 'Judul artikel / journal', icon: Icons.title, required: true, maxLines: 3),
        moduleField(_penulis, 'Penulis artikel', icon: Icons.people_outline, hint: 'mis. Smith J, et al.'),
        moduleField(_jurnal, 'Nama jurnal sumber', icon: Icons.menu_book_outlined, hint: 'mis. Modern Pathology'),
        moduleField(_pembimbing, 'Pembimbing', icon: Icons.school_outlined),
        moduleField(_penguji, 'Penguji', icon: Icons.record_voice_over_outlined),
        DateFormField(
          label: 'Tanggal presentasi',
          initialValue: _tanggal,
          onChanged: (d) => _tanggal = d,
        ),
      ],
    );
  }
}
