import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin/admin_common.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/utils/labels.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Menu "Tambah": pilih jenis akun, lalu buka formulirnya.
/// Mengembalikan true bila akun berhasil dibuat.
Future<bool> showAddUserMenu(BuildContext context) async {
  final role = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Tambah akun', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.school_outlined, color: AppColors.primaryPurple),
          title: const Text('PPDS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Residen. Kurikulum standar dibuat otomatis.', style: TextStyle(fontSize: 13)),
          onTap: () => Navigator.pop(ctx, 'ppds'),
        ),
        ListTile(
          leading: const Icon(Icons.rate_review_outlined, color: AppColors.infoBlue),
          title: const Text('Penilai / Dosen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Dosen wali, pembimbing, atau penguji.', style: TextStyle(fontSize: 13)),
          onTap: () => Navigator.pop(ctx, 'penilai'),
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.errorRed),
          title: const Text('Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: const Text('Akses penuh ke semua data.', style: TextStyle(fontSize: 13)),
          onTap: () => Navigator.pop(ctx, 'admin'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (role == null || !context.mounted) return false;
  final created = await showDialog<bool>(context: context, builder: (_) => _CreateUserDialog(role: role));
  return created == true;
}

class _CreateUserDialog extends StatefulWidget {
  final String role;
  const _CreateUserDialog({required this.role});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nim = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  bool get _isPpds => widget.role == 'ppds';

  @override
  void dispose() {
    _name.dispose();
    _nim.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    final name = _name.text.trim();
    Map<String, dynamic>? result;
    switch (widget.role) {
      case 'ppds':
        result = await _api.createPpdsUser(email, _password.text, name, _nim.text.trim());
        break;
      case 'admin':
        result = await _api.createAdminUser(email, _password.text, name, '-');
        break;
      default:
        result = await _api.createUserWithRole(email, _password.text, name, 'penilai');
    }
    if (!mounted) return;
    if (result != null && result['error'] == null) {
      showSnack(context, '${roleLabel(widget.role)} "$name" berhasil ditambahkan');
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result?['error']?.toString() ?? 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogFrame(
      title: 'Tambah ${roleLabel(widget.role)}',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      submitText: 'Tambah',
      submitColor: widget.role == 'admin' ? AppColors.errorRed : null,
      onSubmit: _submit,
      children: [
        if (widget.role == 'admin') ...[
          const NoteBox(
            title: 'Perhatian',
            text: 'Admin memiliki akses penuh ke semua data PPDS dan penilai.',
            color: AppColors.warningOrange,
            icon: Icons.warning_amber,
          ),
          formGap,
        ],
        if (widget.role == 'penilai') ...[
          const NoteBox(
            title: 'Penilai / Dosen',
            text: 'Setelah dibuat, tugaskan sebagai dosen wali, pembimbing, atau penguji dari halaman detail PPDS.',
          ),
          formGap,
        ],
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nama lengkap',
            hintText: widget.role == 'penilai' ? 'Mis. Dr. Nama, dr., Sp.PA' : null,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          validator: (v) => validateRequired(v, 'Nama'),
        ),
        if (_isPpds) ...[
          formGap,
          TextFormField(
            controller: _nim,
            decoration: const InputDecoration(labelText: 'NIM', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => validateRequired(v, 'NIM'),
          ),
        ],
        formGap,
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          validator: validateEmail,
        ),
        formGap,
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Password awal',
            helperText: 'Minimal 8 karakter. Sampaikan ke pemilik akun.',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Sembunyikan' : 'Tampilkan',
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          validator: validatePassword,
        ),
      ],
    );
  }
}

/// Edit data dasar PPDS: nama, NIM, angkatan, semester, kalung, dan password.
/// Mengembalikan true bila tersimpan.
Future<bool> showEditPpdsDialog(BuildContext context, Map<String, dynamic> user) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => _EditPpdsDialog(user: user));
  return saved == true;
}

