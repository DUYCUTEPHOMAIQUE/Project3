import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'friend_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final result = await _apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (result['error'] != null) {
        setState(() {
          _error = result['error'].toString();
          _isLoading = false;
        });
        return;
      }

      if (result['access_token'] == null) {
        setState(() {
          _error = 'Login failed: No token received';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FriendListPage()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final email = _emailController.text.trim().isEmpty 
        ? null 
        : _emailController.text.trim();

    print('=== REGISTER START ===');
    print('Username: $username');
    print('Password: ${password.isEmpty ? "(empty)" : "${password.length} chars"}');
    print('Email: ${email ?? "(empty)"}');
    print('API URL: ${ApiService.baseUrl}/auth/register');

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('Calling API...');
      final result = await _apiService.register(username, password, email);
      
      print('=== API RESPONSE ===');
      print('Status: ${result['user_id'] != null ? "SUCCESS" : "ERROR"}');
      print('Response: $result');

      if (result['error'] != null) {
        print('ERROR: ${result['error']}');
        setState(() {
          _error = result['error'].toString();
          _isLoading = false;
        });
        return;
      }

      if (result['user_id'] != null) {
        print('SUCCESS: User registered with ID: ${result['user_id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please login.')),
          );
          Navigator.pop(context);
        }
      } else {
        print('WARNING: No user_id in response');
        setState(() {
          _error = 'Registration failed: Invalid response';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('=== EXCEPTION ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = 'Registration failed: $e';
        _isLoading = false;
      });
    }
    print('=== REGISTER END ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
