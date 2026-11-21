import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Stase / rotasi luar milik PPDS (diatur admin).
class RotationsScreen extends StatefulWidget {
  const RotationsScreen({super.key});
  @override
  State<RotationsScreen> createState() => _RotationsScreenState();
}

class _RotationsScreenState extends State<RotationsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>>? _rotations;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Menerima List maupun null (versi lama ApiService mengembalikan [] saat gagal).
  List<dynamic>? _asList(Object? v) => v is List ? v : null;

  Future<void> _load() async {
    final data = _asList(await _api.getRotations());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null;
      _rotations = data?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        ?..sort((a, b) => (b['start_date'] ?? '').toString().compareTo((a['start_date'] ?? '').toString()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stase / Rotasi Luar', style: TextStyle(fontWeight: FontWeight.bold)),
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
    if (_error) {
      return _scrollableCenter(ErrorState(
        message: _api.lastError ?? 'Gagal memuat data stase. Periksa koneksi internet.',
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      ));
    }
    final list = _rotations ?? [];
    if (list.isEmpty) {
      return _scrollableCenter(const EmptyState(
        icon: Icons.local_hospital_outlined,
        title: 'Belum ada jadwal stase',
        message: 'Jadwal stase / rotasi luar diatur oleh admin program studi dan akan tampil di sini.',
      ));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        MaxWidth(
          maxWidth: 760,
          child: Column(children: [for (final r in list) _RotationCard(r)]),
        ),
      ],
    );
  }
}

class _RotationCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RotationCard(this.r);

  String? _text(String key) {
    final v = (r[key] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final status = rotationStatus(r['status']?.toString());
    final start = formatTanggal(r['start_date']?.toString());
    final end = formatTanggal(r['end_date']?.toString());
    final supervisor = _text('supervisor');
    final department = _text('department');
    final city = _text('city');
    final notes = _text('notes');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_hospital, color: status.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_text('hospital_name') ?? 'Rumah sakit belum diisi',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    StatusChip(status),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (department != null) _row(Icons.medical_services_outlined, 'Departemen', department),
          _row(Icons.location_city_outlined, 'Kota', city ?? '-'),
          _row(Icons.date_range, 'Periode', '$start – $end'),
          _row(Icons.person_outline, 'Supervisor', supervisor ?? 'Belum ditentukan', muted: supervisor == null),
          if (notes != null) NoteBox(title: 'Catatan', text: notes),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  color: muted ? AppColors.textGrey : AppColors.textDark,
                )),
          ),
        ],
      ),
    );
  }
}
