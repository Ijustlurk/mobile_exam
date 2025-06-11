import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ExamScreen extends StatefulWidget {
  final String studentName;
  final String subject;
  final String examId;

  const ExamScreen({
    super.key,
    required this.studentName,
    required this.subject,
    required this.examId,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final List<Map<String, dynamic>> questions = [
    // MCQs
    {
      'id': 'q1',
      'type': 'mcq',
      'question': 'What is the capital of France?',
      'choices': ['Paris', 'London', 'Rome', 'Berlin'],
      'correct': 'Paris',
    },
    {
      'id': 'q2',
      'type': 'mcq',
      'question': 'Which planet is known as the Red Planet?',
      'choices': ['Earth', 'Mars', 'Jupiter', 'Venus'],
      'correct': 'Mars',
    },
    {
      'id': 'q3',
      'type': 'mcq',
      'question': 'What is H2O commonly known as?',
      'choices': ['Oxygen', 'Hydrogen', 'Salt', 'Water'],
      'correct': 'Water',
    },
    {
      'id': 'q4',
      'type': 'mcq',
      'question': 'How many continents are there?',
      'choices': ['5', '6', '7', '8'],
      'correct': '7',
    },
    {
      'id': 'q5',
      'type': 'mcq',
      'question': 'Who invented the telephone?',
      'choices': ['Newton', 'Einstein', 'Bell', 'Tesla'],
      'correct': 'Bell',
    },

    // True or False
    {
      'id': 'q6',
      'type': 'true_false',
      'question': 'The sun rises in the west.',
      'correct': 'false',
    },
    {
      'id': 'q7',
      'type': 'true_false',
      'question': 'Bats are mammals.',
      'correct': 'true',
    },
    {
      'id': 'q8',
      'type': 'true_false',
      'question': 'The square root of 64 is 6.',
      'correct': 'false',
    },
    {
      'id': 'q9',
      'type': 'true_false',
      'question': 'Water freezes at 0 degrees Celsius.',
      'correct': 'true',
    },
    {
      'id': 'q10',
      'type': 'true_false',
      'question': 'Mount Everest is the tallest mountain in the world.',
      'correct': 'true',
    },

    // Essay
    {
      'id': 'q11',
      'type': 'essay',
      'question': 'Explain the importance of the water cycle in 3-5 sentences.',
    },
  ];

  final Map<String, dynamic> studentAnswers = {};
  bool showSummary = false;
  bool submitted = false;
  String? qrData;
  Map<String, dynamic>? resultData;

  // Timer
  static const int examDurationSeconds = 2 * 60; // 2 minutes
  late Timer _timer;
  int _remainingSeconds = examDurationSeconds;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void startTimer() {
    _remainingSeconds = examDurationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds == 0) {
        timer.cancel();
        if (!submitted) {
          submitExam();
        }
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void submitExam() {
    int score = 0;
    int total = 0;

    for (var q in questions) {
      if (q['type'] != 'essay') {
        total++;
        final studentAnswer =
            studentAnswers[q['id']]?.toString().toLowerCase().trim();
        final correctAnswer = q['correct'].toString().toLowerCase().trim();
        if (studentAnswer == correctAnswer) {
          score++;
        }
      }
    }

    resultData = {
      'name': widget.studentName,
      'subject': widget.subject,
      'examId': widget.examId,
      'answers': studentAnswers,
      'submittedAt': DateTime.now().toIso8601String(),
      'score': score,
      'total': total,
      'remarks': score / total >= 0.5 ? 'Passed' : 'Failed',
      'note': 'Essay question requires manual review',
    };

    final encoded = base64Encode(utf8.encode(jsonEncode(resultData)));

    setState(() {
      qrData = encoded;
      submitted = true;
    });

    _timer.cancel();
  }

  Widget buildQuestion(Map<String, dynamic> q) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q['question'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (q['type'] == 'mcq')
              ...q['choices'].map<Widget>((opt) {
                return RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                  groupValue: studentAnswers[q['id']] as String?,
                  onChanged:
                      submitted
                          ? null
                          : (String? value) {
                            setState(() {
                              studentAnswers[q['id']] = value;
                            });
                          },
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            if (q['type'] == 'true_false') ...[
              RadioListTile<String>(
                title: const Text('True'),
                value: 'true',
                groupValue: studentAnswers[q['id']] as String?,
                onChanged:
                    submitted
                        ? null
                        : (String? value) {
                          setState(() {
                            studentAnswers[q['id']] = value;
                          });
                        },
                activeColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('False'),
                value: 'false',
                groupValue: studentAnswers[q['id']] as String?,
                onChanged:
                    submitted
                        ? null
                        : (String? value) {
                          setState(() {
                            studentAnswers[q['id']] = value;
                          });
                        },
                activeColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
              ),
            ],
            if (q['type'] == 'essay') ...[
              const SizedBox(height: 6),
              TextFormField(
                initialValue: studentAnswers[q['id']],
                maxLines: 5,
                enabled: !submitted,
                onChanged: (val) => studentAnswers[q['id']] = val,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Your answer...',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSummary() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Review Your Answers',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 16),
        ...questions.map(
          (q) => Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text(q['question']),
              subtitle: Text(
                'Answer: ${studentAnswers[q['id']] ?? 'No answer'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => showSummary = false),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: Colors.orangeAccent,
              ),
              child: const Text('Edit Answers', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: submitted ? null : submitExam,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Submit & QR Code',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildQRCode() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Submission Complete"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                "Exam Submitted!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              QrImageView(data: qrData!, version: QrVersions.auto, size: 220),
              const SizedBox(height: 12),
              const Text(
                "Show this QR to your instructor.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (resultData != null)
                Text(
                  "Score: ${resultData!['score']} / ${resultData!['total']}\nRemarks: ${resultData!['remarks']}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(resultData),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  "Back to Dashboard",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child:
          submitted && qrData != null
              ? buildQRCode()
              : showSummary
              ? Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text("Review Answers"),
                  centerTitle: true,
                ),
                body: buildSummary(),
              )
              : Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: Text('${widget.subject} Exam'),
                  centerTitle: true,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(30),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Time Left: ${formatTime(_remainingSeconds)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListView(
                    children: [
                      Text(
                        'Student: ${widget.studentName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...questions.map(buildQuestion),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (studentAnswers.length < questions.length) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please answer all questions before review.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() => showSummary = true);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: const Text(
                          'Submit Answers',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }
}
