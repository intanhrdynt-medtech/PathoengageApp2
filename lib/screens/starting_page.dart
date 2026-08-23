import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/screens/login_screen.dart';
import 'package:fp_pemrograman/screens/register_screen.dart';


class StartingPage extends StatefulWidget {
  const StartingPage({super.key});

  @override
  State<StartingPage> createState() => _StartingPageState();
}

class _StartingPageState extends State<StartingPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutBack),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.bounceOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _buttonController, curve: Curves.easeOut));

    // Start animations with delays
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondaryPink,
              AppColors.secondaryMagenta,
              AppColors.darkMagenta,
              AppColors.primaryDark,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating circles decoration
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 255, 206, 183)
                      .withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // Logo section with animation
                    Expanded(
                      flex: 2,
                      child: AnimatedBuilder(
                        animation: _logoAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoAnimation.value,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo with glow effect
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 180,
                                      height: 180,
                                      child: Image.asset(
                                        'assets/images/logounair.png',
                                        height: 180,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // App title with animation
                                AnimatedBuilder(
                                  animation: _textAnimation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity:
                                          _textAnimation.value.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(
                                            0, 30 * (1 - _textAnimation.value)),
                                        child: Column(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  AppColors.primaryLight.withValues(alpha: 0.6)
                                                ],
                                              ).createShader(bounds),
                                              child: Text(
                                                'PathoEngage',
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                color: Colors.white
                                                    .withValues(alpha: 0.15),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'Integrated Case & Competency\nTracking for Pathology Residents.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Buttons section with animation
                    SlideTransition(
                      position: _slideAnimation,
                      child: AnimatedBuilder(
                        animation: _buttonAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                            child: Column(
                              children: [
                                // Login Button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accentRed,
                                        AppColors.primaryPurple
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryPurple
                                            .withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.login,
                                            color: Colors.white),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Log In',
                                          style: TextStyle(fontFamily: 'Poppins', 
                                            fontSize: 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Register Button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.person_add,
                                            color: Colors.white),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Register',
                                          style: TextStyle(fontFamily: 'Poppins', 
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
