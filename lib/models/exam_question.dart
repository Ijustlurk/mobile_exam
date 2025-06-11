enum QuestionType { multipleChoice, trueFalse, essay }

class ExamQuestion {
  final String id;
  final QuestionType type;
  final String question;
  final List<String>? options;
  final String? answer; // ✅ Correctly added
  final String? studentAnswer;

  ExamQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options,
    this.answer,
    this.studentAnswer,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'],
      type: QuestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestionType.essay,
      ),
      question: json['question'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      answer: json['answer'],
      studentAnswer: json['studentAnswer'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name, // ✅ Converts enum to string
    'question': question,
    'options': options,
    'answer': answer,
    'studentAnswer': studentAnswer,
  };
}
