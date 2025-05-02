// import 'package:flutter/material.dart';
// import 'package:agaahi/shared/inputdecor.dart';
// import 'package:agaahi/shared/loading.dart';
// import 'package:agaahi/services/auth.dart';

// class Register extends StatefulWidget {
//   final Function toggleview;
//   const Register({super.key, required this.toggleview});

//   @override
//   State<Register> createState() => _RegisterState();
// }

// class _RegisterState extends State<Register> {
//   final AuthService _auth = AuthService();
//   final _formKey = GlobalKey<FormState>();

//   var email = '';
//   var pass = '';
//   String error = '';
//   bool loading = false;

//   @override
//   Widget build(BuildContext context) {
//     return loading
//         ? const Loading()
//         : Scaffold(
//             backgroundColor: const Color.fromARGB(255, 9, 1, 74),
//             appBar: AppBar(
//               backgroundColor: const Color.fromARGB(255, 9, 1, 74),
//               elevation: 0,
//               title: const Text(
//                 'AGAAHI',
//                 style: TextStyle(
//                   color: Colors.white, // Explicitly setting text color to white
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton.icon(
//                   label: const Text(
//                     'Sign In',
//                     style: TextStyle(
//                       color: Colors.white, // Explicitly setting text color to white
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold
//                     ),
//                   ),
//                   onPressed: () async {
//                     widget.toggleview();
//                   },
//                   style: TextButton.styleFrom(
//                     foregroundColor: Colors.white,
//                   ),
//                   icon: const Icon(
//                     Icons.person,
//                     color: Colors.white, // Setting icon color to white
//                   ),
//                 ),
//               ],
//             ),

//             resizeToAvoidBottomInset:
//                 true, // This prevents overflow when the keyboard appears
//             body: SingleChildScrollView(
//               // Wrap with SingleChildScrollView
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20),
//                 child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Image.asset(
//                         'assets/open.png',
//                         height: 420,
//                       ),
//                       Form(
//                         key: _formKey,
//                         child: Column(
//                           children: <Widget>[
//                             TextFormField(
//                               validator: (val) => val!.isEmpty ? 'Enter an email' : null,
//                               onChanged: (val) {
//                                 setState(() => email = val);
//                               },
//                               decoration: textinputdecor.copyWith(
//                                 hintText: 'Email',
//                                 fillColor: Colors.white, // Set background color to white
//                                 filled: true, // Enable filling the background
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                   borderSide: BorderSide(color: Colors.grey.shade300), // Border color
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                   borderSide: BorderSide(color: Colors.grey.shade500), // Focus border color
//                                 ),
//                               ),
//                             ),

//                             const SizedBox(
//                               height: 20,
//                             ),
//                             TextFormField(
//                               obscureText: true,
//                               validator: (val) => val!.isEmpty ? 'Enter a password' : null,
//                               onChanged: (val) {
//                                 setState(() => pass = val);
//                               },
//                               decoration: textinputdecor.copyWith(
//                                 hintText: 'Password',
//                                 fillColor: Colors.white,
//                                 filled: true,
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                   borderSide: BorderSide(color: Colors.grey.shade300),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                   borderSide: BorderSide(color: Colors.grey.shade500),
//                                 ),
//                               ),
//                             ),

//                             const SizedBox(height: 20),
//                             ElevatedButton(
//                               onPressed: () async {
//                                 if (_formKey.currentState!.validate()) {
//                                   setState(() => loading = true);
//                                   dynamic result =
//                                       await _auth.register_wenp(email, pass);
//                                   print('valid');
//                                   if (result == null) {
//                                     setState(() {
//                                       loading = false;
//                                       error =
//                                           'Please provide valid email & password';
//                                     });
//                                   }
//                                 }
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.grey,
//                                 foregroundColor: Colors.black,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                               ),
//                               child: const Padding(
//                                 padding: EdgeInsets.symmetric(
//                                     vertical: 12.0, horizontal: 30.0),
//                                 child: Text('Register',
//                                     style: TextStyle(fontSize: 18)),
//                               ),
//                             ),
//                             const SizedBox(
//                               height: 12,
//                             ),
//                             Text(
//                               error,
//                               style: const TextStyle(
//                                   color: Colors.red, fontSize: 14),
//                             )
//                           ],
//                         ),
//                       ),
//                     ]),
//               ),
//             ),
//           );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'package:agaahi/shared/inputdecor.dart';
import 'package:agaahi/shared/loading.dart';
import 'package:agaahi/services/auth.dart';

class Register extends StatefulWidget {
  final Function toggleview;
  const Register({super.key, required this.toggleview});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  var email = '';
  var pass = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Loading()
        : Scaffold(
            backgroundColor: const Color.fromARGB(255, 9, 1, 74),
            appBar: AppBar(
              backgroundColor: const Color.fromARGB(255, 9, 1, 74),
              elevation: 0,
              title: const Text(
                'Register',
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
                  icon: const Icon(Icons.person,
                      color: Color.fromARGB(255, 255, 213, 79)),
                  label: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 213, 79),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sign In',
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
                    'Register',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Raleway',
                    ),
                  ).animate().slideY(duration: 800.ms),
                  const SizedBox(height: 60), // Increased spacing to push down form

                  // Registration Form
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
                          const SizedBox(height: 30), // Added spacing for usability

                          // Register Button
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => loading = true);
                                dynamic result =
                                    await _auth.register_wenp(email, pass);
                                if (result == null) {
                                  setState(() {
                                    loading = false;
                                    error =
                                        'Please provide valid email & password';
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
                              'Register',
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


