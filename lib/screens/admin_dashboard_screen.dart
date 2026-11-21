import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin_survey_screen.dart';
import 'package:fp_pemrograman/screens/admin_users_screen.dart';
import 'package:fp_pemrograman/screens/admin_verification_screen.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Kerangka halaman admin: Verifikasi, Pengguna, Survey.
/// NavigationBar di ponsel, NavigationRail di layar lebar.
class AdminDashboardScreen extends StatefulWidget {
  // ignore: use_super_parameters
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _NavDest {
  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  const _NavDest(this.label, this.title, this.icon, this.selectedIcon);
}

const _destinations = [
  _NavDest('Verifikasi', 'Verifikasi Pengajuan', Icons.fact_check_outlined, Icons.fact_check),
  _NavDest('Pengguna', 'Pengguna', Icons.people_outline, Icons.people),
  _NavDest('Survey', 'Survey Semester', Icons.assignment_outlined, Icons.assignment),
];

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _verificationKey = GlobalKey<AdminVerificationScreenState>();
  int _index = 0;
  int _pending = 0;

  late final List<Widget> _pages = [
    AdminVerificationScreen(
      key: _verificationKey,
      onCountChanged: (n) {
        if (mounted && n != _pending) setState(() => _pending = n);
      },
    ),
    AdminUsersScreen(key: ValueKey('users-$_usersVersion')),
    const AdminSurveyScreen(),
  ];

  // Dinaikkan setiap tab Pengguna dibuka supaya datanya dimuat ulang (mis.
  // setelah verifikasi menaikkan kalung PPDS).
  int _usersVersion = 0;

  void _select(int i) {
    setState(() {
      if (i == 1 && _index != 1) {
        _usersVersion++;
        _pages[1] = AdminUsersScreen(key: ValueKey('users-$_usersVersion'));
      }
      _index = i;
    });
  }

  Widget _icon(int i, {required bool selected}) {
    final d = _destinations[i];
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (i != 0 || _pending == 0) return icon;
    return Badge(label: Text(_pending > 99 ? '99+' : '$_pending'), child: icon);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(index: _index, children: _pages);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 24 : null,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Admin PathoEngage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          Text(_destinations[_index].title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          NotificationBell(onChanged: () => _verificationKey.currentState?.reload()),
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
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primaryPurple.withValues(alpha: 0.15),
                selectedIconTheme: const IconThemeData(color: AppColors.primaryPurple),
                selectedLabelTextStyle: const TextStyle(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelTextStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                destinations: [
                  for (int i = 0; i < _destinations.length; i++)
                    NavigationRailDestination(
                      icon: _icon(i, selected: false),
                      selectedIcon: _icon(i, selected: true),
                      label: Text(_destinations[i].label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1, color: AppColors.cardBorder),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (int i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: _icon(i, selected: false),
                    selectedIcon: _icon(i, selected: true),
                    label: _destinations[i].label,
                  ),
              ],
            ),
    );
  }
}
