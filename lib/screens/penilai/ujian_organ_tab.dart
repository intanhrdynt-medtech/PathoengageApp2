import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilai/penilai_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Tab "Ujian Organ": ujian organ yang diuji oleh penilai ini.
class UjianOrganTab extends StatefulWidget {
  final ValueNotifier<int> refreshSignal;
  const UjianOrganTab({super.key, required this.refreshSignal});

  @override
  State<UjianOrganTab> createState() => _UjianOrganTabState();
}

class _UjianOrganTabState extends State<UjianOrganTab> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _done = [];

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

  static bool _isUpcoming(Map<String, dynamic> e) {
    final h = e['hasil']?.toString();
    return h == null || h.isEmpty || h == 'terjadwal';
  }

  Future<void> _load() async {
    if (mounted && _upcoming.isEmpty && _done.isEmpty) setState(() => _loading = true);
    final data = await _api.getUjianYangSayaUji();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _error = _api.lastError ?? 'Gagal memuat daftar ujian organ.';
      });
      return;
    }
    final items = data.whereType<Map<String, dynamic>>().toList();
    // Belum dinilai: tanggal terdekat dulu (tanpa tanggal di akhir).
    final upcoming = items.where(_isUpcoming).toList()
      ..sort((a, b) {
        final da = parseDate(a['tanggal']);
        final db = parseDate(b['tanggal']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    // Sudah dinilai: terbaru dulu.
    final done = items.where((e) => !_isUpcoming(e)).toList()
      ..sort((a, b) {
        final da = parseDate(a['tanggal']);
        final db = parseDate(b['tanggal']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    setState(() {
      _loading = false;
      _error = null;
      _upcoming = upcoming;
      _done = done;
    });
  }

  Future<void> _isiHasil(Map<String, dynamic> exam) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _HasilDialog(exam: exam),
    );
    if (!mounted || saved != true) return;
    showSnack(context, 'Hasil ujian tersimpan');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return RefreshableState(onRefresh: _load, child: ErrorState(message: _error!, onRetry: _load));
    }
    if (_upcoming.isEmpty && _done.isEmpty) {
      return RefreshableState(
        onRefresh: _load,
        child: const EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Belum ada ujian organ',
          message: 'Ujian organ yang Anda uji akan muncul di sini setelah admin menjadwalkan ujian dan '
              'menetapkan Anda sebagai penguji.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Perlu diisi hasilnya (${_upcoming.length})'),
              if (_upcoming.isEmpty)
                const AppCard(child: Text('Semua ujian yang Anda uji sudah diisi hasilnya.', style: kBody)),
              ..._upcoming.map(_card),
              if (_done.isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionTitle('Sudah dinilai (${_done.length})'),
                ..._done.map(_card),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> e) {
    final upcoming = _isUpcoming(e);
    final nilai = asDouble(e['nilai']);
    final catatan = textOrNull(e['catatan']);
    final tanggal = parseDate(e['tanggal']);
    final now = DateTime.now();
    final lewat = upcoming && tanggal != null && tanggal.isBefore(DateTime(now.year, now.month, now.day));
    return AppCard(
      borderColor: lewat ? AppColors.warningOrange.withValues(alpha: 0.6) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['nama_ujian']?.toString() ?? '-', style: kCardTitle),
              const SizedBox(height: 2),
              Text(
                '${e['ppds_nama'] ?? '-'}${textOrNull(e['ppds_nim']) != null ? ' · NIM ${e['ppds_nim']}' : ''}',
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(examStatus(e['hasil']?.toString())),
        ]),
        if (textOrNull(e['organ']) != null) InfoLine(Icons.biotech_outlined, 'Organ: ${e['organ']}'),
        InfoLine(Icons.event_outlined,
            tanggal == null ? 'Tanggal belum ditentukan' : 'Tanggal ujian: ${formatTanggal(e['tanggal'])}'),
        if (lewat)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Tanggal ujian sudah lewat — mohon isi hasilnya.',
                style: TextStyle(fontSize: 13, color: AppColors.warningOrange, fontWeight: FontWeight.w600)),
          ),
        if (nilai != null) InfoLine(Icons.grade_outlined, 'Nilai: ${formatNilai(nilai)}'),
        if (catatan != null) NoteBox(title: 'Catatan penguji', text: catatan, icon: Icons.notes),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: upcoming
              ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                  onPressed: () => _isiHasil(e),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Isi hasil'),
                )
              : OutlinedButton.icon(
                  onPressed: () => _isiHasil(e),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ubah hasil'),
                ),
        ),
      ]),
    );
  }
}

