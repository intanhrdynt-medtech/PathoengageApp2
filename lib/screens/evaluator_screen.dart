import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/penilai/bimbingan_tab.dart';
import 'package:fp_pemrograman/screens/penilai/penilai_common.dart';
import 'package:fp_pemrograman/screens/penilai/review_tab.dart';
import 'package:fp_pemrograman/screens/penilai/ujian_organ_tab.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Layar utama untuk role penilai (dosen wali / pembimbing / penguji).
class EvaluatorScreen extends StatefulWidget {
  // ignore: use_super_parameters
  const EvaluatorScreen({Key? key}) : super(key: key);

  @override
  State<EvaluatorScreen> createState() => _EvaluatorScreenState();
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Dest(this.label, this.icon, this.selectedIcon);
}

const _destinations = [
  _Dest('Review', Icons.rate_review_outlined, Icons.rate_review),
  _Dest('Bimbingan', Icons.groups_outlined, Icons.groups),
  _Dest('Ujian Organ', Icons.assignment_outlined, Icons.assignment),
  _Dest('Profil', Icons.person_outline, Icons.person),
];

class _EvaluatorScreenState extends State<EvaluatorScreen> {
  final ApiService _api = ApiService();
  final ValueNotifier<int> _refreshSignal = ValueNotifier(0);

  int _index = 0;
  int? _reviewCount;
  Map<String, dynamic>? _me;
  bool _meLoading = true;
  String? _meError;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _refreshSignal.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    setState(() => _meLoading = true);
    final me = await _api.getMe();
    if (!mounted) return;
    setState(() {
      _meLoading = false;
      _me = me ?? _me;
      _meError = me == null ? (_api.lastError ?? 'Gagal memuat profil.') : null;
    });
  }

  void _refreshAll() {
    _refreshSignal.value++;
    _loadMe();
  }

  Widget _icon(int i, {required bool selected}) {
    final d = _destinations[i];
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    final count = _reviewCount ?? 0;
    if (i == 0 && count > 0) {
      return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
    }
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final name = textOrNull(_me?['full_name']);
    final pages = [
      ReviewTab(
        refreshSignal: _refreshSignal,
        onCountChanged: (n) {
          if (mounted && n != _reviewCount) setState(() => _reviewCount = n);
        },
      ),
      BimbinganTab(refreshSignal: _refreshSignal),
      UjianOrganTab(refreshSignal: _refreshSignal),
      _ProfilTab(me: _me, loading: _meLoading, error: _meError, onRetry: _loadMe),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final body = IndexedStack(index: _index, children: pages);
      return Scaffold(
        appBar: AppBar(
          titleSpacing: wide ? 24 : null,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PathoEngage — Penilai', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (name != null)
              Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70)),
          ]),
          actions: [
            NotificationBell(onChanged: _refreshAll),
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: () => logoutWithConfirm(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: wide
            ? Row(children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                  selectedIconTheme: const IconThemeData(color: AppColors.primaryPurple),
                  selectedLabelTextStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryPurple),
                  unselectedLabelTextStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  destinations: [
                    for (var i = 0; i < _destinations.length; i++)
                      NavigationRailDestination(
                        icon: _icon(i, selected: false),
                        selectedIcon: _icon(i, selected: true),
                        label: Text(_destinations[i].label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.cardBorder),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (var i = 0; i < _destinations.length; i++)
                    NavigationDestination(
                      icon: _icon(i, selected: false),
                      selectedIcon: _icon(i, selected: true),
                      label: _destinations[i].label,
                    ),
                ],
              ),
      );
    });
  }
}

// ── Profil ────────────────────────────────────────────────────────────────────

class _ProfilTab extends StatelessWidget {
  final Map<String, dynamic>? me;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  const _ProfilTab({required this.me, required this.loading, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      if (loading) return const LoadingView();
      return RefreshableState(
        onRefresh: onRetry,
        child: ErrorState(message: error ?? 'Gagal memuat profil.', onRetry: onRetry),
      );
    }
    final m = me!;
    final name = textOrNull(m['full_name']) ?? '-';
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            maxWidth: 600,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.lightPurpleAccent,
                    child: Text(name.isEmpty || name == '-' ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  SmallTag(roleLabel(m['role']?.toString()), icon: Icons.verified_user_outlined),
                ]),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppColors.primaryPurple),
                    title: const Text('Email', style: kCaption),
                    subtitle: Text(textOrNull(m['email']) ?? '-', style: kBody),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: AppColors.primaryPurple),
                    title: const Text('Peran', style: kCaption),
                    subtitle: Text(roleLabel(m['role']?.toString()), style: kBody),
                  ),
                ]),
              ),
              const NoteBox(
                title: 'Tentang penugasan',
                text: 'PPDS bimbingan (Dosen Wali / Pembimbing) dan ujian organ yang Anda uji ditetapkan oleh admin. '
                    'Hubungi admin bila ada penugasan yang belum sesuai.',
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: const BorderSide(color: AppColors.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => logoutWithConfirm(context),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari akun', style: TextStyle(fontSize: 14)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
