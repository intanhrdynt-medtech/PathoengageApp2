import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/screens/admin/verification_sheet.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Admin: daftar pengajuan yang menunggu verifikasi (kompetensi, ujian, tugas
/// akademik, journal reading), dengan ringkasan di bagian atas.
class AdminVerificationScreen extends StatefulWidget {
  /// Dipanggil setiap jumlah pengajuan yang menunggu berubah (untuk badge menu).
  final ValueChanged<int>? onCountChanged;
  const AdminVerificationScreen({super.key, this.onCountChanged});

  @override
  State<AdminVerificationScreen> createState() => AdminVerificationScreenState();
}

class AdminVerificationScreenState extends State<AdminVerificationScreen> {
  bool _loading = true;
  String? _error;
  List<VerifItem> _items = [];
  int? _penelitianMenunggu;
  String _filter = 'all';
  bool _summaryOpen = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Muat ulang data (juga dipanggil dari dashboard setelah notifikasi dibuka).
  Future<void> reload() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    // Instance terpisah supaya pesan error tiap panggilan tidak saling menimpa.
    final verifApi = ApiService();
    final journalApi = ApiService();
    final penelitianApi = ApiService();
    final results = await Future.wait<List<dynamic>?>([
      verifApi.getPendingVerificationsOrNull(),
      journalApi.getPendingJournals(),
      penelitianApi.getAllPenelitianOrNull(),
    ]);
    if (!mounted) return;
    final pending = results[0];
    final journals = results[1];
    final penelitian = results[2];
    if (pending == null && journals == null) {
      setState(() {
        _loading = false;
        _error = verifApi.lastError ?? journalApi.lastError ?? 'Gagal memuat data. Periksa koneksi internet.';
      });
      return;
    }
    final items = <VerifItem>[
      for (final m in pending ?? const []) VerifItem.fromPending(Map<String, dynamic>.from(m as Map)),
      for (final j in journals ?? const []) VerifItem.fromJournal(Map<String, dynamic>.from(j as Map)),
    ];
    setState(() {
      _items = items;
      _penelitianMenunggu = penelitian?.where((p) => p is Map && p['perlu_review'] == true).length;
      _loading = false;
      _error = (pending == null || journals == null)
          ? 'Sebagian data gagal dimuat: ${verifApi.lastError ?? journalApi.lastError ?? 'periksa koneksi'}'
          : null;
    });
    widget.onCountChanged?.call(items.length);
  }

  int _count(String cat) => _items.where((i) => i.category.key == cat).length;

  List<VerifItem> get _visible => _filter == 'all' ? _items : _items.where((i) => i.category.key == _filter).toList();

  Future<void> _open(VerifItem item) async {
    final msg = await showVerificationSheet(context, item);
    if (!mounted || msg == null) return;
    setState(() => _items.removeWhere((i) => i.key == item.key));
    widget.onCountChanged?.call(_items.length);
    showSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) return ErrorState(message: _error!, onRetry: reload);

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: reload,
      child: AdminListView(
        children: [
          _buildSummary(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoteBox(title: 'Perhatian', text: _error!, color: AppColors.warningOrange, icon: Icons.warning_amber),
            ),
          _buildFilters(),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.task_alt,
              title: _items.isEmpty ? 'Semua pengajuan sudah diproses' : 'Tidak ada pengajuan di kategori ini',
              message: _items.isEmpty ? 'Tarik ke bawah untuk memuat ulang.' : null,
            )
          else
            for (final item in visible) _ItemCard(item: item, onOpen: () => _open(item)),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final total = _items.length;
    return AppCard(
      color: AppColors.lightPurpleAccent.withValues(alpha: 0.35),
      borderColor: AppColors.lightPurpleAccent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _summaryOpen = !_summaryOpen),
          child: Row(children: [
            const Icon(Icons.inbox_outlined, color: AppColors.primaryPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                total == 0 ? 'Tidak ada pengajuan yang menunggu' : '$total pengajuan menunggu tindakan Anda',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
            Icon(_summaryOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.textGrey),
          ]),
        ),
        if (_summaryOpen) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in VerifCategory.all)
              _CountTile(
                label: c.label,
                count: _count(c.key),
                icon: c.icon,
                color: c.color,
                selected: _filter == c.key,
                onTap: () => setState(() => _filter = _filter == c.key ? 'all' : c.key),
              ),
          ]),
          if (_penelitianMenunggu != null) ...[
            const SizedBox(height: 8),
            NoteBox(
              title: 'Penelitian menunggu penilai: $_penelitianMenunggu',
              text: 'Informasi saja. Penelitian direview oleh pembimbing/penilai masing-masing PPDS.',
              icon: Icons.science_outlined,
            ),
          ],
        ],
      ]),
    );
  }

  Widget _buildFilters() {
    final chips = <MapEntry<String, String>>[
      MapEntry('all', 'Semua (${_items.length})'),
      for (final c in VerifCategory.all) MapEntry(c.key, '${c.label} (${_count(c.key)})'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final e in chips)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value, style: const TextStyle(fontSize: 13)),
              selected: _filter == e.key,
              onSelected: (_) => setState(() => _filter = e.key),
            ),
          ),
      ]),
    );
  }
}

class _CountTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CountTile({required this.label, required this.count, required this.icon, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : AppColors.cardBorder),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final VerifItem item;
  final VoidCallback onOpen;
  const _ItemCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cat = item.category;
    return AppCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cat.color.withValues(alpha: 0.12),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text('PPDS: ${item.userName}', style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
              if (item.meta.isNotEmpty)
                Text(item.meta.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          const SizedBox(width: 8),
          TagChip(cat.label, color: cat.color),
        ]),
        if (item.resume != null) ...[
          const SizedBox(height: 8),
          _Snippet(title: item.category.key == 'academic' ? 'Resume' : 'Catatan', text: item.resume!),
        ],
        if (item.syarat != null) ...[
          const SizedBox(height: 8),
          _Snippet(title: 'Syarat', text: item.syarat!),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (item.evidenceUrl != null)
            LinkButton(label: 'Buka bukti', url: item.evidenceUrl)
          else
            Text(item.category.key == 'journal' ? 'Pengajuan judul' : 'Tanpa link bukti',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const Spacer(),
          FilledButton.tonal(onPressed: onOpen, child: const Text('Periksa')),
        ]),
      ]),
    );
  }
}

class _Snippet extends StatelessWidget {
  final String title;
  final String text;
  const _Snippet({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.backgroundLightest, borderRadius: BorderRadius.circular(10)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: text),
        ]),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
      ),
    );
  }
}
