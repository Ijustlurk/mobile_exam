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
  
  // Results data - now using the combined structure from API
  List<Map<String, dynamic>> results = []; // Combined question + answer + correctness
  Map<String, dynamic>? statistics; // Pre-calculated statistics from API
  Map<String, dynamic>? attemptInfo; // Attempt metadata
  
  // Legacy support for old cache format
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

    // Load from API after loading from Hive (as enhancement, not replacement)
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
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🔍 LOADING EXAM RESULTS FROM HIVE');
    debugPrint('   Exam ID: ${widget.examId} (type: ${widget.examId.runtimeType})');
    debugPrint('   Student ID: ${widget.studentId} (type: ${widget.studentId.runtimeType})');
    debugPrint('   Expected key pattern: attempt_${widget.examId}_${widget.studentId}');
    
    final allKeys = examBox.keys.toList(); // Don't cast to String - keys can be int or String
    debugPrint('   Total Hive keys: ${allKeys.length}');
    debugPrint('   All keys: $allKeys');

    // Debug all attempt records
    for (var key in allKeys) {
      final record = examBox.get(key);
      if (record is Map && record['recordType'] == 'attempt') {
        debugPrint('   Attempt Record:');
        debugPrint('      Key: $key');
        debugPrint('      Attempt ID: ${record['attemptId']}');
        debugPrint('      Exam ID: ${record['examId']}');
        debugPrint('      Student ID: ${record['studentId']}');
        debugPrint('      Questions count: ${record['questions']?.length ?? 0}');
        debugPrint('      Answers count: ${(record['answers'] ?? record['studentAnswers'])?.length ?? 0}');
      }
    }

    final matchingAttempts = allKeys.where((key) {
      final record = examBox.get(key);
      return record is Map &&
          record['recordType'] == 'attempt' &&
          record['examId']?.toString() == widget.examId &&
          record['studentId']?.toString() == widget.studentId;
    }).toList();

    debugPrint('   Matching attempts: ${matchingAttempts.length}');

    if (matchingAttempts.isNotEmpty) {
      // Get the attempt with the highest attempt_id (most recent)
      dynamic latestAttempt;
      int highestAttemptId = 0;
      dynamic latestKey;
      
      for (var key in matchingAttempts) {
        final record = examBox.get(key);
        final currentAttemptId = record['attemptId'] is int 
            ? record['attemptId'] 
            : int.tryParse(record['attemptId'].toString()) ?? 0;
        
        if (currentAttemptId > highestAttemptId) {
          highestAttemptId = currentAttemptId;
          latestAttempt = record;
          latestKey = key;
        }
      }
      
      final attempt = Map<String, dynamic>.from(latestAttempt);

      debugPrint('   ✅ Found matching attempt:');
      debugPrint('      Key: $latestKey');
      debugPrint('      Attempt ID: ${attempt['attemptId']} (highest)');
      debugPrint('      Attempt data keys: ${attempt.keys.toList()}');

      final loadedAnswers = Map<String, dynamic>.from(
        attempt['answers'] ?? attempt['studentAnswers'] ?? {},
      );
      
      final loadedQuestions = attempt['questions'] != null
          ? List<Map<String, dynamic>>.from(attempt['questions'])
          : [];

      debugPrint('      Questions loaded: ${loadedQuestions.length}');
      debugPrint('      Answers loaded: ${loadedAnswers.length}');
      
      if (loadedQuestions.isNotEmpty) {
        debugPrint('      First question: ${loadedQuestions[0]['question']}');
        debugPrint('      First question ID: ${loadedQuestions[0]['id']}');
      }
      
      if (loadedAnswers.isNotEmpty) {
        debugPrint('      Answer keys: ${loadedAnswers.keys.toList()}');
        debugPrint('      First answer: ${loadedAnswers.values.first}');
      }

      // If questions are missing from cache, we'll try to fetch from API later
      if (loadedQuestions.isEmpty && loadedAnswers.isNotEmpty) {
        debugPrint('      ⚠️ Questions missing from cache - will fetch from API');
      }

      setState(() {
        studentAnswers = loadedAnswers;
        questions = List<Map<String, dynamic>>.from(loadedQuestions);
        flagged = attempt['flagged'] ?? false;
        loaded = true;
      });

      debugPrint('   State updated:');
      debugPrint('      questions.length: ${questions.length}');
      debugPrint('      studentAnswers.length: ${studentAnswers.length}');
      debugPrint('      loaded: $loaded');
      debugPrint('═══════════════════════════════════════════════════════');

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
      debugPrint('   ❌ No matching attempts found');
      debugPrint('═══════════════════════════════════════════════════════');
      
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
  int getCorrectCount() {
    // Use statistics from API if available
    if (statistics != null && statistics!['correctAnswers'] != null) {
      return statistics!['correctAnswers'] as int;
    }
    
    // Otherwise count from results array
    if (results.isNotEmpty) {
      return results.where((r) => r['isCorrect'] == true).length;
    }
    
    // Fallback to legacy manual checking
    return questions.where((q) {
      final correct = q['correct']?.toString().trim().toLowerCase();
      final answer = studentAnswers[q['id']]?.toString().trim().toLowerCase();
      return correct != null && correct == answer;
    }).length;
  }

  int getIncorrectCount() {
    // Use statistics from API if available
    if (statistics != null && statistics!['incorrectAnswers'] != null) {
      return statistics!['incorrectAnswers'] as int;
    }
    
    // Otherwise count from results array
    if (results.isNotEmpty) {
      return results.where((r) => r['isCorrect'] == false).length;
    }
    
    // Fallback to legacy
    return questions.length - getCorrectCount();
  }

  int getUnansweredCount() {
    // Use statistics from API if available
    if (statistics != null && statistics!['unanswered'] != null) {
      return statistics!['unanswered'] as int;
    }
    
    // Otherwise count from results array
    if (results.isNotEmpty) {
      return results.where((r) => 
        r['studentAnswer'] == null || r['studentAnswer'].toString().isEmpty
      ).length;
    }
    
    // Fallback to legacy
    return questions.length -
        studentAnswers.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .length;
  }

  List<Map<String, dynamic>> getFilteredQuestions() {
    // Use new results structure if available
    if (results.isNotEmpty) {
      switch (filter) {
        case FilterOption.correct:
          return results.where((r) => r['isCorrect'] == true).toList();
        case FilterOption.incorrect:
          return results.where((r) => r['isCorrect'] == false).toList();
        default:
          return results;
      }
    }
    
    // Fallback to legacy structure
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

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📊 RESULTS SCREEN BUILD');
    debugPrint('   Results: ${results.length} (new format)');
    debugPrint('   Questions: ${questions.length} (legacy)');
    debugPrint('   Student Answers: ${studentAnswers.length} (legacy)');
    debugPrint('   Statistics: ${statistics != null ? "Available" : "Not available"}');
    debugPrint('═══════════════════════════════════════════════════════');

    // Check if we have data in either format
    final hasData = results.isNotEmpty || questions.isNotEmpty;
    
    if (!hasData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No results available.',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'The exam results could not be loaded.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => navigateToDashboard(context, widget.studentId),
                icon: const Icon(Icons.dashboard),
                label: const Text("Back to Dashboard"),
              ),
            ],
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
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔍 LOADING EXAM RESULTS FROM API');
      debugPrint('   Exam ID: ${widget.examId}');
      debugPrint('   Student ID: ${widget.studentId}');
      
      // First, try to get attemptId from Hive cache
      final allKeys = examBox.keys.toList(); // Don't cast to String - keys can be int or String
      debugPrint('   Total Hive keys: ${allKeys.length}');
      
      final matchingAttempts = allKeys.where((key) {
        final record = examBox.get(key);
        final isAttempt = record is Map && record['recordType'] == 'attempt';
        if (isAttempt) {
          debugPrint('   Found attempt record:');
          debugPrint('      Attempt ID: ${record['attemptId']}');
          debugPrint('      Exam ID: ${record['examId']}');
          debugPrint('      Student ID: ${record['studentId']}');
          
          // Match by examId and studentId fields, not by attemptId substring
          final examIdMatch = record['examId']?.toString() == widget.examId;
          final studentIdMatch = record['studentId']?.toString() == widget.studentId;
          
          debugPrint('      Exam ID match: $examIdMatch');
          debugPrint('      Student ID match: $studentIdMatch');
          
          return examIdMatch && studentIdMatch;
        }
        return false;
      }).toList();

      debugPrint('   Matching attempts found: ${matchingAttempts.length}');

      if (matchingAttempts.isEmpty) {
        debugPrint('⚠️ No attempt found in cache for exam ID: ${widget.examId}');
        debugPrint('   Cannot fetch from API without attempt ID');
        return;
      }

      // Get the attempt with the highest attempt_id (most recent)
      dynamic latestAttempt;
      int highestAttemptId = 0;
      
      for (var key in matchingAttempts) {
        final record = examBox.get(key);
        final currentAttemptId = record['attemptId'] is int 
            ? record['attemptId'] 
            : int.tryParse(record['attemptId'].toString()) ?? 0;
        
        if (currentAttemptId > highestAttemptId) {
          highestAttemptId = currentAttemptId;
          latestAttempt = record;
        }
      }
      
      final attempt = Map<String, dynamic>.from(latestAttempt);
      final attemptId = attempt['attemptId'];

      debugPrint('   Using attempt with highest ID: $attemptId');

      if (attemptId == null) {
        debugPrint('⚠️ Attempt ID is null');
        return;
      }

      debugPrint('📡 Fetching results from API for attempt: $attemptId');
      final apiResponse = await ApiService.fetchExamResults(attemptId: attemptId is int ? attemptId : int.parse(attemptId.toString()));
      
      debugPrint('   API Response: ${apiResponse != null ? 'Received' : 'Null'}');
      if (apiResponse != null) {
        debugPrint('   Response keys: ${apiResponse.keys.toList()}');
      }
      
      if (apiResponse != null && !apiResponse.containsKey('error')) {
        debugPrint('✅ API returned results data');
        
        setState(() {
          // New structure: results array with correctness data
          if (apiResponse['results'] != null && apiResponse['results'] is List) {
            results = List<Map<String, dynamic>>.from(apiResponse['results']);
            debugPrint('   📊 Results: ${results.length} items with correctness data');
            
            // Also populate legacy structures for backward compatibility
            questions = results.map((r) => {
              'id': r['id'],
              'question': r['question'],
              'type': r['type'],
              'choices': r['choices'],
              'correct': r['correctAnswer'],
              'marks': r['maxPoints'],
            }).toList();
            
            studentAnswers = Map.fromEntries(
              results.map((r) => MapEntry(r['id'] as String, r['studentAnswer']))
            );
          } 
          // Legacy structure: separate questions and answers arrays
          else {
            if (apiResponse['answers'] != null) {
              studentAnswers = Map<String, dynamic>.from(apiResponse['answers']);
            }
            
            if (apiResponse['questions'] != null && apiResponse['questions'] is List) {
              questions = List<Map<String, dynamic>>.from(apiResponse['questions']);
            }
            
            debugPrint('   📊 Legacy format - Questions: ${questions.length}, Answers: ${studentAnswers.length}');
          }
          
          // Store statistics if available
          if (apiResponse['statistics'] != null) {
            statistics = Map<String, dynamic>.from(apiResponse['statistics']);
            debugPrint('   📈 Statistics: ${statistics!['correctAnswers']}/${statistics!['totalQuestions']} correct');
          }
          
          // Store attempt info if available
          if (apiResponse['attempt'] != null) {
            attemptInfo = Map<String, dynamic>.from(apiResponse['attempt']);
          }
        });
        
        debugPrint('   ✅ State updated successfully');
      } else {
        debugPrint('⚠️ No results found from API: ${apiResponse?['error'] ?? 'Unknown error'}');
        debugPrint('   Using Hive cache data instead');
      }
      debugPrint('═══════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error loading exam results from API: $e');
      debugPrint('   Stack trace: $stackTrace');
      debugPrint('   Falling back to Hive cache data');
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

  /// Get the display text for an answer (converts key to text if needed)
  String getAnswerDisplayText(Map<String, dynamic> question, dynamic answerValue) {
    if (answerValue == null || answerValue.toString().isEmpty) {
      return "No answer provided";
    }

    final answerStr = answerValue.toString();
    
    // For MCQ and True/False, convert key to text from choices
    if ((question['type'] == 'mcq' || question['type'] == 'true_false') && 
        question['choices'] != null) {
      final choices = question['choices'] as List;
      
      // Handle comma-separated multiple selections
      if (answerStr.contains(',')) {
        final selectedKeys = answerStr.split(',').map((s) => s.trim()).toList();
        final selectedTexts = selectedKeys.map((key) {
          final choice = choices.firstWhere(
            (c) => c['key'].toString().toLowerCase() == key.toLowerCase(),
            orElse: () => {'text': key},
          );
          return choice['text'];
        }).join(', ');
        return selectedTexts;
      }
      
      // Single selection
      final choice = choices.firstWhere(
        (c) => c['key'].toString().toLowerCase() == answerStr.toLowerCase(),
        orElse: () => {'text': answerStr},
      );
      return choice['text'].toString();
    }
    
    // For other types, return as-is
    return answerStr;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: ValueKey(filter),
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        
        // New format: use isCorrect directly from API
        bool? isCorrect;
        dynamic studentAnswer;
        dynamic correctAnswer;
        
        if (q.containsKey('isCorrect')) {
          // New API format with correctness data
          isCorrect = q['isCorrect'];
          studentAnswer = q['studentAnswer'];
          correctAnswer = q['correctAnswer'];
        } else {
          // Legacy format: manual checking
          final answer = studentAnswers[q['id']];
          final correct = q['correct'];
          isCorrect = correct?.toString().trim().toLowerCase() ==
              answer?.toString().trim().toLowerCase();
          studentAnswer = answer;
          correctAnswer = correct;
        }

        // Determine status color and icon
        Color statusColor;
        IconData statusIcon;
        
        if (studentAnswer == null || studentAnswer.toString().isEmpty) {
          statusColor = Colors.grey;
          statusIcon = Icons.help_outline;
        } else if (isCorrect == true) {
          statusColor = Colors.green.shade600;
          statusIcon = Icons.check_circle;
        } else if (isCorrect == false) {
          statusColor = Colors.red.shade600;
          statusIcon = Icons.cancel;
        } else {
          // Manually graded (essay) - null
          statusColor = Colors.orange.shade600;
          statusIcon = Icons.pending;
        }

        // Get display text for answers
        final studentAnswerText = getAnswerDisplayText(q, studentAnswer);
        final correctAnswerText = getAnswerDisplayText(q, correctAnswer);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: statusColor.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: ExpansionTile(
            key: Key(q['id'].toString()),
            leading: Icon(
              statusIcon,
              color: statusColor,
              size: 28,
            ),
            title: Text(
              q['question'] ?? "Question",
              style: const TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isCorrect == true ? Icons.check : Icons.close,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Your answer: $studentAnswerText",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (correctAnswer != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Correct answer: $correctAnswerText",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Show points if available
                    if (q.containsKey('pointsAwarded') && q.containsKey('maxPoints')) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Points: ${q['pointsAwarded']} / ${q['maxPoints']}",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    
                    // Show feedback if available (for essays)
                    if (q.containsKey('feedback') && q['feedback'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.feedback,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q['feedback'],
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
