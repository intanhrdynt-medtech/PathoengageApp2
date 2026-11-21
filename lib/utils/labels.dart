import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';

/// Satu sumber istilah & warna untuk seluruh aplikasi (glosarium).
/// Pakai fungsi di sini — jangan membuat peta status/label sendiri di layar.

class StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  const StatusInfo(this.label, this.color, this.icon);
}

// ── Kalung (phase) ────────────────────────────────────────────────────────────

String phaseLabel(String? phase) {
  switch (phase) {
    case 'MKDU':
      return 'MKDU';
    case 'red':
      return 'Kalung Merah';
    case 'yellow':
      return 'Kalung Kuning';
    case 'green':
      return 'Kalung Hijau';
    default:
      return 'Belum ditentukan';
  }
}

Color phaseColor(String? phase) {
  switch (phase) {
    case 'red':
      return AppColors.phaseRed;
    case 'yellow':
      return AppColors.phaseYellow;
    case 'green':
      return AppColors.phaseGreen;
    default:
      return AppColors.phaseMkdu;
  }
}

const List<String> phaseOrder = ['MKDU', 'red', 'yellow', 'green'];

// ── Status per jenis item ─────────────────────────────────────────────────────

/// Kompetensi & tugas akademik.
StatusInfo progressStatus(String? status, {bool isCompleted = false, String? alasanTolak}) {
  if (isCompleted || status == 'completed') {
    return const StatusInfo('Selesai', AppColors.successGreen, Icons.check_circle);
  }
  if (status == 'pending_verification') {
    return const StatusInfo('Menunggu verifikasi', AppColors.infoBlue, Icons.hourglass_top);
  }
  if (alasanTolak != null && alasanTolak.isNotEmpty) {
    return const StatusInfo('Perlu diperbaiki', AppColors.errorRed, Icons.error_outline);
  }
  if (status == 'in_progress') {
    return const StatusInfo('Sedang dikerjakan', AppColors.warningOrange, Icons.edit_note);
  }
  return const StatusInfo('Belum dikirim', AppColors.neutralGrey, Icons.radio_button_unchecked);
}

/// Ujian (lokal / nasional) & ujian organ.
StatusInfo examStatus(String? result, {String? alasanTolak}) {
  switch (result) {
    case 'lulus':
      return const StatusInfo('Lulus', AppColors.successGreen, Icons.verified);
    case 'tidak_lulus':
      return const StatusInfo('Tidak lulus', AppColors.errorRed, Icons.cancel);
    case 'pending_verification':
      return const StatusInfo('Menunggu verifikasi', AppColors.infoBlue, Icons.hourglass_top);
  }
  if (alasanTolak != null && alasanTolak.isNotEmpty) {
    return const StatusInfo('Perlu diperbaiki', AppColors.errorRed, Icons.error_outline);
  }
  return const StatusInfo('Terjadwal', AppColors.warningOrange, Icons.event);
}

/// Journal reading.
StatusInfo journalStatus(String? status, {bool buktiSubmitted = false}) {
  switch (status) {
    case 'approved':
      return buktiSubmitted
          ? const StatusInfo('Selesai', AppColors.successGreen, Icons.check_circle)
          : const StatusInfo('Disetujui — unggah bukti', AppColors.successGreen, Icons.upload_file);
    case 'rejected':
      return const StatusInfo('Ditolak', AppColors.errorRed, Icons.cancel);
    default:
      return const StatusInfo('Menunggu persetujuan', AppColors.infoBlue, Icons.hourglass_top);
  }
}

/// Penelitian.
StatusInfo penelitianStatus(String? status, {bool perluReview = false}) {
  switch (status) {
    case 'draft':
      return const StatusInfo('Draft — belum diajukan', AppColors.neutralGrey, Icons.edit_note);
    case 'submitted':
      return const StatusInfo('Menunggu review', AppColors.infoBlue, Icons.hourglass_top);
    case 'revisi_1':
      return perluReview
          ? const StatusInfo('Revisi 1 terkirim', AppColors.infoBlue, Icons.hourglass_top)
          : const StatusInfo('Perlu Revisi 1', AppColors.warningOrange, Icons.edit_document);
    case 'revisi_2':
      return perluReview
          ? const StatusInfo('Revisi 2 terkirim', AppColors.infoBlue, Icons.hourglass_top)
          : const StatusInfo('Perlu Revisi 2', AppColors.warningOrange, Icons.edit_document);
    case 'approved':
      return const StatusInfo('Disetujui', AppColors.successGreen, Icons.check_circle);
    case 'published':
      return const StatusInfo('Terpublikasi', AppColors.successGreen, Icons.public);
    case 'rejected':
      return const StatusInfo('Ditolak', AppColors.errorRed, Icons.cancel);
    default:
      return StatusInfo(status ?? '-', AppColors.neutralGrey, Icons.help_outline);
  }
}

/// Stase / rotasi luar.
StatusInfo rotationStatus(String? status) {
  switch (status) {
    case 'selesai':
      return const StatusInfo('Selesai', AppColors.successGreen, Icons.check_circle);
    case 'berlangsung':
    case 'aktif':
      return const StatusInfo('Sedang berjalan', AppColors.infoBlue, Icons.play_circle);
    default:
      return const StatusInfo('Terjadwal', AppColors.warningOrange, Icons.event);
  }
}

// ── Peran ─────────────────────────────────────────────────────────────────────

String roleLabel(String? role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'penilai':
      return 'Penilai / Dosen';
    default:
      return 'PPDS';
  }
}

const Map<String, String> peranPembimbingLabel = {
  'dosen_wali': 'Dosen Wali',
  'pembimbing_1': 'Pembimbing 1',
  'pembimbing_2': 'Pembimbing 2',
  'pembimbing_retrospektif': 'Pembimbing Retrospektif',
};

// ── Tanggal ───────────────────────────────────────────────────────────────────

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// [serverTimestamp]: waktu yang dibuat server (created_at dll.) disimpan dalam
/// UTC tanpa zona waktu, jadi dikonversi ke waktu lokal. Tanggal yang diisi
/// user (tanggal ujian, dsb.) ditampilkan apa adanya.
String formatTanggal(String? iso, {bool withTime = false, bool serverTimestamp = false}) {
  if (iso == null || iso.isEmpty) return '-';
  final hasZone = iso.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(iso);
  final d = DateTime.tryParse(serverTimestamp && !hasZone ? '${iso}Z' : iso);
  if (d == null) return '-';
  final local = d.isUtc ? d.toLocal() : d;
  final base = '${local.day} ${_bulan[local.month - 1]} ${local.year}';
  if (!withTime) return base;
  return '$base, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
