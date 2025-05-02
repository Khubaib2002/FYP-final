import 'package:flutter/material.dart';
import 'package:agaahi/screens/authenticate/authenticate.dart';
import 'package:agaahi/screens/home/homepage.dart';
import 'package:provider/provider.dart';
import 'package:agaahi/models/user.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User_?>(context);
    //return either home or authenticate
    if (user == null) {
      return const Authenticate();
    } else {
      return const HomePage();
    }
  }
}
