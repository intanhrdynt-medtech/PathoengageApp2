import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/admin_dashboard_screen.dart';
import 'package:fp_pemrograman/screens/dashboard_screen.dart';
import 'package:fp_pemrograman/screens/evaluator_screen.dart';
import 'package:fp_pemrograman/screens/register_screen.dart';
import 'package:fp_pemrograman/service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _error = '';
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(String? message) {
    final m = (message ?? '').trim();
    if (m.isEmpty) return 'Email atau kata sandi salah.';
    if (m.startsWith('Error:') || m.contains('SocketException') || m.contains('ClientException')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.';
    }
    return m;
  }

  Future<void> _tryLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final result = await _auth.signInWithEmailAndPassword(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (result == null || result['success'] == false) {
      setState(() {
        _error = _friendlyError(result?['message']?.toString());
        _isLoading = false;
      });
      return;
    }

    final role = result['role'];
    final Widget home = role == 'admin'
        ? const AdminDashboardScreen()
        : role == 'penilai'
            ? const EvaluatorScreen()
            : const DashboardScreen();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => home), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Masuk',
      subtitle: 'Masuk dengan email yang terdaftar di PathoEngage.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'nama@contoh.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.accentRed),
              ),
              validator: (val) {
                final v = (val ?? '').trim();
                if (v.isEmpty) return 'Email wajib diisi';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _isLoading ? null : _tryLogin(),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.accentRed),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textGrey),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (val) => (val ?? '').isEmpty ? 'Kata sandi wajib diisi' : null,
            ),
            const SizedBox(height: 20),
            if (_error.isNotEmpty) AuthErrorBox(_error),
            AuthSubmitButton(label: 'Masuk', loading: _isLoading, onPressed: _tryLogin),
            const SizedBox(height: 12),
            const Text(
              'Lupa kata sandi? Hubungi admin program studi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Belum punya akun?', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Daftar',
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

// ── Komponen tampilan halaman Masuk & Daftar (dipakai juga oleh RegisterScreen) ──

class AuthFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const AuthFrame({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.secondaryPink, AppColors.secondaryMagenta, AppColors.darkMagenta, AppColors.primaryDark],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
                        ]),
                        child: ClipOval(
                          child: Image.asset('assets/images/logounair.png',
                              width: 84, height: 84, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthErrorBox extends StatelessWidget {
  final String message;
  const AuthErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.errorRed, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.errorRed))),
      ]),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const AuthSubmitButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primaryPurple, AppColors.accentRed]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
