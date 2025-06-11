import 'package:flutter/material.dart';
import 'student_dashboard.dart';

class OTPScreen extends StatefulWidget {
  final String studentName;
  final String college;
  final String section;

  const OTPScreen({
    super.key,
    required this.studentName,
    required this.college,
    required this.section,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final otpController = TextEditingController();

  // Map of OTPs to subject and examId
  final Map<String, Map<String, String>> otpMap = {
    'ABCDEF': {'subject': 'Computer Science', 'examId': 'EXAM_CS_001'},
    '123456': {'subject': 'Mathematics', 'examId': 'EXAM_MATH_002'},
    '654321': {'subject': 'Physics', 'examId': 'EXAM_PHYS_003'},
  };

  void verifyOTP() {
    final enteredOTP = otpController.text.trim().toUpperCase();
    if (otpMap.containsKey(enteredOTP)) {
      final examData = otpMap[enteredOTP]!;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => StudentDashboard(
                studentName: widget.studentName,
                college: widget.college,
                subject: examData['subject']!,
                examId: examData['examId']!,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid OTP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Student Name: ${widget.studentName}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "College: ${widget.college}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Year & Section: ${widget.section}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: verifyOTP,
              child: const Text('Verify & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
