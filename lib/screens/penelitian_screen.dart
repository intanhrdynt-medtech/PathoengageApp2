import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Penelitian / karya akhir PPDS.
/// Alur: draft → diajukan → revisi 1 / revisi 2 → disetujui / ditolak (→ terpublikasi).
class PenelitianScreen extends StatefulWidget {
  const PenelitianScreen({super.key});

  @override
  State<PenelitianScreen> createState() => _PenelitianScreenState();
}

const List<String> _kJenisOptions = ['Karya Akhir', 'Telaah Retrospektif', 'Laporan Kasus', 'Penelitian Lain'];
const List<String> _kEditableStatuses = ['draft', 'revisi_1', 'revisi_2'];

/// Catatan revisi tanpa baris "[Dokumen revisi sebelumnya: URL]"; link-link
/// tersebut dikumpulkan terpisah.
class _CleanNote {
  final String text;
  final List<String> links;
  const _CleanNote(this.text, this.links);
}

_CleanNote _cleanRevisi(dynamic raw) {
  final s = str(raw);
  final re = RegExp(r'\[Dokumen revisi sebelumnya:\s*([^\]]*)\]');
  final links = re.allMatches(s).map((m) => (m.group(1) ?? '').trim()).where((l) => l.isNotEmpty).toList();
  final text = s
      .replaceAll(re, '')
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .join('\n')
      .trim();
  return _CleanNote(text, links);
}

