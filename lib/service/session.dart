import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penanganan sesi global: bila server menjawab 401 (token kedaluwarsa atau
/// password diganti admin), pengguna dikeluarkan dan diarahkan ke halaman
/// login — bukan dibiarkan melihat tombol "Coba lagi" terus-menerus.

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Diisi oleh main.dart dengan halaman login, supaya file ini tidak perlu
/// mengimpor layar (menghindari import melingkar).
Widget Function()? loginPageBuilder;

bool _handling = false;

Future<void> handleUnauthorized() async {
  if (_handling) return;
  _handling = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('jwt_token') == null) return; // sudah keluar
    await prefs.remove('jwt_token');
    final nav = appNavigatorKey.currentState;
    final builder = loginPageBuilder;
    if (nav == null || builder == null) return;
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => builder()), (_) => false);
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        const SnackBar(content: Text('Sesi login berakhir. Silakan masuk kembali.')),
      );
    }
  } finally {
    _handling = false;
  }
}
