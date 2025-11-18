import 'package:flutter/material.dart';
import 'bridge_generated/frb_generated.dart';
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'views/e2ee_home_page.dart';
import 'views/chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge
  if (Platform.isWindows) {
    // Load the Windows DLL from the Rust crate's target directory
    final lib = ExternalLibrary.open(
        'C:\\Workspace\\Project3\\target\\release\\e2ee_core.dll');
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
      title: 'E2EE Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatPage(), // Use ChatPage for full conversation support
    );
  }
}
