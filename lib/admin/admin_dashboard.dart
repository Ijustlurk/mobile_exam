import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'exam_edit_screen.dart';
import 'exam_model.dart';
import '../screens/mode_selection_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Exam> exams = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadExamsFromPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExamsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final examListString = prefs.getString('exams');
    if (examListString != null) {
      final List decoded = jsonDecode(examListString);
      setState(() {
        exams = decoded.map((e) => Exam.fromJson(e)).toList();
        exams.sort((a, b) => a.subject.compareTo(b.subject));
      });
    }
  }

  Future<void> _saveExamsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(exams.map((e) => e.toJson()).toList());
    await prefs.setString('exams', encoded);
  }

  void _createExam() async {
    final newExam = await Navigator.push<Exam>(
      context,
      MaterialPageRoute(builder: (_) => const ExamEditScreen()),
    );

    if (newExam != null) {
      setState(() {
        exams.add(newExam);
        exams.sort((a, b) => a.subject.compareTo(b.subject));
      });
      await _saveExamsToPrefs();
      _showSnackbar('Exam created successfully!');
    }
  }

  void _editExam(Exam exam) async {
    final updatedExam = await Navigator.push<Exam>(
      context,
      MaterialPageRoute(builder: (_) => ExamEditScreen(existingExam: exam)),
    );

    if (updatedExam != null) {
      setState(() {
        int index = exams.indexWhere((e) => e.id == exam.id);
        if (index != -1) {
          exams[index] = updatedExam;
          exams.sort((a, b) => a.subject.compareTo(b.subject));
        }
      });
      await _saveExamsToPrefs();
      _showSnackbar('Exam updated successfully!');
    }
  }

  void _confirmDeleteExam(String examId) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: const Text("Are you sure you want to delete this exam?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteExam(examId);
                },
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  void _deleteExam(String examId) async {
    setState(() {
      exams.removeWhere((exam) => exam.id == examId);
    });
    await _saveExamsToPrefs();
    _showSnackbar('Exam deleted.');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredExams =
        exams.where((exam) {
          final searchIn = '${exam.subject} ${exam.id}'.toLowerCase();
          return searchIn.contains(_searchQuery);
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to Mode Selection',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createExam,
        icon: const Icon(Icons.add),
        label: const Text("Create Exam"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search exams',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child:
                filteredExams.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No exams available.\nTap the + button to create one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredExams.length,
                      itemBuilder: (context, index) {
                        final exam = filteredExams[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            title: Text(
                              '${exam.subject} (${exam.id})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration: ${exam.durationMinutes} minutes',
                                ),
                                Text('Questions: ${exam.questions.length}'),
                                if (exam.instructions != null &&
                                    exam.instructions!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Instructions: ${exam.instructions!}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                if (exam.otp != null &&
                                    exam.otp!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'OTP: ${exam.otp!} (${exam.isOtpReusable ? 'Reusable' : 'One-time'})',
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: _ExamActions(
                              exam: exam,
                              onEdit: () => _editExam(exam),
                              onDelete: () => _confirmDeleteExam(exam.id),
                              onViewSubmissions: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Submissions for "${exam.subject}" not available yet.',
                                    ),
                                    backgroundColor: Colors.blueGrey,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _ExamActions extends StatelessWidget {
  final Exam exam;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewSubmissions;

  const _ExamActions({
    required this.exam,
    required this.onEdit,
    required this.onDelete,
    required this.onViewSubmissions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.list_alt),
          tooltip: 'View Submissions',
          onPressed: onViewSubmissions,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete',
          onPressed: onDelete,
          color: Colors.red,
        ),
      ],
    );
  }
}
