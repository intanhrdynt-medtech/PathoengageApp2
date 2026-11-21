import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Helper kecil khusus layar admin (tidak dipakai layar lain).

/// ListView yang membatasi lebar konten di layar lebar (maks. [maxWidth]),
/// tetapi area scroll tetap selebar ruang yang tersedia (scroll mouse di luar
/// kolom tetap berfungsi). Selalu bisa ditarik untuk RefreshIndicator.
class AdminListView extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;
  const AdminListView({super.key, required this.children, this.maxWidth = 900, this.top = 16, this.bottom = 24});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.max(16.0, (constraints.maxWidth - maxWidth) / 2);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, top, side, bottom),
        children: children,
      );
    });
  }
}

/// Tanggal untuk dikirim ke server (YYYY-MM-DD).
String isoDateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(dynamic iso) {
  if (iso is! String || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

String textOf(dynamic v) => v == null ? '' : v.toString().trim();

String initialsOf(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Email wajib diisi';
  if (!_emailRe.hasMatch(s)) return 'Format email tidak valid';
  return null;
}

String? validatePassword(String? v, {bool required = true}) {
  final s = v ?? '';
  if (s.isEmpty) return required ? 'Password wajib diisi' : null;
  if (s.length < 8) return 'Password minimal 8 karakter';
  return null;
}

String? validateRequired(String? v, String label) => (v ?? '').trim().isEmpty ? '$label wajib diisi' : null;

/// Nilai opsional 0-100. Koma diterima sebagai pemisah desimal.
String? validateScore(String? v, {bool required = false}) {
  final s = (v ?? '').trim().replaceAll(',', '.');
  if (s.isEmpty) return required ? 'Nilai wajib diisi' : null;
  final n = double.tryParse(s);
  if (n == null) return 'Nilai harus berupa angka';
  if (n < 0 || n > 100) return 'Nilai harus di antara 0 dan 100';
  return null;
}

double? parseScore(String v) {
  final s = v.trim().replaceAll(',', '.');
  return s.isEmpty ? null : double.tryParse(s);
}

String formatNilai(dynamic n) {
  if (n is num) return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  return textOf(n).isEmpty ? '-' : textOf(n);
}

/// Avatar bulat berisi inisial nama.
class PersonAvatar extends StatelessWidget {
  final String? name;
  final Color color;
  final double radius;
  const PersonAvatar({super.key, required this.name, this.color = AppColors.primaryPurple, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(initialsOf(name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.7)),
    );
  }
}

/// Baris label + nilai di detail.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.textGrey),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

/// Chip kecil berwarna (mis. "SP aktif").
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const TagChip(this.label, {super.key, this.color = AppColors.primaryPurple, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

/// Bilah progres dengan label "x / y".
class ProgressLine extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  final Color color;
  const ProgressLine({super.key, required this.label, required this.done, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text('$done / $total', style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }
}

/// Kolom tanggal yang membuka date picker.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;
  final bool clearable;
  const DateField({super.key, required this.label, required this.value, required this.onChanged,
      this.errorText, this.clearable = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: label,
          cancelText: 'Batal',
          confirmText: 'Pilih',
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: clearable && value != null
              ? IconButton(tooltip: 'Kosongkan', icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(value == null ? 'Belum diisi' : formatTanggal(value!.toIso8601String()),
            style: TextStyle(fontSize: 14, color: value == null ? AppColors.textGrey : AppColors.textDark)),
      ),
    );
  }
}

/// Dropdown akun penilai, dengan pilihan "Belum ditentukan" (null).
class PenilaiDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<dynamic> penilai;
  final ValueChanged<int?> onChanged;
  final IconData icon;
  const PenilaiDropdown({super.key, required this.label, required this.value, required this.penilai,
      required this.onChanged, this.icon = Icons.person_outline});

  @override
  Widget build(BuildContext context) {
    final ids = penilai.map((p) => p['id']).toSet();
    final current = ids.contains(value) ? value : null;
    return DropdownButtonFormField<int?>(
      key: ValueKey('$label-$current-${penilai.length}'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Belum ditentukan', style: TextStyle(color: AppColors.textGrey)),
        ),
        for (final p in penilai)
          DropdownMenuItem<int?>(
            value: p['id'] as int,
            child: Text(textOf(p['full_name']).isEmpty ? '-' : textOf(p['full_name']), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Hasil dialog alasan.
class ReasonResult {
  final String text;
  final double? score;
  const ReasonResult(this.text, this.score);
}

/// Dialog meminta alasan / catatan (opsional dengan nilai).
Future<ReasonResult?> promptReason(
  BuildContext context, {
  required String title,
  String? message,
  String label = 'Alasan',
  String? hint,
  bool required = true,
  bool withScore = false,
  String confirmText = 'Kirim',
  bool danger = false,
}) {
  return showDialog<ReasonResult>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      label: label,
      hint: hint,
      required: required,
      withScore: withScore,
      confirmText: confirmText,
      danger: danger,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String label;
  final String? hint;
  final bool required;
  final bool withScore;
  final String confirmText;
  final bool danger;
  const _ReasonDialog({required this.title, this.message, required this.label, this.hint, required this.required,
      required this.withScore, required this.confirmText, required this.danger});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _score = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.message != null) ...[
                Text(widget.message!, style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _text,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, alignLabelWithHint: true),
                validator: (v) => widget.required && (v ?? '').trim().isEmpty ? '${widget.label} wajib diisi' : null,
              ),
              if (widget.withScore) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _score,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Nilai (opsional, 0-100)', prefixIcon: Icon(Icons.grade)),
                  validator: (v) => validateScore(v),
                ),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.danger ? AppColors.errorRed : AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, ReasonResult(_text.text.trim(), widget.withScore ? parseScore(_score.text) : null));
          },
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// Kerangka dialog formulir standar: judul, isi bergulir, pesan error, tombol.
class FormDialogFrame extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final String? error;
  final bool busy;
  final String submitText;
  final VoidCallback onSubmit;
  final Color? submitColor;
  const FormDialogFrame({super.key, required this.title, required this.formKey, required this.children,
      required this.onSubmit, this.error, this.busy = false, this.submitText = 'Simpan', this.submitColor});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...children,
              if (error != null && error!.isNotEmpty)
                NoteBox(title: 'Gagal menyimpan', text: error!, color: AppColors.errorRed, icon: Icons.error_outline),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: submitColor ?? AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(submitText),
        ),
      ],
    );
  }
}

/// Jarak vertikal standar antar field formulir.
const Widget formGap = SizedBox(height: 12);
