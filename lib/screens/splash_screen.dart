import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool showM = false;
  double logoOpacity = 0.0;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _gradientController;
  late Timer logoTimer;
  late Timer letterTimer;
  late Timer navigationTimer;

  @override
  void initState() {
    super.initState();

    // Flip animation controller
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _flipAnimation =
        Tween<double>(begin: 0.0, end: pi).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // Gradient animation controller (looping)
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Fade-in logo
    logoTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        logoOpacity = 1.0;
      });
    });

    // Trigger flip transition (O → M)
    letterTimer = Timer(const Duration(milliseconds: 1500), () {
      _flipController.forward().then((_) {
        setState(() {
          showM = true;
        });
      });
    });

    // Navigate to Login
    navigationTimer = Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    logoTimer.cancel();
    letterTimer.cancel();
    navigationTimer.cancel();
    _flipController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.lobster(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: [
        Shadow(
          blurRadius: 15,
          color: Colors.blue.shade200.withOpacity(0.9),
          offset: const Offset(0, 0),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        // Animate gradient stops between two sets of colors
        final colors = [
          Color.lerp(const Color(0xFF1565C0), const Color(0xFF1E88E5),
              _gradientController.value)!,
          Color.lerp(const Color(0xFF42A5F5), const Color(0xFF90CAF9),
              _gradientController.value)!,
        ];

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Fade-In
                  AnimatedOpacity(
                    duration: const Duration(seconds: 1),
                    opacity: logoOpacity,
                    child: Image.asset('assets/CicsLogo.png', width: 120),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'College of Information and Computing Sciences',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Flip animation O → M
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final isFirstHalf = _flipAnimation.value < pi / 2;
                      final rotationValue = isFirstHalf
                          ? _flipAnimation.value
                          : _flipAnimation.value - pi;

                      return Transform(
                        transform: Matrix4.rotationY(rotationValue),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isFirstHalf ? 'O' : 'M', style: textStyle),
                            Text('obe', style: textStyle),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