class _PenelitianScreenState extends State<PenelitianScreen> {
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
    final data = await _api.list('/penelitian');
    if (!mounted) return;
    setState(() {
      _loadingMine = false;
      _errorMine = data == null ? _api.errorMessage : null;
      if (data != null) _mine = data;
    });
  }

  Future<void> _loadAll() async {
    final q = _searchCtrl.text.trim();
    final data = await _api.list('/penelitian/all?q=${Uri.encodeQueryComponent(q)}');
    if (!mounted) return;
    setState(() {
      _loadingAll = false;
      _errorAll = data == null ? _api.errorMessage : null;
      if (data != null) _all = data;
    });
  }

  Future<void> _refreshBoth() async {
    await Future.wait([_loadMine(), _loadAll()]);
  }

  void _onSearch(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadAll);
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final msg = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => _PenelitianFormPage(existing: existing)));
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _refreshBoth();
  }

  Future<void> _patch(Map<String, dynamic> p, Map<String, dynamic> body, String success) async {
    final ok = await _api.ok('PATCH', '/penelitian/${p['id']}', body: body);
    if (!mounted) return;
    if (ok) {
      showSnack(context, success);
      _refreshBoth();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  Future<void> _ajukan(Map<String, dynamic> p) async {
    final res = await showSubmitLinkDialog(
      context,
      title: 'Ajukan ke penilai',
      description: '${str(p['judul'])}\n\nProposal akan dikirim ke dosen pembimbing/penilai untuk direview. '
          'Setelah diajukan, judul, jenis, dan pembimbing hanya bisa diubah saat diminta revisi.',
      linkLabel: 'Link dokumen proposal',
      initialLink: str(p['dokumen_proposal_url']),
      submitText: 'Ajukan',
    );
    if (res == null || !mounted) return;
    await _patch(p, {'status': 'submitted', 'dokumen_proposal_url': res['link']},
        'Penelitian diajukan. Menunggu review penilai.');
  }

  Future<void> _unggahRevisi(Map<String, dynamic> p, int n) async {
    final res = await showSubmitLinkDialog(
      context,
      title: 'Unggah Revisi $n',
      description: '${str(p['judul'])}\n\nUnggah dokumen yang sudah diperbaiki sesuai catatan revisi. '
          'Setelah diunggah, penilai akan meninjau ulang.',
      linkLabel: 'Link dokumen revisi $n',
      submitText: 'Kirim revisi',
    );
    if (res == null || !mounted) return;
    await _patch(p, {'dokumen_revisi${n}_url': res['link']}, 'Revisi $n terkirim. Menunggu review penilai.');
  }

  Future<void> _unggahFinal(Map<String, dynamic> p) async {
    final msg = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => _FinalDocsPage(penelitian: p)));
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Penelitian', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: moduleTabBar(const ['Penelitian Saya', 'Semua Penelitian']),
        ),
        body: TabBarView(children: [_buildMine(), _buildAll()]),
      ),
    );
  }

  // ── Tab: Penelitian Saya ──────────────────────────────────────────────────

  Widget _buildMine() {
    return moduleBody(
      loading: _loadingMine,
      error: _errorMine,
      onRefresh: _loadMine,
      builder: () => [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Ajukan Penelitian Baru'),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Penelitian saya'),
        if (_mine.isEmpty)
          const EmptyState(
            icon: Icons.science_outlined,
            title: 'Belum ada penelitian',
            message: 'Tambahkan penelitian/karya akhir Anda. Bisa disimpan sebagai draft dulu atau langsung diajukan.',
          )
        else
          ..._mine.map((p) => _myCard(p as Map<String, dynamic>)),
      ],
    );
  }

  Widget _myCard(Map<String, dynamic> p) {
    final status = str(p['status']);
    final perluReview = p['perlu_review'] == true;
    final rev1 = _cleanRevisi(p['catatan_revisi1']);
    final rev2 = _cleanRevisi(p['catatan_revisi2']);
    final catatanPenilai = str(p['catatan_penilai']);
    final hasFinal = str(p['dokumen_final_url']).isNotEmpty;

    // Satu aksi utama sesuai status.
    Widget? action;
    if (status == 'draft') {
      action = CardActionButton(label: 'Ajukan ke penilai', icon: Icons.send, onPressed: () => _ajukan(p));
    } else if ((status == 'revisi_1' || status == 'revisi_2') && !perluReview) {
      final n = status == 'revisi_1' ? 1 : 2;
      action = CardActionButton(label: 'Unggah Revisi $n', icon: Icons.upload_file, onPressed: () => _unggahRevisi(p, n));
    } else if (status == 'approved') {
      action = CardActionButton(
        label: hasFinal ? 'Perbarui dokumen final' : 'Unggah dokumen final',
        icon: Icons.upload_file,
        outlined: hasFinal,
        onPressed: () => _unggahFinal(p),
      );
    }

    String? hint;
    if (status == 'draft') {
      hint = 'Belum diajukan. Ajukan ke penilai dengan menyertakan link dokumen proposal.';
    } else if (status == 'submitted') {
      hint = 'Proposal sudah dikirim dan sedang direview dosen pembimbing/penilai.';
    } else if ((status == 'revisi_1' || status == 'revisi_2') && perluReview) {
      hint = 'Dokumen revisi sudah diunggah dan sedang direview penilai.';
    } else if ((status == 'revisi_1' || status == 'revisi_2') && !perluReview) {
      hint = 'Penilai meminta revisi. Perbaiki sesuai catatan, lalu unggah dokumen revisinya.';
    } else if (status == 'approved' && !hasFinal) {
      hint = 'Penelitian disetujui. Unggah dokumen final beserta data publikasi/etik bila sudah ada.';
    }

    final docs = <MapEntry<String, String>>[
      MapEntry('Proposal', str(p['dokumen_proposal_url'])),
      MapEntry('Revisi 1', str(p['dokumen_revisi1_url'])),
      MapEntry('Revisi 2', str(p['dokumen_revisi2_url'])),
      MapEntry('Dokumen final', str(p['dokumen_final_url'])),
      MapEntry('Publikasi', str(p['link_publikasi'])),
      MapEntry('LOA', str(p['loa_url'])),
      MapEntry('Ethical clearance', str(p['ethical_clearance_url'])),
    ].where((e) => e.value.isNotEmpty).toList();

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(str(p['judul']).isEmpty ? '-' : str(p['judul']), style: kCardTitle),
        const SizedBox(height: 8),
        StatusChip(penelitianStatus(status, perluReview: perluReview)),
        const SizedBox(height: 12),
        _StatusStepper(status: status, perluReview: perluReview),
        const SizedBox(height: 4),
        MetaRow(icon: Icons.category_outlined, label: 'Jenis', value: str(p['jenis'])),
        MetaRow(icon: Icons.school_outlined, label: 'Pembimbing 1', value: str(p['pembimbing_1'])),
        MetaRow(icon: Icons.school_outlined, label: 'Pembimbing 2', value: str(p['pembimbing_2'])),
        MetaRow(icon: Icons.school_outlined, label: 'Pembimbing retrospektif', value: str(p['pembimbing_retrospektif'])),
        if (str(p['created_at']).isNotEmpty)
          MetaRow(icon: Icons.schedule, label: 'Dibuat', value: formatTanggal(p['created_at'], serverTimestamp: true)),
        if (hint != null) NoteBox(title: 'Status', text: hint),
        ..._revisiNotes(1, rev1, current: status == 'revisi_1'),
        ..._revisiNotes(2, rev2, current: status == 'revisi_2'),
        if (catatanPenilai.isNotEmpty)
          NoteBox(
            title: 'Catatan penilai',
            text: catatanPenilai,
            color: status == 'rejected'
                ? AppColors.errorRed
                : (status == 'approved' || status == 'published')
                    ? AppColors.successGreen
                    : AppColors.infoBlue,
            icon: status == 'rejected' ? Icons.cancel_outlined : Icons.comment_outlined,
          ),
        if (docs.isNotEmpty || str(p['nomor_etik']).isNotEmpty) ...[
          const CardSectionLabel('Dokumen'),
          Wrap(spacing: 4, children: docs.map((d) => LinkButton(label: d.key, url: d.value)).toList()),
          MetaRow(icon: Icons.verified_outlined, label: 'Nomor etik', value: str(p['nomor_etik'])),
        ],
        if (action != null) action,
        if (_kEditableStatuses.contains(status))
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () => _openForm(p),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Ubah judul / jenis / pembimbing'),
              ),
            ),
          ),
      ]),
    );
  }

  List<Widget> _revisiNotes(int n, _CleanNote note, {required bool current}) {
    if (note.text.isEmpty && note.links.isEmpty) return const [];
    return [
      if (note.text.isNotEmpty)
        NoteBox(
          title: 'Catatan Revisi $n dari penilai',
          text: note.text,
          color: current ? AppColors.warningOrange : AppColors.neutralGrey,
          icon: Icons.edit_document,
        ),
      if (note.links.isNotEmpty)
        Wrap(
          spacing: 4,
          children: [
            for (var i = 0; i < note.links.length; i++)
              LinkButton(
                label: note.links.length > 1
                    ? 'Dokumen revisi $n sebelumnya (${i + 1})'
                    : 'Dokumen revisi $n sebelumnya',
                url: note.links[i],
              ),
          ],
        ),
    ];
  }

  // ── Tab: Semua Penelitian ─────────────────────────────────────────────────

  Widget _buildAll() {
    final myIds = _mine.map((p) => p['id']).toSet();
    return moduleBody(
      loading: _loadingAll,
      error: _errorAll,
      onRefresh: _loadAll,
      builder: () {
        final others = _all.where((p) => !myIds.contains(p['id'])).toList();
        return [
          ModuleSearchField(controller: _searchCtrl, hint: 'Cari judul penelitian...', onChanged: _onSearch),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Penelitian PPDS lain. Cek daftar ini agar topik Anda tidak sama.', style: kCaption),
          ),
          if (others.isEmpty)
            EmptyState(
              icon: Icons.search_off,
              title: _searchCtrl.text.trim().isEmpty
                  ? 'Belum ada penelitian dari PPDS lain'
                  : 'Tidak ada judul yang cocok',
            )
          else
            ...others.map((p) => _publicCard(p as Map<String, dynamic>)),
        ];
      },
    );
  }

  Widget _publicCard(Map<String, dynamic> p) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(str(p['judul']).isEmpty ? '-' : str(p['judul']), style: kCardTitle),
        const SizedBox(height: 8),
        StatusChip(penelitianStatus(str(p['status']), perluReview: p['perlu_review'] == true)),
        const SizedBox(height: 4),
        MetaRow(icon: Icons.person_outline, label: 'PPDS', value: str(p['user_name'])),
        MetaRow(icon: Icons.category_outlined, label: 'Jenis', value: str(p['jenis'])),
        if (str(p['created_at']).isNotEmpty)
          MetaRow(icon: Icons.schedule, label: 'Dibuat', value: formatTanggal(p['created_at'], serverTimestamp: true)),
      ]),
    );
  }
}

