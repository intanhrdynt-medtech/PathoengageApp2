import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Catatan prestasi (lomba, penghargaan) PPDS.
class PrestasiScreen extends StatefulWidget {
  const PrestasiScreen({super.key});
  @override
  State<PrestasiScreen> createState() => _PrestasiScreenState();
}

const List<String> _kTingkat = ['Lokal', 'Regional', 'Nasional', 'Internasional'];
const List<String> _kJuara = ['Juara 1', 'Juara 2', 'Juara 3', 'Harapan', 'Finalis', 'Peserta', 'Lainnya'];

class _PrestasiScreenState extends State<PrestasiScreen> {
  final ModuleApi _api = ModuleApi();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.list('/prestasi');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? _api.errorMessage : null;
      if (data != null) _items = data;
    });
  }

  String _nama(Map<String, dynamic> item) =>
      str(item['nama_lomba']).isNotEmpty ? str(item['nama_lomba']) : str(item['nama_prestasi']);

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final msg = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => _PrestasiFormPage(existing: existing)));
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await confirmDialog(
      context,
      title: 'Hapus prestasi?',
      message: '"${_nama(item)}" akan dihapus dari catatan prestasi Anda.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!yes || !mounted) return;
    final ok = await _api.ok('DELETE', '/prestasi/${item['id']}');
    if (!mounted) return;
    if (ok) {
      showSnack(context, 'Prestasi dihapus.');
      _load();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prestasi', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: moduleBody(
        loading: _loading,
        error: _error,
        onRefresh: _load,
        bottomPadding: 96,
        builder: () => [
          if (_items.isEmpty)
            EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Belum ada prestasi',
              message: 'Catat lomba atau penghargaan yang Anda raih beserta sertifikatnya.',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah prestasi'),
              ),
            )
          else ...[
            SectionTitle('${_items.length} prestasi tercatat'),
            ..._items.map((i) => _card(i as Map<String, dynamic>)),
          ],
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final tingkat = str(item['tingkat']);
    final juara = str(item['juara_ke']);
    return AppCard(
      onTap: () => _openForm(item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.warningOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.emoji_events, color: AppColors.warningOrange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_nama(item).isEmpty ? '-' : _nama(item), style: kCardTitle)),
          _PrestasiMenu(onEdit: () => _openForm(item), onDelete: () => _delete(item)),
        ]),
        if (tingkat.isNotEmpty || juara.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (juara.isNotEmpty) _chip(juara, AppColors.warningOrange, Icons.military_tech),
            if (tingkat.isNotEmpty) _chip('Tingkat $tingkat', AppColors.infoBlue, Icons.public),
          ]),
        ],
        const SizedBox(height: 4),
        if (str(item['waktu_pelaksanaan']).isNotEmpty)
          MetaRow(icon: Icons.event, label: 'Tanggal', value: formatTanggal(item['waktu_pelaksanaan']))
        else if (item['tahun'] != null)
          MetaRow(icon: Icons.event, label: 'Tahun', value: '${item['tahun']}'),
        if (str(item['deskripsi']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(str(item['deskripsi']), style: kBody, maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
        if (str(item['sertifikat_url']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinkButton(label: 'Lihat sertifikat', url: str(item['sertifikat_url'])),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Belum ada link sertifikat.', style: kCaption),
          ),
      ]),
    );
  }

  Widget _chip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _PrestasiMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PrestasiMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Pilihan',
      icon: const Icon(Icons.more_vert, color: AppColors.textGrey),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Ubah'), dense: true)),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.errorRed),
              title: Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
              dense: true),
        ),
      ],
    );
  }
}

class _PrestasiFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _PrestasiFormPage({this.existing});

  @override
  State<_PrestasiFormPage> createState() => _PrestasiFormPageState();
}

class _PrestasiFormPageState extends State<_PrestasiFormPage> {
  final ModuleApi _api = ModuleApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _sertifikat;
  late final TextEditingController _deskripsi;
  String? _tingkat;
  String? _juara;
  DateTime? _tanggal;
  bool _saving = false;

  Map<String, dynamic>? get _e => widget.existing;
  bool get _isEdit => _e != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(
        text: str(_e?['nama_lomba']).isNotEmpty ? str(_e?['nama_lomba']) : str(_e?['nama_prestasi']));
    _sertifikat = TextEditingController(text: str(_e?['sertifikat_url']));
    _deskripsi = TextEditingController(text: str(_e?['deskripsi']));
    _tingkat = str(_e?['tingkat']).isEmpty ? null : str(_e?['tingkat']);
    _juara = str(_e?['juara_ke']).isEmpty ? null : str(_e?['juara_ke']);
    _tanggal = parseDate(_e?['waktu_pelaksanaan']);
  }

  @override
  void dispose() {
    for (final c in [_nama, _sertifikat, _deskripsi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'nama_lomba': _nama.text.trim(),
      'waktu_pelaksanaan': _tanggal == null ? '' : isoDate(_tanggal!),
      'tingkat': _tingkat ?? '',
      'juara_ke': _juara ?? '',
      'sertifikat_url': _sertifikat.text.trim(),
      'deskripsi': _deskripsi.text.trim(),
    };
    final ok = _isEdit
        ? await _api.ok('PATCH', '/prestasi/${_e!['id']}', body: data)
        : await _api.ok('POST', '/prestasi', body: data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, _api.errorMessage, error: true);
      return;
    }
    Navigator.pop(context, _isEdit ? 'Perubahan prestasi tersimpan.' : 'Prestasi ditambahkan.');
  }

  Widget _dropdown(String label, IconData icon, List<String> base, String? value, ValueChanged<String?> onChanged) {
    final options = [...base, if (value != null && !base.contains(value)) value];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: '$label *', prefixIcon: Icon(icon)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null || v.isEmpty ? '$label wajib dipilih' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPageScaffold(
      title: _isEdit ? 'Ubah Prestasi' : 'Tambah Prestasi',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitIcon: Icons.save_outlined,
      submitLabel: _isEdit ? 'Simpan perubahan' : 'Simpan prestasi',
      children: [
        moduleField(_nama, 'Nama lomba / penghargaan', icon: Icons.emoji_events_outlined, required: true, maxLines: 2),
        DateFormField(
          label: 'Tanggal pelaksanaan',
          initialValue: _tanggal,
          required: true,
          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
          onChanged: (d) => _tanggal = d,
        ),
        _dropdown('Tingkat', Icons.public, _kTingkat, _tingkat, (v) => setState(() => _tingkat = v)),
        _dropdown('Pencapaian', Icons.military_tech_outlined, _kJuara, _juara, (v) => setState(() => _juara = v)),
        moduleField(_deskripsi, 'Deskripsi singkat', icon: Icons.notes, maxLines: 4),
        moduleLinkField(_sertifikat, 'Link sertifikat (opsional)',
            helper: 'Sertifikat atau bukti penghargaan di Google Drive.'),
      ],
    );
  }
}
