import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/ppds_modules/module_common.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Logbook kompetensi PPDS, dikelompokkan per kalung.
class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});
  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  final ModuleApi _api = ModuleApi();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  /// null = semua kalung.
  static const List<String?> _phases = [null, 'red', 'yellow', 'green'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.list('/competencies');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? _api.errorMessage : null;
      if (data != null) _items = data;
    });
  }

  List<dynamic> _filter(String? phase) =>
      phase == null ? _items : _items.where((c) => c['phase_category'] == phase).toList();

  bool _isDone(dynamic c) => c['status'] == 'completed';

  Future<void> _open(Map<String, dynamic> item) async {
    final status = str(item['status']);
    if (status == 'completed') {
      showSnack(context, 'Kompetensi ini sudah diverifikasi admin dan tidak bisa diubah lagi.');
      return;
    }
    final rejected = str(item['alasan_tolak']).isNotEmpty;
    final pending = status == 'pending_verification';
    final result = await showSubmitLinkDialog(
      context,
      title: pending
          ? 'Ubah link bukti'
          : rejected
              ? 'Kirim ulang bukti'
              : 'Kirim bukti kompetensi',
      description: pending
          ? '${str(item['competency_name'])}\n\nBukti sedang menunggu verifikasi admin. Anda masih bisa mengganti link-nya.'
          : rejected
              ? '${str(item['competency_name'])}\n\nPerbaiki bukti sesuai alasan penolakan, lalu kirim ulang.'
              : str(item['competency_name']),
      initialLink: str(item['evidence_url']),
      submitText: pending ? 'Simpan perubahan' : 'Kirim untuk diverifikasi',
    );
    if (result == null || !mounted) return;
    final ok = await _api.ok('PUT', '/competencies/${item['id']}',
        body: {'status': 'pending_verification', 'evidence_url': result['link']});
    if (!mounted) return;
    if (ok) {
      showSnack(context, pending ? 'Link bukti diperbarui.' : 'Bukti terkirim. Menunggu verifikasi admin.');
      _load();
    } else {
      showSnack(context, _api.errorMessage, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _phases.length,
      child: Scaffold(
        // Ditampilkan sebagai tab di dalam DashboardScreen yang sudah punya
        // AppBar (judul, notifikasi, akun) — di sini cukup baris tab-nya.
        appBar: AppBar(
          primary: false,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          bottom: moduleTabBar(_phases.map((p) => p == null ? 'Semua' : phaseLabel(p)).toList(), scrollable: true),
        ),
        body: TabBarView(children: _phases.map(_buildTab).toList()),
      ),
    );
  }

  Widget _buildTab(String? phase) {
    return moduleBody(
      loading: _loading,
      error: _error,
      onRefresh: _load,
      builder: () {
        final items = _filter(phase);
        final done = items.where(_isDone).length;
        final waiting = items.where((c) => c['status'] == 'pending_verification').length;
        final fix = items.where((c) => c['status'] != 'completed' && str(c['alasan_tolak']).isNotEmpty).length;
        final parts = <String>[
          if (waiting > 0) '$waiting menunggu verifikasi',
          if (fix > 0) '$fix perlu diperbaiki',
        ];
        return [
          ModuleProgressCard(
            title: phase == null ? 'Progres semua kompetensi' : 'Progres ${phaseLabel(phase)}',
            done: done,
            total: items.length,
            caption: parts.isEmpty ? 'Ketuk kompetensi untuk mengirim link bukti.' : parts.join(' · '),
          ),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Belum ada kompetensi',
              message: 'Kompetensi untuk kalung ini belum tersedia.',
            )
          else
            ...items.map((c) => _card(c as Map<String, dynamic>, showPhase: phase == null)),
        ];
      },
    );
  }

  Widget _card(Map<String, dynamic> c, {required bool showPhase}) {
    final status = str(c['status']);
    final alasan = str(c['alasan_tolak']);
    final done = status == 'completed';
    final pending = status == 'pending_verification';
    final color = phaseColor(c['phase_category']);

    String? actionLabel;
    IconData actionIcon = Icons.upload;
    if (pending) {
      actionLabel = 'Ubah link bukti';
      actionIcon = Icons.edit;
    } else if (!done && alasan.isNotEmpty) {
      actionLabel = 'Kirim ulang bukti';
      actionIcon = Icons.refresh;
    } else if (!done) {
      actionLabel = 'Kirim bukti';
    }

    return AppCard(
      onTap: () => _open(c),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 5,
          height: 44,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(c['competency_name']).isEmpty ? '-' : str(c['competency_name']), style: kCardTitle),
            if (str(c['organ_system']).isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(str(c['organ_system']), style: kCaption),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusChip(progressStatus(status, alasanTolak: alasan)),
              if (showPhase) PhaseBadge(c['phase_category']),
            ]),
            if (done && str(c['completed_at']).isNotEmpty)
              MetaRow(
                  icon: Icons.verified,
                  label: 'Diverifikasi',
                  value: formatTanggal(c['completed_at'], serverTimestamp: true)),
            if (alasan.isNotEmpty && !pending && !done)
              NoteBox(title: 'Alasan ditolak admin', text: alasan, color: AppColors.errorRed, icon: Icons.error_outline),
            if (str(c['evidence_url']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinkButton(label: 'Lihat bukti', url: str(c['evidence_url'])),
              ),
            if (actionLabel != null)
              CardActionButton(
                label: actionLabel,
                icon: actionIcon,
                outlined: pending,
                onPressed: () => _open(c),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Sudah selesai — tidak bisa diubah lagi.', style: kCaption),
              ),
          ]),
        ),
      ]),
    );
  }
}
