import 'package:flutter/material.dart';
import 'exam_model.dart';
import 'package:mo_be/models/exam_question.dart';
import 'question_editor_screen.dart';

class ExamEditScreen extends StatefulWidget {
  final Exam? existingExam;

  const ExamEditScreen({super.key, this.existingExam});

  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> {
  late TextEditingController _idController;
  late TextEditingController _subjectController;
  late TextEditingController _durationController;
  late TextEditingController _instructionsController;
  late TextEditingController _otpController;

  bool _isOtpReusable = false;
  List<ExamQuestion> _questions = [];

  final _formKey = GlobalKey<FormState>();
  bool _formValid = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.existingExam?.id ?? '');
    _subjectController = TextEditingController(
      text: widget.existingExam?.subject ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existingExam?.durationMinutes.toString() ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.existingExam?.instructions ?? '',
    );
    _otpController = TextEditingController(
      text: widget.existingExam?.otp ?? '',
    );
    _isOtpReusable = widget.existingExam?.isOtpReusable ?? false;
    _questions = widget.existingExam?.questions ?? [];

    // Listen for form changes to update save button state
    _idController.addListener(_validateForm);
    _subjectController.addListener(_validateForm);
    _durationController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid != _formValid) {
      setState(() {
        _formValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _saveExam() {
    if (_formKey.currentState?.validate() ?? false) {
      final exam = Exam(
        id: _idController.text.trim(),
        subject: _subjectController.text.trim(),
        durationMinutes: int.parse(_durationController.text),
        instructions:
            _instructionsController.text.trim().isEmpty
                ? null
                : _instructionsController.text.trim(),
        otp:
            _otpController.text.trim().isEmpty
                ? null
                : _otpController.text.trim(),
        isOtpReusable: _isOtpReusable,
        questions: _questions,
      );

      Navigator.pop(context, exam);

      // Show snackbar after returning to previous screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingExam == null
                  ? 'Exam created successfully!'
                  : 'Exam updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
  }

  Future<void> _addOrEditQuestion({ExamQuestion? existing, int? index}) async {
    final result = await Navigator.push<ExamQuestion>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditorScreen(existingQuestion: existing),
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _questions[index] = result;
        } else {
          _questions.add(result);
        }
      });
    }
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Widget _buildQuestionCard(int index, ExamQuestion question) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          question.question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("Type: ${question.type.name}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              tooltip: 'Edit question',
              onPressed:
                  () => _addOrEditQuestion(existing: question, index: index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: 'Delete question',
              onPressed: () => _removeQuestion(index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingExam == null ? "Create Exam" : "Edit Exam"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          onChanged: _validateForm,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: "Exam ID",
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: "Subject",
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: "Duration (minutes)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final num = int.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: "Exam Instructions (optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: "OTP (optional)",
                  hintText: "e.g. ABC123",
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                value: _isOtpReusable,
                onChanged: (val) => setState(() => _isOtpReusable = val),
                title: const Text("Allow OTP to be reused"),
              ),
              const Divider(height: 32, thickness: 1.2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Questions (${_questions.length})",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Question"),
                    onPressed: () => _addOrEditQuestion(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_questions.isEmpty)
                const Text(
                  "No questions added yet.",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              else
                ..._questions.asMap().entries.map(
                  (entry) => _buildQuestionCard(entry.key, entry.value),
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                onPressed: _formValid ? _saveExam : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                label: const Text("Save Exam"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
