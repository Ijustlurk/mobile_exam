import 'package:flutter/material.dart';
import 'otp_screen.dart';

class LoginInfoScreen extends StatefulWidget {
  const LoginInfoScreen({super.key});

  @override
  State<LoginInfoScreen> createState() => _LoginInfoScreenState();
}

class _LoginInfoScreenState extends State<LoginInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController studentNameController = TextEditingController();
  final TextEditingController sectionController = TextEditingController();

  String? selectedCollege;

  final List<String> colleges = [
    'CICS - College of Information and Computing Sciences',
    'CTE - College of Teacher Education',
    'CHM - College of Hospitality Management',
    'CCJE - College of Criminal Justice Education',
    'CBEA - College of Business, Entrepreneurship, and Accountancy',
    'CFAS - College of Fisheries and Aquatic Sciences',
    'CIT - College of Industrial Technology',
  ];

  void proceedToOTP() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => OTPScreen(
                studentName: studentNameController.text.trim(),
                college: selectedCollege!,
                section: sectionController.text.trim(),
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Information"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your details to proceed",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: studentNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'Enter your name' : null,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'College/Department',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                value: selectedCollege,
                items:
                    colleges.map((college) {
                      return DropdownMenuItem(
                        value: college,
                        child: Text(
                          college,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                onChanged:
                    (value) => setState(() {
                      selectedCollege = value;
                    }),
                validator:
                    (value) => value == null ? 'Select your college' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: sectionController,
                decoration: const InputDecoration(
                  labelText: 'Year & Section',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                validator:
                    (value) => value!.isEmpty ? 'Enter year and section' : null,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: proceedToOTP,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    "Continue to OTP",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
