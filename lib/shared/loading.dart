import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.yellow[700],
        child: Center(
          child: SpinKitChasingDots(
            color: Colors.yellow[900],
            size: 30,
          ),
        ));
  }
}
