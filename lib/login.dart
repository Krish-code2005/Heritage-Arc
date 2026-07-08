import 'package:flutter/material.dart';
import 'package:heritage_arc/home_screen.dart';
import 'package:heritage_arc/screens/app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  // Custom colors
  final Color primaryGreen = const Color.fromARGB(255, 0, 0, 0);
  final Color bgColor =  const Color.fromARGB(255, 255, 255, 255);
  final Color textColor = const Color.fromARGB(221, 0, 0, 0);

 Future<void> _handleLogin() async {
  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();

  if (username.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields"))
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 1. Fetch the user's real email from your updated table using their username
    final response = await Supabase.instance.client
        .from('user_credentials')
        .select('email')
        .eq('username', username)
        .eq('password', password) // Validating against your custom table credentials
        .maybeSingle();

    if (response == null || response['email'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid username or password"))
        );
      }
      return;
    }

    final String realEmail = response['email'];

    // 2. Log into Supabase Auth using the retrieved email.
    // This starts the official session that AppShell is waiting for!
    await Supabase.instance.client.auth.signInWithPassword(
      email: realEmail,
      password: password,
    );

    // 3. Navigate directly to AppShell
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.toString()}"))
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: Colors.grey[400]!),
    );
    final focusedRoundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: primaryGreen, width: 2.0),
    );

    // The login form as a reusable widget variable
    Widget loginForm = Container(
      padding: const EdgeInsets.all(40.0),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20,),
            // full logo with tagline
            Text('Welcome back!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              cursorColor: Colors.grey,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: const Color.fromARGB(137, 255, 255, 255)),
                enabledBorder: roundedBorder,
                focusedBorder: focusedRoundedBorder,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              cursorColor: Colors.grey,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: const Color.fromARGB(137, 255, 255, 255)),
                enabledBorder: roundedBorder,
                focusedBorder: focusedRoundedBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              child: _isLoading
                  ? CircularProgressIndicator(color: primaryGreen)
                  : OutlinedButton(onPressed: _handleLogin, child: Text('Login', style: TextStyle(color: primaryGreen))),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account?", style: TextStyle(color: textColor)),
                const SizedBox(width: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
               
                    child: Text('Contact Krish', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If screen is wider than 800px, show the split screen
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: Image.asset('assets/register.png', fit: BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: loginForm),
              ],
            );
          } else {
            // If screen is narrow, just show the form centered
            return Center(child: loginForm);
          }
        },
      ),
    );
  }
}