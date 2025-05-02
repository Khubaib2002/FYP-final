import 'package:flutter/material.dart';

class StyledBodyText extends StatelessWidget {
  const StyledBodyText(this.text, this.font, {super.key});

  final String text;
  final double font;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.brown[900],
        fontWeight: FontWeight.bold,
        fontSize: font,
      ),
    );
  }
}
