import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/auth_service.dart';
import 'package:fp_pemrograman/screens/register_screen.dart';
import 'package:fp_pemrograman/screens/dashboard_screen.dart';
import 'package:fp_pemrograman/screens/admin_dashboard_screen.dart';
import 'package:fp_pemrograman/screens/evaluator_screen.dart';

import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool _isLoading = false;
  bool _isPasswordObscure = true;

  void _tryLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      dynamic result = await _auth.signInWithEmailAndPassword(email, password);

      if (!mounted) return;
      if (result == null) {
        setState(() {
          error = 'Login Failed: Could not connect to API.';
          _isLoading = false;
        });
      } else if (result['success'] == false) {
          setState(() {
          error = 'Login Failed: ${result['message'] ?? 'Could not sign in with those credentials.'}';
          _isLoading = false;
        });
      } else {
        if (result['role'] == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
        } else if (result['role'] == 'penilai') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EvaluatorScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double designWidth = 1080.0;
    final double designHeight = 1920.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final double scaleX = screenWidth / designWidth;
    final double scaleY = screenHeight / designHeight;

    double scaleW(double val) => val * scaleX;
    double scaleH(double val) => val * scaleY;
    double scaleFont(double val) => val * min(scaleX, scaleY);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.secondaryPink,
                        AppColors.secondaryMagenta,
                        AppColors.darkMagenta,
                        AppColors.primaryDark,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: screenWidth,
                    height: screenHeight * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(scaleW(120)),
                        topRight: Radius.circular(scaleW(120)),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: scaleH(350)),
                        Text(
                          'Login',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: scaleFont(120),
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentRed, // merah tua
                            shadows: [
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black.withValues(alpha: 0.25),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: scaleH(100)),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Container(
                              width: screenWidth,
                              padding: EdgeInsets.symmetric(horizontal: screenWidth > 600 ? 0 : scaleW(100)),
                              child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildTextFieldWithIcon(
                                  context: context,
                                  hint: 'Enter your email',
                                  icon: Icons.email_outlined,
                                  onChanged: (val) => email = val,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    // Simple email regex validation
                                    const emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
                                    if (!RegExp(emailPattern).hasMatch(val)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                SizedBox(height: scaleH(50)),
                                _buildTextFieldWithIcon(
                                  context: context,
                                  hint: 'Enter password',
                                  icon: Icons.lock_outline,
                                  obscureText: _isPasswordObscure,
                                  onChanged: (val) => password = val,
                                  validator: (val) => val!.length < 6
                                      ? 'Password must be 6+ characters'
                                      : null,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordObscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.accentRed, // merah tua
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordObscure =
                                            !_isPasswordObscure;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: scaleH(50)),
                                _buildLoginButton(context),
                                SizedBox(height: scaleH(160)),
                                _buildRegisterLink(context),
                                if (error.isNotEmpty) ...[
                                  SizedBox(height: scaleH(20)),
                                  Text(
                                    error,
                                    style: TextStyle(
                                      color: AppColors.accentRed, // merah tua
                                      fontSize: scaleFont(30),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextFieldWithIcon({
    required BuildContext context,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    double scaleFont(double val) =>
        val *
        min(MediaQuery.of(context).size.width / 1080.0,
            MediaQuery.of(context).size.height / 1920.0);

    return TextFormField(
      onChanged: onChanged,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontFamily: 'Poppins', fontSize: scaleFont(40), color: Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.accentRed), // magenta-red
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle:
            TextStyle(fontFamily: 'Poppins', fontSize: scaleFont(40), color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 20.0),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    double scaleH(double val) =>
        val * MediaQuery.of(context).size.height / 1920.0;
    double scaleFont(double val) =>
        val *
        min(MediaQuery.of(context).size.width / 1080.0,
            MediaQuery.of(context).size.height / 1920.0);

    return GestureDetector(
      onTap: _tryLogin,
      child: Container(
        width: double.infinity,
        height: scaleH(160),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.accentRed],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Login',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: scaleFont(50),
              fontWeight: FontWeight.bold,
              color: Colors.white, // putih
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    double scaleFont(double val) =>
        val *
        min(MediaQuery.of(context).size.width / 1080.0,
            MediaQuery.of(context).size.height / 1920.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: scaleFont(40),
            color: Colors.black54,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RegisterScreen()),
            );
          },
          child: Text(
            'Register',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: scaleFont(40),
              fontWeight: FontWeight.bold,
              color: AppColors.accentRed, // merah tua
            ),
          ),
        ),
      ],
    );
  }
}
