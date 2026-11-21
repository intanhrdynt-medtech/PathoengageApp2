import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/screens/register_screen.dart';

/// Halaman awal sebelum login: logo, nama aplikasi, tombol Masuk & Daftar.
class StartingPage extends StatefulWidget {
  const StartingPage({super.key});

  @override
  State<StartingPage> createState() => _StartingPageState();
}

class _StartingPageState extends State<StartingPage> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _buttonController;
  late final Animation<double> _logoAnimation;
  late final Animation<double> _textAnimation;
  late final Animation<double> _buttonAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _textController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _buttonController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _logoAnimation = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    _textAnimation = CurvedAnimation(parent: _textController, curve: Curves.easeOutBack);
    _buttonAnimation = CurvedAnimation(parent: _buttonController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _buttonController, curve: Curves.easeOut));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.secondaryPink, AppColors.secondaryMagenta, AppColors.darkMagenta, AppColors.primaryDark],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Lingkaran dekoratif
            Positioned(top: -50, right: -50, child: _circle(200, const Color(0xFFFFCEB7).withValues(alpha: 0.1))),
            Positioned(top: 100, left: -30, child: _circle(100, Colors.white.withValues(alpha: 0.08))),
            Positioned(bottom: -30, left: -20, child: _circle(150, Colors.white.withValues(alpha: 0.05))),

            SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final logoSize = math.min(180.0, constraints.maxHeight * 0.24);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: _logoAnimation,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset('assets/images/logounair.png',
                                        width: logoSize, height: logoSize, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              AnimatedBuilder(
                                animation: _textAnimation,
                                builder: (context, child) => Opacity(
                                  opacity: _textAnimation.value.clamp(0.0, 1.0),
                                  child: Transform.translate(
                                      offset: Offset(0, 30 * (1 - _textAnimation.value)), child: child),
                                ),
                                child: Column(children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white, AppColors.primaryLight.withValues(alpha: 0.6)],
                                    ).createShader(bounds),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('PathoEngage',
                                          style: TextStyle(
                                              fontSize: 44,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.2)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: Colors.white.withValues(alpha: 0.15),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      'Pencatatan kasus & kompetensi terpadu\nuntuk PPDS Patologi Anatomi UNAIR',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white, height: 1.4),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 48),
                              SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _buttonAnimation,
                                  child: Column(children: [
                                    _GradientButton(
                                      icon: Icons.login,
                                      label: 'Masuk',
                                      onPressed: () => _open(const LoginScreen()),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () => _open(const RegisterScreen()),
                                        icon: const Icon(Icons.person_add),
                                        label: const Text('Daftar akun baru',
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Akun penilai dan admin dibuat oleh admin program studi.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _GradientButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.accentRed, AppColors.primaryPurple]),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
