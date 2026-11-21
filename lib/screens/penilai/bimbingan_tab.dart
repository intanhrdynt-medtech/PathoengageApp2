import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilai/bimbingan_detail_screen.dart';
import 'package:fp_pemrograman/screens/penilai/penilai_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Tab "PPDS Bimbingan": PPDS yang ditugaskan admin kepada penilai ini
/// (sebagai dosen wali / pembimbing).
class BimbinganTab extends StatefulWidget {
  final ValueNotifier<int> refreshSignal;
  const BimbinganTab({super.key, required this.refreshSignal});

  @override
  State<BimbinganTab> createState() => _BimbinganTabState();
}

class _BimbinganTabState extends State<BimbinganTab> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_load);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _items.isEmpty) setState(() => _loading = true);
    final data = await _api.getBimbingan();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = _api.lastError ?? 'Gagal memuat daftar PPDS bimbingan.';
      } else {
        _error = null;
        _items = data.whereType<Map<String, dynamic>>().toList();
      }
    });
  }

  Future<void> _open(Map<String, dynamic> ppds) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BimbinganDetailScreen(ppds: ppds)));
    if (!mounted) return;
    _load();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final nim = (p['nim'] ?? '').toString().toLowerCase();
      return name.contains(q) || nim.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return RefreshableState(onRefresh: _load, child: ErrorState(message: _error!, onRetry: _load));
    }
    if (_items.isEmpty) {
      return RefreshableState(
        onRefresh: _load,
        child: const EmptyState(
          icon: Icons.groups_outlined,
          title: 'Belum ada PPDS bimbingan',
          message: 'PPDS bimbingan ditetapkan oleh admin (sebagai Dosen Wali, Pembimbing 1/2, atau '
              'Pembimbing Retrospektif). Hubungi admin bila ada PPDS yang seharusnya Anda bimbing.',
        ),
      );
    }
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('${_items.length} PPDS bimbingan'),
              if (_items.length > 4) ...[
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau NIM',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
              ],
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Tidak ada PPDS yang cocok dengan pencarian.', textAlign: TextAlign.center, style: kBody),
                ),
              ...items.map(_card),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final peran = (p['peran_saya'] as List?)?.whereType<Map>().toList() ?? const [];
    final kalung = p['progres_kalung'] is Map ? p['progres_kalung'] as Map : const {};
    final komp = kalung['kompetensi_tahap_ini'] is Map ? kalung['kompetensi_tahap_ini'] as Map : const {};
    final kompTotal = asInt(komp['total']) ?? 0;
    final kompDone = asInt(komp['selesai']) ?? 0;
    final syarat = (kalung['syarat'] as List?)?.whereType<Map>().toList() ?? const [];
    final nextLabel = textOrNull(kalung['next_label']);
    final peringatan = textOrNull(kalung['peringatan_otomatis']);
    final sp = p['warning_active'] == true;

    final penilaian = (p['penilaian_saya'] as List?)?.whereType<Map>().toList() ?? [];
    penilaian.sort((a, b) {
      final s = (asInt(b['semester']) ?? 0).compareTo(asInt(a['semester']) ?? 0);
      if (s != 0) return s;
      final da = parseDate(a['updated_at'] ?? a['created_at']);
      final db = parseDate(b['updated_at'] ?? b['created_at']);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    final latest = penilaian.isNotEmpty ? penilaian.first : null;
    final latestNilai = latest == null ? null : asDouble(latest['nilai']);

    final meta = <String>[
      if (textOrNull(p['nim']) != null) 'NIM ${p['nim']}',
      if (textOrNull(p['angkatan']) != null) 'Angkatan ${p['angkatan']}',
      if (asInt(p['current_semester']) != null) 'Semester ${p['current_semester']}',
    ];

    return AppCard(
      onTap: () => _open(p),
      borderColor: sp || peringatan != null ? AppColors.errorRed.withValues(alpha: 0.4) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: phaseColor(p['phase']?.toString()).withValues(alpha: 0.15),
            child: Text(
              _initial(p['full_name']),
              style: TextStyle(fontWeight: FontWeight.w700, color: phaseColor(p['phase']?.toString())),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['full_name']?.toString() ?? '-', style: kCardTitle),
              if (meta.isNotEmpty) Text(meta.join(' · '), style: kCaption),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PhaseBadge(p['phase']?.toString()),
                for (final r in peran)
                  SmallTag(r['label']?.toString() ?? peranPembimbingLabel[r['peran']] ?? '-',
                      icon: Icons.badge_outlined),
                if (sp) const SmallTag('SP aktif', color: AppColors.errorRed, icon: Icons.warning_amber),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ]),
        const SizedBox(height: 8),
        ProgressRow(
          label: 'Kompetensi ${phaseLabel(kalung['phase']?.toString() ?? p['phase']?.toString())}',
          done: kompDone,
          total: kompTotal,
          color: phaseColor(kalung['phase']?.toString() ?? p['phase']?.toString()),
        ),
        if (nextLabel != null && syarat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Menuju $nextLabel:', style: kCaption),
              for (final s in syarat)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s['selesai'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 15, color: s['selesai'] == true ? AppColors.successGreen : AppColors.neutralGrey),
                  const SizedBox(width: 4),
                  Text(s['label']?.toString() ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                ]),
            ]),
          ),
        if (peringatan != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber, size: 16, color: AppColors.errorRed),
              const SizedBox(width: 6),
              Expanded(child: Text(peringatan, style: const TextStyle(fontSize: 13, color: AppColors.errorRed))),
            ]),
          ),
        const Divider(height: 20),
        if (latest != null && latestNilai != null)
          Row(children: [
            NilaiBadge(latestNilai, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Penilaian terakhir Anda: ${nilaiLabel(latestNilai)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: nilaiColor(latestNilai))),
                Text(
                  'Semester ${latest['semester'] ?? '-'} · '
                  '${latest['peran_label'] ?? peranPembimbingLabel[latest['peran']] ?? '-'}',
                  style: kCaption,
                ),
              ]),
            ),
          ])
        else
          const Row(children: [
            Icon(Icons.grade_outlined, size: 18, color: AppColors.textGrey),
            SizedBox(width: 8),
            Expanded(child: Text('Belum ada penilaian dari Anda. Ketuk untuk memberi nilai.', style: kCaption)),
          ]),
      ]),
    );
  }

  String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }
}
