import 'package:mo_be/models/exam_question.dart';

class Exam {
  final String id;
  final String subject;
  final int durationMinutes;
  final String? instructions;
  final String? otp;
  final bool isOtpReusable;
  final List<ExamQuestion> questions;

  Exam({
    required this.id,
    required this.subject,
    required this.durationMinutes,
    this.instructions,
    this.otp,
    this.isOtpReusable = false,
    required this.questions,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'durationMinutes': durationMinutes,
    'instructions': instructions,
    'otp': otp,
    'isOtpReusable': isOtpReusable,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory Exam.fromJson(Map<String, dynamic> json) => Exam(
    id: json['id'],
    subject: json['subject'],
    durationMinutes: json['durationMinutes'],
    instructions: json['instructions'],
    otp: json['otp'],
    isOtpReusable: json['isOtpReusable'] ?? false,
    questions:
        (json['questions'] as List<dynamic>)
            .map((q) => ExamQuestion.fromJson(q))
            .toList(),
  );
}
