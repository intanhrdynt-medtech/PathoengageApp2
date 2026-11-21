import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Catatan kegiatan pengabdian masyarakat PPDS.
class PengabdianScreen extends StatefulWidget {
  const PengabdianScreen({super.key});
  @override
  State<PengabdianScreen> createState() => _PengabdianScreenState();
}

class _PengabdianScreenState extends State<PengabdianScreen> {
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
    final data = await _api.list('/pengabdian');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? _api.errorMessage : null;
      if (data != null) _items = data;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final msg = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => _PengabdianFormPage(existing: existing)));
    if (msg == null || !mounted) return;
    showSnack(context, msg);
    _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await confirmDialog(
      context,
      title: 'Hapus kegiatan?',
      message: '"${str(item['nama_kegiatan'])}" akan dihapus dari catatan pengabdian Anda.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!yes || !mounted) return;
    final ok = await _api.ok('DELETE', '/pengabdian/${item['id']}');
    if (!mounted) return;
    if (ok) {
      showSnack(context, 'Kegiatan dihapus.');
      _load();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengabdian Masyarakat', style: TextStyle(fontWeight: FontWeight.w700))),
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
              icon: Icons.diversity_3,
              title: 'Belum ada kegiatan pengabdian',
              message: 'Catat kegiatan pengabdian masyarakat yang Anda ikuti beserta buktinya.',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah kegiatan'),
              ),
            )
          else ...[
            SectionTitle('${_items.length} kegiatan tercatat'),
            ..._items.map((i) => _card(i as Map<String, dynamic>)),
          ],
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final tanggal = str(item['waktu_pelaksanaan']).isNotEmpty ? item['waktu_pelaksanaan'] : item['tanggal'];
    final tempat = str(item['tempat']).isNotEmpty ? str(item['tempat']) : str(item['lokasi']);
    return AppCard(
      onTap: () => _openForm(item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.diversity_3, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(str(item['nama_kegiatan']).isEmpty ? '-' : str(item['nama_kegiatan']), style: kCardTitle),
          ),
          _ItemMenu(onEdit: () => _openForm(item), onDelete: () => _delete(item)),
        ]),
        const SizedBox(height: 4),
        if (str(tanggal).isNotEmpty) MetaRow(icon: Icons.event, label: 'Tanggal', value: formatTanggal(str(tanggal))),
        MetaRow(icon: Icons.location_on_outlined, label: 'Tempat', value: tempat),
        MetaRow(icon: Icons.badge_outlined, label: 'Peran', value: str(item['peran'])),
        if (str(item['deskripsi']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(str(item['deskripsi']), style: kBody, maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
        if (str(item['bukti_url']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinkButton(label: 'Lihat bukti', url: str(item['bukti_url'])),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Belum ada link bukti.', style: kCaption),
          ),
      ]),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ItemMenu({required this.onEdit, required this.onDelete});

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

class _PengabdianFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _PengabdianFormPage({this.existing});

  @override
  State<_PengabdianFormPage> createState() => _PengabdianFormPageState();
}

class _PengabdianFormPageState extends State<_PengabdianFormPage> {
  final ModuleApi _api = ModuleApi();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _tempat;
  late final TextEditingController _peran;
  late final TextEditingController _bukti;
  late final TextEditingController _deskripsi;
  DateTime? _tanggal;
  bool _saving = false;

  Map<String, dynamic>? get _e => widget.existing;
  bool get _isEdit => _e != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: str(_e?['nama_kegiatan']));
    _tempat = TextEditingController(text: str(_e?['tempat']).isNotEmpty ? str(_e?['tempat']) : str(_e?['lokasi']));
    _peran = TextEditingController(text: str(_e?['peran']));
    _bukti = TextEditingController(text: str(_e?['bukti_url']));
    _deskripsi = TextEditingController(text: str(_e?['deskripsi']));
    _tanggal = parseDate(_e?['waktu_pelaksanaan'] ?? _e?['tanggal']);
  }

  @override
  void dispose() {
    for (final c in [_nama, _tempat, _peran, _bukti, _deskripsi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'nama_kegiatan': _nama.text.trim(),
      'waktu_pelaksanaan': _tanggal == null ? '' : isoDate(_tanggal!),
      'tempat': _tempat.text.trim(),
      'peran': _peran.text.trim(),
      'bukti_url': _bukti.text.trim(),
      'deskripsi': _deskripsi.text.trim(),
    };
    final ok = _isEdit
        ? await _api.ok('PATCH', '/pengabdian/${_e!['id']}', body: data)
        : await _api.ok('POST', '/pengabdian', body: data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      showSnack(context, _api.errorMessage, error: true);
      return;
    }
    Navigator.pop(context, _isEdit ? 'Perubahan kegiatan tersimpan.' : 'Kegiatan pengabdian ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return FormPageScaffold(
      title: _isEdit ? 'Ubah Pengabdian' : 'Tambah Pengabdian',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _submit,
      submitIcon: Icons.save_outlined,
      submitLabel: _isEdit ? 'Simpan perubahan' : 'Simpan kegiatan',
      children: [
        moduleField(_nama, 'Nama kegiatan', icon: Icons.event_note, required: true, maxLines: 2),
        DateFormField(
          label: 'Tanggal pelaksanaan',
          initialValue: _tanggal,
          required: true,
          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
          onChanged: (d) => _tanggal = d,
        ),
        moduleField(_tempat, 'Tempat', icon: Icons.location_on_outlined, required: true),
        moduleField(_peran, 'Peran', icon: Icons.badge_outlined, required: true, hint: 'mis. Narasumber, Panitia, Peserta'),
        moduleField(_deskripsi, 'Deskripsi singkat', icon: Icons.notes, maxLines: 4),
        moduleLinkField(_bukti, 'Link bukti (opsional)',
            helper: 'Sertifikat, foto, atau laporan kegiatan di Google Drive.'),
      ],
    );
  }
}
