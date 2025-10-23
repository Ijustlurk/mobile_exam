import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  const StudentDashboard({super.key, required this.studentId});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _connectionStatus = "Checking connection...";
  Color _bannerColor = Colors.grey.shade300;
  late Box examBox;
  bool _isSyncing = false;
  bool _isRefreshing = false;
  bool _isManualSyncing = false;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = false;

    @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initHive();
    _initConnectivity();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _updateConnectionStatus(result);
      if (result != ConnectivityResult.none) _autoSync();
    });

    _scrollController.addListener(() {
      if (!mounted) return;
      setState(() => _showFAB = _scrollController.offset > 200);
    });
  }

  Future<void> _initHive() async {
  examBox = await Hive.openBox('examBox');

  // ✅ Ensure every existing record has a proper 'recordType'
  for (var key in examBox.keys) {
    final record = examBox.get(key);
    if (record is Map && record['recordType'] == null) {
      await examBox.put(key, {...record, 'recordType': 'exam'});
    }
  }

  // 🧹 Clean malformed or old entries (safety measure)
  for (var key in examBox.keys.toList()) {
    if (key is! String || !key.contains('_')) {
      await examBox.delete(key);
    }
  }

  final mockData = _mockExamData();

  // ✅ Insert mock exams only if they don't exist yet
  for (var exam in mockData) {
    final metaKey = 'meta_${exam['id']}_${widget.studentId}';
    final existing = examBox.get(metaKey);

    if (existing == null) {
      await examBox.put(metaKey, {
        ...exam,
        'recordType': 'exam',
        'studentId': widget.studentId,
        'attemptId': 1,
        'submitted': exam['submitted'] ?? false,
        'available': !(exam['submitted'] ?? false),
        'flagged': false,
        'completedAt': null,
        'questions': exam['questions'] ?? [],
      });
    }
  }

  debugPrint("🗂️ All exams in Hive after init:");
  for (var e in examBox.values) {
    debugPrint(e.toString());
  }

  setState(() {}); // refresh UI
}


  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      switch (result) {
        case ConnectivityResult.wifi:
          _connectionStatus = "Online via Wi-Fi: Exams synced automatically.";
          _bannerColor = Colors.green.shade100;
          break;
        case ConnectivityResult.mobile:
          _connectionStatus = "Online (Mobile Data): Sync may be slower.";
          _bannerColor = Colors.yellow.shade100;
          break;
        case ConnectivityResult.none:
          _connectionStatus = "Offline Mode: Showing cached exams.";
          _bannerColor = Colors.red.shade100;
          break;
        default:
          _connectionStatus = "Unknown network status.";
          _bannerColor = Colors.grey.shade300;
      }
    });
  }

  //autosynccccccccc................
  Future<void> _autoSync() async {
    if (!mounted || _isSyncing) return;

    setState(() => _isSyncing = true);

    final mockData = _mockExamData();
    final updates = <Future>[];

    // Track metaKeys from mockData
    final seenMetaKeys = <String>{};

    for (var exam in mockData) {
      final metaKey = 'meta_${exam['id']}_${widget.studentId}';
      seenMetaKeys.add(metaKey);

      final existing = examBox.get(metaKey);

      if (existing != null) {
        // ✅ Skip overwriting fully submitted exams
        if (existing['submitted'] == true) {
          continue; 
        }

        // Merge existing data with new data from mockData
        final updated = {
          ...exam, // new info
          'recordType': 'exam',
          'studentId': widget.studentId,
          'submitted': existing['submitted'] ?? exam['submitted'] ?? false,
          'studentAnswers': existing['studentAnswers'] ?? exam['studentAnswers'] ?? {},
          'available': !(existing['submitted'] ?? exam['submitted'] ?? false),
          'completedAt': existing['completedAt'],
          'flagged': existing['flagged'] ?? false,
          'questions': existing['questions'] ?? [],
        };

        updates.add(examBox.put(metaKey, updated));
      } else {
        // Insert new record if it doesn't exist yet
        updates.add(examBox.put(metaKey, {
          ...exam,
          'recordType': 'exam',
          'studentId': widget.studentId,
          'attemptId': 1,
          'submitted': exam['submitted'] ?? false,
          'studentAnswers': exam['studentAnswers'] ?? {},
          'available': !(exam['submitted'] ?? false),
          'flagged': false,
          'completedAt': null,
          'questions': exam['questions'] ?? [],
        }));
      }
    }

    // Sync any "attempt" records
    for (var key in examBox.keys.toList()) {
      final record = examBox.get(key);
      if (record is Map && record['recordType'] == 'attempt') {
        final updatedAttempt = {
          ...record,
          'synced': true,
          'lastSyncedAt': DateTime.now().toIso8601String(),
        };
        updates.add(examBox.put(key, updatedAttempt));
      }
    }

    // Clean orphaned exams that are not in mockData
    for (var key in examBox.keys.toList()) {
      final record = examBox.get(key);
      if (record is Map && record['recordType'] == 'exam') {
        final metaKey = 'meta_${record['id']}_${record['studentId']}';
        if (!seenMetaKeys.contains(metaKey) && record['submitted'] != true) {
          updates.add(examBox.delete(key));
        }
      }
    }

    await Future.wait(updates);

    if (!mounted) return;
    setState(() => _isSyncing = false);

    // User feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("✅ Sync complete! Data updated successfully."),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }



  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _autoSync();
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isRefreshing = false);
  }


  List<Map<String, dynamic>> _mockExamData() => [
      {
        "id": "exam01",
        "subject": "Dummy Exam1",
        "date": "10/20/2025",
        "available": true, // can be taken
        "requiresOtp": true,
        "resultsReleased": false,
        "submitted": false,
        "studentAnswers": {},
      },
      {
        "id": "exam02",
        "subject": "Dummy Exam2",
        "date": "10/05/2025",
        "available": false,
        "requiresOtp": false,
        "resultsReleased": false,
        "submitted": true,
        "studentAnswers": {"q1": "C", "q2": "D"},
      }
    ];


  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {  
    final allExams = examBox.values
    .where((e) => e is Map && e['recordType'] == 'exam' && e['studentId'] == widget.studentId)
    .cast<Map>()
    .toList();

    // ✅ Available exams: only not submitted AND exam is available
    final availableExams = allExams
        .where((e) => e['available'] == true && e['submitted'] == false)
        .toList();

    // ✅ Completed exams: only submitted
    final completedExams = allExams
        .where((e) => e['submitted'] == true)
        .toList();


    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _showFAB ? 1 : 0,
        child: _showFAB
            ? FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut);
                },
                child: const Icon(Icons.arrow_upward),
              )
            : null,
      ),
      body: Column(
        children: [
          ConnectivityBanner(
            status: _connectionStatus,
            color: _bannerColor,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: TabBarView(
                controller: _tabController,
                children: [
                  ExamList(
                    exams: availableExams,
                    studentId: widget.studentId,
                    completed: false,
                    scrollController: _scrollController,
                  ),
                  ExamList(
                    exams: completedExams,
                    studentId: widget.studentId,
                    completed: true,
                    scrollController: _scrollController,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() => AppBar(
      title: Text("Welcome, ${widget.studentId}"),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        if (_isManualSyncing)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Manual Sync',
            onPressed: () async {
              setState(() => _isManualSyncing = true);
              final start = DateTime.now();

              try {
                await _autoSync();
                final duration = DateTime.now().difference(start);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "✅ Sync complete in ${duration.inSeconds}s!",
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("❌ Sync failed: $e"),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isManualSyncing = false);
              }
            },
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: "Available"),
          Tab(text: "Completed"),
        ],
      ),
    );

}

// ---------- Modular Widgets ---------- //

class ConnectivityBanner extends StatelessWidget {
  final String status;
  final Color color;
  const ConnectivityBanner({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: color,
      child: Row(
        children: [
          Icon(status.startsWith("Offline") ? Icons.wifi_off : Icons.wifi,
              color: status.startsWith("Offline") ? Colors.red : Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(status, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class ExamList extends StatelessWidget {
  final List<Map> exams;
  final String studentId;
  final bool completed;
  final ScrollController scrollController;

  const ExamList({
    super.key,
    required this.exams,
    required this.studentId,
    required this.completed,
    required this.scrollController,
  });

  void _navigateWithOtp({
    required BuildContext context,
    required String subject,
    required String route,
    required Map arguments,
    required bool forResults,
  }) {
    Navigator.pushNamed(context, '/otp', arguments: {
      'subject': subject,
      'expectedOTP': '1234',
      'forResults': forResults,
      'studentId': studentId,
      'onVerified': () => Navigator.pushNamed(context, route, arguments: arguments),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return const Center(
        child: Text("No exams found.", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        final examId = (exam['id'] ?? '').toString();
        final subject = (exam['subject'] ?? 'Unknown Subject').toString();
        final date = (exam['date'] ?? 'No date set').toString();
        final requiresOtp = exam['requiresOtp'] ?? false;
        final resultsReleased = exam['resultsReleased'] ?? false;
        final submitted = exam['submitted'] ?? false;

        final buttonText = completed
        ? (resultsReleased ? "View Results" : "Pending Results")
        : "Take Exam";

        // ✅ Button enabled only if:
        // - Taking exam: available && not submitted
        // - Viewing results: resultsReleased
        final isButtonEnabled = !completed
            ? exam['available'] == true && !exam['submitted']
            : resultsReleased;

        void onButtonPressed() {
          if (!isButtonEnabled) return;

          final route = completed ? '/results' : '/exam';
          final arguments = completed
              ? {'examId': examId, 'studentId': studentId}
              : {'studentId': studentId, 'subject': subject, 'examId': examId};

          if (requiresOtp) {
            _navigateWithOtp(
              context: context,
              subject: subject,
              route: route,
              arguments: arguments,
              forResults: completed,
            );
          } else {
            Navigator.pushNamed(context, route, arguments: arguments);
          }
        }


        // Determine card color
        final cardColor = completed
            ? Colors.orange.shade50
            : Colors.blue.shade50;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onButtonPressed,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject title
                    Text(
                      subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Date and Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Date: $date",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        // ✅ Replace the Row below with a Wrap
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              if (requiresOtp)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "OTP",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              if (completed)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: resultsReleased
                                        ? Colors.green.shade100
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    resultsReleased ? "Results Ready" : "Pending",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: resultsReleased
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              if (submitted)
                                  (exam['synced'] == true)
                                      ? Container(
                                          constraints: const BoxConstraints(maxWidth: 80),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            border: Border.all(color: Colors.green.shade200),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              "Synced ✅",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        )
                                      : TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.6, end: 1.0),
                                          duration: const Duration(seconds: 1),
                                          curve: Curves.easeInOut,
                                          builder: (context, value, child) {
                                            return Opacity(
                                              opacity: value,
                                              child: Container(
                                                constraints: const BoxConstraints(maxWidth: 80),
                                                padding:
                                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  border: Border.all(color: Colors.orange.shade200),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    "Syncing…",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        onEnd: () {
                                          if (context.mounted) {
                                            (context as Element).markNeedsBuild();
                                          }
                                        },
                                      ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isButtonEnabled ? onButtonPressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: completed ? Colors.orange : Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            buttonText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
