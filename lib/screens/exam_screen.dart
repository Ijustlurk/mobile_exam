import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:http/http.dart' as http;
import 'student_dashboard.dart';
import 'otp_screen.dart';
import 'package:mo_be/screens/results_screen.dart';


/// 🌟 Fade navigation helper
void navigateWithFade(BuildContext context, Widget destination) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ),
    (route) => false,
  );
}

// ------------------------ EXAM SCREEN ------------------------

class ExamScreen extends StatefulWidget {
  final String studentId;
  final String subject;
  final String examId;

  const ExamScreen({
    super.key,
    required this.studentId,
    required this.subject,
    required this.examId,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  late Box examBox;
   bool isExamInProgress = true;
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _questionScrollController = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};

  final List<Map<String, dynamic>> questions = [
      // 🧠 Multiple Choice Questions (10)
    {
      'id': 'q1',
      'type': 'mcq',
      'question': 'What is the capital of the Philippines?',
      'choices': ['Manila', 'Baguio City', 'Cebu', 'Davao'],
      'correct': 'Manila',
      'marks': 1,
    },
    {
      'id': 'q2',
      'type': 'mcq',
      'question': 'Which planet is known as the Red Planet?',
      'choices': ['Earth', 'Mars', 'Jupiter', 'Venus'],
      'correct': 'Mars',
      'marks': 1,
    },
    {
      'id': 'q3',
      'type': 'mcq',
      'question': 'Which language is primarily used for Flutter development?',
      'choices': ['Dart', 'Java', 'Python', 'C#'],
      'correct': 'Dart',
      'marks': 1,
    },
    {
      'id': 'q4',
      'type': 'mcq',
      'question': 'What is the largest ocean on Earth?',
      'choices': ['Atlantic', 'Indian', 'Pacific', 'Arctic'],
      'correct': 'Pacific',
      'marks': 1,
    },
    {
      'id': 'q5',
      'type': 'mcq',
      'question': 'Which of the following is a web browser?',
      'choices': ['Chrome', 'Windows', 'Linux', 'Python'],
      'correct': 'Chrome',
      'marks': 1,
    },
    {
      'id': 'q6',
      'type': 'mcq',
      'question': 'Which of these is not a programming language?',
      'choices': ['Java', 'HTML', 'Python', 'C++'],
      'correct': 'HTML',
      'marks': 1,
    },
    {
      'id': 'q7',
      'type': 'mcq',
      'question': 'Who developed the theory of relativity?',
      'choices': ['Isaac Newton', 'Albert Einstein', 'Nikola Tesla', 'Galileo Galilei'],
      'correct': 'Albert Einstein',
      'marks': 1,
    },
    {
      'id': 'q8',
      'type': 'mcq',
      'question': 'What year did World War II end?',
      'choices': ['1945', '1939', '1918', '1950'],
      'correct': '1945',
      'marks': 1,
    },
    {
      'id': 'q9',
      'type': 'mcq',
      'question': 'Which data structure works on FIFO principle?',
      'choices': ['Stack', 'Queue', 'Array', 'Tree'],
      'correct': 'Queue',
      'marks': 1,
    },
    {
      'id': 'q10',
      'type': 'mcq',
      'question': 'What does CPU stand for?',
      'choices': ['Central Processing Unit', 'Computer Personal Unit', 'Central Peripheral Unit', 'Control Processing Unit'],
      'correct': 'Central Processing Unit',
      'marks': 1,
    },

    // ✏️ Identification (5)
    {
      'id': 'q11',
      'type': 'identification',
      'question': 'What is the smallest prime number?',
      'correct': '2',
      'marks': 1,
    },
    {
      'id': 'q12',
      'type': 'identification',
      'question': 'Who is known as the “Father of Computers”?',
      'correct': 'Charles Babbage',
      'marks': 1,
    },
    {
      'id': 'q13',
      'type': 'identification',
      'question': 'What do you call the device used to input text into a computer?',
      'correct': 'Keyboard',
      'marks': 1,
    },
    {
      'id': 'q14',
      'type': 'identification',
      'question': 'What programming language is used to design web pages along with CSS?',
      'correct': 'HTML',
      'marks': 1,
    },
    {
      'id': 'q15',
      'type': 'identification',
      'question': 'What unit is used to measure computer memory?',
      'correct': 'Byte',
      'marks': 1,
    },

    // 🧮 Enumeration
    {
      'id': 'q16',
      'type': 'enumeration',
      'question': 'List at least 3 programming languages.',
      'correct': 'C#, C++, Python',
      'marks': 2,
    },

    // 📝 Essay
    {
      'id': 'q17',
      'type': 'essay',
      'question': 'Explain why data privacy is important in 3-5 sentences.',
      'correct': 'Data privacy is important because it protects sensitive information and builds user trust.',
      'marks': 5,
    },
  ];

  Map<String, dynamic> studentAnswers = {};
  Set<String> flaggedQuestions = {};
  bool showSummary = false;
  bool submitted = false;
  bool syncing = false;
  bool flaggedSuspicious = false;
  bool showSuspiciousBanner = false;
  bool _isWarningDialogVisible = false;
  bool _isExamPausedOverlayVisible = false;
  int _backgroundExitCount = 0;
  int _currentQuestionIndex = 0;
  int _lastHandledBackgroundCount = 0; 

  static const int examDurationSeconds = 60 * 30;
  Timer? _timer;
  int _remainingSeconds = examDurationSeconds;

  Timer? _autoSyncTimer;
  static const int autoSyncIntervalSeconds = 15;

  late String attemptId;

  @override
  void initState() {
    super.initState();

    _saveExamProgress();
    WidgetsBinding.instance.addObserver(this);
    examBox = Hive.box('examBox');
    _pageController = PageController(initialPage: _currentQuestionIndex);

    _secureExamEnvironment();
    

    for (var q in questions) {
    if (q['type'] == 'mcq') q['choices'] = List<String>.from(q['choices'])..shuffle();
    // Initialize FocusNode for text fields
    if (q['type'] == 'identification' || q['type'] == 'enumeration' || q['type'] == 'essay') {
      _focusNodes[q['id']] = FocusNode();
      _focusNodes[q['id']]!.addListener(() {
        if (_focusNodes[q['id']]!.hasFocus) {
          // Scroll to the question when focused
          _scrollToCurrentQuestion();
        }
      });
    }
  }
  questions.shuffle();

  WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUnfinishedExam());
}

