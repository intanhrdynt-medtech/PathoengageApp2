import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PrestasiScreen extends StatefulWidget {
  const PrestasiScreen({Key? key}) : super(key: key);
  @override
  State<PrestasiScreen> createState() => _PrestasiScreenState();
}

class _PrestasiScreenState extends State<PrestasiScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _api.getPrestasi();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka link: $url')),
        );
      }
    }
  }

  void _showAddDialog() {
    final namaCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    DateTime? selectedDate;
    String selectedTingkat = 'Lokal';
    String selectedJuara = 'Juara 1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Prestasi',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(namaCtrl, 'Nama Perlombaan/Kegiatan', Icons.emoji_events),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedTingkat,
                  decoration: InputDecoration(
                    labelText: 'Tingkat',
                    prefixIcon: const Icon(Icons.public, color: AppColors.primaryPurple),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: ['Lokal', 'Nasional', 'Internasional'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedTingkat = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedJuara,
                  decoration: InputDecoration(
                    labelText: 'Pencapaian/Juara',
                    prefixIcon: const Icon(Icons.star, color: AppColors.primaryPurple),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: ['Juara 1', 'Juara 2', 'Juara 3', 'Harapan', 'Lainnya'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedJuara = v!),
                ),
                const SizedBox(height: 10),
                _buildTextField(urlCtrl, 'Link Bukti (Sertifikat)', Icons.link),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range, color: AppColors.primaryPurple),
                  title: Text(selectedDate == null ? 'Pilih Waktu Pelaksanaan' : selectedDate.toString().split(' ')[0]),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              onPressed: () async {
                if (namaCtrl.text.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mohon isi nama perlombaan dan tanggal!')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final success = await _api.addPrestasi({
                  'nama_lomba': namaCtrl.text,
                  'waktu_pelaksanaan': selectedDate!.toIso8601String(),
                  'tingkat': selectedTingkat,
                  'juara_ke': selectedJuara,
                  'sertifikat_url': urlCtrl.text,
                });
                if (success) {
                  _loadData();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal menambahkan prestasi')),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestasi', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nama_lomba'] ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(item['waktu_pelaksanaan']?.toString().split('T')[0] ?? ''),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(item['tingkat'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(item['juara_ke'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.orange, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (item['sertifikat_url'] != null && item['sertifikat_url'].toString().isNotEmpty) ...[
                                const Divider(height: 24),
                                TextButton.icon(
                                  onPressed: () => _openUrl(item['sertifikat_url']),
                                  icon: const Icon(Icons.military_tech),
                                  label: const Text('Lihat Sertifikat'),
                                )
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat prestasi.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Prestasi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }
}
