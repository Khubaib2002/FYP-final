import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'package:agaahi/shared/inputdecor.dart';
import 'package:agaahi/shared/loading.dart';
import 'package:agaahi/services/auth.dart';
import 'package:agaahi/screens/authenticate/forgot.dart'; // Import the Forgot screen

class Signin extends StatefulWidget {
  final Function toggleview;
  const Signin({super.key, required this.toggleview});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Text field state
  var email = '';
  var pass = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Loading()
        : Scaffold(
            backgroundColor: const Color.fromARGB(255, 28, 10, 161),
            appBar: AppBar(
              backgroundColor: const Color.fromARGB(255, 28, 10, 161),
              elevation: 0,
              title: const Text(
                'Welcome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Raleway',
                ),
              ).animate().fadeIn(duration: 800.ms),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: () async {
                    widget.toggleview();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                  icon: const Icon(Icons.person_add_alt_1,
                      color: Color.fromARGB(255, 255, 213, 79)),
                  label: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 213, 79),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Register',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenSans',
                      ),
                    ).animate().fadeIn(duration: 800.ms),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo Section
                  Image.asset(
                    'assets/open.png',
                    height: 150,
                  ).animate().fadeIn().scale(),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway',
                    ),
                  ).animate().slideY(duration: 800.ms),
                  const SizedBox(height: 60),

                  // Login Form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          // Email Input Field
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: TextFormField(
                              validator: (val) =>
                                  val!.isEmpty ? 'Enter an email' : null,
                              onChanged: (val) {
                                setState(() => email = val);
                              },
                              decoration: textinputdecor.copyWith(
                                hintText: 'Email Address',
                                fillColor: Colors.white,
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blueAccent.shade100),
                                ),
                              ),
                            ),
                          ).animate().slideY(),
                          const SizedBox(height: 20),

                          // Password Input Field
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: TextFormField(
                              obscureText: true,
                              validator: (val) =>
                                  val!.isEmpty ? 'Enter a password' : null,
                              onChanged: (val) {
                                setState(() => pass = val);
                              },
                              decoration: textinputdecor.copyWith(
                                hintText: 'Password',
                                fillColor: Colors.white,
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blueAccent.shade100),
                                ),
                              ),
                            ),
                          ).animate().slideY(delay: 200.ms),
                          const SizedBox(height: 20),

                          // Forgot Password Link
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>  const Forgot(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Login Button
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => loading = true);
                                dynamic result =
                                    await _auth.signin_wenp(email, pass);
                                if (result == null) {
                                  setState(() {
                                    loading = false;
                                    error =
                                        'Could not sign in with given credentials';
                                  });
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                  255, 255, 213, 79),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 36.0),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenSans',
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms),
                          const SizedBox(height: 20),
                          Text(
                            error,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
