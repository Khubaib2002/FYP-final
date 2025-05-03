
import 'dart:convert'; // for decoding JSON
import 'package:agaahi/screens/home/services.dart';
import 'package:flutter/material.dart';
import 'package:agaahi/services/auth.dart';
import 'package:agaahi/screens/home/profile.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart'; // For formatting the time
import 'package:http/http.dart' as http;
import 'package:agaahi/screens/maps/weather_map.dart';
import 'package:agaahi/screens/home/tempgraph.dart';

class HomePage extends StatefulWidget {
  final int selectedIndex;
  const HomePage({super.key, this.selectedIndex = 0});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String currentTime = DateFormat('hh:mm a').format(DateTime.now());
  final AuthService _auth = AuthService();
  String weatherCondition = 'Loading...';
  String temperature = 'Loading...';
  String humidity = 'Loading...';
  String windSpeed = 'Loading...';
  String pressure = 'Loading...';  // Added pressure variable

  @override
  void initState() {
    super.initState();
    _fetchWeatherData(); // Fetch weather data when the page loads
    _updateTime();
  }

  // Function to fetch weather data
  Future<void> _fetchWeatherData() async {
    const url =  "https://api.tomorrow.io/v4/weather/realtime?location=karachi&apikey=m0nWSTMtRvReHl5KIpTX5eYbzx0PSGQY";

    final response = await http.get(Uri.parse(url), headers: {"accept": "application/json"});

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        print(data);  // Debug: Inspect the response structure

        setState(() {
          // Access values correctly based on the response structure
          weatherCondition = _getWeatherCondition(data['data']['values']['weatherCode']);
          temperature = '${data['data']['values']['temperature']}°C' ?? 'Unknown';
          humidity = '${data['data']['values']['humidity']}%' ?? 'Unknown';
          windSpeed = '${data['data']['values']['windSpeed']} km/h' ?? 'Unknown';
          pressure = '${data['data']['values']['pressureSurfaceLevel']} hPa' ?? 'Unknown';  // Update pressure value
        });
      } catch (e) {
        setState(() {
          weatherCondition = 'Error parsing data';
          temperature = 'Error';
          humidity = 'Error';
          windSpeed = 'Error';
          pressure = 'Error';  // Handle error for pressure
        });
        print('Error parsing weather data: $e');
      }

    } else {
      setState(() {
        weatherCondition = 'Error fetching data';
        temperature = 'Error';
        humidity = 'Error';
        windSpeed = 'Error';
        pressure = 'Error';  // Handle error for pressure
      });
      print('Error: ${response.statusCode}');
    }
  }

  // A simple method to map weatherCode to a weather condition string
  String _getWeatherCondition(int weatherCode) {
    switch (weatherCode) {
      case 1100:
        return 'Clear';  // You can add more cases for different codes
      case 1000:
        return 'Clear Sky';  // You can add more cases for different codes  
      case 1101:
        return 'Cloudy';
      // Add other cases based on the weatherCode values in the API
      default:
        return 'Unknown';
    }
  }

  void _updateTime() {
    Future.delayed(const Duration(seconds: 10), () {
      setState(() {
        currentTime = DateFormat('hh:mm a').format(DateTime.now());
      });
      _updateTime();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                color: Color.fromARGB(255, 255, 255, 255),
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.w600,
              ),
            ).animate().scale(delay: 200.ms),
            onPressed: () async {
              await _auth.SignOut();
            },
            icon: const Icon(
              Icons.logout,
              color: Color.fromARGB(255, 255, 255, 255),
            ).animate().rotate(),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 25),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.fromLTRB(10, 30, 10, 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.yellow),
                    SizedBox(width: 8),
                    Text(
                      "Karachi",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
                    ),
                  ],
                ),
                Text(
                  currentTime,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GraphScreen(), // Replace with your Graph Screen widget
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(
                          weatherCondition == 'Clear Sky' ? Icons.wb_sunny : Icons.cloud,
                          color: Colors.yellow,
                          size: 50,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          weatherCondition,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    Text(
                      temperature,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 35),
                    ),
                  ],
                ),
              ),
            ),

          
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoCard("Humidity", humidity, Icons.water_drop, [
                  const Color(0xFF42A5F5),
                  const Color(0xFF0D47A1)
                ]),
                _buildInfoCard("Wind", windSpeed, Icons.air, [
                  const Color(0xFF64B5F6),
                  const Color(0xFF1E88E5)
                ]),
                _buildInfoCard("Pressure", pressure, Icons.speed, [
                  const Color(0xFFBBDEFB),
                  const Color(0xFF1976D2)
                ]),  // Added Pressure info card
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.indigo,
        selectedItemColor: Colors.lightBlueAccent,
        currentIndex: 0,
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

  Widget _buildInfoCard(String label, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}







