import 'dart:async';
import 'package:flutter/material.dart';
import 'login_info_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool showM = false;
  late Timer logoTimer;
  late Timer letterTimer;
  late Timer navigationTimer;
  double logoOpacity = 0.0;

  @override
  void initState() {
    super.initState();

    // Fade in logo
    logoTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        logoOpacity = 1.0;
      });
    });

    // Animate letter change from 'o' to 'M'
    letterTimer = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        showM = true;
      });
    });

    // Navigate to login screen
    navigationTimer = Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginInfoScreen()),
      );
    });
  }

  @override
  void dispose() {
    logoTimer.cancel();
    letterTimer.cancel();
    navigationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo fade in
            AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: logoOpacity,
              child: Image.asset('assets/CsuLogo.png', width: 120),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cagayan State University - Aparri Campus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Animated Text "Mobe"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    showM ? 'M' : 'o',
                    key: ValueKey(showM),
                    style: GoogleFonts.lobster(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  'obe',
                  style: GoogleFonts.lobster(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
