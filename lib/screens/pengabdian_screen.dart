import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PengabdianScreen extends StatefulWidget {
  const PengabdianScreen({Key? key}) : super(key: key);
  @override
  State<PengabdianScreen> createState() => _PengabdianScreenState();
}

class _PengabdianScreenState extends State<PengabdianScreen> {
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
    // TODO: implement _api.getPengabdian()
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengabdian Masyarakat')),
      body: const Center(child: Text('Segera Hadir')),
    );
  }
}
