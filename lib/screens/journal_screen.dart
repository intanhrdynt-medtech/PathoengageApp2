import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _myJournals = [];
  List<dynamic> _allJournals = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final myJournals = await _api.getMyJournalReadings();
    final allJournals = await _api.getAllJournalReadings('');
    setState(() {
      _myJournals = myJournals;
      _allJournals = allJournals;
      _isLoading = false;
    });
  }

  void _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak bisa membuka link: ')),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return AppColors.textGrey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved': return 'Approved ✓';
      case 'pending': return 'Menunggu ACC';
      case 'rejected': return 'Ditolak';
      default: return 'Draft';
    }
  }

  void _showAddDialog() {
    final judulCtrl = TextEditingController();
    final penulisCtrl = TextEditingController();
    final jurnalCtrl = TextEditingController();
    final pembimbingCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajukan Topik Journal Reading',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: judulCtrl,
                    decoration: const InputDecoration(labelText: 'Judul Jurnal / Topik', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: penulisCtrl,
                    decoration: const InputDecoration(labelText: 'Penulis (Opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: jurnalCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Jurnal Sumber (Opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pembimbingCtrl,
                    decoration: const InputDecoration(labelText: 'Pembimbing', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (judulCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Judul wajib diisi')));
                                return;
                              }
                              setDlg(() => isSubmitting = true);
                              // Cek duplikasi topik
                              final dupCheck = await _api.checkTopicDuplication(judulCtrl.text.trim(), 'journal');
                              if (dupCheck['exists'] == true) {
                                setDlg(() => isSubmitting = false);
                                if (ctx.mounted) {
                                  showDialog(
                                    context: ctx,
                                    builder: (c) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Row(children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text('Topik Duplikat', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                                      ]),
                                      content: Text(dupCheck['message'] ?? 'Judul sudah pernah diajukan.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                          onPressed: () async {
                                            Navigator.pop(c);
                                            setDlg(() => isSubmitting = true);
                                            final success = await _api.submitJournalReading({
                                              'judul': judulCtrl.text.trim(),
                                              'penulis': penulisCtrl.text.trim(),
                                              'nama_jurnal': jurnalCtrl.text.trim(),
                                              'pembimbing': pembimbingCtrl.text.trim(),
                                              'jenis': 'Journal Reading',
                                            });
                                            setDlg(() => isSubmitting = false);
                                            if (mounted) Navigator.pop(ctx);
                                            if (success && mounted) {
                                              _loadData();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Berhasil diajukan, menunggu ACC admin.')));
                                            } else if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Gagal mengajukan topik. Periksa koneksi/server.')));
                                            }
                                          },
                                          child: const Text('Tetap Ajukan', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return;
                              }
                              final success = await _api.submitJournalReading({
                                'judul': judulCtrl.text.trim(),
                                'penulis': penulisCtrl.text.trim(),
                                'nama_jurnal': jurnalCtrl.text.trim(),
                                'pembimbing': pembimbingCtrl.text.trim(),
                                'jenis': 'Journal Reading',
                              });
                              setDlg(() => isSubmitting = false);
                              if (mounted) Navigator.pop(ctx);
                              if (success) {
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Berhasil diajukan, menunggu ACC admin.')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Gagal mengajukan topik. Periksa koneksi/server.')));
                              }
                            },
                      child: isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Ajukan Topik', style: TextStyle(fontFamily: 'Poppins')),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadBuktiDialog(Map<String, dynamic> journal) {
    final buktiCtrl = TextEditingController(text: journal['bukti_url'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload Bukti (Link)',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: buktiCtrl,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    labelText: 'URL Bukti Pelaksanaan',
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDlg(() => isSubmitting = true);
                            final success = await _api.updateJournalReadingBukti(
                                journal['id'], buktiCtrl.text.trim());
                            setDlg(() => isSubmitting = false);
                            if (mounted) Navigator.pop(ctx);
                            if (success) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bukti berhasil diupload.')));
                            }
                          },
                    child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Simpan', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyJournals() {
    if (_myJournals.isEmpty) {
      return const Center(
        child: Text('Belum ada pengajuan Journal Reading', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myJournals.length,
      itemBuilder: (ctx, i) {
        final j = _myJournals[i];
        final status = j['status'];
        final isApproved = status == 'approved';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(j['judul'] ?? '', 
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(status),
                          style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                if (j['pembimbing'] != null && j['pembimbing'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Pembimbing: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (isApproved) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(j['bukti_submitted'] == true ? 'Bukti sudah diupload' : 'Belum upload bukti', 
                          style: TextStyle(fontSize: 12, color: j['bukti_submitted'] == true ? Colors.green : Colors.orange)),
                      TextButton(
                        onPressed: () => _showUploadBuktiDialog(j),
                        child: Text(j['bukti_submitted'] == true ? 'Edit Bukti' : 'Upload Bukti'),
                      )
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllJournals() {
    if (_allJournals.isEmpty) {
      return const Center(
        child: Text('Belum ada Journal Reading yang di-ACC', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allJournals.length,
      itemBuilder: (ctx, i) {
        final j = _allJournals[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(j['judul'] ?? '', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Oleh: ', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11)),
            trailing: j['bukti_url'] != null && j['bukti_url'].toString().isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.link, color: AppColors.primaryPurple),
                    onPressed: () => _openUrl(j['bukti_url']),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightest,
      appBar: AppBar(
        title: const Text('Journal Reading', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Jurnal Saya'),
            Tab(text: 'Semua PPDS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyJournals(),
                  _buildAllJournals(),
                ],
              ),
            ),
      floatingActionButton: _tabController.index == 0 
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajukan Topik', style: TextStyle(fontFamily: 'Poppins')),
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
