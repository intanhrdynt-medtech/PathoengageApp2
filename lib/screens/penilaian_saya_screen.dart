import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// "Nilai Saya": nilai yang diberikan dosen wali & pembimbing, per semester.
class PenilaianSayaScreen extends StatefulWidget {
  const PenilaianSayaScreen({super.key});

  @override
  State<PenilaianSayaScreen> createState() => _PenilaianSayaScreenState();
}

class _PenilaianSayaScreenState extends State<PenilaianSayaScreen> {
  final ApiService _api = ApiService();
  List<dynamic>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.getMyPenilaian();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = data;
      _error = data == null ? (_api.lastError ?? 'Gagal memuat nilai. Periksa koneksi internet.') : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nilai Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _scrollableCenter(Widget child) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: child),
        ),
      );

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return _scrollableCenter(ErrorState(
        message: _error!,
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      ));
    }
    final items = (_items ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (items.isEmpty) {
      return _scrollableCenter(const EmptyState(
        icon: Icons.grade_outlined,
        title: 'Belum ada nilai',
        message: 'Nilai diisi oleh dosen wali dan pembimbing Anda setiap semester. '
            'Nilai akan muncul di sini setelah mereka mengisinya.',
      ));
    }

    // Kelompokkan per semester (terbaru di atas; tanpa semester di akhir).
    final groups = <int?, List<Map<String, dynamic>>>{};
    for (final n in items) {
      final sem = (n['semester'] as num?)?.toInt();
      groups.putIfAbsent(sem, () => []).add(n);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        MaxWidth(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nilai dari dosen wali dan pembimbing (skala 0–100).',
                style: TextStyle(fontSize: 14, color: AppColors.textGrey),
              ),
              const SizedBox(height: 8),
              for (final sem in keys) ...[
                SectionTitle(
                  sem == null ? 'Tanpa semester' : 'Semester $sem',
                  trailing: _averageChip(groups[sem]!),
                ),
                for (final n in groups[sem]!) _PenilaianCard(n),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget? _averageChip(List<Map<String, dynamic>> list) {
    final values = list.map((n) => (n['nilai'] as num?)?.toDouble()).whereType<double>().toList();
    if (values.length < 2) return null;
    final avg = values.reduce((a, b) => a + b) / values.length;
    return Text('Rata-rata ${_formatNilai(avg)}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey));
  }
}

String _formatNilai(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

StatusInfo _kualitas(num? v) {
  if (v == null) return const StatusInfo('Belum dinilai', AppColors.neutralGrey, Icons.remove);
  if (v >= 85) return const StatusInfo('Sangat baik', AppColors.successGreen, Icons.star);
  if (v >= 70) return const StatusInfo('Baik', AppColors.infoBlue, Icons.thumb_up_alt_outlined);
  if (v >= 60) return const StatusInfo('Cukup', AppColors.warningOrange, Icons.trending_flat);
  return const StatusInfo('Perlu perbaikan', AppColors.errorRed, Icons.trending_down);
}

class _PenilaianCard extends StatelessWidget {
  final Map<String, dynamic> n;
  const _PenilaianCard(this.n);

  @override
  Widget build(BuildContext context) {
    final nilai = n['nilai'] as num?;
    final q = _kualitas(nilai);
    final peran = (n['peran_label'] ?? peranPembimbingLabel[n['peran']] ?? n['peran'] ?? '-').toString();
    final catatan = (n['catatan'] ?? '').toString().trim();
    final tanggal = n['updated_at'] ?? n['created_at'];

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurpleAccent.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(peran,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
                ),
                const SizedBox(height: 8),
                Text((n['penilai_nama'] ?? '-').toString(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('Diperbarui ${formatTanggal(tanggal?.toString(), serverTimestamp: true)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                if (catatan.isNotEmpty) NoteBox(title: 'Catatan', text: catatan, icon: Icons.chat_bubble_outline),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84),
            child: Column(
              children: [
                Text(nilai == null ? '-' : _formatNilai(nilai),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: q.color, height: 1.1)),
                const SizedBox(height: 4),
                StatusChip(q),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
