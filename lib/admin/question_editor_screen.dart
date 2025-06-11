import 'package:flutter/material.dart';
import 'package:mo_be/models/exam_question.dart';

class QuestionEditorScreen extends StatefulWidget {
  final ExamQuestion? existingQuestion;

  const QuestionEditorScreen({super.key, this.existingQuestion});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late TextEditingController _questionController;
  late TextEditingController _essayAnswerController;
  late List<TextEditingController> _optionControllers;
  QuestionType _selectedType = QuestionType.multipleChoice;
  String? _selectedAnswer;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(
      text: widget.existingQuestion?.question ?? '',
    );
    _selectedType =
        widget.existingQuestion?.type ?? QuestionType.multipleChoice;
    _selectedAnswer = widget.existingQuestion?.answer;

    _essayAnswerController = TextEditingController(
      text:
          _selectedType == QuestionType.essay
              ? widget.existingQuestion?.studentAnswer ?? ''
              : '',
    );

    List<String> opts = widget.existingQuestion?.options ?? [];
    if (_selectedType == QuestionType.trueFalse) {
      opts = ["True", "False"];
    }

    _optionControllers = List.generate(4, (index) {
      final controller = TextEditingController(
        text: index < opts.length ? opts[index] : '',
      );
      controller.addListener(() {
        setState(() {});
      });
      return controller;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _essayAnswerController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTypeChanged(QuestionType? newType) {
    if (newType == null) return;

    setState(() {
      _selectedType = newType;
      _selectedAnswer = null;

      if (newType == QuestionType.essay) {
        _essayAnswerController = TextEditingController();
        _optionControllers.clear();
      } else if (newType == QuestionType.trueFalse) {
        _optionControllers = [
          TextEditingController(text: "True")
            ..addListener(() => setState(() {})),
          TextEditingController(text: "False")
            ..addListener(() => setState(() {})),
        ];
        _selectedAnswer = "True";
      } else {
        _optionControllers = List.generate(4, (_) {
          final controller = TextEditingController();
          controller.addListener(() => setState(() {}));
          return controller;
        });
      }
    });
  }

  void _saveQuestion() {
    if (!_formKey.currentState!.validate()) return;

    ExamQuestion newQuestion;

    if (_selectedType == QuestionType.essay) {
      newQuestion = ExamQuestion(
        id:
            widget.existingQuestion?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedType,
        question: _questionController.text.trim(),
        studentAnswer: _essayAnswerController.text.trim(),
        options: [],
        answer: null,
      );
    } else {
      List<String> options =
          _optionControllers
              .map((c) => c.text.trim())
              .where((opt) => opt.isNotEmpty)
              .toList();
      if (_selectedType == QuestionType.trueFalse) {
        options = ["True", "False"];
      }

      newQuestion = ExamQuestion(
        id:
            widget.existingQuestion?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedType,
        question: _questionController.text.trim(),
        options: options,
        answer: _selectedAnswer ?? '',
      );
    }

    Navigator.pop(context, newQuestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingQuestion == null ? 'Add Question' : 'Edit Question',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveQuestion),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionTitle("Question"),
              _styledCard(
                child: TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    hintText: "Enter the exam question...",
                    border: InputBorder.none,
                  ),
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Question is required'
                              : null,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle("Question Type"),
              _styledCard(
                child: DropdownButtonFormField<QuestionType>(
                  value: _selectedType,
                  decoration: const InputDecoration(border: InputBorder.none),
                  items:
                      QuestionType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.name),
                            ),
                          )
                          .toList(),
                  onChanged: _onTypeChanged,
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedType == QuestionType.essay) ...[
                _buildSectionTitle("Expected Answer (optional)"),
                _styledCard(
                  child: TextFormField(
                    controller: _essayAnswerController,
                    decoration: const InputDecoration(
                      hintText: "Provide a sample or guide answer...",
                      border: InputBorder.none,
                    ),
                    maxLines: 5,
                  ),
                ),
              ] else if (_selectedType == QuestionType.multipleChoice) ...[
                _buildSectionTitle("Options"),
                ..._optionControllers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _styledCard(
                      child: TextFormField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          hintText: 'Option ${idx + 1}',
                          border: InputBorder.none,
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Option required'
                                    : null,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _buildSectionTitle("Correct Answer"),
                _styledCard(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAnswer,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items:
                        _optionControllers
                            .map((c) => c.text.trim())
                            .where((opt) => opt.isNotEmpty)
                            .map(
                              (opt) => DropdownMenuItem(
                                value: opt,
                                child: Text(opt),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedAnswer = val),
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Select the correct answer'
                                : null,
                  ),
                ),
              ] else if (_selectedType == QuestionType.trueFalse) ...[
                _buildSectionTitle("Correct Answer"),
                _styledCard(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAnswer,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items:
                        ["True", "False"]
                            .map(
                              (opt) => DropdownMenuItem(
                                value: opt,
                                child: Text(opt),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedAnswer = val),
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Select the correct answer'
                                : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ----- Helper Widgets -----

  Widget _styledCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
