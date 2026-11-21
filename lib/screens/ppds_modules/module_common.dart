import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/service/session.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';
import 'package:http/http.dart' as http;

/// Bagian bersama untuk layar modul PPDS (logbook, ujian, akademik, journal,
/// penelitian, pengabdian, prestasi).

const String kGenericError = 'Terjadi kesalahan. Silakan coba lagi.';

// ── API ───────────────────────────────────────────────────────────────────────

/// Pembungkus HTTP kecil untuk layar modul PPDS. Berbeda dengan sebagian
/// method lama di [ApiService], setiap panggilan membedakan "gagal" (null)
/// dari "kosong" dan menyimpan pesan error server di [lastError].
class ModuleApi {
  final ApiService _base = ApiService();
  String? lastError;

  /// Pesan error terakhir, atau pesan umum bila server tidak memberi alasan.
  String get errorMessage => lastError ?? kGenericError;

  String _errorFrom(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['error'] != null) return body['error'].toString();
    } catch (_) {}
    if (r.statusCode == 401) return 'Sesi login berakhir. Silakan login ulang.';
    if (r.statusCode == 409) return 'Data ini sudah final dan tidak bisa diubah lagi.';
    if (r.statusCode == 429) return 'Terlalu banyak percobaan. Coba lagi nanti.';
    return 'Terjadi kesalahan (kode ${r.statusCode}).';
  }

  /// Mengembalikan body JSON bila sukses, atau null bila gagal.
  Future<dynamic> send(String method, String path, {Map<String, dynamic>? body}) async {
    lastError = null;
    final token = await _base.getAdminToken();
    if (token == null) {
      lastError = 'Sesi login berakhir. Silakan login ulang.';
      return null;
    }
    try {
      final uri = Uri.parse('${_base.baseUrl}$path');
      final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
      final encoded = body == null ? null : jsonEncode(body);
      final http.Response r;
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers);
          break;
        default:
          r = await http.get(uri, headers: headers);
      }
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      }
      lastError = _errorFrom(r);
      if (r.statusCode == 401) handleUnauthorized();
    } catch (e) {
      debugPrint('ModuleApi $method $path error: $e');
      lastError = 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
    return null;
  }

  Future<List<dynamic>?> list(String path) async {
    final data = await send('GET', path);
    if (data is List) return data;
    if (data != null) lastError = 'Format data dari server tidak dikenali.';
    return null;
  }

  Future<bool> ok(String method, String path, {Map<String, dynamic>? body}) async =>
      await send(method, path, body: body) != null;

  // Profil
  Future<Map<String, dynamic>?> me() async {
    final d = await send('GET', '/me');
    return d is Map<String, dynamic> ? d : null;
  }

  /// Cek judul yang sama. jenis: 'journal' | 'penelitian'. Bila gagal
  /// dianggap tidak ada duplikat (server tetap menerima pengajuan).
  Future<Map<String, dynamic>> checkTopic(String judul, String jenis) async {
    final d = await send('GET',
        '/check-topic?judul=${Uri.encodeQueryComponent(judul)}&jenis=${Uri.encodeQueryComponent(jenis)}');
    return d is Map<String, dynamic> ? d : {'exists': false};
  }
}

// ── Format & data kecil ──────────────────────────────────────────────────────

/// Nilai string yang sudah di-trim ('' bila null).
String str(dynamic v) => v == null ? '' : v.toString().trim();

/// Tanggal → 'YYYY-MM-DD' (diterima server sebagai ISO 8601).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(dynamic v) {
  final s = str(v);
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

// ── Gaya teks ────────────────────────────────────────────────────────────────

const TextStyle kCardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark);
const TextStyle kBody = TextStyle(fontSize: 14, color: AppColors.textDark);
const TextStyle kCaption = TextStyle(fontSize: 13, color: AppColors.textGrey);

// ── Tata letak ───────────────────────────────────────────────────────────────

/// TabBar putih di atas AppBar ungu.
TabBar moduleTabBar(List<String> labels, {bool scrollable = false}) {
  return TabBar(
    isScrollable: scrollable,
    tabAlignment: scrollable ? TabAlignment.start : null,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white70,
    indicatorColor: Colors.white,
    indicatorWeight: 3,
    dividerColor: Colors.transparent,
    labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14),
    unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 14),
    tabs: labels.map((l) => Tab(text: l)).toList(),
  );
}

/// Daftar yang bisa ditarik untuk memuat ulang; setiap anak dibatasi lebarnya
/// dengan [MaxWidth] supaya tetap enak dibaca di layar lebar.
class ModuleList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final double bottomPadding;
  const ModuleList({super.key, required this.onRefresh, required this.children, this.bottomPadding = 32});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        // MaxWidth memakai Align (lebar longgar); SizedBox memaksa kartu
        // tetap selebar konten maksimum.
        children: children.map((w) => MaxWidth(child: SizedBox(width: double.infinity, child: w))).toList(),
      ),
    );
  }
}

