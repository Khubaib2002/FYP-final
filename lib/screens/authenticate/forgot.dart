import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase authentication
import 'package:agaahi/shared/inputdecor.dart';
import 'package:agaahi/shared/loading.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Text field state
  var email = '';
  bool loading = false;
  String message = '';

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
                'Forgot Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Raleway',
                ),
              ).animate().fadeIn(duration: 800.ms),
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
                  const SizedBox(height: 50),
                  const Text(
                    'Reset Your Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway',
                    ),
                  ).animate().slideY(duration: 800.ms),
                  const SizedBox(height: 40),

                  // Email Form
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

                          // Forgot Button
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => loading = true);
                                try {
                                  await _auth.sendPasswordResetEmail(
                                      email: email);
                                  setState(() {
                                    message =
                                        'Password reset email sent! Check your inbox.';
                                    loading = false;
                                  });
                                } catch (e) {
                                  setState(() {
                                    message =
                                        'Error: Unable to send email. Please try again.';
                                    loading = false;
                                  });
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                  255, 255, 213, 79), // Yellow button
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14.0, horizontal: 36.0),
                            ),
                            child: const Text(
                              'Send Reset Email',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenSans',
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms),
                          const SizedBox(height: 20),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: message.contains('Error')
                                  ? Colors.redAccent
                                  : Colors.green,
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