  Future<void> _secureExamEnvironment() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      await WakelockPlus.enable();
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (e) {
      debugPrint("Security setup failed: $e");
    }
  }
  

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(seconds: autoSyncIntervalSeconds),
      (timer) async {
        if (!submitted && studentAnswers.isNotEmpty) {
          await _syncToServer();
        }
      },
    );
  }

  

  Future<bool> _syncToServer() async {
  final attemptKey = 'attempt_${widget.examId}_${widget.studentId}';
  final metaKey = 'meta_${widget.examId}_${widget.studentId}';
  final now = DateTime.now().toIso8601String();

  // 🧾 Prepare payload to send to server
  final payload = {
    'studentId': widget.studentId,
    'examId': widget.examId,
    'answers': studentAnswers,
    'flaggedQuestions': flaggedQuestions.toList(),
    'submitted': true,
    'timestamp': now,
    'questions': questions,
  };

  final url = Uri.parse('https://yourserver.com/api/exam/submit');

  try {
    debugPrint('📡 Syncing exam ${widget.examId} for ${widget.studentId}...');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      debugPrint('✅ Sync success for ${widget.examId}');

      // 🔹 Update attempt record
      final attempt = examBox.get(attemptKey) as Map? ?? {};
      await examBox.put(attemptKey, {
        ...attempt,
        'submitted': true,
        'synced': true,
        'flagged': flaggedSuspicious,
        'lastSyncedAt': now,
        'recordType': 'attempt',
      });

      // 🔹 Update meta record (used in dashboard)
      final meta = examBox.get(metaKey) as Map? ?? {};
      await examBox.put(metaKey, {
        ...meta,
        'submitted': true,
        'completed': true,
        'available': false,
        'synced': true,
        'recordType': 'exam',
        'lastSyncedAt': now,
      });

      return true;
    } else {
      debugPrint('❌ Sync failed: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    debugPrint('⚠️ Sync error: $e');
    return false;
  }
}


  Future<void> markExamCompleted(
    String examId,
    Map<String, dynamic> answers, {
    int attemptId = 1,
  }) async {
    final examBox = Hive.box('examBox');
    final attemptKey = 'attempt_${examId}_${widget.studentId}_$attemptId';
    final metaKey = 'meta_${examId}_${widget.studentId}';
    final now = DateTime.now().toIso8601String();

    // ✅ Load attempt safely
    final rawAttempt = examBox.get(attemptKey);
    final attempt = (rawAttempt is Map)
        ? Map<String, dynamic>.from(rawAttempt)
        : <String, dynamic>{};

    // ✅ Update the attempt record
    await examBox.put(attemptKey, {
      ...attempt,
      'examId': examId,
      'studentId': widget.studentId,
      'attemptId': attemptId,
      'studentAnswers': answers,
      'submitted': true,
      'completed': true,
      'available': false,
      'completedAt': now,
      'recordType': 'attempt',
      'synced': attempt['synced'] ?? false,
    });

    // ✅ Update meta exam record (the one dashboard reads)
    final rawMeta = examBox.get(metaKey);
    final meta = (rawMeta is Map)
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};

    await examBox.put(metaKey, {
      ...meta,
      'id': examId,
      'examId': examId,
      'studentId': widget.studentId,
      'submitted': true,
      'completed': true,
      'available': false,
      'completedAt': now,
      'recordType': 'exam',
      'synced': true,
      // 🔹 Add missing data for result screen
      'questions': attempt['questions'] ?? [],
      'studentAnswers': attempt['studentAnswers'] ?? answers,
      'score': attempt['score'],
      'totalMarks': attempt['totalMarks'],
      'subject': attempt['subject'],
    });

    // ✅ Clean duplicate "exam" entries
    final duplicates = examBox.keys.where((key) {
      final record = examBox.get(key);
      return record is Map &&
          record['id'] == examId &&
          record['recordType'] == 'exam' &&
          key != metaKey;
    }).toList();

    for (var key in duplicates) {
      await examBox.delete(key);
    }

    debugPrint('✅ Cleaned ${duplicates.length} duplicate records for $examId');
    debugPrint('✅ Marked exam $examId as completed for ${widget.studentId}');

    // 🔹 Simulated sync (replace with actual upload logic if online)
    try {
      debugPrint('☁️ Synced completed exam $examId to server successfully.');
    } catch (e) {
      debugPrint('⚠️ Sync skipped (offline or failed): $e');
    }

    setState(() {}); // refresh UI
  }




  @override
  void dispose() {
    _cancelTimer();
    _pageController.dispose();
    _scrollController.dispose();
    _questionScrollController.dispose();
    for (var node in _focusNodes.values) node.dispose();
    saveLocalData();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scrollToCurrentQuestion() {
    // Scroll PageView content so the focused field is visible
      _questionScrollController.animateTo(
      _currentQuestionIndex * 300.0, // approximate offset per question card
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
  
  void _cancelTimer() => _timer?.cancel();
  

  // Lifecycle changes
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (!mounted || submitted) return;

  switch (state) {
    case AppLifecycleState.paused:
    case AppLifecycleState.inactive:
      _handleExitAttempt();
      break;
    case AppLifecycleState.resumed:
      if (!submitted && (_timer == null || !(_timer?.isActive ?? false))) {
        startTimer();
      }
      _syncToServer();
      _checkExamStatus();
      break;
    default:
      break;
  }
}

// Back button pressed
Future<bool> _onWillPop() async {
  if (submitted) return true;

  _handleExitAttempt();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Back navigation is disabled during the exam."),
      duration: Duration(seconds: 2),
    ),
  );

  return false;
}


