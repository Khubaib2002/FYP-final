// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:agaahi/services/auth.dart';

// class ProfileScreen extends StatelessWidget {
//   final TextEditingController _feedbackController = TextEditingController();
//   final AuthService _auth = AuthService();

//   ProfileScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         elevation: 0,
//         title: const Text('Profile'),
//         actions: <Widget>[
//           TextButton.icon(
//             label: const Text(
//               "Log Out",
//               style: TextStyle(color: Color.fromARGB(255, 241, 235, 183)),
//             ),
//             onPressed: () async {
//               await _auth.SignOut();
//             },
//             icon: const Icon(Icons.person,
//                 color: Color.fromARGB(255, 241, 235, 183)),
//           )
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Full-width header block
//             Container(
//               color: Colors.blue,
//               width: double.infinity, // Full-width container
//               padding: const EdgeInsets.symmetric(vertical: 30),
//               child: const Column(
//                 children: [
//                   CircleAvatar(
//                     radius: 40,
//                     backgroundColor: Color.fromARGB(255, 231, 231, 231),
//                     child: Icon(Icons.person, size: 50, color: Colors.grey),
//                   ),
//                   SizedBox(height: 10),
//                   Text(
//                     'Khubaib',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   SizedBox(height: 5),
//                   Text(
//                     '03356719166',
//                     style: TextStyle(
//                       fontSize: 16,
//                       color: Colors.white70,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   buildStatCard('Power', '1'),
//                   buildStatCard('Weather Points', '0'),
//                 ],
//               ),
//             ),
//             const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Give Feedback',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 10)
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   TextField(
//                     controller: _feedbackController,
//                     maxLines: 5,
//                     decoration: const InputDecoration(
//                       hintText: 'Enter your feedback here...',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   ElevatedButton(
//                     onPressed: () async {
//                       String feedback = _feedbackController.text.trim();
//                       if (feedback.isNotEmpty) {
//                         await saveFeedback(feedback);
//                         _feedbackController.clear();
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                           content: Text('Feedback sent successfully!'),
//                         ));
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                           content: Text('Feedback cannot be empty!'),
//                         ));
//                       }
//                     },
//                     child: const Text('Submit Feedback'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildStatCard(String label, String value) {
//     return Expanded(
//       child: Column(
//         children: [
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.blue,
//             ),
//           ),
//           const SizedBox(height: 5),
//           Text(
//             label,
//             style: const TextStyle(fontSize: 14, color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> saveFeedback(String feedback) async {
//     try {
//       await FirebaseFirestore.instance.collection('feedbacks').add({
//         'feedback': feedback,
//         'timestamp': DateTime.now(),
//       });
//       print("Feedback saved to Firestore!");
//     } catch (e) {
//       print("Error saving feedback: $e");
//     }
//   }
// }



import 'package:agaahi/screens/home/homepage.dart';
import 'package:agaahi/screens/home/services.dart';
import 'package:agaahi/screens/maps/weather_map.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:agaahi/services/auth.dart';
import 'package:agaahi/screens/home/editpro.dart';
import 'package:agaahi/screens/home/help.dart';

class ProfileScreen extends StatefulWidget {
  final int selectedIndex;
  const ProfileScreen({super.key, this.selectedIndex = 3});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  File? _selectedImage;

  // Image Picker
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : const AssetImage('assets/tt.png') as ImageProvider,
                        backgroundColor: Colors.grey[200],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: const CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.blue,
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Khubaib',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '03356719166',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // List of Options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // buildOption(
                  //   context,
                  //   icon: Icons.person_outline,
                  //   label: 'Edit Profile',
                  //   screen: EditProfileScreen(),
                  // ),
                  // buildOption(
                  //   context,
                  //   icon: Icons.settings_outlined,
                  //   label: 'Settings',
                  //   screen: const SettingsScreen(),
                  // ),
                  buildOption(
                    context,
                    icon: Icons.help_outline,
                    label: 'Help Center',
                    screen: HelpCenterScreen(),
                  ),
                  buildOption(
                    context,
                    icon: Icons.logout,
                    label: 'Log Out',
                    onTap: () async {
                      await _auth.SignOut();
                      Navigator.pop(context); // Navigate back to login
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.indigo,
        selectedItemColor: Colors.lightBlueAccent,
        currentIndex: 3,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
          BottomNavigationBarItem(icon: Icon(Icons.home_repair_service), label: "Services"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        onTap: (index) {
          switch (index) {
            case 0: // Home
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
                (route) => false,
              );
              break;
            case 1: // Explore
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapSample()),
              );
              break;
            case 2: // Services
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Services(selectedIndex: 2)),
              );
              break;
            case 3: // Profile
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen(selectedIndex: 3)),
              );
              break;
          }
        },
      ),
    );
  }

  Widget buildOption(BuildContext context,
      {required IconData icon, required String label, Widget? screen, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ??
          () {
            if (screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
            }
          },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blue.withOpacity(0.2),
      highlightColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}