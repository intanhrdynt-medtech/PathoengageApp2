import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = await _auth.getCurrentUser();
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar?', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
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
      case 'mkdu': return 'MKDU';
      case 'red': return 'Tahap Merah';
      case 'yellow': return 'Tahap Kuning';
      case 'green': return 'Tahap Hijau';
      default: return 'Tidak Diketahui';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Gagal memuat data profil'))
              : ResponsiveWrapper(
                  child: SingleChildScrollView(
                    child: Column(
                    children: [
                      // Header gradient card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryPurple, AppColors.darkMagenta],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: AppColors.accentRed,
                                child: Text(
                                  (_user?['full_name'] ?? 'P').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(_user?['full_name'] ?? '-',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(_user?['email'] ?? '-',
                                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 12),
                            // Phase badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getPhaseColor(_user?['phase']),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_hospital, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(_getPhaseLabel(_user?['phase']),
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Info Cards
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildInfoCard([
                                _buildInfoRow(Icons.badge_outlined, 'NIM', _user?['nim'] ?? '-'),
                                _buildInfoRow(Icons.school_outlined, 'Semester', '${_user?['current_semester'] ?? '-'}'),
                                _buildInfoRow(Icons.email_outlined, 'Email', _user?['email'] ?? '-'),
                              ]),
                              const SizedBox(height: 12),
                              _buildInfoCard([
                                _buildInfoRow(Icons.info_outline, 'Status',
                                    'PPDS Patologi Anatomi - UNAIR'),
                                _buildInfoRow(Icons.location_city_outlined, 'Institusi',
                                    'Universitas Airlangga'),
                              ]),
                              const SizedBox(height: 12),

                              // ── Dosen Wali & Pembimbing Card ──
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.people_alt_outlined, color: AppColors.primaryPurple, size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Pembimbing & Pengajar',
                                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryPurple)),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    _buildInfoRow(Icons.person_outline, 'Dosen Wali',
                                        _user?['dosen_wali'] ?? '-'),
                                    _buildInfoRow(Icons.school_outlined, 'Pembimbing 1',
                                        _user?['pembimbing_1'] ?? '-'),
                                    _buildInfoRow(Icons.school_outlined, 'Pembimbing 2',
                                        _user?['pembimbing_2'] ?? '-'),
                                    _buildInfoRow(Icons.history_edu_outlined, 'Pemb. Retrospektif',
                                        _user?['pembimbing_retrospektif'] ?? '-'),
                                  ],
                                ),
                              ),

                              // ── SP/Warning Badge (jika aktif) ──
                              if (_user?['warning_active'] == true) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Status Peringatan Aktif',
                                                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                            const SizedBox(height: 2),
                                            Text(_user?['warning_message'] ?? 'Anda sedang dalam status SP. Hubungi koordinator.',
                                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.red.shade700)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Logout Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _logout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 4,
                                  ),
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Logout',
                                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: rows),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textGrey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
