import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';

class RotationsScreen extends StatefulWidget {
  const RotationsScreen({super.key});
  @override
  State<RotationsScreen> createState() => _RotationsScreenState();
}

class _RotationsScreenState extends State<RotationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _rotations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRotations();
  }

  void _loadRotations() async {
    final data = await _api.getRotations();
    setState(() {
      _rotations = data;
      _isLoading = false;
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'selesai': return AppColors.successGreen;
      case 'aktif': return const Color(0xFF2980B9);
      case 'terjadwal': return AppColors.warningOrange;
      default: return AppColors.textGrey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'selesai': return 'Selesai';
      case 'aktif': return 'Sedang Berjalan';
      case 'terjadwal': return 'Terjadwal';
      default: return 'Tidak Diketahui';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Stase / Rotasi Luar', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: _rotations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_hospital_outlined, size: 72, color: AppColors.textGrey.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text('Belum ada data stase luar',
                              style: TextStyle(fontFamily: 'Poppins', color: AppColors.textGrey, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rotations.length,
                      itemBuilder: (ctx, i) => _buildRotationCard(_rotations[i]),
                    ),
            ),
    );
  }

  Widget _buildRotationCard(Map<String, dynamic> rotation) {
    final statusColor = _getStatusColor(rotation['status']);
    final startDate = _formatDate(rotation['start_date']);
    final endDate = _formatDate(rotation['end_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_hospital, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rotation['hospital_name'] ?? 'RS Tidak Diketahui',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textDark)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(_getStatusLabel(rotation['status']),
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Body info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (rotation['department'] != null)
                  _buildInfoRow(Icons.medical_services_outlined, 'Departemen', rotation['department']),
                _buildInfoRow(Icons.location_city_outlined, 'Kota', rotation['city'] ?? '-'),
                _buildInfoRow(Icons.date_range, 'Mulai', startDate),
                _buildInfoRow(Icons.event_available, 'Selesai', endDate),
                if (rotation['supervisor'] != null)
                  _buildInfoRow(Icons.person_outline, 'Supervisor', rotation['supervisor']),
                if (rotation['notes'] != null && rotation['notes'].isNotEmpty)
                  _buildInfoRow(Icons.notes, 'Catatan', rotation['notes']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('$label:', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
