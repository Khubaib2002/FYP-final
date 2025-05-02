import 'package:flutter/material.dart';

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
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
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('Choose Algorithm'),
            onTap: () {
              // Navigate to Algorithm Selection Screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlgorithmSelectionScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('App Info'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('App Info'),
                    content: const Text('WeatherWalay App v1.0. All rights reserved.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AlgorithmSelectionScreen extends StatelessWidget {
  const AlgorithmSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Choose Algorithm',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Algorithm 1'),
            onTap: () {
              // Logic to set Algorithm 1
            },
          ),
          ListTile(
            title: const Text('Algorithm 2'),
            onTap: () {
              // Logic to set Algorithm 2
            },
          ),
          ListTile(
            title: const Text('Algorithm 3'),
            onTap: () {
              // Logic to set Algorithm 3
            },
          ),
        ],
      ),
    );
  }
}