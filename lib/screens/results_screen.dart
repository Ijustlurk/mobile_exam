import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pie_chart/pie_chart.dart';
import 'student_dashboard.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';

// 🧭 Navigation Helper with Fade Transition
void navigateToDashboard(BuildContext context, String studentId) {
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          StudentDashboard(studentId: studentId),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ),
    (route) => false,
  );
}

enum FilterOption { all, correct, incorrect }

class ResultsScreen extends StatefulWidget {
  final String examId;
  final String studentId;

  const ResultsScreen({
    super.key,
    required this.examId,
    required this.studentId,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late Box examBox;
  Map<String, dynamic> studentAnswers = {};
  List<Map<String, dynamic>> questions = [];
  bool flagged = false;
  bool loaded = false;
  FilterOption filter = FilterOption.all;
  final ScrollController _scrollController = ScrollController();
  bool showFAB = false;
  bool _confettiPlayed = false; 

  // ✨ Confetti controller
  late ConfettiController _confettiController;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    examBox = Hive.box('examBox');
    _loadExamResults();

    _scrollController.addListener(() {
      if (!mounted) return;
      setState(() => showFAB = _scrollController.offset > 300);
    });

    _loadExamResultsFromAPI();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }


  // 🔍 Load latest attempt and answers
  void _loadExamResults() async {
    final allKeys = examBox.keys.cast<String>().toList();

    final matchingAttempts = allKeys.where((key) {
      final record = examBox.get(key);
      return record is Map &&
          record['recordType'] == 'attempt' &&
          record['attemptId'] != null &&
          record['attemptId'].toString().contains(widget.examId) &&
          record['attemptId'].toString().contains(widget.studentId);
    }).toList();

    if (matchingAttempts.isNotEmpty) {
      final latestKey = matchingAttempts.last;
      final attempt = Map<String, dynamic>.from(examBox.get(latestKey));

      setState(() {
        studentAnswers = Map<String, dynamic>.from(
          attempt['answers'] ?? attempt['studentAnswers'] ?? {},
        );

        questions = attempt['questions'] != null
            ? List<Map<String, dynamic>>.from(attempt['questions'])
            : [];
        flagged = attempt['flagged'] ?? false;
        loaded = true;
      });

      if (mounted) _controller.forward();

      if (mounted) _controller.forward();

      // --- Confetti trigger here ---
      if (!_confettiPlayed) {
        final correctCount = getCorrectCount();
        final total = questions.length;
        final scorePercent = total == 0 ? 0 : ((correctCount / total) * 100).round();
        final passed = scorePercent >= 75;

        if (passed) {
          _confettiPlayed = true; // mark as played
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _confettiController.play();
          });
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Results loaded successfully!"),
            duration: Duration(seconds: 2),
          ),
        );
      });
    } else {
      setState(() => loaded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ No results available for this exam."),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  // 🧮 Score Computations
  int getCorrectCount() => questions.where((q) {
        final correct = q['correct']?.toString().trim().toLowerCase();
        final answer = studentAnswers[q['id']]?.toString().trim().toLowerCase();
        return correct != null && correct == answer;
      }).length;

  int getIncorrectCount() => questions.length - getCorrectCount();

  int getUnansweredCount() => questions.length -
      studentAnswers.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty)
          .length;

  List<Map<String, dynamic>> getFilteredQuestions() {
    switch (filter) {
      case FilterOption.correct:
        return questions.where((q) {
          final correct = q['correct']?.toString().trim().toLowerCase();
          final answer = studentAnswers[q['id']]?.toString().trim().toLowerCase();
          return correct == answer;
        }).toList();
      case FilterOption.incorrect:
        return questions.where((q) {
          final correct = q['correct']?.toString().trim().toLowerCase();
          final answer = studentAnswers[q['id']]?.toString().trim().toLowerCase();
          return correct != answer;
        }).toList();
      default:
        return questions;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    debugPrint('Questions: ${questions.length}');
    debugPrint('Student Answers: ${studentAnswers.length}');

    if (questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'No results available.',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final filteredQuestions = getFilteredQuestions();
    final correctCount = getCorrectCount();
    final incorrectCount = getIncorrectCount();
    final unansweredCount = getUnansweredCount();
    final total = questions.length;
    final scorePercent = total == 0 ? 0 : ((correctCount / total) * 100).round();
    final passed = scorePercent >= 75;

    final dataMap = <String, double>{
      "Correct": correctCount.toDouble(),
      "Incorrect": incorrectCount.toDouble(),
      "Unanswered": unansweredCount.toDouble(),
    };

    return Scaffold(
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: showFAB ? 1 : 0,
        child: showFAB
            ? FloatingActionButton(
                heroTag: "scrollToTop",
                onPressed: () => _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
                child: const Icon(Icons.arrow_upward),
              )
            : null,
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  color: const Color(0xFFF3F4F8),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ExamSummaryCard(
                          correctCount: correctCount,
                          incorrectCount: incorrectCount,
                          unansweredCount: unansweredCount,
                          total: total,
                          scorePercent: scorePercent,
                          passed: passed,
                          flagged: flagged,
                          dataMap: dataMap,
                          filter: filter,
                          onFilterChanged: (FilterOption newFilter) =>
                              setState(() => filter = newFilter),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: QuestionList(
                          questions: filteredQuestions,
                          studentAnswers: studentAnswers,
                          controller: _scrollController,
                          filter: filter,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _buttonFade,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                navigateToDashboard(context, widget.studentId),
                            icon: const Icon(Icons.dashboard),
                            label: const Text("Back to Dashboard"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: const Size(180, 45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🎊 Confetti animation overlay
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive, // 💥 burst outward
              emissionFrequency: 0.08,
              numberOfParticles: 40,
              gravity: 0.25,
              maxBlastForce: 30,
              minBlastForce: 10,
              shouldLoop: false,
              colors: [
                Colors.greenAccent,
                Colors.indigo,
                Colors.orange,
                Colors.pink,
                Colors.yellowAccent,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadExamResultsFromAPI() async {
    try {
      final results = await ApiService.fetchExamResults(attemptId: int.parse(widget.examId));
      if (results != null) {
        setState(() {
          studentAnswers = results['answers'] ?? {};
          questions = results['questions'] ?? [];
        });
      } else {
        debugPrint('⚠️ No results found for exam ID: ${widget.examId}');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading exam results: $e');
    } finally {
      setState(() => loaded = true);
    }
  }
}

// ✅ Improved Subwidgets (same style, cleaner animation)

class ResultBadge extends StatelessWidget {
  final bool passed;
  final int score;

  const ResultBadge({super.key, required this.passed, required this.score});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: passed ? Colors.green.shade100 : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$score%",
              style: TextStyle(
                color: passed ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              passed ? "✅ Passed" : "❌ Failed",
              style: TextStyle(
                color: passed ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExamSummaryCard extends StatelessWidget {
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final int total;
  final int scorePercent;
  final bool passed;
  final bool flagged;
  final Map<String, double> dataMap;
  final FilterOption filter;
  final ValueChanged<FilterOption> onFilterChanged;

  const ExamSummaryCard({
    super.key,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.total,
    required this.scorePercent,
    required this.passed,
    required this.flagged,
    required this.dataMap,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "📊 Exam Results Summary",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ResultBadge(passed: passed, score: scorePercent),
              ],
            ),
            if (flagged) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "⚠️ App interruption detected during the exam.",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Total", total, Colors.black),
                _buildStat("Correct", correctCount, Colors.green),
                _buildStat("Incorrect", incorrectCount, Colors.red),
                _buildStat("Unanswered", unansweredCount, Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: PieChart(
                dataMap: dataMap,
                chartType: ChartType.disc,
                chartRadius: MediaQuery.of(context).size.width * 0.28,
                colorList: [
                  Colors.green.shade400,
                  Colors.red.shade400,
                  Colors.grey.shade400
                ],
                chartValuesOptions:
                    const ChartValuesOptions(showChartValuesInPercentage: true),
                legendOptions: const LegendOptions(
                  legendPosition: LegendPosition.bottom,
                  showLegendsInRow: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                spacing: 8,
                children: FilterOption.values.map((option) {
                  final selected = filter == option;
                  final label = "${option.name[0].toUpperCase()}${option.name.substring(1)}";
                  return GestureDetector(
                    onTap: () => onFilterChanged(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.indigo.shade100 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.indigo.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.indigo.shade800 : Colors.black87,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String title, int value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          "$value",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// 📋 Clean Question List without animations
class QuestionList extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Map<String, dynamic> studentAnswers;
  final ScrollController controller;
  final FilterOption filter;

  const QuestionList({
    super.key,
    required this.questions,
    required this.studentAnswers,
    required this.controller,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: ValueKey(filter), // ensures instant rebuild on filter change
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        final answer = studentAnswers[q['id']];
        final correct = q['correct'];
        final isCorrect = correct?.toString().trim().toLowerCase() ==
            answer?.toString().trim().toLowerCase();

        Color statusColor;
        if (answer == null || answer.toString().isEmpty) {
          statusColor = Colors.grey;
        } else if (isCorrect) {
          statusColor = Colors.green.shade600;
        } else {
          statusColor = Colors.red.shade600;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: statusColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: ExpansionTile(
            key: Key(q['id'].toString()),
            leading: Icon(
              answer == null || answer.toString().isEmpty
                  ? Icons.access_time
                  : isCorrect
                      ? Icons.check_circle
                      : Icons.cancel,
              color: statusColor,
            ),
            title: Text(
              q['question'] ?? "Question",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              answer == null || answer.toString().isEmpty
                  ? "No answer"
                  : "Your answer: $answer",
              style: TextStyle(color: statusColor),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Correct answer: ${q['correct'] ?? 'N/A'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