/// Isi satu tab/halaman dengan status memuat / gagal / data.
Widget moduleBody({
  required bool loading,
  required String? error,
  required Future<void> Function() onRefresh,
  required List<Widget> Function() builder,
  double bottomPadding = 32,
}) {
  if (loading) return const LoadingView();
  if (error != null) {
    return ModuleList(onRefresh: onRefresh, children: [
      const SizedBox(height: 48),
      ErrorState(message: error, onRetry: onRefresh),
    ]);
  }
  return ModuleList(onRefresh: onRefresh, bottomPadding: bottomPadding, children: builder());
}

/// Kartu ringkasan progres (x / y selesai).
class ModuleProgressCard extends StatelessWidget {
  final String title;
  final int done;
  final int total;
  final String? caption;
  final String doneLabel;
  const ModuleProgressCard(
      {super.key, required this.title, required this.done, required this.total, this.caption, this.doneLabel = 'selesai'});

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.darkMagenta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Text('$done / $total $doneLabel',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(caption!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
        ],
      ]),
    );
  }
}

/// Baris keterangan kecil: ikon + "Label: nilai". Tidak tampil bila nilai kosong.
class MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  const MetaRow({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final v = (value ?? '').trim();
    if (v.isEmpty || v == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.textGrey),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label: ', style: kCaption),
            TextSpan(
                text: v,
                style: TextStyle(fontSize: 14, color: valueColor ?? AppColors.textDark, fontWeight: FontWeight.w500)),
          ])),
        ),
      ]),
    );
  }
}

/// Judul bagian kecil di dalam kartu (mis. "Referensi", "Bukti").
class CardSectionLabel extends StatelessWidget {
  final String text;
  const CardSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textGrey)),
    );
  }
}

/// Tombol aksi utama di kartu (lebar penuh di layar sempit).
class CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outlined;
  const CardActionButton(
      {super.key, required this.label, required this.icon, required this.onPressed, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    const textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final child = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: outlined
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: padding,
                  foregroundColor: AppColors.primaryPurple,
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: textStyle,
                ),
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: padding, textStyle: textStyle),
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
              ),
      ),
    );
    return child;
  }
}

// ── Formulir ─────────────────────────────────────────────────────────────────

/// Kolom teks standar untuk formulir modul.
Widget moduleField(
  TextEditingController controller,
  String label, {
  IconData? icon,
  bool required = false,
  int maxLines = 1,
  String? hint,
  String? helper,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      validator: validator ?? (required ? (v) => (v ?? '').trim().isEmpty ? '$label wajib diisi' : null : null),
    ),
  );
}

/// Kolom link opsional/wajib dengan validasi standar.
Widget moduleLinkField(TextEditingController controller, String label,
    {bool required = false, String? helper, ValueChanged<String>? onChanged}) {
  return moduleField(
    controller,
    label,
    icon: Icons.link,
    required: required,
    hint: 'https://drive.google.com/...',
    helper: helper,
    keyboardType: TextInputType.url,
    onChanged: onChanged,
    validator: (v) => validateLink(v, required: required),
  );
}

/// Kolom tanggal dengan pemilih tanggal.
class DateFormField extends FormField<DateTime> {
  DateFormField({
    super.key,
    required String label,
    super.initialValue,
    required ValueChanged<DateTime?> onChanged,
    bool required = false,
    DateTime? firstDate,
    DateTime? lastDate,
  }) : super(
          validator: (v) => required && v == null ? '$label wajib diisi' : null,
          builder: (state) {
            final first = firstDate ?? DateTime(2000);
            final last = lastDate ?? DateTime(DateTime.now().year + 5, 12, 31);
            Future<void> pick() async {
              var initial = state.value ?? DateTime.now();
              if (initial.isBefore(first)) initial = first;
              if (initial.isAfter(last)) initial = last;
              final picked = await showDatePicker(
                context: state.context,
                initialDate: initial,
                firstDate: first,
                lastDate: last,
                helpText: 'Pilih tanggal',
                cancelText: 'Batal',
                confirmText: 'Pilih',
              );
              if (picked != null) {
                state.didChange(picked);
                onChanged(picked);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: pick,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  isEmpty: state.value == null,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    prefixIcon: const Icon(Icons.event),
                    errorText: state.errorText,
                    suffixIcon: !required && state.value != null
                        ? IconButton(
                            tooltip: 'Kosongkan tanggal',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              state.didChange(null);
                              onChanged(null);
                            },
                          )
                        : const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(state.value == null ? '' : formatTanggal(isoDate(state.value!)),
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
            );
          },
        );
}

/// Kerangka halaman formulir: AppBar, isi yang bisa digulir, tombol simpan.
class FormPageScaffold extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final String submitLabel;
  final IconData submitIcon;
  final bool saving;
  final VoidCallback onSubmit;
  const FormPageScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.submitLabel,
    required this.saving,
    required this.onSubmit,
    this.submitIcon = Icons.send,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            MaxWidth(
              maxWidth: 640,
              child: SizedBox(
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ...children,
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(submitIcon),
                  label: Text(saving ? 'Menyimpan...' : submitLabel),
                ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom pencarian sederhana untuk tab "Semua ...".
class ModuleSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const ModuleSearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          fillColor: Colors.white,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