// ── Dialog isi hasil ──────────────────────────────────────────────────────────

class _HasilDialog extends StatefulWidget {
  final Map<String, dynamic> exam;
  const _HasilDialog({required this.exam});

  @override
  State<_HasilDialog> createState() => _HasilDialogState();
}

class _HasilDialogState extends State<_HasilDialog> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nilaiCtrl;
  late final TextEditingController _catatanCtrl;
  late final String _hasilAwal;
  late String _hasil;
  DateTime? _tanggal;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    final h = e['hasil']?.toString();
    _hasilAwal = (h == 'lulus' || h == 'tidak_lulus') ? h! : 'terjadwal';
    _hasil = _hasilAwal;
    final nilai = asDouble(e['nilai']);
    _nilaiCtrl = TextEditingController(text: nilai == null ? '' : formatNilai(nilai));
    _catatanCtrl = TextEditingController(text: e['catatan']?.toString() ?? '');
    _tanggal = parseDate(e['tanggal']);
  }

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Tanggal ujian',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    final old = _tanggal;
    // Pertahankan jam bila sebelumnya sudah ada.
    setState(() => _tanggal = DateTime(picked.year, picked.month, picked.day, old?.hour ?? 0, old?.minute ?? 0));
  }

  String _hasilLabel(String h) => h == 'lulus' ? 'Lulus' : (h == 'tidak_lulus' ? 'Tidak lulus' : 'Terjadwal');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final e = widget.exam;
    if (_hasil != _hasilAwal && (_hasil == 'lulus' || _hasil == 'tidak_lulus')) {
      final ok = await confirmDialog(
        context,
        title: 'Tandai ${_hasilLabel(_hasil)}?',
        message: '${e['ppds_nama'] ?? 'PPDS'} akan ditandai ${_hasilLabel(_hasil).toLowerCase()} '
            'pada ${e['nama_ujian'] ?? 'ujian ini'}. PPDS dan admin akan menerima notifikasi'
            '${_hasil == 'lulus' ? ', dan kelulusan Ujian Organ dapat menaikkan kalung PPDS secara otomatis' : ''}.',
        confirmText: 'Ya, ${_hasilLabel(_hasil)}',
        danger: _hasil == 'tidak_lulus',
      );
      if (!ok || !mounted) return;
    }
    final nilaiText = _nilaiCtrl.text.trim().replaceAll(',', '.');
    final data = <String, dynamic>{
      'hasil': _hasil,
      'nilai': nilaiText.isEmpty ? null : double.parse(nilaiText),
      'catatan': _catatanCtrl.text.trim(),
      if (_tanggal != null) 'tanggal': _tanggal!.toIso8601String(),
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = asInt(e['id']);
    final success = id != null && await _api.isiHasilUjianOrgan(id, data);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = _api.lastError ?? 'Gagal menyimpan hasil ujian.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    return AlertDialog(
      title: const Text('Hasil ujian organ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['nama_ujian']?.toString() ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                [
                  e['ppds_nama']?.toString() ?? '-',
                  if (textOrNull(e['organ']) != null) 'Organ: ${e['organ']}',
                ].join(' · '),
                style: kCaption,
              ),
              const SizedBox(height: 16),
              const Text('Hasil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'terjadwal', label: _SegLabel('Terjadwal')),
                    ButtonSegment(value: 'lulus', label: _SegLabel('Lulus')),
                    ButtonSegment(value: 'tidak_lulus', label: _SegLabel('Tidak lulus')),
                  ],
                  selected: {_hasil},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: _saving ? null : (s) => setState(() => _hasil = s.first),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nilaiCtrl,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(labelText: 'Nilai 0–100 (opsional)', prefixIcon: Icon(Icons.grade_outlined)),
                validator: (v) {
                  final t = (v ?? '').trim().replaceAll(',', '.');
                  if (t.isEmpty) return null;
                  final n = double.tryParse(t);
                  if (n == null || n < 0 || n > 100) return 'Nilai harus angka 0–100';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _saving ? null : _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal ujian', prefixIcon: Icon(Icons.event_outlined)),
                  child: Text(
                    _tanggal == null ? 'Pilih tanggal' : formatTanggal(_tanggal!.toIso8601String()),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _catatanCtrl,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Catatan penguji (opsional)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                NoteBox(title: 'Gagal menyimpan', text: _error!, color: AppColors.errorRed, icon: Icons.error_outline),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan hasil'),
        ),
      ],
    );
  }
}

/// Label segmen yang tidak terpotong jadi dua baris di layar sempit.
class _SegLabel extends StatelessWidget {
  final String text;
  const _SegLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}
