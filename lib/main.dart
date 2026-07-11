import 'package:flutter/material.dart';

import 'package:heritage_arc/screens/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 // 1. Import the SDK

void main() async {
  // 2. Ensure Flutter bindings are ready for async operations
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize Supabase with your project credentials
  await Supabase.initialize(
    url: 'https://lpflxbfphmjraxvgcjkv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwZmx4YmZwaG1qcmF4dmdjamt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MDQxOTUsImV4cCI6MjA5ODk4MDE5NX0.DxITwLdLOms3Wct8CEWNzW5HC-yVI3brilvTMUZeweA',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Fixed the debug banner property flag
      debugShowCheckedModeBanner: false, 
      title: 'Bangsha',
      theme: ThemeData(
        // Fixed the missing ColorScheme syntax error
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AppShell(),
    );
  }
}