import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/screens/logbook_screen.dart';
import 'package:fp_pemrograman/screens/exams_screen.dart';
import 'package:fp_pemrograman/screens/academic_screen.dart';
import 'package:fp_pemrograman/screens/rotations_screen.dart';
import 'package:fp_pemrograman/screens/profile_screen.dart';
import 'package:fp_pemrograman/screens/penelitian_screen.dart';
import 'package:fp_pemrograman/screens/pengabdian_screen.dart';
import 'package:fp_pemrograman/screens/prestasi_screen.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Statistik ringkasan
  int _totalCompetencies = 0;
  int _completedCompetencies = 0;
  int _totalExams = 0;
  int _passedExams = 0;
  int _pendingTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final user = await _auth.getCurrentUser();
    final competencies = await _api.getCompetencies();
    final exams = await _api.getExams();
    final tasks = await _api.getAcademicTasks();

    setState(() {
      userProfile = user;
      _totalCompetencies = competencies.length;
      _completedCompetencies = competencies.where((c) => c['status'] == 'completed').length;
      _totalExams = exams.length;
      _passedExams = exams.where((e) => e['result'] == 'lulus').length;
      _pendingTasks = tasks.where((t) => t['is_completed'] == false).length;
      _isLoading = false;
    });
  }

  Color _getPhaseColor(String? phase) {
    switch (phase?.toLowerCase()) {
      case 'red': return Colors.red.shade600;
      case 'yellow': return Colors.orange.shade600;
      case 'green': return Colors.green.shade600;
      default: return Colors.blueGrey;
    }
  }

  String _getPhaseLabel(String? phase) {
    switch (phase?.toLowerCase()) {
      case 'mkdu': return '🎓 MKDU';
      case 'red': return '🔴 Tahap Merah';
      case 'yellow': return '🟡 Tahap Kuning';
      case 'green': return '🟢 Tahap Hijau';
      default: return '❓ Tidak Diketahui';
    }
  }

  Widget _buildHomeContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (userProfile == null) return const Center(child: Text('Gagal memuat data'));

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting + profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.darkMagenta],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      (userProfile?['full_name'] ?? 'P').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat datang,',
                          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          userProfile?['full_name'] ?? '-',
                          style: const TextStyle(
                              fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Semester ${userProfile?['current_semester'] ?? '-'}  ·  ',
                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              _getPhaseLabel(userProfile?['phase']),
                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Survey Semester Reminder Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.orange.shade200)),
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.assignment, color: Colors.orange, size: 36),
                title: const Text('Survey Semester', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Jangan lupa isi survey evaluasi semester ini.', style: TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () {
                    // TODO: Ganti dengan URL survey yang sebenarnya
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link survey belum tersedia.')));
                  },
                  child: const Text('Isi Sekarang'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Kewenangan Medis Card
            _buildPrivilegeCard(userProfile?['phase']),

            const SizedBox(height: 24),

            // Statistik ringkasan
            const Text('Ringkasan', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Kompetensi', '$_completedCompetencies/$_totalCompetencies', Icons.book, AppColors.primaryPurple)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Ujian Lulus', '$_passedExams/$_totalExams', Icons.school, const Color(0xFF2980B9))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Tugas Pending', '$_pendingTasks', Icons.pending_actions, AppColors.accentRed)),
              ],
            ),

            const SizedBox(height: 24),

            // Menu utama
            const Text('Menu Utama', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.2,
                  children: [
                    _buildMenuCard(
                      icon: Icons.book,
                      title: 'Logbook\nKompetensi',
                      subtitle: '$_completedCompetencies dari $_totalCompetencies',
                      color: AppColors.primaryPurple,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    _buildMenuCard(
                      icon: Icons.school,
                      title: 'Ujian',
                      subtitle: '$_passedExams lulus',
                      color: const Color(0xFF2980B9),
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                    _buildMenuCard(
                      icon: Icons.article,
                      title: 'Tugas\nAkademik',
                      subtitle: '$_pendingTasks pending',
                      color: const Color(0xFF8E44AD),
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                    _buildMenuCard(
                      icon: Icons.local_hospital,
                      title: 'Stase\nLuar',
                      subtitle: 'Lihat jadwal',
                      color: const Color(0xFF16A085),
                      onTap: () => setState(() => _selectedIndex = 4),
                    ),
                  ],
                );
              }

                    _buildMenuCard(
                      icon: Icons.science,
                      title: 'Penelitian',
                      subtitle: 'Karya akhir',
                      color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PenelitianScreen())),
                    ),
                    _buildMenuCard(
                      icon: Icons.group,
                      title: 'Pengabdian',
                      subtitle: 'Masyarakat',
                      color: Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PengabdianScreen())),
                    ),
                    _buildMenuCard(
                      icon: Icons.star,
                      title: 'Prestasi',
                      subtitle: 'Penghargaan',
                      color: Colors.amber,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrestasiScreen())),
                    ),
            ),

            const SizedBox(height: 24),

            // Info pilar regulasi
            _buildPilarCard(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(title,
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivilegeCard(String? phase) {
    String status = '';
    String kewenangan = '';
    String transisi = '';
    IconData icon = Icons.info_outline;

    switch (phase?.toLowerCase()) {
      case 'mkdu':
        status = 'Observer / Mahasiswa Baru';
        kewenangan = 'Mengikuti perkuliahan umum bersama seluruh PPDS baru lintas departemen.';
        transisi = 'Menyelesaikan MKDU untuk masuk ke Tahap Kalung Merah.';
        icon = Icons.school;
        break;
      case 'red':
        status = 'Junior PPDS';
        kewenangan = 'Belum diperbolehkan melakukan tindakan medis apa pun secara mandiri tanpa pengawasan penuh. Fokus pada keilmuan dasar dan metodologi.';
        transisi = 'Lulus Ujian Organ I untuk naik ke level Kalung Kuning.';
        icon = Icons.local_hospital;
        break;
      case 'yellow':
        status = 'Intermediate PPDS';
        kewenangan = 'Boleh melakukan tindakan medis/pelayanan diagnostik di bawah pengawasan senior atau dokter spesialis penanggung jawab.';
        transisi = 'Lulus Ujian Organ II untuk naik ke level Kalung Hijau.';
        icon = Icons.medical_services;
        break;
      case 'green':
        status = 'Senior PPDS';
        kewenangan = 'Kompeten secara mandiri melakukan tindakan level SPPA (Spesialis Patologi Anatomi) tanpa pengawasan. Menjalani stase luar.';
        transisi = 'Persiapan Ujian Nasional Tahap 1, Tesis, dan Ujian Board/Sp.PA.';
        icon = Icons.verified;
        break;
      default:
        status = 'Status Belum Diketahui';
        kewenangan = 'Data kewenangan belum tersedia.';
        transisi = '-';
        break;
    }

    final color = _getPhaseColor(phase);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              const Text('Kewenangan Medis & Status',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrivilegeRow('Status', status),
          const SizedBox(height: 8),
          _buildPrivilegeRow('Kewenangan', kewenangan),
          const SizedBox(height: 8),
          _buildPrivilegeRow('Syarat Transisi', transisi),
        ],
      ),
    );
  }

  Widget _buildPrivilegeRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
        ),
        const Text(': ', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.black)),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildPilarCard() {
    final pilar = [
      {'icon': Icons.business, 'color': AppColors.primaryPurple, 'title': 'Pilar Internal Prodi', 'desc': 'Stase, logbook, ujian organ lokal'},
      {'icon': Icons.account_balance, 'color': const Color(0xFF2980B9), 'title': 'Pilar Kolegium PA', 'desc': 'Ujian Nasional Tahap 1 & Board Sp.PA'},
      {'icon': Icons.school, 'color': const Color(0xFF16A085), 'title': 'Pilar UNAIR', 'desc': 'Administrasi, MKDU, Publikasi Scopus'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('3 Pilar Regulasi PPDS',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ...pilar.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (p['color'] as Color).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(p['icon'] as IconData, color: p['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] as String,
                              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(p['desc'] as String,
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  final List<Widget> _screens = const [
    SizedBox(), // placeholder; home content rendered separately
    LogbookScreen(),
    ExamsScreen(),
    AcademicScreen(),
    RotationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: AppColors.primaryPurple,
              elevation: 0,
              title: Row(
                children: [
                  Image.asset('assets/images/logounair.png', height: 32, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 10),
                  const Text('PathoEngage',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: IconThemeData(color: AppColors.primaryPurple),
                  selectedLabelTextStyle: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Beranda')),
                    NavigationRailDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: Text('Logbook')),
                    NavigationRailDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: Text('Ujian')),
                    NavigationRailDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: Text('Akademik')),
                    NavigationRailDestination(icon: Icon(Icons.local_hospital_outlined), selectedIcon: Icon(Icons.local_hospital), label: Text('Stase')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _selectedIndex == 0 ? _buildHomeContent() : _screens[_selectedIndex]),
              ],
            );
          }
          return _selectedIndex == 0 ? _buildHomeContent() : _screens[_selectedIndex];
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 800
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: Colors.white,
              indicatorColor: AppColors.primaryPurple.withOpacity(0.15),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
                NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Logbook'),
                NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Ujian'),
                NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'Akademik'),
                NavigationDestination(icon: Icon(Icons.local_hospital_outlined), selectedIcon: Icon(Icons.local_hospital), label: 'Stase'),
              ],
            )
          : null,
    );
  }
}