class _EditPpdsDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  const _EditPpdsDialog({required this.user});

  @override
  State<_EditPpdsDialog> createState() => _EditPpdsDialogState();
}

class _EditPpdsDialogState extends State<_EditPpdsDialog> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: textOf(widget.user['full_name']));
  late final TextEditingController _nim = TextEditingController(text: textOf(widget.user['nim']));
  late final TextEditingController _angkatan = TextEditingController(text: textOf(widget.user['angkatan']));
  final _password = TextEditingController();
  late int _semester = ((widget.user['current_semester'] as num?)?.toInt() ?? 1).clamp(1, 20);
  late String _phase = phaseOrder.contains(widget.user['phase']) ? widget.user['phase'] as String : 'MKDU';
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _nim.dispose();
    _angkatan.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final oldPhase = widget.user['phase'] ?? 'MKDU';
    if (_phase != oldPhase) {
      final ok = await confirmDialog(
        context,
        title: 'Ubah kalung secara manual?',
        message: 'Kalung ${textOf(widget.user['full_name'])} akan diubah dari ${phaseLabel(oldPhase)} '
            'menjadi ${phaseLabel(_phase)}. Kenaikan Merah ke Kuning ke Hijau biasanya otomatis '
            'setelah Ujian Organ I/II disetujui.',
        confirmText: 'Ubah kalung',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final uid = widget.user['id'] as int;
    final ok = await _api.adminSaveProfile(uid, {
      'full_name': _name.text.trim(),
      'nim': _nim.text.trim(),
      'angkatan': _angkatan.text.trim(),
      'current_semester': _semester,
      'phase': _phase,
    });
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = _api.lastError ?? 'Gagal menyimpan data PPDS.';
      });
      return;
    }
    if (_password.text.isNotEmpty) {
      final passOk = await _api.updateUser(uid, {'password': _password.text});
      if (!mounted) return;
      if (!passOk) {
        setState(() {
          _busy = false;
          _error = 'Data tersimpan, tetapi password gagal diganti. Coba lagi.';
        });
        return;
      }
    }
    showSnack(context, 'Data PPDS diperbarui');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return FormDialogFrame(
      title: 'Edit data PPDS',
      formKey: _formKey,
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => validateRequired(v, 'Nama'),
        ),
        formGap,
        TextFormField(
          controller: _nim,
          decoration: const InputDecoration(labelText: 'NIM', prefixIcon: Icon(Icons.badge_outlined)),
          validator: (v) => validateRequired(v, 'NIM'),
        ),
        formGap,
        TextFormField(
          controller: _angkatan,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Angkatan (mis. 2024)', prefixIcon: Icon(Icons.groups_outlined)),
          validator: (v) => (v ?? '').trim().length > 10 ? 'Maksimal 10 karakter' : null,
        ),
        formGap,
        DropdownButtonFormField<int>(
          initialValue: _semester,
          decoration: const InputDecoration(labelText: 'Semester', prefixIcon: Icon(Icons.school_outlined)),
          items: [for (int i = 1; i <= 20; i++) DropdownMenuItem(value: i, child: Text('Semester $i'))],
          onChanged: (v) => setState(() => _semester = v ?? _semester),
        ),
        formGap,
        DropdownButtonFormField<String>(
          initialValue: _phase,
          decoration: const InputDecoration(labelText: 'Kalung', prefixIcon: Icon(Icons.military_tech_outlined)),
          items: [
            for (final p in phaseOrder)
              DropdownMenuItem(
                value: p,
                child: Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: phaseColor(p), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(phaseLabel(p)),
                ]),
              ),
          ],
          onChanged: (v) => setState(() => _phase = v ?? _phase),
        ),
        formGap,
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Password baru (opsional)',
            helperText: 'Kosongkan bila tidak diganti. Minimal 8 karakter.',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Sembunyikan' : 'Tampilkan',
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          validator: (v) => validatePassword(v, required: false),
        ),
      ],
    );
  }
}
