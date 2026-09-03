import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PenelitianScreen extends StatefulWidget {
  const PenelitianScreen({Key? key}) : super(key: key);

  @override
  State<PenelitianScreen> createState() => _PenelitianScreenState();
}

class _PenelitianScreenState extends State<PenelitianScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<dynamic> _myPenelitian = [];
  List<dynamic> _allPenelitian = [];
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
    final myPenelitian = await _api.getMyPenelitian();
    final allPenelitian = await _api.getAllPenelitian('');
    setState(() {
      _myPenelitian = myPenelitian;
      _allPenelitian = allPenelitian;
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
      case 'published':
      case 'approved': return Colors.green;
      case 'revisi_1':
      case 'revisi_2': return Colors.red;
      case 'submitted': return Colors.orange;
      default: return AppColors.textGrey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'published': return 'Published 🎉';
      case 'approved': return 'Approved ✓';
      case 'revisi_1': return 'Revisi 1';
      case 'revisi_2': return 'Revisi 2';
      case 'submitted': return 'Menunggu Review';
      default: return 'Draft';
    }
  }

  void _showAddDialog() {
    final judulCtrl = TextEditingController();
    final jenisCtrl = TextEditingController();
    final pemb1Ctrl = TextEditingController();
    final pemb2Ctrl = TextEditingController();
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
                  const Text('Ajukan Penelitian / Karya Akhir',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: judulCtrl,
                    decoration: const InputDecoration(labelText: 'Judul Penelitian', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: jenisCtrl,
                    decoration: const InputDecoration(labelText: 'Jenis (Case Report/Karya Akhir dll)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pemb1Ctrl,
                    decoration: const InputDecoration(labelText: 'Pembimbing 1', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pemb2Ctrl,
                    decoration: const InputDecoration(labelText: 'Pembimbing 2 (Opsional)', border: OutlineInputBorder()),
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
                              final dupCheck = await _api.checkTopicDuplication(judulCtrl.text.trim(), 'penelitian');
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
                                            final success = await _api.submitPenelitian({
                                              'judul': judulCtrl.text.trim(),
                                              'jenis': jenisCtrl.text.trim(),
                                              'pembimbing_1': pemb1Ctrl.text.trim(),
                                              'pembimbing_2': pemb2Ctrl.text.trim(),
                                            });
                                            setDlg(() => isSubmitting = false);
                                            if (mounted) Navigator.pop(ctx);
                                            if (success && mounted) {
                                              _loadData();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Berhasil diajukan.')));
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
                              final success = await _api.submitPenelitian({
                                'judul': judulCtrl.text.trim(),
                                'jenis': jenisCtrl.text.trim(),
                                'pembimbing_1': pemb1Ctrl.text.trim(),
                                'pembimbing_2': pemb2Ctrl.text.trim(),
                              });
                              setDlg(() => isSubmitting = false);
                              if (mounted) Navigator.pop(ctx);
                              if (success) {
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Berhasil diajukan.')));
                              }
                            },
                      child: isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Ajukan Penelitian', style: TextStyle(fontFamily: 'Poppins')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                      ),
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

  void _showUpdateDialog(Map<String, dynamic> pen) {
    final status = pen['status'] ?? 'draft';
    final linkDocCtrl = TextEditingController();
    bool isSubmitting = false;

    String label = 'Upload Dokumen';
    String field = 'dokumen_proposal_url';

    if (status == 'revisi_1') {
      label = 'Upload Dokumen Revisi 1';
      field = 'dokumen_revisi1_url';
    } else if (status == 'revisi_2') {
      label = 'Upload Dokumen Revisi 2';
      field = 'dokumen_revisi2_url';
    } else if (status == 'approved') {
      label = 'Upload Dokumen Final';
      field = 'dokumen_final_url';
    }

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
                Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: linkDocCtrl,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    labelText: 'URL Dokumen',
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
                            final nextStatus = status == 'draft' ? 'submitted' : status;
                            final success = await _api.updatePenelitian(
                                pen['id'], {
                                  field: linkDocCtrl.text.trim(),
                                  'status': nextStatus, // draft -> submitted, others stay same until admin changes
                                });
                            setDlg(() => isSubmitting = false);
                            if (mounted) Navigator.pop(ctx);
                            if (success) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dokumen berhasil diupload.')));
                            }
                          },
                    child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Simpan', style: TextStyle(fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPenelitian() {
    if (_myPenelitian.isEmpty) {
      return const Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text('Belum ada penelitian',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myPenelitian.length,
      itemBuilder: (ctx, i) {
        final p = _myPenelitian[i];
        final status = p['status'];
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
                      child: Text(p['judul'] ?? '', 
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
                const SizedBox(height: 8),
                Text('Jenis: ${p['jenis'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Pembimbing 1: ${p['pembimbing_1'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                
                if (status == 'revisi_1' && p['catatan_revisi1'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.shade50,
                    child: Text('Catatan Revisi 1: ${p['catatan_revisi1']}', style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                  ),
                ],
                if (status == 'revisi_2' && p['catatan_revisi2'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.shade50,
                    child: Text('Catatan Revisi 2: ${p['catatan_revisi2']}', style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showUpdateDialog(p),
                      child: const Text('Update / Upload Doc'),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllPenelitian() {
    if (_allPenelitian.isEmpty) {
      return const Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text('Belum ada penelitian dari PPDS lain',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allPenelitian.length,
      itemBuilder: (ctx, i) {
        final p = _allPenelitian[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p['judul'] ?? '-', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(p['status']).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(p['status']), style: TextStyle(fontSize: 10, color: _statusColor(p['status']), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Oleh: ${p['user_name'] ?? '-'}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
                Text('Jenis: ${p['jenis'] ?? '-'}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey)),
              ],
            ),
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
        title: const Text('Penelitian', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Penelitian Saya'),
            Tab(text: 'Semua Penelitian'),
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
                  _buildMyPenelitian(),
                  _buildAllPenelitian(),
                ],
              ),
            ),
      floatingActionButton: _tabController.index == 0 
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajukan Penelitian', style: TextStyle(fontFamily: 'Poppins')),
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