// ── Stepper status ──────────────────────────────────────────────────────────

class _StatusStepper extends StatelessWidget {
  final String status;
  final bool perluReview;
  const _StatusStepper({required this.status, required this.perluReview});

  int get _current {
    switch (status) {
      case 'draft':
        return 0;
      case 'submitted':
        return 1;
      case 'revisi_1':
      case 'revisi_2':
        return 2;
      case 'approved':
      case 'published':
      case 'rejected':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Draft',
      'Diajukan',
      status == 'revisi_1'
          ? 'Revisi 1'
          : status == 'revisi_2'
              ? 'Revisi 2'
              : 'Revisi',
      status == 'rejected'
          ? 'Ditolak'
          : status == 'published'
              ? 'Terpublikasi'
              : 'Disetujui',
    ];
    final current = _current;
    final currentColor = penelitianStatus(status, perluReview: perluReview).color;
    const doneColor = AppColors.successGreen;
    const todoColor = Color(0xFFCFC6D9);

    Color stepColor(int i) => i < current ? doneColor : (i == current ? currentColor : todoColor);
    Color lineColor(int i) => i <= current ? doneColor : todoColor; // garis menuju langkah i

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(labels.length, (i) {
        final color = stepColor(i);
        final isCurrent = i == current;
        return Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : lineColor(i))),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: i < current || isCurrent ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: i < current
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : isCurrent && status == 'rejected'
                          ? const Icon(Icons.close, size: 15, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent ? Colors.white : AppColors.textGrey)),
                ),
              ),
              Expanded(
                  child: Container(
                      height: 2, color: i == labels.length - 1 ? Colors.transparent : lineColor(i + 1))),
            ]),
            const SizedBox(height: 4),
            Text(labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: i <= current ? AppColors.textDark : AppColors.textGrey,
                )),
          ]),
        );
      }),
    );
  }
}

