import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/dashboard_screen.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/widgets/ui.dart';

/// Pendaftaran akun PPDS. Setelah berhasil, token sudah disimpan oleh
/// AuthService sehingga pengguna langsung masuk ke Beranda.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  static const int _minPassword = 8;

  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nimCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _error = '';
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nimCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(String? message) {
    final m = (message ?? '').trim();
    if (m.isEmpty || m == 'Registration failed') return 'Pendaftaran gagal. Silakan coba lagi.';
    if (m.startsWith('Registration Error:') || m.contains('SocketException') || m.contains('ClientException')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.';
    }
    return m;
  }

  Future<void> _tryRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final result = await _auth.registerWithEmailAndPassword(
        _nameCtrl.text.trim(), _nimCtrl.text.trim(), _emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (result['success'] == true) {
      showSnack(context, 'Akun berhasil dibuat. Selamat datang di PathoEngage!');
      Navigator.of(context)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (_) => false);
      return;
    }
    setState(() {
      _error = _friendlyError(result['message']?.toString());
      _isLoading = false;
    });
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint, String? helper, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
      prefixIcon: Icon(icon, color: AppColors.accentRed),
      suffixIcon: suffix,
    );
  }

  Widget _eye(bool obscure, VoidCallback onTap) => IconButton(
        tooltip: obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textGrey),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(fontSize: 15);
    return AuthFrame(
      title: 'Daftar Akun',
      subtitle: 'Untuk PPDS Patologi Anatomi UNAIR.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              style: fieldStyle,
              decoration: _decoration('Nama lengkap', Icons.person_outline),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nimCtrl,
              textInputAction: TextInputAction.next,
              style: fieldStyle,
              decoration: _decoration('NIM', Icons.badge_outlined),
              validator: (v) => (v ?? '').trim().isEmpty ? 'NIM wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: fieldStyle,
              decoration: _decoration('Email', Icons.email_outlined, hint: 'nama@contoh.com'),
              validator: (val) {
                final v = (val ?? '').trim();
                if (v.isEmpty) return 'Email wajib diisi';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              style: fieldStyle,
              decoration: _decoration('Kata sandi', Icons.lock_outline,
                  helper: 'Minimal $_minPassword karakter', suffix: _eye(_obscure, () => setState(() => _obscure = !_obscure))),
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return 'Kata sandi wajib diisi';
                if (value.length < _minPassword) return 'Kata sandi minimal $_minPassword karakter';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _isLoading ? null : _tryRegister(),
              style: fieldStyle,
              decoration: _decoration('Ulangi kata sandi', Icons.lock_outline,
                  suffix: _eye(_obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm))),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Ulangi kata sandi Anda';
                if (v != _passwordCtrl.text) return 'Kata sandi tidak sama';
                return null;
              },
            ),
            const SizedBox(height: 20),
            if (_error.isNotEmpty) AuthErrorBox(_error),
            AuthSubmitButton(label: 'Daftar', loading: _isLoading, onPressed: _tryRegister),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Sudah punya akun?', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Masuk',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accentRed)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
