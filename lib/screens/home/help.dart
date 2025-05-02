import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class HelpCenterScreen extends StatelessWidget {
  final TextEditingController _feedbackController = TextEditingController();

  HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'FAQs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          buildFAQSection(),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'Feedback Form',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _feedbackController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter your feedback here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: 
            ElevatedButton(
            onPressed: () async {
              String feedback = _feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                await saveFeedback(feedback);
                _feedbackController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Feedback sent successfully!'),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Feedback cannot be empty!'),
                ));
              }
            },
            child: const Text('Submit Feedback'),
            ),

          ),
        ],
      ),
    );
  }

  Widget buildFAQSection() {
    return const Column(
      children: [
        ExpansionTile(
          title: Text('What is WeatherWalay?', style: TextStyle(fontSize: 16)),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'WeatherWalay is a weather advisory app providing hyper-local forecasts.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('How do I submit feedback?', style: TextStyle(fontSize: 16)),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Go to the Help Center and fill out the Feedback Form at the bottom of the page.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('What algorithms are used?', style: TextStyle(fontSize: 16)),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'We use algorithms like Kriging, LSTM, and others for accurate predictions.',
              ),
            ),
          ],
        ),
      ],
    );
  }


  Future<void> saveFeedback(String feedback) async {
    try {
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'feedback': feedback,
        'timestamp': DateTime.now(),
      });
      print("Feedback saved to Firestore!");
    } catch (e) {
      print("Error saving feedback: $e");
    }
  }
}
