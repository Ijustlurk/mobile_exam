import 'package:flutter/material.dart';
import 'package:mo_be/screens/student_dashboard.dart';

void navigateToDashboard(BuildContext context, String studentId) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          StudentDashboard(studentId: studentId),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
    ),
    (route) => false,
  );
}
