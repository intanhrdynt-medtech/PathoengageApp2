import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/academic_screen.dart';
import 'package:fp_pemrograman/screens/exams_screen.dart';
import 'package:fp_pemrograman/screens/logbook_screen.dart';
import 'package:fp_pemrograman/screens/penilaian_saya_screen.dart';
import 'package:fp_pemrograman/screens/ppds/beranda_tab.dart';
import 'package:fp_pemrograman/screens/profile_screen.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Kerangka aplikasi PPDS: AppBar (notifikasi + menu akun) dan navigasi
/// Beranda, Logbook, Ujian, Akademik, Profil. Bottom navigation di ponsel,
/// NavigationRail di layar lebar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _wideBreakpoint = 800;
  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Beranda'),
    _NavItem(Icons.book_outlined, Icons.book, 'Logbook'),
    _NavItem(Icons.school_outlined, Icons.school, 'Ujian'),
    _NavItem(Icons.article_outlined, Icons.article, 'Akademik'),
    _NavItem(Icons.person_outline, Icons.person, 'Profil'),
  ];

  int _index = PpdsTab.beranda;
  final GlobalKey<BerandaTabState> _berandaKey = GlobalKey<BerandaTabState>();
  final GlobalKey<NotificationBellState> _bellKey = GlobalKey<NotificationBellState>();

  void _select(int i) {
    if (i == _index) {
      if (i == PpdsTab.beranda) _berandaKey.currentState?.reload(silent: true);
      return;
    }
    setState(() => _index = i);
    // Kembali ke Beranda: muat ulang supaya progres & daftar tindakan terbaru.
    if (i == PpdsTab.beranda) _berandaKey.currentState?.reload(silent: true);
    _bellKey.currentState?.refresh();
  }

  Future<void> _onAccountMenu(String value) async {
    switch (value) {
      case 'profil':
        _select(PpdsTab.profil);
        break;
      case 'nilai':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PenilaianSayaScreen()));
        if (!mounted) return;
        if (_index == PpdsTab.beranda) _berandaKey.currentState?.reload(silent: true);
        break;
      case 'keluar':
        await logoutWithConfirm(context);
        break;
    }
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: _index != PpdsTab.beranda
          ? Text(_tabTitle(_index), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
          : Row(
              children: [
                Image.asset('assets/images/logounair.png',
                    height: 32, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const SizedBox(width: 10),
                const Text('PathoEngage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
      actions: [
        NotificationBell(
          key: _bellKey,
          onChanged: () {
            if (_index == PpdsTab.beranda) _berandaKey.currentState?.reload(silent: true);
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'Akun',
          onSelected: _onAccountMenu,
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'profil',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline),
                title: Text('Profil saya', style: TextStyle(fontSize: 14)),
              ),
            ),
            PopupMenuItem(
              value: 'nilai',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.grade_outlined),
                title: Text('Nilai Saya', style: TextStyle(fontSize: 14)),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'keluar',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: AppColors.errorRed),
                title: Text('Keluar', style: TextStyle(fontSize: 14, color: AppColors.errorRed)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _tabTitle(int i) {
    switch (i) {
      case PpdsTab.logbook:
        return 'Logbook Kompetensi';
      case PpdsTab.ujian:
        return 'Ujian';
      case PpdsTab.akademik:
        return 'Tugas Akademik';
      case PpdsTab.profil:
        return 'Profil Saya';
      default:
        return 'PathoEngage';
    }
  }

  Widget _otherTab(int i) {
    switch (i) {
      case PpdsTab.logbook:
        return const LogbookScreen();
      case PpdsTab.ujian:
        return const ExamsScreen();
      case PpdsTab.akademik:
        return const AcademicScreen();
      case PpdsTab.profil:
        return const ProfileScreen(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _content() {
    // Beranda tetap hidup (Offstage) supaya tidak memuat ulang dari nol setiap
    // pindah tab; tab lain dibuat ulang setiap dibuka agar datanya selalu baru.
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: _index != PpdsTab.beranda,
          child: TickerMode(
            enabled: _index == PpdsTab.beranda,
            child: BerandaTab(
              key: _berandaKey,
              onOpenTab: _select,
              onReloaded: () => _bellKey.currentState?.refresh(),
            ),
          ),
        ),
        if (_index != PpdsTab.beranda) _otherTab(_index),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > _wideBreakpoint;

    return PopScope(
      canPop: _index == PpdsTab.beranda,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(PpdsTab.beranda);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLightest,
        appBar: _appBar(),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    indicatorColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                    destinations: [
                      for (final it in _items)
                        NavigationRailDestination(
                          icon: Icon(it.icon),
                          selectedIcon: Icon(it.selectedIcon),
                          label: Text(it.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: _content()),
                ],
              )
            : _content(),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final it in _items)
                    NavigationDestination(icon: Icon(it.icon), selectedIcon: Icon(it.selectedIcon), label: it.label),
                ],
              ),
      ),
    );
  }
}
