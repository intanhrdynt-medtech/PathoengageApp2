import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilai/penilai_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Tab "Perlu Direview": journal reading yang menunggu persetujuan dan
/// penelitian yang menunggu keputusan penilai.
class ReviewTab extends StatefulWidget {
  /// Bertambah setiap kali layar induk meminta muat ulang (mis. setelah
  /// notifikasi dibuka).
  final ValueNotifier<int> refreshSignal;

  /// Dipanggil dengan jumlah total item di antrean (untuk badge navigasi).
  final ValueChanged<int>? onCountChanged;

  const ReviewTab({super.key, required this.refreshSignal, this.onCountChanged});

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  final PenilaiReviewApi _reviewApi = PenilaiReviewApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _penelitian = [];
  Set<int> _bimbinganIds = {};

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_load);
    super.dispose();
  }

  bool _isMine(Map<String, dynamic> item) => _bimbinganIds.contains(asInt(item['user_id']));

  /// Bimbingan saya lebih dulu, lalu yang paling lama menunggu.
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> items, String dateField) {
    final list = [...items];
    list.sort((a, b) {
      final mine = (_isMine(a) ? 0 : 1).compareTo(_isMine(b) ? 0 : 1);
      if (mine != 0) return mine;
      final da = parseDate(a[dateField]) ?? parseDate(a['created_at']);
      final db = parseDate(b[dateField]) ?? parseDate(b['created_at']);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  Future<void> _load() async {
    if (mounted && _journals.isEmpty && _penelitian.isEmpty) setState(() => _loading = true);
    final journalApi = ApiService();
    final penelitianApi = ApiService();
    final bimbinganApi = ApiService();
    final results = await Future.wait([
      journalApi.getPendingJournals(),
      penelitianApi.getAllPenelitianOrNull(),
      bimbinganApi.getBimbingan(),
    ]);
    if (!mounted) return;
    final journals = results[0];
    final penelitian = results[1];
    final bimbingan = results[2];
    if (journals == null || penelitian == null) {
      setState(() {
        _loading = false;
        _error = journalApi.lastError ?? penelitianApi.lastError ?? 'Gagal memuat antrean review.';
      });
      return;
    }
    final ids = <int>{};
    for (final b in bimbingan ?? const []) {
      final id = asInt((b as Map)['id']);
      if (id != null) ids.add(id);
    }
    setState(() {
      _loading = false;
      _error = null;
      _bimbinganIds = ids;
      _journals = _sorted(journals.whereType<Map<String, dynamic>>().toList(), 'created_at');
      _penelitian = _sorted(
        penelitian
            .whereType<Map<String, dynamic>>()
            .where((p) => p['perlu_review'] == true || p['status'] == 'submitted')
            // Hanya pembimbing/dosen wali yang ditugaskan yang boleh mereview.
            .where((p) => ids.contains(asInt(p['user_id'])))
            .toList(),
        'updated_at',
      );
    });
    widget.onCountChanged?.call(_journals.length + _penelitian.length);
  }

  // ── Review ────────────────────────────────────────────────────────────────

  Future<void> _reviewJournal(Map<String, dynamic> j) async {
    final id = asInt(j['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(
        title: 'Review Journal Reading',
        itemTitle: j['judul']?.toString() ?? '-',
        ppdsName: j['user_name']?.toString() ?? '-',
        options: const [
          _Decision('approve', 'Setujui', Icons.check_circle, AppColors.successGreen,
              hint: 'PPDS dapat mempresentasikan journal ini lalu mengunggah bukti presentasi.'),
          _Decision('reject', 'Tolak', Icons.cancel, AppColors.errorRed,
              needsNote: true, danger: true, hint: 'PPDS diminta memperbaiki lalu mengajukan ulang.'),
        ],
        onSubmit: (decision, note) => _reviewApi.reviewJournal(id, decision, note),
      ),
    );
    if (!mounted || ok != true) return;
    showSnack(context, 'Review journal reading tersimpan');
    _load();
  }

  Future<void> _reviewPenelitian(Map<String, dynamic> p) async {
    final id = asInt(p['id']);
    if (id == null) return;
    final status = p['status']?.toString();
    final hadRevisi1 = textOrNull(p['catatan_revisi1']) != null ||
        textOrNull(p['dokumen_revisi1_url']) != null ||
        status == 'revisi_2';
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(
        title: 'Review Penelitian',
        itemTitle: p['judul']?.toString() ?? '-',
        ppdsName: p['user_name']?.toString() ?? '-',
        options: [
          const _Decision('approved', 'Setujui', Icons.check_circle, AppColors.successGreen,
              hint: 'Penelitian dinyatakan disetujui.'),
          _Decision('revisi_1', 'Revisi 1', Icons.edit_document, AppColors.warningOrange,
              needsNote: true,
              enabled: status != 'revisi_2',
              disabledReason: 'Penelitian sudah berada di ronde Revisi 2.',
              hint: 'PPDS diminta mengunggah dokumen Revisi 1. Link dokumen revisi lama (bila ada) '
                  'disimpan otomatis di catatan.'),
          _Decision('revisi_2', 'Revisi 2', Icons.edit_document, AppColors.warningOrange,
              needsNote: true,
              enabled: hadRevisi1,
              disabledReason: 'Revisi 2 hanya bisa diminta setelah ada ronde Revisi 1.',
              hint: 'PPDS diminta mengunggah dokumen Revisi 2. Link dokumen revisi lama (bila ada) '
                  'disimpan otomatis di catatan.'),
          const _Decision('rejected', 'Tolak', Icons.cancel, AppColors.errorRed,
              needsNote: true, danger: true, hint: 'Penelitian ditolak.'),
        ],
        onSubmit: (decision, note) => _reviewApi.reviewPenelitian(id, decision, note),
      ),
    );
    if (!mounted || ok != true) return;
    showSnack(context, 'Review penelitian tersimpan');
    _load();
  }

  // ── Tampilan ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return RefreshableState(onRefresh: _load, child: ErrorState(message: _error!, onRetry: _load));
    }
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(
            labelColor: AppColors.primaryPurple,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primaryPurple,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: 'Journal Reading (${_journals.length})'),
              Tab(text: 'Penelitian (${_penelitian.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _buildList(
              items: _journals,
              emptyTitle: 'Tidak ada journal reading yang menunggu',
              emptyIcon: Icons.article_outlined,
              itemBuilder: _journalCard,
            ),
            _buildList(
              items: _penelitian,
              emptyTitle: 'Tidak ada penelitian yang menunggu review',
              emptyIcon: Icons.science_outlined,
              itemBuilder: _penelitianCard,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyTitle,
    required IconData emptyIcon,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    if (items.isEmpty) {
      return RefreshableState(
        onRefresh: _load,
        child: EmptyState(
          icon: emptyIcon,
          title: emptyTitle,
          message: 'Pengajuan baru dari PPDS akan muncul di sini. Anda juga mendapat notifikasi '
              'saat PPDS bimbingan Anda mengirim pengajuan.',
        ),
      );
    }
    final mineCount = items.where(_isMine).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (mineCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('$mineCount dari ${items.length} pengajuan berasal dari PPDS bimbingan Anda '
                      '(ditampilkan paling atas).', style: kCaption),
                ),
              ...items.map(itemBuilder),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ppdsHeader(Map<String, dynamic> item) {
    final nim = textOrNull(item['user_nim']);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.lightPurpleAccent,
        child: Icon(Icons.person, size: 18, color: AppColors.primaryPurple),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['user_name']?.toString() ?? '-',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          if (nim != null) Text('NIM $nim', style: kCaption),
        ]),
      ),
      if (_isMine(item)) const SmallTag('Bimbingan saya', icon: Icons.star, color: AppColors.secondaryMagenta),
    ]);
  }

  Widget _journalCard(Map<String, dynamic> j) {
    final note = textOrNull(j['catatan_admin']);
    final details = <String>[
      if (textOrNull(j['jenis']) != null) j['jenis'].toString(),
      if (textOrNull(j['nama_jurnal']) != null) j['nama_jurnal'].toString(),
    ];
    return AppCard(
      borderColor: _isMine(j) ? AppColors.secondaryMagenta.withValues(alpha: 0.5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ppdsHeader(j),
        const SizedBox(height: 12),
        Text(j['judul']?.toString() ?? '-', style: kCardTitle),
        if (textOrNull(j['penulis']) != null) InfoLine(Icons.people_outline, 'Penulis: ${j['penulis']}'),
        if (details.isNotEmpty) InfoLine(Icons.menu_book_outlined, details.join(' · ')),
        if (textOrNull(j['pembimbing']) != null) InfoLine(Icons.school_outlined, 'Pembimbing: ${j['pembimbing']}'),
        if (textOrNull(j['penguji']) != null) InfoLine(Icons.how_to_reg_outlined, 'Penguji: ${j['penguji']}'),
        if (textOrNull(j['tanggal_presentasi']) != null)
          InfoLine(Icons.event_outlined, 'Rencana presentasi: ${formatTanggal(j['tanggal_presentasi'])}'),
        InfoLine(Icons.schedule, 'Diajukan ${formatTanggal(j['created_at'], withTime: true, serverTimestamp: true)}'),
        const SizedBox(height: 10),
        StatusChip(journalStatus(j['status']?.toString(), buktiSubmitted: j['bukti_submitted'] == true)),
        if (textOrNull(j['bukti_url']) != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(children: [LinkButton(label: 'Bukti presentasi', url: j['bukti_url']?.toString())]),
          ),
        if (note != null)
          NoteBox(title: 'Catatan review sebelumnya', text: note, icon: Icons.history, color: AppColors.neutralGrey),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            onPressed: () => _reviewJournal(j),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Review'),
          ),
        ),
      ]),
    );
  }

  Widget _penelitianCard(Map<String, dynamic> p) {
    final status = p['status']?.toString();
    final pembimbing = <String>[
      if (textOrNull(p['pembimbing_1']) != null) 'Pembimbing 1: ${p['pembimbing_1']}',
      if (textOrNull(p['pembimbing_2']) != null) 'Pembimbing 2: ${p['pembimbing_2']}',
      if (textOrNull(p['pembimbing_retrospektif']) != null) 'Retrospektif: ${p['pembimbing_retrospektif']}',
    ];
    const linkFields = {
      'Dokumen proposal': 'dokumen_proposal_url',
      'Dokumen Revisi 1': 'dokumen_revisi1_url',
      'Dokumen Revisi 2': 'dokumen_revisi2_url',
      'Dokumen final': 'dokumen_final_url',
      'Ethical clearance': 'ethical_clearance_url',
      'Publikasi': 'link_publikasi',
      'LoA': 'loa_url',
    };
    final links = <Widget>[
      for (final e in linkFields.entries)
        if (textOrNull(p[e.value]) != null) LinkButton(label: e.key, url: textOrNull(p[e.value])),
    ];
    final hasLink = links.isNotEmpty;
    final created = formatTanggal(p['created_at'], withTime: true, serverTimestamp: true);
    final updated = formatTanggal(p['updated_at'], withTime: true, serverTimestamp: true);

    return AppCard(
      borderColor: _isMine(p) ? AppColors.secondaryMagenta.withValues(alpha: 0.5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ppdsHeader(p),
        const SizedBox(height: 12),
        Text(p['judul']?.toString() ?? '-', style: kCardTitle),
        if (textOrNull(p['jenis']) != null) InfoLine(Icons.category_outlined, p['jenis'].toString()),
        for (final line in pembimbing) InfoLine(Icons.school_outlined, line),
        if (textOrNull(p['nomor_etik']) != null) InfoLine(Icons.verified_outlined, 'Nomor etik: ${p['nomor_etik']}'),
        InfoLine(Icons.schedule, 'Diajukan $created'),
        if (updated != '-' && updated != created) InfoLine(Icons.update, 'Diperbarui $updated'),
        const SizedBox(height: 10),
        StatusChip(penelitianStatus(status, perluReview: p['perlu_review'] == true)),
        const SizedBox(height: 6),
        if (hasLink)
          Wrap(spacing: 4, runSpacing: 0, children: links)
        else
          const Text('Belum ada dokumen terlampir.', style: kCaption),
        if (textOrNull(p['catatan_revisi1']) != null)
          NoteBox(title: 'Catatan Revisi 1', text: p['catatan_revisi1'].toString(),
              icon: Icons.history, color: AppColors.warningOrange),
        if (textOrNull(p['catatan_revisi2']) != null)
          NoteBox(title: 'Catatan Revisi 2', text: p['catatan_revisi2'].toString(),
              icon: Icons.history, color: AppColors.warningOrange),
        if (textOrNull(p['catatan_penilai']) != null)
          NoteBox(title: 'Catatan penilai', text: p['catatan_penilai'].toString(),
              icon: Icons.history, color: AppColors.neutralGrey),
        if (textOrNull(p['notes']) != null)
          NoteBox(title: 'Catatan dari PPDS', text: p['notes'].toString(), icon: Icons.chat_bubble_outline),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            onPressed: () => _reviewPenelitian(p),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Review'),
          ),
        ),
      ]),
    );
  }
}

