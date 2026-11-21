import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/service/session.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Helper khusus layar penilai (dosen wali / pembimbing / penguji).

// ── Konversi nilai JSON ───────────────────────────────────────────────────────

int? asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Teks non-kosong atau null.
String? textOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == '-' ? null : s;
}

/// Tanggal (ISO) untuk diurutkan; null bila kosong / tidak valid.
DateTime? parseDate(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

// ── Nilai 0-100 ───────────────────────────────────────────────────────────────

String formatNilai(num? n) {
  if (n == null) return '-';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

String nilaiLabel(num n) {
  if (n >= 85) return 'Sangat baik';
  if (n >= 70) return 'Baik';
  if (n >= 60) return 'Cukup';
  return 'Perlu perbaikan';
}

Color nilaiColor(num n) {
  if (n >= 85) return AppColors.successGreen;
  if (n >= 70) return AppColors.infoBlue;
  if (n >= 60) return AppColors.warningOrange;
  return AppColors.errorRed;
}

// ── Review dengan pesan error dari server ────────────────────────────────────
//
// `adminReviewJournal` & `adminUpdatePenelitianStatus` di ApiService hanya
// mengembalikan bool (tanpa alasan gagal). Versi ini memakai endpoint yang sama
// tetapi mengembalikan pesan error server (mis. 403 "tidak bisa mereview milik
// sendiri") supaya bisa ditampilkan ke penilai.

class PenilaiReviewApi {
  final String _baseUrl = ApiService().baseUrl;

  /// null = sukses; selain itu pesan kegagalan.
  Future<String?> _patch(String path, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return 'Sesi login berakhir. Silakan login ulang.';
    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) return null;
      if (r.statusCode == 401) {
        handleUnauthorized();
        return 'Sesi login berakhir. Silakan login ulang.';
      }
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['error'] != null) return decoded['error'].toString();
      } catch (_) {}
      if (r.statusCode == 401) return 'Sesi login berakhir. Silakan login ulang.';
      if (r.statusCode == 403) return 'Anda tidak berhak melakukan tindakan ini.';
      return 'Terjadi kesalahan (kode ${r.statusCode}).';
    } catch (e) {
      debugPrint('PenilaiReviewApi $path error: $e');
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
  }

  /// action: approve | reject.
  Future<String?> reviewJournal(int id, String action, String catatan) =>
      _patch('/admin/journal-readings/$id/review', {'action': action, 'catatan_admin': catatan});

  /// status: approved | revisi_1 | revisi_2 | rejected.
  Future<String?> reviewPenelitian(int id, String status, String catatan) =>
      _patch('/admin/penelitian/$id/status', {'status': status, 'catatan': catatan});
}

// ── Widget kecil ──────────────────────────────────────────────────────────────

const TextStyle kCaption = TextStyle(fontSize: 12, color: AppColors.textGrey);
const TextStyle kBody = TextStyle(fontSize: 14, color: AppColors.textDark);
const TextStyle kCardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark);

/// Label kecil berwarna, mis. "Bimbingan saya" atau nama peran.
class SmallTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const SmallTag(this.text, {super.key, this.color = AppColors.primaryPurple, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// Baris ikon + teks kecil (tanggal, nama jurnal, dll.).
class InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoLine(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: AppColors.textGrey),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textGrey))),
      ]),
    );
  }
}

/// Lingkaran nilai berwarna sesuai kategori.
class NilaiBadge extends StatelessWidget {
  final num nilai;
  final double size;
  const NilaiBadge(this.nilai, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = nilaiColor(nilai);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(formatNilai(nilai),
          style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Membungkus state kosong/gagal agar tetap bisa ditarik untuk refresh.
class RefreshableState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const RefreshableState({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: child)],
        ),
      ),
    );
  }
}

/// Bilah kemajuan sederhana dengan label "selesai/total".
class ProgressRow extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  final Color color;
  final String? extra;
  const ProgressRow({super.key, required this.label, required this.done, required this.total,
      this.color = AppColors.primaryPurple, this.extra});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: kBody)),
          Text(total == 0 ? 'Belum ada data' : '$done / $total',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 4), Text(extra!, style: kCaption)],
      ]),
    );
  }
}
