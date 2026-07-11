import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heritage_arc/home_screen.dart';
import 'package:heritage_arc/screens/app_shell.dart';
import 'package:lottie/lottie.dart';
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
  final Color bgColor = const Color.fromARGB(255, 255, 255, 255);
  final Color textColor = const Color.fromARGB(221, 0, 0, 0);

    static final TextStyle _titleStyle = GoogleFonts.limelight(
    fontWeight: FontWeight.bold,
    fontSize: 42,
  );


  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('user_credentials')
          .select('email')
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (response == null || response['email'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid username or password")),
          );
        }
        return;
      }

      final String realEmail = response['email'];

      await Supabase.instance.client.auth.signInWithPassword(
        email: realEmail,
        password: password,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${e.toString()}")),
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

    Widget loginForm = Container(
      padding: const EdgeInsets.only(left: 40, right: 40, bottom: 40, top: 20),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(
            'Bangsha',
            style: _titleStyle,
          ),
           Text(
              'The thread that binds us',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

        
               const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              cursorColor: Colors.grey,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: const Color.fromARGB(136, 0, 0, 0)),
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
                labelStyle: TextStyle(color: const Color.fromARGB(136, 0, 0, 0)),
                enabledBorder: roundedBorder,
                focusedBorder: focusedRoundedBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              child: _isLoading
                  ? CircularProgressIndicator(color: primaryGreen)
                  : OutlinedButton(
                      onPressed: _handleLogin,
                      child: Text(
                        'Login',
                        style: TextStyle(color: primaryGreen, fontSize: 16),
                      ),
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account?", style: TextStyle(color: textColor)),
                const SizedBox(width: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      // Add your contact logic here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                           Row(
                            children: [
                              Icon(Icons.email, color: Colors.white,),
                              SizedBox(width: 10,),
                              Text('krishshrestha.contact@gmail.com')
                            ],
                           ),
                            
                            Row(
                            children: [
                              Icon(Icons.phone, color: Colors.white,),
                              SizedBox(width: 10,),
                              Text('+977 9869750231')
                            ],
                           )
                          ],
                        )),
                      );
                    },
                    child: Text(
                      'Contact Krish',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                       
                      ),
                    ),
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
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                // Lottie Animation on Left
              // Lottie Animation on Left
Expanded(
  child: Container(
    color: Colors.white,
    child: Center(
      child: Lottie.asset(
        'assets/bangsha.json',
        width: 900,                    // ← Adjust this
        height: 900,                   // ← Adjust this
        fit: BoxFit.contain,
        repeat: true,
        // Optional: Control alignment
        alignment: Alignment.center,
      ),
    ),
  ),
),
                // Login Form on Right
                Expanded(child: loginForm),
              ],
            );
          } else {
            // Mobile view - only form
            return Center(child: loginForm);
          }
        },
      ),
    );
  }
}