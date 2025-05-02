import 'package:flutter/material.dart';
import 'package:agaahi/screens/authenticate/register.dart';
import 'package:agaahi/screens/authenticate/signin.dart';

class Authenticate extends StatefulWidget {
  const Authenticate({super.key});

  @override
  State<Authenticate> createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  bool showsignin = true;

  toggleview() {
    setState(() => showsignin = !showsignin);
  }

  @override
  Widget build(BuildContext context) {
    if (showsignin) {
      return Signin(toggleview: toggleview);
    } else {
      return Register(toggleview: toggleview);
    }
  }
}
