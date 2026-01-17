import 'package:flutter/material.dart';
import 'bridge_generated/frb_generated.dart';
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'views/login_page.dart';
import 'views/friend_list_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge
  if (Platform.isWindows) {
    // Load the Windows DLL from the Rust crate's target directory
    final lib = ExternalLibrary.open(
        'C:\\Workspace\\Project3\\target\\release\\e2ee_core.dll');
    await E2EECore.init(externalLibrary: lib);
  } else if (Platform.isMacOS) {
    // Load the macOS dylib from app bundle Resources folder
    // Construct bundle path from executable location
    final executablePath = Platform.resolvedExecutable;
    // For macOS app bundle: executable is at Contents/MacOS/<executable_name>
    // Resources folder is at Contents/Resources/
    // Navigate up from MacOS to Contents, then to Resources
    final executableDir = executablePath.substring(0, executablePath.lastIndexOf('/'));
    final contentsDir = executableDir.substring(0, executableDir.lastIndexOf('/'));
    final libPath = '$contentsDir/Resources/libe2ee_core.dylib';
    final lib = ExternalLibrary.open(libPath);
    await E2EECore.init(externalLibrary: lib);
  } else {
    await E2EECore.init();
  }

  runApp(const E2EEDemoApp());
}

class E2EEDemoApp extends StatelessWidget {
  const E2EEDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeAndCheckAuth();
  }

  Future<void> _initializeAndCheckAuth() async {
    print('[AuthWrapper] 🔍 Checking authentication status...');
    await _authService.initialize();
    final isAuth = await _authService.isAuthenticated();
    print('[AuthWrapper] 🔍 Auth status: $isAuth');
    setState(() {
      _isAuthenticated = isAuth;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isAuthenticated
        ? const FriendListPage()
        : const LoginPage();
  }
}