// ── Formulir penelitian (baru / ubah identitas) ─────────────────────────────

class _PenelitianFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _PenelitianFormPage({this.existing});

  @override
  State<_PenelitianFormPage> createState() => _PenelitianFormPageState();
}

class _PenelitianFormPageState extends State<_PenelitianFormPage> {
  final ModuleApi _api = ModuleApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judul;
  late final TextEditingController _pemb1;
  late final TextEditingController _pemb2;
  late final TextEditingController _pembRetro;
  final TextEditingController _proposal = TextEditingController();
  String? _jenis;
  bool _saving = false;

  Map<String, dynamic>? get _e => widget.existing;
  bool get _isEdit => _e != null;
  bool get _withProposal => _proposal.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _judul = TextEditingController(text: str(_e?['judul']));
    _pemb1 = TextEditingController(text: str(_e?['pembimbing_1']));
    _pemb2 = TextEditingController(text: str(_e?['pembimbing_2']));
    _pembRetro = TextEditingController(text: str(_e?['pembimbing_retrospektif']));
    _jenis = str(_e?['jenis']).isEmpty ? null : str(_e?['jenis']);
    if (!_isEdit) _prefillPembimbing();
  }

  Future<void> _prefillPembimbing() async {
    final me = await _api.me();
    if (!mounted || me == null) return;
    setState(() {
      if (_pemb1.text.trim().isEmpty) _pemb1.text = str(me['pembimbing_1']);
      if (_pemb2.text.trim().isEmpty) _pemb2.text = str(me['pembimbing_2']);
      if (_pembRetro.text.trim().isEmpty) _pembRetro.text = str(me['pembimbing_retrospektif']);
    });
  }

  @override
  void dispose() {
    for (final c in [_judul, _pemb1, _pemb2, _pembRetro, _proposal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final judul = _judul.text.trim();
    setState(() => _saving = true);

    final titleChanged = !_isEdit || judul.toLowerCase() != str(_e?['judul']).toLowerCase();
    if (titleChanged) {
      final dup = await _api.checkTopic(judul, 'penelitian');
      if (!mounted) return;
      if (dup['exists'] == true) {
        final go = await confirmDialog(
          context,
          title: 'Judul sudah pernah diajukan',
          message: '${str(dup['message']).isEmpty ? 'Judul penelitian ini sudah ada.' : str(dup['message'])}\n\n'
              'Pastikan topik Anda berbeda. Tetap simpan judul ini?',
          confirmText: 'Tetap simpan',
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
      'jenis': _jenis ?? '',
      'pembimbing_1': _pemb1.text.trim(),
      'pembimbing_2': _pemb2.text.trim(),
      'pembimbing_retrospektif': _pembRetro.text.trim(),
    };
    final bool ok;
    if (_isEdit) {
      ok = await _api.ok('PATCH', '/penelitian/${_e!['id']}', body: data);
    } else {
      ok = await _api.ok('POST', '/penelitian',
          body: {...data, if (_withProposal) 'dokumen_proposal_url': _proposal.text.trim()});
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, _api.errorMessage, error: true);
      return;
    }
    Navigator.pop(
      context,
      _isEdit
          ? 'Data penelitian diperbarui.'
          : _withProposal
              ? 'Penelitian diajukan ke penilai.'
              : 'Penelitian disimpan sebagai draft.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [..._kJenisOptions, if (_jenis != null && !_kJenisOptions.contains(_jenis)) _jenis!];
    return FormPageScaffold(
      title: _isEdit ? 'Ubah Data Penelitian' : 'Ajukan Penelitian',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitIcon: _isEdit || !_withProposal ? Icons.save_outlined : Icons.send,
      submitLabel: _isEdit
          ? 'Simpan perubahan'
          : _withProposal
              ? 'Ajukan ke penilai'
              : 'Simpan sebagai draft',
      children: [
        if (_isEdit)
          const NoteBox(
            title: 'Catatan',
            text: 'Judul, jenis, dan pembimbing hanya bisa diubah selama status masih draft atau sedang revisi.',
          ),
        if (_isEdit) const SizedBox(height: 16),
        moduleField(_judul, 'Judul penelitian', icon: Icons.title, required: true, maxLines: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            initialValue: _jenis,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Jenis penelitian *', prefixIcon: Icon(Icons.category_outlined)),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => setState(() => _jenis = v),
            validator: (v) => v == null || v.isEmpty ? 'Jenis penelitian wajib dipilih' : null,
          ),
        ),
        moduleField(_pemb1, 'Pembimbing 1', icon: Icons.school_outlined, required: true),
        moduleField(_pemb2, 'Pembimbing 2', icon: Icons.school_outlined),
        moduleField(_pembRetro, 'Pembimbing retrospektif', icon: Icons.school_outlined),
        if (!_isEdit) ...[
          const SizedBox(height: 4),
          const NoteBox(
            title: 'Kirim sekarang atau simpan draft?',
            text: 'Isi link proposal untuk langsung mengirim ke penilai, atau kosongkan untuk menyimpan sebagai draft '
                'dan mengajukannya nanti.',
            icon: Icons.lightbulb_outline,
          ),
          const SizedBox(height: 12),
          moduleLinkField(_proposal, 'Link dokumen proposal (opsional)', onChanged: (_) => setState(() {})),
        ],
      ],
    );
  }
}

// ── Dokumen final (setelah disetujui) ───────────────────────────────────────

class _FinalDocsPage extends StatefulWidget {
  final Map<String, dynamic> penelitian;
  const _FinalDocsPage({required this.penelitian});

  @override
  State<_FinalDocsPage> createState() => _FinalDocsPageState();
}

class _FinalDocsPageState extends State<_FinalDocsPage> {
  final ModuleApi _api = ModuleApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _final;
  late final TextEditingController _publikasi;
  late final TextEditingController _loa;
  late final TextEditingController _nomorEtik;
  late final TextEditingController _etik;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.penelitian;
    _final = TextEditingController(text: str(p['dokumen_final_url']));
    _publikasi = TextEditingController(text: str(p['link_publikasi']));
    _loa = TextEditingController(text: str(p['loa_url']));
    _nomorEtik = TextEditingController(text: str(p['nomor_etik']));
    _etik = TextEditingController(text: str(p['ethical_clearance_url']));
  }

  @override
  void dispose() {
    for (final c in [_final, _publikasi, _loa, _nomorEtik, _etik]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await _api.ok('PATCH', '/penelitian/${widget.penelitian['id']}', body: {
      'dokumen_final_url': _final.text.trim(),
      'link_publikasi': _publikasi.text.trim(),
      'loa_url': _loa.text.trim(),
      'nomor_etik': _nomorEtik.text.trim(),
      'ethical_clearance_url': _etik.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, _api.errorMessage, error: true);
      return;
    }
    Navigator.pop(context, 'Dokumen final tersimpan.');
  }

  @override
  Widget build(BuildContext context) {
    return FormPageScaffold(
      title: 'Dokumen Final',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitIcon: Icons.save_outlined,
      submitLabel: 'Simpan dokumen',
      children: [
        Text(str(widget.penelitian['judul']), style: kCardTitle),
        const SizedBox(height: 8),
        const NoteBox(
          title: 'Dokumen final',
          text: 'Link dokumen final wajib diisi. Data publikasi, LOA, dan etik boleh dilengkapi belakangan.',
        ),
        const SizedBox(height: 16),
        moduleLinkField(_final, 'Link dokumen final', required: true),
        const CardSectionLabel('Opsional'),
        const SizedBox(height: 8),
        moduleLinkField(_publikasi, 'Link publikasi'),
        moduleLinkField(_loa, 'Link LOA (Letter of Acceptance)'),
        moduleField(_nomorEtik, 'Nomor ethical clearance', icon: Icons.verified_outlined),
        moduleLinkField(_etik, 'Link dokumen ethical clearance'),
      ],
    );
  }
}