// ── Dialog review ─────────────────────────────────────────────────────────────

class _Decision {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool needsNote;
  final bool danger;
  final bool enabled;
  final String? disabledReason;
  final String? hint;
  const _Decision(this.value, this.label, this.icon, this.color,
      {this.needsNote = false, this.danger = false, this.enabled = true, this.disabledReason, this.hint});
}

/// Dialog keputusan review. Tidak ada keputusan yang dipilih otomatis.
/// Mengembalikan true bila review berhasil dikirim.
class _ReviewDialog extends StatefulWidget {
  final String title;
  final String itemTitle;
  final String ppdsName;
  final List<_Decision> options;

  /// Mengembalikan null bila sukses, atau pesan error.
  final Future<String?> Function(String decision, String note) onSubmit;

  const _ReviewDialog({
    required this.title,
    required this.itemTitle,
    required this.ppdsName,
    required this.options,
    required this.onSubmit,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _Decision? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final decision = _selected;
    if (decision == null) {
      setState(() => _error = 'Pilih keputusan review terlebih dahulu.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final ok = await confirmDialog(
      context,
      title: '${decision.label}?',
      message: 'Keputusan "${decision.label}" untuk "${widget.itemTitle}" (${widget.ppdsName}) akan dikirim '
          'dan PPDS menerima notifikasi.',
      confirmText: decision.label,
      danger: decision.danger,
    );
    if (!ok || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await widget.onSubmit(decision.value, _noteCtrl.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  Widget _choice(_Decision d) {
    final selected = _selected?.value == d.value;
    final chip = ChoiceChip(
      avatar: Icon(d.icon, size: 18, color: d.enabled ? (selected ? Colors.white : d.color) : AppColors.neutralGrey),
      label: Text(d.label),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: !d.enabled ? AppColors.neutralGrey : (selected ? Colors.white : d.color),
      ),
      showCheckmark: false,
      selected: selected,
      selectedColor: d.color,
      backgroundColor: Colors.white,
      side: BorderSide(color: d.enabled ? d.color.withValues(alpha: 0.6) : AppColors.cardBorder),
      onSelected: d.enabled && !_submitting
          ? (_) => setState(() {
                _selected = d;
                _error = null;
              })
          : null,
    );
    if (!d.enabled && d.disabledReason != null) return Tooltip(message: d.disabledReason!, child: chip);
    return chip;
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final noteRequired = sel?.needsNote ?? false;
    final disabledReasons = widget.options.where((o) => !o.enabled && o.disabledReason != null).toList();
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.itemTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(widget.ppdsName, style: kCaption),
              const SizedBox(height: 16),
              const Text('Keputusan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: widget.options.map(_choice).toList()),
              for (final d in disabledReasons)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.label} tidak tersedia: ${d.disabledReason}', style: kCaption),
                ),
              if (sel?.hint != null) ...[
                const SizedBox(height: 8),
                NoteBox(title: sel!.label, text: sel.hint!, color: sel.color, icon: sel.icon),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 4,
                minLines: 3,
                enabled: !_submitting,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: noteRequired ? 'Catatan untuk PPDS (wajib)' : 'Catatan untuk PPDS (opsional)',
                  hintText: noteRequired ? 'Jelaskan apa yang perlu diperbaiki' : null,
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (noteRequired && (v ?? '').trim().isEmpty) {
                    return 'Catatan wajib diisi untuk keputusan ${sel?.label ?? ''}';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                NoteBox(title: 'Gagal mengirim', text: _error!, color: AppColors.errorRed, icon: Icons.error_outline),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: sel?.danger == true ? AppColors.errorRed : AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: _submitting || sel == null ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(sel == null ? 'Pilih keputusan' : 'Kirim: ${sel.label}'),
        ),
      ],
    );
  }
}
