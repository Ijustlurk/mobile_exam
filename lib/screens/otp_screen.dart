import 'package:flutter/material.dart';
import 'results_screen.dart';

class OTPScreen extends StatefulWidget {
  final String examId;
  final String subject;
  final String? expectedOTP;
  final bool forResults;
  final String studentId;
  final VoidCallback? onVerified;

  const OTPScreen({
    super.key,
    required this.examId,
    required this.subject,
    this.expectedOTP,
    this.forResults = false,
    required this.studentId,
    this.onVerified,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController otpController = TextEditingController();
  bool isVerifying = false;
  bool isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation =
        Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
  }

  Future<void> verifyOTP() async {
    setState(() {
      isVerifying = true;
      isError = false;
    });

    await Future.delayed(const Duration(seconds: 1));

    final enteredOTP = otpController.text.trim();
    final expectedOTP = widget.expectedOTP ?? "";

    if (expectedOTP.isEmpty || enteredOTP == expectedOTP) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.forResults
              ? "✅ OTP Verified! Loading Results..."
              : "✅ OTP Verified! Starting Exam..."),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      if (widget.forResults) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              examId: widget.examId,
              studentId: widget.studentId,
            ),
          ),
        );
      } else {
        widget.onVerified?.call();
      }
    } else {
      setState(() => isError = true);
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("❌ Invalid OTP. Please try again."),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => isVerifying = false);
  }

  @override
  void dispose() {
    otpController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.forResults ? "Verify OTP to View Results" : "Verify OTP to Start Exam";

    final subtitle = widget.forResults
        ? "Enter the OTP provided by your instructor to access your results."
        : "Enter the OTP provided by your instructor to begin your exam.";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 60,
                        color: Colors.blueAccent.shade700,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subject,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Animated OTP box
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(isError ? _shakeAnimation.value : 0, 0),
                            child: child,
                          );
                        },
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "••••••",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isError ? Colors.red : Colors.blueAccent, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isError
                                      ? Colors.red.shade300
                                      : Colors.grey.shade400,
                                  width: 1.5),
                            ),
                            prefixIcon: const Icon(Icons.key_rounded),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isVerifying ? null : verifyOTP,
                          icon: isVerifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user),
                          label: Text(
                            isVerifying
                                ? "Verifying..."
                                : (widget.forResults
                                    ? "Verify & View Results"
                                    : "Verify & Start Exam"),
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Back to Dashboard"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
