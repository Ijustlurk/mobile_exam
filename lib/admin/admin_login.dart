import 'package:flutter/material.dart';
import 'admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final String _adminUsername = 'admin';
  final String _adminPassword = 'admin';

  bool _obscurePassword = true;
  bool _isButtonEnabled = false;

  void _login() {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackbar('Please fill in both username and password');
      return;
    }

    if (_usernameController.text == _adminUsername &&
        _passwordController.text == _adminPassword) {
      // Navigate directly to AdminDashboardScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      _showSnackbar('Invalid credentials');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _onTextChanged() {
    final isFilled =
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (isFilled != _isButtonEnabled) {
      setState(() {
        _isButtonEnabled = isFilled;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onTextChanged);
    _passwordController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isButtonEnabled ? _login : null,
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