// import 'package:agaahi/screens/home/services.dart';
// import 'package:flutter/material.dart';
// import 'package:agaahi/services/auth.dart';
// import 'package:agaahi/screens/home/profile.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:intl/intl.dart'; // For formatting the time

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   String currentTime = DateFormat('hh:mm a').format(DateTime.now());
//   final AuthService _auth = AuthService();

//   @override
//   void initState() {
//     super.initState();
//     _updateTime();
//   }

//   void _updateTime() {
//     Future.delayed(const Duration(seconds: 0), () {
//       setState(() {
//         currentTime = DateFormat('hh:mm a').format(DateTime.now());
//       });
//       _updateTime();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text(
//           'AGAAHI',
//           style: TextStyle(
//             fontSize: 26,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//             fontFamily: 'Raleway',
//           ),
//         ).animate().fadeIn(duration: 800.ms),
//         backgroundColor: Colors.indigo,
//         actions: <Widget>[
//           TextButton.icon(
//             label: const Text(
//               "Log Out",
//               style: TextStyle(
//                 color: Color.fromARGB(255, 255, 255, 255),
//                 fontFamily: 'OpenSans',
//                 fontWeight: FontWeight.w600,
//               ),
//             ).animate().scale(delay: 200.ms),
//             onPressed: () async {
//               await _auth.SignOut();
//             },
//             icon: const Icon(
//               Icons.logout,
//               color: Color.fromARGB(255, 255, 255, 255),
//             ).animate().rotate(),
//           )
//         ],
//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 25),
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 20),
//             padding: const EdgeInsets.fromLTRB(10, 30, 10, 30),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 const Row(
//                   children: [
//                     Icon(Icons.location_on, color: Color.fromARGB(255, 0, 0, 0)),
//                     SizedBox(width: 8),
//                     Text(
//                       "Karachi",
//                       style: TextStyle(color: Colors.white,  fontWeight:  FontWeight.bold, fontSize: 30),
//                     ),
//                   ],
//                 ),
//                 Text(
//                   currentTime,
//                   style: const TextStyle(color: Colors.white,  fontWeight:  FontWeight.bold, fontSize: 20),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 20),
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Column(
//                   children: [
//                     Icon(Icons.wb_sunny, color: Colors.yellow, size: 50),
//                     SizedBox(height: 10),
//                     Text(
//                       "Clear Sky",
//                       style: TextStyle(color: Colors.white,  fontWeight:  FontWeight.bold, fontSize: 18),
//                     ),
//                   ],
//                 ),
//                 Text(
//                   "19.7°C",
//                   style: TextStyle(color: Colors.white,  fontWeight:  FontWeight.bold, fontSize: 35),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 _buildInfoCard("Humidity", "66", Icons.water_drop, [
//                   Color(0xFF42A5F5),
//                   Color(0xFF0D47A1)
//                 ]),
//                 _buildInfoCard("Wind", "7.2", Icons.air, [
//                   Color(0xFF64B5F6),
//                   Color(0xFF1E88E5)
//                 ]),
//                 _buildInfoCard("Pressure", "1066", Icons.speed, [
//                   Color(0xFFBBDEFB),
//                   Color(0xFF1976D2)
//                 ]),
//               ],
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         backgroundColor: Colors.indigo,
//         selectedItemColor: Colors.lightBlueAccent,
//         unselectedItemColor: Colors.grey[400],
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
//           BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
//           BottomNavigationBarItem(icon: Icon(Icons.home_repair_service), label: "Services"),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
//         ],
//         onTap: (index) {
//           switch (index) {
//             case 0: // Home
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => const HomePage()),
//               );
//               break;
//             case 1: // Explore
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => Services()),
//               );
//               break;
//             case 2: // Services
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => Services()),
//               );
//               break;
//             case 3: // Profile
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const ProfileScreen()),
//               );
//               break;
//           }
//         },
//       ),
//     );
//   }

//   Widget _buildInfoCard(String label, String value, IconData icon, List<Color> gradientColors) {
//     return Container(
//       width: 100,
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: gradientColors,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: Colors.white, size: 30),
//           const SizedBox(height: 10),
//           Text(
//             label,
//             style: const TextStyle(color: Colors.white, fontWeight:  FontWeight.bold, fontSize: 15),
//           ),
//           const SizedBox(height: 5),
//           Text(
//             value,
//             style: const TextStyle(color: Colors.white, fontWeight:  FontWeight.bold, fontSize: 20),
//           ),
//         ],
//       ),
//     );
//   }
// }


