import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/screens/admin/ppds_detail_screen.dart';
import 'package:fp_pemrograman/screens/admin/user_forms.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Admin: daftar PPDS dan penilai, pencarian, dan tambah akun.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

const _peranKeys = ['dosen_wali', 'pembimbing_1', 'pembimbing_2', 'pembimbing_retrospektif'];

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _users;
  bool _loading = true;
  String? _error;
  String _segment = 'ppds';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _users == null;
      _error = null;
    });
    final data = await _api.adminGetUsers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = _api.lastError ?? 'Gagal memuat daftar pengguna.';
      } else {
        _users = [for (final u in data) Map<String, dynamic>.from(u as Map)]
          ..sort((a, b) => textOf(a['full_name']).toLowerCase().compareTo(textOf(b['full_name']).toLowerCase()));
      }
    });
    if (data == null && _users != null && mounted) showSnack(context, _error!, error: true);
  }

  List<Map<String, dynamic>> _byRole(String role) =>
      (_users ?? const []).where((u) => (u['role'] ?? 'ppds') == role).toList();

  bool _matches(Map<String, dynamic> u) {
    if (_query.isEmpty) return true;
    final hay = '${textOf(u['full_name'])} ${textOf(u['nim'])} ${textOf(u['email'])}'.toLowerCase();
    return hay.contains(_query);
  }

  int _assignedCount(int penilaiId) =>
      _byRole('ppds').where((p) => _peranKeys.any((k) => p['${k}_id'] == penilaiId)).length;

  Future<void> _add() async {
    final created = await showAddUserMenu(context);
    if (created && mounted) _load();
  }

  Future<void> _openPpds(Map<String, dynamic> u) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PpdsDetailScreen(user: u)));
    if (mounted) _load();
  }

  Future<void> _deletePenilai(Map<String, dynamic> u) async {
    final n = _assignedCount(u['id'] as int);
    final ok = await confirmDialog(
      context,
      title: 'Hapus penilai?',
      message: 'Akun ${textOf(u['full_name'])} akan dihapus permanen dan tidak dapat dikembalikan.'
          '${n > 0 ? ' Penugasannya sebagai dosen wali / pembimbing untuk $n PPDS akan dilepas.' : ''}'
          ' Penilaian yang sudah diberikan tetap tersimpan.',
      confirmText: 'Hapus permanen',
      danger: true,
    );
    if (!ok || !mounted) return;
    final deleted = await _api.deleteUser(u['id'] as int);
    if (!mounted) return;
    if (deleted) {
      showSnack(context, 'Penilai ${textOf(u['full_name'])} dihapus');
      _load();
    } else {
      showSnack(context, 'Gagal menghapus penilai. Coba lagi.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-users-add',
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const LoadingView()
          : _users == null
              ? ErrorState(message: _error ?? 'Gagal memuat daftar pengguna.', onRetry: _load)
              : Column(children: [
                  _buildToolbar(),
                  Expanded(child: _buildList()),
                ]),
    );
  }

  Widget _buildToolbar() {
    final ppds = _byRole('ppds').length;
    final penilai = _byRole('penilai').length;
    return Container(
      color: Colors.white,
      child: MaxWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ppds', label: Text('PPDS ($ppds)'), icon: const Icon(Icons.school_outlined)),
                ButtonSegment(
                    value: 'penilai', label: Text('Penilai ($penilai)'), icon: const Icon(Icons.rate_review_outlined)),
              ],
              selected: {_segment},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _segment = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: _segment == 'ppds' ? 'Cari nama, NIM, atau email' : 'Cari nama atau email',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildList() {
    final all = _byRole(_segment);
    final list = all.where(_matches).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: AdminListView(
        bottom: 96,
        children: [
          if (list.isEmpty)
            EmptyState(
              icon: _segment == 'ppds' ? Icons.school_outlined : Icons.rate_review_outlined,
              title: all.isEmpty
                  ? (_segment == 'ppds' ? 'Belum ada PPDS terdaftar' : 'Belum ada akun penilai')
                  : 'Tidak ada yang cocok dengan "$_query"',
              message: all.isEmpty ? 'Gunakan tombol Tambah untuk membuat akun.' : null,
            )
          else
            for (final u in list)
              _segment == 'ppds'
                  ? _PpdsCard(user: u, onTap: () => _openPpds(u))
                  : _PenilaiCard(
                      user: u,
                      assigned: _assignedCount(u['id'] as int),
                      onDelete: () => _deletePenilai(u),
                    ),
        ],
      ),
    );
  }
}

class _PpdsCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _PpdsCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final phase = user['phase'] as String?;
    final meta = [
      'NIM ${textOf(user['nim']).isEmpty ? '-' : textOf(user['nim'])}',
      'Semester ${user['current_semester'] ?? '-'}',
      if (textOf(user['angkatan']).isNotEmpty) 'Angkatan ${textOf(user['angkatan'])}',
    ];
    final pembimbing = [
      for (final k in _peranKeys)
        if (textOf(user[k]).isNotEmpty) '${peranPembimbingLabel[k]}: ${textOf(user[k])}',
    ];
    return AppCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PersonAvatar(name: user['full_name'] as String?, color: phaseColor(phase)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(textOf(user['full_name']),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(meta.join(' · '), style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              PhaseBadge(phase),
              if (user['warning_active'] == true)
                const TagChip('SP aktif', color: AppColors.errorRed, icon: Icons.warning_amber),
            ]),
            const SizedBox(height: 6),
            if (pembimbing.isEmpty)
              const Text('Pembimbing belum ditentukan',
                  style: TextStyle(fontSize: 12, color: AppColors.warningOrange, fontWeight: FontWeight.w600))
            else
              Text(pembimbing.join('\n'), style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textGrey),
      ]),
    );
  }
}

class _PenilaiCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int assigned;
  final VoidCallback onDelete;
  const _PenilaiCard({required this.user, required this.assigned, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [
        PersonAvatar(name: user['full_name'] as String?, color: AppColors.infoBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(textOf(user['full_name']),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(textOf(user['email']), style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 6),
            TagChip(
              assigned == 0 ? 'Belum membimbing PPDS' : 'Membimbing $assigned PPDS',
              color: assigned == 0 ? AppColors.neutralGrey : AppColors.infoBlue,
              icon: Icons.groups_outlined,
            ),
          ]),
        ),
        IconButton(
          tooltip: 'Hapus penilai',
          icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}
