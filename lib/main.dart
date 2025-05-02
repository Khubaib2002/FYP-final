import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agaahi/screens/wrapper.dart';
import 'package:agaahi/services/auth.dart';
import 'package:provider/provider.dart';
import 'package:agaahi/models/user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    
      options: const FirebaseOptions(
          apiKey: "AIzaSyD6a6QHf_2BEgchp2FyaI1fX35LBVDQ38k",
          appId: "1:779097774614:android:c7169667c0d9cfb667f337",
          messagingSenderId: "779097774614",
          projectId: "agaahi"));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<User_?>.value(
      initialData: null,
      value: AuthService().user,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Wrapper(),
      ),
    );
  }
}

