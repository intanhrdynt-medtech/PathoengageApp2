import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/service/session.dart';
import 'package:fp_pemrograman/screens/admin_dashboard_screen.dart';
import 'package:fp_pemrograman/screens/dashboard_screen.dart';
import 'package:fp_pemrograman/screens/evaluator_screen.dart';
import 'package:fp_pemrograman/screens/starting_page.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/service/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  loginPageBuilder = () => const LoginScreen();
  runApp(const MyApp());
}

/// Di web/desktop, daftar juga bisa digeser & ditarik (pull-to-refresh) dengan mouse.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scrollBehavior: const _AppScrollBehavior(),
      title: 'PathoEngage - PPDS PA UNAIR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryPurple,
          primary: AppColors.primaryPurple,
          secondary: AppColors.secondaryMagenta,
          tertiary: AppColors.accentRed,
          surface: AppColors.backgroundLightest,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLightest,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accentRed, width: 2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primaryPurple.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryPurple);
            }
            return const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primaryPurple);
            }
            return const IconThemeData(color: AppColors.textGrey);
          }),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Colors.white,
          selectedLabelTextStyle: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryPurple),
          unselectedLabelTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textGrey),
          selectedIconTheme: IconThemeData(color: AppColors.primaryPurple),
          unselectedIconTheme: IconThemeData(color: AppColors.textGrey),
        ),
      ),
      home: const _SessionGate(),
    );
  }
}

/// Splash: memeriksa token tersimpan lewat /me lalu membuka halaman sesuai
/// peran. Tanpa token / token tidak valid -> halaman awal.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

enum _GateState { checking, offline, done }

class _SessionGateState extends State<_SessionGate> {
  _GateState _state = _GateState.checking;
  Widget? _target;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _GateState.checking);
    final auth = AuthService();
    final token = await auth.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _target = const StartingPage();
        _state = _GateState.done;
      });
      return;
    }

    final api = ApiService();
    final me = await api.getMe();
    if (!mounted) return;

    if (me == null) {
      final err = api.lastError ?? '';
      // Hanya keluarkan pengguna bila token memang ditolak (401). Gangguan lain
      // (jaringan, server sedang sibuk) -> tawarkan coba lagi, token tetap disimpan.
      if (api.lastStatus != 401) {
        setState(() {
          _message = err;
          _state = _GateState.offline;
        });
        return;
      }
      // Token tidak valid / kedaluwarsa.
      await auth.signOut();
      if (!mounted) return;
      setState(() {
        _target = const StartingPage();
        _state = _GateState.done;
      });
      return;
    }

    final role = me['role'];
    setState(() {
      _target = role == 'admin'
          ? const AdminDashboardScreen()
          : role == 'penilai'
              ? const EvaluatorScreen()
              : const DashboardScreen();
      _state = _GateState.done;
    });
  }

  Future<void> _useOtherAccount() async {
    await AuthService().signOut();
    if (!mounted) return;
    setState(() {
      _target = const StartingPage();
      _state = _GateState.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _GateState.done && _target != null) return _target!;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.secondaryPink, AppColors.secondaryMagenta, AppColors.darkMagenta, AppColors.primaryDark],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset('assets/images/logounair.png',
                        width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                  const SizedBox(height: 20),
                  const Text('PathoEngage',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 28),
                  if (_state == _GateState.checking) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text('Memeriksa sesi login...', style: TextStyle(fontSize: 14, color: Colors.white)),
                  ] else ...[
                    const Icon(Icons.cloud_off, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    Text(_message ?? 'Tidak dapat terhubung ke server.',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: _check,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: _useOtherAccount,
                      child: const Text('Masuk dengan akun lain', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
