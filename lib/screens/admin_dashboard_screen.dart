import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/screens/admin_verification_screen.dart';
import 'package:fp_pemrograman/screens/admin_users_screen.dart';
import 'package:fp_pemrograman/service/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _auth = AuthService();
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminVerificationScreen(),
    const AdminUsersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkPendingVerifications();
  }

  bool _notifShown = false;

  Future<void> _checkPendingVerifications() async {
    if (_notifShown) return;
    final api = ApiService();

    // Fetch semua pending secara paralel
    final results = await Future.wait([
      api.getPendingVerifications(),
      api.getAdminJournalReadings('pending'),
      api.getAllPenelitian(''),
    ]);

    final pendingVerif = results[0] as List;
    final pendingJournals = results[1] as List;
    final pendingPenelitian = (results[2] as List)
        .where((p) => p['status'] == 'submitted')
        .toList();

    final totalPending = pendingVerif.length + pendingJournals.length + pendingPenelitian.length;

    if (totalPending > 0 && mounted && !_notifShown) {
      _notifShown = true;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active, color: AppColors.accentRed, size: 36),
                ),
                const SizedBox(height: 14),
                const Text('Ada Pengajuan Baru!',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Terdapat $totalPending item yang menunggu tindakan Anda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                // Breakdown per kategori
                if (pendingVerif.isNotEmpty)
                  _notifRow(Icons.verified_outlined, 'Verifikasi Umum', pendingVerif.length, Colors.blue),
                if (pendingJournals.isNotEmpty)
                  _notifRow(Icons.article_outlined, 'Journal Reading', pendingJournals.length, Colors.orange),
                if (pendingPenelitian.isNotEmpty)
                  _notifRow(Icons.science_outlined, 'Penelitian', pendingPenelitian.length, Colors.purple),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Nanti', style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedIndex = 0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Lihat Sekarang', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _notifRow(IconData icon, String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: color, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.pending_actions),
      activeIcon: Icon(Icons.pending_actions),
      label: 'Verifikasi',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'Manajemen PPDS',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 0: return 'Verifikasi Pengajuan';
      case 1: return 'Manajemen PPDS';
      default: return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin PathoEngage',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              _pageTitle,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