// Update _handleExitAttempt
void _handleExitAttempt() {
  if (!mounted || submitted) return;

  flaggedSuspicious = true;
  showSuspiciousBanner = true;

  if (_backgroundExitCount == _lastHandledBackgroundCount) {
    _backgroundExitCount++;
    _lastHandledBackgroundCount = _backgroundExitCount;

    saveLocalData();
    _saveExamProgress();
    _cancelTimer();

    if (_backgroundExitCount >= 3) {
      submitExam(autoSubmitted: true);
      return;
    }

    if (!_isWarningDialogVisible) {
      _isExamPausedOverlayVisible = true; // show overlay

      String message;
      if (_backgroundExitCount == 1) {
        message = "You left the exam window. Please return immediately.";
      } else {
        message = "⚠️ You left the exam again. Leaving one more time will auto-submit your exam.";
      }
      _showWarningDialog(message);
    }
  }

  setState(() {});
}

// Update _showWarningDialog
void _showWarningDialog(String message) {
  if (!mounted) return;

  _isWarningDialogVisible = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      // Prevent dialog from being dismissed by back button
      onWillPop: () async => false,
      child: Stack(
        children: [
          // Frozen semi-transparent overlay
          if (_isExamPausedOverlayVisible)
            Opacity(
              opacity: 0.6,
              child: ModalBarrier(
                dismissible: false,
                color: Colors.black38,
              ),
            ),
          Center(
            child: AlertDialog(
              title: const Text("Exam Paused"),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!mounted) return;

                    Navigator.pop(context);
                    _isWarningDialogVisible = false;
                    _isExamPausedOverlayVisible = false; // hide overlay

                    if (!submitted) startTimer();
                  },
                  child: const Text("Continue Exam"),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}




  String generateAttemptId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'exam_${widget.examId}_${widget.studentId}_$timestamp';
  }

  void _checkForUnfinishedExam() {
  String resumeKey = '${widget.examId}_${widget.studentId}';
  final savedRef = examBox.get(resumeKey);

  
  if (savedRef != null) {
    final savedAttemptId = savedRef['attemptId'];
    attemptId = savedRef['attemptId'] ?? generateAttemptId();
    final savedSubmitted = savedRef['submitted'] is bool ? savedRef['submitted'] : false;

    if (!savedSubmitted) {
      attemptId = savedAttemptId ?? generateAttemptId();
      _showResumeDialog();
      return;
    }
  } else {
    attemptId = generateAttemptId();
    saveLocalData();
  }

  _startExamNormally();
}

  void _showResumeDialog() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Resume Exam"),
          content: const Text(
              "An unfinished exam was found. Would you like to resume your previous attempt or start fresh?"),
          actions: [
            TextButton(
              onPressed: () {
                // Start fresh attempt
                attemptId = generateAttemptId();
                if (!mounted) return;
                Navigator.pop(context);
                // Reset local data
                studentAnswers.clear();
                flaggedQuestions.clear();
                _remainingSeconds = examDurationSeconds;
                submitted = false;
                flaggedSuspicious = false;

                saveLocalData();
                _startExamNormally();
              },
              child: const Text("Start New"),
            ),
            ElevatedButton(
              onPressed: () {
                // Resume previous attempt safely
                if (!mounted) return;
                Navigator.pop(context);

                // Use stored attemptId to load correct answers and state
                loadLocalData();
                startTimer();
                _startAutoSync();
              },
            child: const Text("Resume"),
          ),
        ],
      ),
    );
  });
}


  void _startExamNormally() {
    loadLocalData();
    startTimer();
    _startAutoSync();
  }

  void loadLocalData() {
    final saved = examBox.get(attemptId);
    setState(() {
      studentAnswers = saved != null
          ? Map<String, dynamic>.from(saved['answers'] ?? {})
          : {};
      flaggedQuestions = saved != null
          ? Set<String>.from(saved['flaggedQuestions'] ?? [])
          : {};
      _remainingSeconds = saved != null
          ? (saved['remainingTime'] ?? examDurationSeconds).toInt()
          : examDurationSeconds;
      submitted = saved != null ? saved['submitted'] ?? false : false;
      flaggedSuspicious = saved != null ? saved['flagged'] ?? false : false;
    });

    // Always update resume reference to ensure next resume works
    examBox.put('${widget.examId}_${widget.studentId}', {
      'attemptId': attemptId,
      'submitted': submitted,
    });
  }


  void saveLocalData() {
    examBox.put(attemptId, {
      'attemptId': attemptId,
      'recordType': 'attempt',
      'answers': studentAnswers,
      'flaggedQuestions': flaggedQuestions.toList(),
      'remainingTime': _remainingSeconds,
      'submitted': submitted,
      'synced': false,
      'flagged': flaggedSuspicious,
      'questions': questions,
    });

    // Save quick reference for resume check
    examBox.put('${widget.examId}_${widget.studentId}', {
      'attemptId': attemptId,
      'submitted': submitted,
    });
  }

  void startTimer() {
  _cancelTimer();
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    // 1️⃣ Countdown logic
    if (_remainingSeconds <= 0) {
      _cancelTimer();
      if (!submitted) submitExam();
    } else {
      _remainingSeconds--;
    }

    // 2️⃣ Auto-save logic every 30 seconds
    if (_remainingSeconds % 30 == 0 && !submitted) {
      _saveExamProgress();
      saveLocalData();
    }

    setState(() {}); // refresh UI every second
  });
}


  String formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _saveExamProgress() async {
  // Example: save time left and current answers to Hive
  final box = await Hive.openBox('examProgress');
  box.put(widget.examId, {
    'answers': studentAnswers,
    'timeLeft': _remainingSeconds,
    'inProgress': true,
  });
}

  void _checkExamStatus() async {
    final box = await Hive.openBox('examProgress');
    final savedData = box.get(widget.examId);

    if (savedData != null && savedData['inProgress'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Resume Exam?'),
          content: const Text(
              'You had an unfinished exam. Would you like to continue where you left off?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeExam(savedData);
              },
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                submitExam();
              },
              child: const Text('Submit Now'),
            ),
          ],
        ),
      );
    }
  }

  void _resumeExam(Map savedData) {
    setState(() {
      studentAnswers = Map<String, dynamic>.from(savedData['answers']);
      _remainingSeconds = savedData['timeLeft'];
    });
  }

  Future<void> _confirmSubmitExam(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Submit Exam?"),
        content: const Text(
            "Once submitted, you can no longer change your answers.\nDo you wish to continue?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Submit")),
        ],
      ),
    );
    if (confirm == true) submitExam();
  }

  Future<void> submitExam({bool autoSubmitted = false}) async {
  if (!mounted) return;
  setState(() => syncing = true);

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  bool synced = await _syncToServer();
  await markExamCompleted(widget.examId, studentAnswers);

  num totalMarks = 0;
  num correctMarks = 0;

  for (var q in questions) {
    totalMarks += (q['marks'] ?? 1).toInt();
    final correctAnswer = q['correct']?.toString().trim().toLowerCase();
    final studentAnswer = studentAnswers[q['id']]?.toString().trim().toLowerCase();
    if (q['type'] == 'mcq' || q['type'] == 'true_false' || q['type'] == 'identification') {
      if (studentAnswer == correctAnswer) correctMarks += (q['marks'] ?? 1).toInt();
    }
  }

  final scorePercentage = (totalMarks > 0) ? (correctMarks / totalMarks) * 100 : 0;

  final attemptKey = 'attempt_${widget.examId}_${widget.studentId}';
  final metaKey = 'meta_${widget.examId}_${widget.studentId}';
  final existingMeta = examBox.get(metaKey) as Map? ?? {};

  await examBox.put(attemptKey, {
    'attemptId': attemptId,
    'examId': widget.examId,
    'studentId': widget.studentId,
    'subject': widget.subject,
    'answers': studentAnswers,
    'flaggedQuestions': flaggedQuestions.toList(),
    'submitted': true,
    'completed': true,
    'flagged': flaggedSuspicious,
    'synced': synced,
    'score': scorePercentage,
    'totalMarks': totalMarks,
    'correctMarks': correctMarks,
    'completedAt': DateTime.now().toIso8601String(),
    'questions': questions,
    'recordType': 'attempt',
  });

  await examBox.put(metaKey, {
    ...existingMeta,
    'id': widget.examId,
    'studentId': widget.studentId,
    'subject': widget.subject,
    'submitted': true,
    'available': false,
    'completed': true,
    'allowReview': existingMeta['allowReview'] ?? false,
    'score': correctMarks,
    'totalMarks': totalMarks,
    'studentAnswers': studentAnswers,
    'questions': questions,
    'resultsReleased': true,
    'synced': synced || (existingMeta['synced'] == true),
    'recordType': 'exam',
    'completedAt': DateTime.now().toIso8601String(),
  });

  setState(() {
    syncing = false;
    submitted = true;
  });

  if (mounted && Navigator.canPop(context)) Navigator.pop(context);

  if (!mounted) return;

  final allowReview = (examBox.get(metaKey)?['allowReview'] ?? false) as bool;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(autoSubmitted ? "Exam Auto-Submitted" : "Exam Submitted"),
      content: Text(autoSubmitted
          ? "The exam was auto-submitted after multiple exits."
          : "Your exam has been successfully submitted."),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (allowReview) {
              navigateWithFade(
                context,
                ReviewScreen(
                  duration: const Duration(minutes: 1),
                  studentAnswers: studentAnswers,
                  flaggedQuestions: flaggedQuestions,
                  questions: questions,
                  flagged: flaggedSuspicious,
                  studentId: widget.studentId,
                ),
              );
            } else {
              navigateWithFade(
                context,
                StudentDashboard(studentId: widget.studentId));
            }
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );
}


  double getAnswerProgress() {
    if (questions.isEmpty) return 0.0;
    int answeredCount = studentAnswers.entries
        .where((entry) => questions.any(
            (q) => q['id'] == entry.key &&
                entry.value != null &&
                entry.value.toString().isNotEmpty))
        .length;
    return answeredCount / questions.length;
  }

  Widget buildQuestion(Map<String, dynamic> q) {
  final isFlagged = flaggedQuestions.contains(q['id']);
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(q['question'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: Icon(
                  isFlagged ? Icons.flag : Icons.outlined_flag,
                  color: isFlagged ? Colors.orange : Colors.grey,
                ),
                onPressed: submitted
                    ? null
                    : () {
                        setState(() {
                          if (isFlagged)
                            flaggedQuestions.remove(q['id']);
                          else
                            flaggedQuestions.add(q['id']);
                        });
                        saveLocalData();
                      },
              )
            ],
          ),
          const SizedBox(height: 12),
          if (q['type'] == 'mcq' || q['type'] == 'true_false')
            ...q['choices'].map<Widget>((opt) {
              return RadioListTile<String>(
                title: Text(opt),
                value: opt,
                groupValue: studentAnswers[q['id']] as String?,
                onChanged: submitted
                    ? null
                    : (String? value) {
                        setState(() {
                          studentAnswers[q['id']] = value;
                        });
                        saveLocalData();
                        _saveExamProgress();
                      },
                activeColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          if (q['type'] == 'identification' ||
              q['type'] == 'enumeration' ||
              q['type'] == 'essay')
            TextFormField(
              focusNode: _focusNodes[q['id']],
              initialValue: studentAnswers[q['id']],
              enabled: !submitted,
              maxLines: q['type'] == 'essay' ? null : 1,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: q['type'] == 'enumeration'
                    ? 'List answers separated by commas'
                    : 'Your answer...',
              ),
              onChanged: (val) {
                studentAnswers[q['id']] = val;
                saveLocalData();
                _saveExamProgress();
              },
            ),
        ],
      ),
    ),
  );
}

  void _navigateToQuestion(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _currentQuestionIndex = index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = 58;
    double targetScrollOffset =
        (index * itemWidth) - screenWidth / 2 + itemWidth / 2;

    if (targetScrollOffset < 0) targetScrollOffset = 0;
    _scrollController.animateTo(
      targetScrollOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }


  Widget buildQuestionNavigation() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final answered = studentAnswers[questions[index]['id']] != null &&
              studentAnswers[questions[index]['id']].toString().isNotEmpty;
          final flagged = flaggedQuestions.contains(questions[index]['id']);
          final isCurrent = _currentQuestionIndex == index;

          Color color = isCurrent
              ? Colors.blueAccent
              : answered
                  ? Colors.green
                  : flagged
                      ? Colors.orange
                      : Colors.grey[300]!;

          return GestureDetector(
            onTap: () => _navigateToQuestion(index),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

    Widget buildExamUI() {
      if (showSummary) {
        // Review mode remains mostly the same
        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: questions.length,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final q = questions[index];
                  final answer = studentAnswers[q['id']] ?? 'No answer';
                  final isFlagged = flaggedQuestions.contains(q['id']);
                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(q['question'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                              if (isFlagged)
                                const Icon(Icons.flag, color: Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (q['type'] == 'mcq' || q['type'] == 'true_false')
                            ...q['choices'].map((opt) {
                              bool isSelected = opt == answer;
                              return ListTile(
                                title: Text(opt),
                                leading: Radio(
                                  value: opt,
                                  groupValue: answer,
                                  onChanged: null,
                                ),
                                tileColor: isSelected ? Colors.green[100] : null,
                              );
                            }).toList(),
                          if (q['type'] == 'identification' ||
                              q['type'] == 'enumeration' ||
                              q['type'] == 'essay')
                            TextFormField(
                              initialValue: answer,
                              enabled: false,
                              maxLines: q['type'] == 'essay' ? null : 1,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => setState(() => showSummary = false),
                child: const Text("Back to Exam"),
              ),
            )
          ],
        );
      }

      // ---------- Regular Exam Mode ----------
      return Column(
        children: [
          if (showSuspiciousBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.redAccent,
              child: const Text(
                "⚠️ Suspicious activity detected! Leaving the exam may lead to automatic submission.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: getAnswerProgress(),
                  backgroundColor: Colors.grey[300],
                  color: Colors.blueAccent,
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  "Progress: ${(getAnswerProgress() * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          buildQuestionNavigation(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) => setState(() => _currentQuestionIndex = index),
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  controller: _questionScrollController,
                  padding: const EdgeInsets.all(12),
                  child: buildQuestion(questions[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0
                      ? () => _navigateToQuestion(_currentQuestionIndex - 1)
                      : null,
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: _currentQuestionIndex < questions.length - 1
                      ? () => _navigateToQuestion(_currentQuestionIndex + 1)
                      : null,
                  child: const Text("Next"),
                ),
                ElevatedButton(
                  onPressed: submitted ? null : () => _confirmSubmitExam(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Submit Exam"),
                ),
              ],
            ),
          ),
        ],
      );
    }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text("${widget.subject} Exam"),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Time Left: ${formatTime(_remainingSeconds)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 60 ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            body: syncing ? const SizedBox() : buildExamUI(),
          ),
          if (syncing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ------------------------ REVIEW SCREEN ------------------------

class ReviewScreen extends StatefulWidget {
  final Duration duration;
  final Map<String, dynamic> studentAnswers;
  final Set<String> flaggedQuestions;
  final List<Map<String, dynamic>> questions;
  final bool flagged;
  final String studentId;

  const ReviewScreen({
    super.key,
    required this.duration,
    required this.studentAnswers,
    required this.flaggedQuestions,
    required this.questions,
    required this.flagged,
    required this.studentId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late int remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.duration.inSeconds;
    _startTimer();
  }

  void _startTimer() {
    _cancelTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) _finishReview();
      else setState(() => remainingSeconds--);
    });
  }

  void _cancelTimer() => _timer?.cancel();

  Future<void> _finishReview() async {
  _cancelTimer();
  if (!mounted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateWithFade(
      context,
      StudentDashboard(studentId: widget.studentId),
    );
  });
}


  String formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Review Period")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "You have ${formatTime(remainingSeconds)} to review your answers.",
              style: TextStyle(
                fontSize: 18,
                color: remainingSeconds <= 60 ? Colors.red : Colors.black,
              ),
            ),
          ),

          // ⚠️ Suspicious activity banner
          if (widget.flagged)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              child: const Text(
                "⚠️ Warning: App interruption detected during the exam. Your exam may have been auto-submitted if repeated.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          Expanded(
            child: ListView(
              children: widget.questions.map((q) {
                final isFlagged = widget.flaggedQuestions.contains(q['id']);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(q['question'])),
                        if (isFlagged)
                          const Icon(Icons.flag, color: Colors.orange, size: 18),
                      ],
                    ),
                    subtitle: Text(
                        "Answer: ${widget.studentAnswers[q['id']] ?? 'No answer'}"),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _finishReview,
              child: const Text("Finish Review Now"),
            ),
          ),
        ],
      ),
    );
  }
}
