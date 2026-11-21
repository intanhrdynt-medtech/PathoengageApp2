import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilaian_saya_screen.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Profil pengguna: identitas, pembimbing & dosen wali, status SP, Nilai Saya,
/// 3 pilar regulasi, dan tombol keluar.
///
/// [embedded] = true bila ditampilkan sebagai tab di dalam DashboardScreen
/// (AppBar disediakan oleh shell), false bila dibuka sebagai halaman sendiri.
class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _api.getMe();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = me;
      _error = me == null ? (_api.lastError ?? 'Gagal memuat profil. Periksa koneksi internet.') : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(onRefresh: _load, child: _body());
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell(), SizedBox(width: 4)],
      ),
      body: body,
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: ErrorState(
              message: _error!,
              onRetry: () {
                setState(() => _loading = true);
                _load();
              },
            ),
          ),
        ),
      );
    }
    final u = _user!;
    final isPpds = (u['role'] ?? 'ppds') == 'ppds';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        MaxWidth(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(u),
              const SizedBox(height: 12),
              const SectionTitle('Identitas'),
              _identityCard(u, isPpds),
              if (isPpds) ...[
                const SectionTitle('Pembimbing & Dosen Wali'),
                _pembimbingCard(u),
                const SectionTitle('Status Surat Peringatan (SP)'),
                _spCard(u),
                const SectionTitle('Penilaian'),
                AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PenilaianSayaScreen())),
                  child: const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(Icons.grade_outlined, color: AppColors.primaryPurple),
                    title: Text('Nilai Saya', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text('Nilai dari dosen wali & pembimbing per semester', style: TextStyle(fontSize: 13)),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),
                const _PilarRegulasiCard(),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => logoutWithConfirm(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _str(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty || s == '-' ? '' : s;
  }

  Widget _header(Map<String, dynamic> u) {
    final name = _str(u['full_name']);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.darkMagenta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? '-' : name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_str(u['email']).isNotEmpty)
                  Text(_str(u['email']), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                if ((u['role'] ?? 'ppds') == 'ppds')
                  PhaseBadge(u['phase']?.toString(), onDark: true)
                else
                  Text(roleLabel(u['role']?.toString()),
                      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(Map<String, dynamic> u, bool isPpds) {
    return AppCard(
      child: Column(children: [
        _row(Icons.person_outline, 'Nama', _str(u['full_name'])),
        if (isPpds) ...[
          _row(Icons.badge_outlined, 'NIM', _str(u['nim'])),
          _row(Icons.groups_outlined, 'Angkatan', _str(u['angkatan'])),
          _row(Icons.school_outlined, 'Semester', _str(u['current_semester'])),
          _rowWidget(Icons.military_tech_outlined, 'Kalung', PhaseBadge(u['phase']?.toString())),
        ] else
          _row(Icons.work_outline, 'Peran', roleLabel(u['role']?.toString())),
        _row(Icons.email_outlined, 'Email', _str(u['email'])),
      ]),
    );
  }

  Widget _pembimbingCard(Map<String, dynamic> u) {
    return AppCard(
      child: Column(children: [
        for (final e in peranPembimbingLabel.entries)
          _row(e.key == 'dosen_wali' ? Icons.person_pin_outlined : Icons.school_outlined, e.value, _str(u[e.key]),
              emptyText: 'Belum ditentukan'),
      ]),
    );
  }

  Widget _spCard(Map<String, dynamic> u) {
    if (u['warning_active'] == true) {
      final msg = _str(u['warning_message']);
      return AppCard(
        borderColor: AppColors.errorRed.withValues(alpha: 0.4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.gpp_maybe_outlined, color: AppColors.errorRed),
            SizedBox(width: 8),
            Expanded(
              child: Text('Surat Peringatan (SP) aktif',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
            ),
          ]),
          NoteBox(
            title: 'Keterangan',
            text: msg.isEmpty ? 'Anda sedang menerima Surat Peringatan. Segera hubungi koordinator program studi.' : msg,
            color: AppColors.errorRed,
            icon: Icons.warning_amber_rounded,
          ),
        ]),
      );
    }
    return const AppCard(
      child: Row(children: [
        Icon(Icons.verified_user_outlined, color: AppColors.successGreen),
        SizedBox(width: 10),
        Expanded(
          child: Text('Tidak ada Surat Peringatan aktif.', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value, {String emptyText = '-'}) {
    final empty = value.isEmpty;
    return _rowWidget(
      icon,
      label,
      Text(empty ? emptyText : value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
            fontStyle: empty && emptyText != '-' ? FontStyle.italic : FontStyle.normal,
            color: empty ? AppColors.textGrey : AppColors.textDark,
          )),
    );
  }

  Widget _rowWidget(IconData icon, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
        ],
      ),
    );
  }
}

/// Info "3 Pilar Regulasi PPDS" (dapat dibuka-tutup).
class _PilarRegulasiCard extends StatelessWidget {
  const _PilarRegulasiCard();

  static const _pilar = [
    (Icons.business, AppColors.primaryPurple, 'Pilar Internal Prodi', 'Stase, logbook, ujian organ lokal'),
    (Icons.account_balance, AppColors.infoBlue, 'Pilar Kolegium PA', 'Ujian Nasional Tahap 1 & Board Sp.PA'),
    (Icons.school, AppColors.successGreen, 'Pilar UNAIR', 'Administrasi, MKDU, publikasi Scopus'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Icons.account_tree_outlined, color: AppColors.primaryPurple),
          title: const Text('3 Pilar Regulasi PPDS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Aturan yang mengatur pendidikan Anda', style: TextStyle(fontSize: 12)),
          children: [
            for (final p in _pilar)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: p.$2.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(p.$1, color: p.$2, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.$3, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(p.$4, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
