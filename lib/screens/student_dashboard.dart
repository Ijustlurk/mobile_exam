import 'package:flutter/material.dart';
import 'exam_screen.dart';
import '../screens/mode_selection_screen.dart';

/// ResultScreen
class ResultScreen extends StatefulWidget {
  final String examId;
  final String studentName;

  const ResultScreen({
    super.key,
    required this.examId,
    required this.studentName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool isLoading = true;
  Map<String, dynamic>? results;

  @override
  void initState() {
    super.initState();
    fetchResults();
  }

  Future<void> fetchResults() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate fetch delay

    final mockResultData = {
      'score': 85,
      'total': 100,
      'remarks': 'Well done!',
      'released': true, // Toggle to false to simulate unreleased results
    };

    setState(() {
      results = mockResultData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exam Results")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : results == null || !(results!['released'] as bool)
              ? const Center(
                child: Text(
                  "Results not yet released by admin.",
                  style: TextStyle(fontSize: 16),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Student: ${widget.studentName}",
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Score: ${results!['score']} / ${results!['total']}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Remarks: ${results!['remarks']}",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
    );
  }
}

/// StudentDashboard
class StudentDashboard extends StatefulWidget {
  final String studentName;
  final String college;
  final String subject;
  final String examId;

  const StudentDashboard({
    super.key,
    required this.studentName,
    required this.college,
    required this.subject,
    required this.examId,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool hasSubmittedExam = false;
  Map<String, dynamic>? examResult;

  void onExamSubmitted(Map<String, dynamic> resultData) {
    setState(() {
      hasSubmittedExam = true;
      examResult = resultData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Offline Exam"),
          backgroundColor: Colors.blueAccent,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync Now',
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Sync triggered")));
              },
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Back to Mode Selection',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModeSelectionScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileHeader(),
              const SizedBox(height: 20),
              offlineModeNote(),
              const SizedBox(height: 20),
              const Text(
                "Your Exam",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              examCard(),

              if (hasSubmittedExam && examResult != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "Submission History",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                submissionCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget profileHeader() {
    return Row(
      children: [
        const CircleAvatar(radius: 30, child: Icon(Icons.person)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.studentName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(widget.college, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget offlineModeNote() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange),
          SizedBox(width: 8),
          Text("Offline Mode: Data will sync when online"),
        ],
      ),
    );
  }

  Widget examCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Placeholder(fallbackHeight: 100),
          const SizedBox(height: 8),
          Text(
            "Subject: ${widget.subject}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton(
              onPressed:
                  hasSubmittedExam
                      ? null
                      : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ExamScreen(
                                  studentName: widget.studentName,
                                  subject: widget.subject,
                                  examId: widget.examId,
                                ),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          onExamSubmitted(result);
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSubmittedExam ? Colors.grey : Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              child: Text(
                hasSubmittedExam ? "Exam Submitted" : "Start Exam",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget submissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Status: ✅ Submitted",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text("Score: ${examResult!['score']} / ${examResult!['total']}"),
          const SizedBox(height: 6),
          Text("Remarks: ${examResult!['remarks']}"),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ResultScreen(
                        examId: widget.examId,
                        studentName: widget.studentName,
                      ),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
            label: const Text("View Detailed Results"),
          ),
        ],
      ),
    );
  }
}
