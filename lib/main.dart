import 'package:flutter/material.dart';
import 'package:fp_pemrograman/screens/starting_page.dart';
import 'package:fp_pemrograman/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          indicatorColor: AppColors.primaryPurple.withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryPurple);
            }
            return TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textGrey);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primaryPurple);
            }
            return IconThemeData(color: AppColors.textGrey);
          }),
        ),
      ),
      home: const StartingPage(),
    );
  }
}
