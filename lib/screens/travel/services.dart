import 'package:agaahi/screens/freight/perishable.dart';
import 'package:agaahi/screens/events/eventer.dart';
import 'package:flutter/material.dart';
import 'package:agaahi/services/auth.dart';
import 'package:agaahi/screens/travel/travel_main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agaahi/screens/home/profile.dart';
import 'package:agaahi/screens/home/homepage.dart';
import 'package:agaahi/screens/maps/weather_map.dart';

class Services extends StatelessWidget {
  final int selectedIndex;
  Services({super.key, this.selectedIndex = 3});

  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AGAAHI',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Raleway',
          ),
        ).animate().fadeIn(duration: 800.ms),
        backgroundColor: Colors.indigo,
        actions: <Widget>[
          TextButton.icon(
            label: const Text(
              "Log Out",
              style: TextStyle(
                color: Color(0xFFF1EBB7),
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.w600,
              ),
            ).animate().scale(delay: 200.ms),
            onPressed: () async {
              await _auth.SignOut();
            },
            icon: const Icon(
              Icons.logout,
              color: Color(0xFFF1EBB7),
            ).animate().rotate(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20,),
            const Center(
              child: Text(
                "Choose Your Service",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Raleway',
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _buildFullWidthButton(
                    icon: Icons.event_available,
                    label: 'EVENTS',
                    subtitle: "Plan your events seamlessly.",
                    gradientColors: [Colors.blue, Colors.lightBlueAccent],
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Eventer()), // Correct widget usage
                      );
                    },
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 25),
                  _buildFullWidthButton(
                    icon: Icons.flight_takeoff,
                    label: 'TRAVEL',
                    subtitle: "Get travel updates instantly.",
                    gradientColors: [Colors.indigo, Colors.blueAccent],
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TravelRouteScreen()), // Correct widget usage
                      );
                    },
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 25),
                  _buildFullWidthButton(
                    icon: Icons.local_shipping_outlined,
                    label: 'FREIGHT',
                    subtitle: "Track your freight shipment.",
                    gradientColors: [Colors.blueGrey, Colors.cyanAccent],
                    onPressed: () {
                      Navigator.push(
                        context,
                        _createPageRoute(const PerishableItemsScreen()),
                      );
                    },
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 25),
                  _buildFullWidthButton(
                    icon: Icons.explore,
                    label: 'Explore',
                    subtitle: "Explore the world and its weather.",
                    gradientColors: [Colors.blueGrey, Colors.cyanAccent],
                    onPressed: () {
                      Navigator.push(
                        context,
                        _createPageRoute(const MapSample()),
                      );
                    },
                  ).animate().fadeIn().slideX(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.indigo,
        selectedItemColor: Colors.lightBlueAccent,
        currentIndex: selectedIndex, 
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Services(selectedIndex: 2)),
              );
              break;
            case 3: // Profile
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen(selectedIndex: 3)),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildFullWidthButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 4),
              blurRadius: 8.0,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'OpenSans',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontFamily: 'OpenSans',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page route with fade transition
  PageRouteBuilder _createPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
