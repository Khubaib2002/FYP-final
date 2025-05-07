import 'dart:convert'; // for decoding JSON
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';            // for formatting the time
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

import 'package:agaahi/services/auth.dart';
import 'package:agaahi/screens/home/services.dart';
import 'package:agaahi/screens/home/profile.dart';
import 'package:agaahi/screens/maps/weather_map.dart';
import 'package:agaahi/screens/home/tempgraph.dart';

class HomePage extends StatefulWidget {
  final int selectedIndex;
  const HomePage({super.key, this.selectedIndex = 0});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /* ──────────────────── UI state ──────────────────── */
  final AuthService _auth = AuthService();
  String currentTime  = DateFormat('hh:mm a').format(DateTime.now());

  String weatherCondition = 'Loading...';
  String temperature      = 'Loading...';
  String humidity         = 'Loading...';
  String windSpeed        = 'Loading...';
  String pressure         = 'Loading...';

  String userCity = 'Karachi';          // fallback until we get GPS
  List<String> weatherNews = ['Loading news…'];

  /* ──────────────────── life‑cycle ──────────────────── */
  @override
  void initState() {
    super.initState();
    _getCityFromLocation();     // gets city, then refreshes everything
    _fetchWeatherData(userCity); // first paint with fallback city
    _updateTime();
  }

  /* ──────────────────── geo‑lookup ──────────────────── */
  Future<void> _getCityFromLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled && !(serviceEnabled = await location.requestService())) return;

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied &&
        (permissionGranted = await location.requestPermission()) !=
            PermissionStatus.granted) {
      return;
    }

    LocationData locationData = await location.getLocation();
    final lat = locationData.latitude;
    final lon = locationData.longitude;

    if (lat == null || lon == null) return;

    final url =
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data['city'] ?? data['locality'] ?? 'Karachi';

        setState(() => userCity = city);

        // refresh both weather + news with real city
        _fetchWeatherData(city);
        _fetchWeatherNews(city);
      }
    } catch (e) {
      debugPrint('Reverse‑geocoding error: $e');
      _fetchWeatherNews('Karachi');
    }
  }

  /* ──────────────────── Tomorrow.io weather ──────────────────── */
  Future<void> _fetchWeatherData(String city) async {
    final url =
        'https://api.tomorrow.io/v4/weather/realtime'
        '?location=${Uri.encodeComponent(city)}'
        '&apikey=m0nWSTMtRvReHl5KIpTX5eYbzx0PSGQY'; // TODO: secure key

    try {
      final response =
          await http.get(Uri.parse(url), headers: {'accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          weatherCondition =
              _getWeatherCondition(data['data']['values']['weatherCode']);
          temperature = '${data['data']['values']['temperature']}°C';
          humidity    = '${data['data']['values']['humidity']}%';
          windSpeed   = '${data['data']['values']['windSpeed']} km/h';
          pressure    = '${data['data']['values']['pressureSurfaceLevel']} hPa';
        });
      } else {
        _setWeatherError('Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      _setWeatherError('Fetch error');
    }
  }

  void _setWeatherError(String msg) {
    setState(() {
      weatherCondition = msg;
      temperature = humidity = windSpeed = pressure = '—';
    });
  }

  /* ──────────────────── GNews headlines ──────────────────── */
  Future<void> _fetchWeatherNews(String city) async {
    const apiKey = '8a1ff2d23fae99e57f70b1122106ad0e';  // TODO: secure key

    final rawQuery =
        '("weather" OR "heatwave" OR "temperature" OR "rain" OR "mercury" OR "heat") '
        'AND "$city"';
    final query = Uri.encodeComponent(rawQuery);

    final url =
        'https://gnews.io/api/v4/search?q=$query&lang=en&max=10&apikey=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List;

        final cutoff = DateTime.now().subtract(const Duration(days: 60));
        final filtered = articles.where((a) {
          final published = DateTime.tryParse(a['publishedAt'] ?? '') ??
              DateTime(2000);
          return published.isAfter(cutoff);
        }).take(5);

        setState(() {
          weatherNews = filtered.map((a) {
            final title   = a['title'] ?? '';
            final source  = a['source']['name'] ?? 'Unknown';
            final date    = DateTime.tryParse(a['publishedAt'] ?? '') ??
                            DateTime(2000);
            final stamp   =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            return '• $title\n   🗞 $source | 📅 $stamp';
          }).toList();
        });
      } else {
        setState(() => weatherNews = ['API error ${response.statusCode}']);
      }
    } catch (e) {
      debugPrint('News fetch error: $e');
      setState(() => weatherNews = ['Failed to fetch news.']);
    }
  }

  /* ──────────────────── helpers ──────────────────── */
  String _getWeatherCondition(int code) {
    switch (code) {
      case 1000:
      case 1100:
        return 'Clear';
      case 1101:
        return 'Cloudy';
      default:
        return 'Unknown';
    }
  }

  void _updateTime() {
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => currentTime = DateFormat('hh:mm a').format(DateTime.now()));
      _updateTime();
    });
  }

  /* ──────────────────── UI ──────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          const SizedBox(height: 25),
          _buildCityTimeCard(),
          const SizedBox(height: 20),
          _buildMainWeatherCard(),
          const SizedBox(height: 20),
          _buildInfoRow(),
          const SizedBox(height: 20),
          _buildNewsCard(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /* ────────── tiny UI builders (unchanged except for state vars) ────────── */

  AppBar _buildAppBar() => AppBar(
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
        actions: [
          TextButton.icon(
            label: const Text(
              'Log Out',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OpenSans',
                  fontWeight: FontWeight.w600),
            ).animate().scale(delay: 200.ms),
            icon: const Icon(Icons.logout, color: Colors.white)
                .animate()
                .rotate(),
            onPressed: () async => _auth.SignOut(),
          )
        ],
      );

  Widget _buildCityTimeCard() => Container(
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
            Row(children: [
              const Icon(Icons.location_on, color: Colors.yellow),
              const SizedBox(width: 8),
              Text(userCity,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 30)),
            ]),
            Text(currentTime,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ],
        ),
      );

  Widget _buildMainWeatherCard() => GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GraphScreen())),
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
                    weatherCondition.contains('Clear')
                        ? Icons.wb_sunny
                        : Icons.cloud,
                    color: Colors.yellow,
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(weatherCondition,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
              Text(temperature,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 35)),
            ],
          ),
        ),
      );

  Widget _buildInfoRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard('Humidity', humidity, Icons.water_drop,
                [const Color(0xFF42A5F5), const Color(0xFF0D47A1)]),
            _buildInfoCard('Wind', windSpeed, Icons.air,
                [const Color(0xFF64B5F6), const Color(0xFF1E88E5)]),
            _buildInfoCard('Pressure', pressure, Icons.speed,
                [const Color(0xFFBBDEFB), const Color(0xFF1976D2)]),
          ],
        ),
      );

  Widget _buildNewsCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weather News in $userCity',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.indigo)),
            const SizedBox(height: 10),
            SizedBox(
              height: 125,
              child: ListView.builder(
                  itemCount: weatherNews.length,
                  itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• ${weatherNews[i]}',
                            style: const TextStyle(fontSize: 14)),
                      )),
            ),
          ],
        ),
      );

  BottomNavigationBar _buildBottomNav(BuildContext context) =>
      BottomNavigationBar(
        backgroundColor: Colors.indigo,
        selectedItemColor: Colors.lightBlueAccent,
        currentIndex: 0,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home_repair_service), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HomePage(selectedIndex: 0)),
                  (_) => false);
              break;
            case 1:
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MapSample()));
              break;
            case 2:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Services(selectedIndex: 2)));
              break;
            case 3:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen(selectedIndex: 3)));
              break;
          }
        },
      );

  /* ────────── tiny helper ────────── */
  Widget _buildInfoCard(
          String label, String value, IconData icon, List<Color> colors) =>
      Container(
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      );
}










// import 'dart:convert'; // for decoding JSON
// import 'package:agaahi/screens/home/services.dart';
// import 'package:flutter/material.dart';
// import 'package:agaahi/services/auth.dart';
// import 'package:agaahi/screens/home/profile.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:intl/intl.dart'; // For formatting the time
// import 'package:http/http.dart' as http;
// import 'package:agaahi/screens/maps/weather_map.dart';
// import 'package:agaahi/screens/home/tempgraph.dart';
// import 'package:location/location.dart';


// class HomePage extends StatefulWidget {
//   final int selectedIndex;
//   const HomePage({super.key, this.selectedIndex = 0});
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   String currentTime = DateFormat('hh:mm a').format(DateTime.now());
//   final AuthService _auth = AuthService();
//   String weatherCondition = 'Loading...';
//   String temperature = 'Loading...';
//   String humidity = 'Loading...';
//   String windSpeed = 'Loading...';
//   String pressure = 'Loading...';  // Added pressure variable

//   String userCity = 'Karachi'; // fallback
//   List<String> weatherNews = ['Loading news...'];

//   @override
//   void initState() {
//     super.initState();
//     _getCityFromLocation();
//     _fetchWeatherData(); // Fetch weather data when the page loads
//     _updateTime();
//   }




// Future<void> _getCityFromLocation() async {
//   Location location = Location();

//   bool serviceEnabled = await location.serviceEnabled();
//   if (!serviceEnabled) {
//     serviceEnabled = await location.requestService();
//     if (!serviceEnabled) return;
//   }

//   PermissionStatus permissionGranted = await location.hasPermission();
//   if (permissionGranted == PermissionStatus.denied) {
//     permissionGranted = await location.requestPermission();
//     if (permissionGranted != PermissionStatus.granted) return;
//   }

//   LocationData locationData = await location.getLocation();

//   double? lat = locationData.latitude;
//   double? lon = locationData.longitude;

//   if (lat != null && lon != null) {
//     final url =
//         'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en';

//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         String city = data['city'] ?? data['locality'] ?? 'Karachi';

//         setState(() {
//           userCity = city;
//         });

//         _fetchWeatherNews(city); // Fetch news for the dynamic city
//       }
//     } catch (e) {
//       print("Error during reverse geocoding: $e");
//       _fetchWeatherNews('Karachi'); // fallback
//     }
//   }
// }









//   // Function to fetch weather data
//   Future<void> _fetchWeatherData() async {
//     const url =  "https://api.tomorrow.io/v4/weather/realtime?location=karachi&apikey=m0nWSTMtRvReHl5KIpTX5eYbzx0PSGQY";

//     final response = await http.get(Uri.parse(url), headers: {"accept": "application/json"});

//     if (response.statusCode == 200) {
//       try {
//         final data = json.decode(response.body);
//         print(data);  // Debug: Inspect the response structure

//         setState(() {
//           // Access values correctly based on the response structure
//           weatherCondition = _getWeatherCondition(data['data']['values']['weatherCode']);
//           temperature = '${data['data']['values']['temperature']}°C' ?? 'Unknown';
//           humidity = '${data['data']['values']['humidity']}%' ?? 'Unknown';
//           windSpeed = '${data['data']['values']['windSpeed']} km/h' ?? 'Unknown';
//           pressure = '${data['data']['values']['pressureSurfaceLevel']} hPa' ?? 'Unknown';  // Update pressure value
//         });
//       } catch (e) {
//         setState(() {
//           weatherCondition = 'Error parsing data';
//           temperature = 'Error';
//           humidity = 'Error';
//           windSpeed = 'Error';
//           pressure = 'Error';  // Handle error for pressure
//         });
//         print('Error parsing weather data: $e');
//       }

//     } else {
//       setState(() {
//         weatherCondition = 'Error fetching data';
//         temperature = 'Error';
//         humidity = 'Error';
//         windSpeed = 'Error';
//         pressure = 'Error';  // Handle error for pressure
//       });
//       print('Error: ${response.statusCode}');
//     }
//   }


// Future<void> _fetchWeatherNews(String city) async {
//   const apiKey = '8a1ff2d23fae99e57f70b1122106ad0e'; // Replace with your GNews key

//   // Optimized query for weather-related terms in city
//   final rawQuery =
//   '("weather" OR "heatwave" OR "temperature" OR "rain" OR "mercury" OR "heat") '
//   'AND "$city"';          // no extra () and no quotes around April

// // Always encode once, after the whole string is ready
//   final query = Uri.encodeComponent(rawQuery);
//   final url = 'https://gnews.io/api/v4/search?q=$query&lang=en&max=10&apikey=$apiKey';

//   try {
//     final response = await http.get(Uri.parse(url));
//     print('Raw response: ${response.body}');

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final articles = data['articles'] as List;
//       print('Fetched articles: ${articles.length}');

//       final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 60));

//       final filtered = articles.where((a) {
//         final publishedAt = DateTime.tryParse(a['publishedAt'] ?? '') ?? DateTime(2000);
//         return publishedAt.isAfter(twoWeeksAgo);
//       }).toList();

//       print('Filtered articles: ${filtered.length}');

//       setState(() {
//         weatherNews = filtered.take(5).map<String>((a) {
//           final title = a['title'] ?? '';
//           final source = a['source']['name'] ?? 'Unknown';
//           final published = DateTime.tryParse(a['publishedAt'] ?? '') ?? DateTime(2000);
//           final formattedDate = '${published.year}-${published.month.toString().padLeft(2, '0')}-${published.day.toString().padLeft(2, '0')}';

//           return '• $title\n   🗞 $source | 📅 $formattedDate';
//         }).toList();
//       });

//     } else {
//       setState(() {
//         weatherNews = ['GNews API error: ${response.statusCode}'];
//       });
//     }
//   } catch (e) {
//     setState(() {
//       weatherNews = ['Failed to fetch news.'];
//     });
//     print('GNews fetch error: $e');
//   }
// }





//   // A simple method to map weatherCode to a weather condition string
//   String _getWeatherCondition(int weatherCode) {
//     switch (weatherCode) {
//       case 1100:
//         return 'Clear';  // You can add more cases for different codes
//       case 1000:
//         return 'Clear Sky';  // You can add more cases for different codes  
//       case 1101:
//         return 'Cloudy';
//       // Add other cases based on the weatherCode values in the API
//       default:
//         return 'Unknown';
//     }
//   }

//   void _updateTime() {
//     Future.delayed(const Duration(seconds: 10), () {
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
//                 Row(
//                     children: [
//                       const Icon(Icons.location_on, color: Colors.yellow),
//                       const SizedBox(width: 8),
//                       Text(
//                         userCity,
//                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
//                       ),
//                     ],
//                   ),

//                 Text(
//                   currentTime,
//                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 20),

//           GestureDetector(
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const GraphScreen(), // Replace with your Graph Screen widget
//                   ),
//                 );
//               },
//               child: Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 20),
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     Column(
//                       children: [
//                         Icon(
//                           weatherCondition == 'Clear Sky' ? Icons.wb_sunny : Icons.cloud,
//                           color: Colors.yellow,
//                           size: 50,
//                         ),
//                         const SizedBox(height: 10),
//                         Text(
//                           weatherCondition,
//                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
//                         ),
//                       ],
//                     ),
//                     Text(
//                       temperature,
//                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 35),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

          
//           const SizedBox(height: 20),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 _buildInfoCard("Humidity", humidity, Icons.water_drop, [
//                   const Color(0xFF42A5F5),
//                   const Color(0xFF0D47A1)
//                 ]),
//                 _buildInfoCard("Wind", windSpeed, Icons.air, [
//                   const Color(0xFF64B5F6),
//                   const Color(0xFF1E88E5)
//                 ]),
//                 _buildInfoCard("Pressure", pressure, Icons.speed, [
//                   const Color(0xFFBBDEFB),
//                   const Color(0xFF1976D2)
//                 ]),  // Added Pressure info card
//               ],
//             ),
//           ),

//         const SizedBox(height: 20),
//       Container(
//         margin: const EdgeInsets.symmetric(horizontal: 20),
//         padding: const EdgeInsets.all(15),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.indigo, width: 1.5),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Weather News in $userCity',
//               style: const TextStyle(
//                   fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
//             ),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 125,
//               child: ListView.builder(
//                 itemCount: weatherNews.length,
//                 itemBuilder: (context, index) {
//                   return Padding(
//                     padding: const EdgeInsets.only(bottom: 6.0),
//                     child: Text('• ${weatherNews[index]}', style: const TextStyle(fontSize: 14)),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),









//         ],
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         backgroundColor: Colors.indigo,
//         selectedItemColor: Colors.lightBlueAccent,
//         currentIndex: 0,
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
//               Navigator.pushAndRemoveUntil(
//                 context,
//                 MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
//                 (route) => false,
//               );
//               break;
//             case 1: // Explore
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const MapSample()),
//               );
//               break;
//             case 2: // Services
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => Services(selectedIndex: 2)),
//               );
//               break;
//             case 3: // Profile
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const ProfileScreen(selectedIndex: 3)),
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
//           Icon(icon, color: Colors.white),
//           Text(
//             value,
//             textAlign: TextAlign.center,
//             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
//           ),
//           Text(
//             label,
//             textAlign: TextAlign.center,
//             style: const TextStyle(color: Colors.white, fontSize: 10),
//           ),
//         ],
//       ),
//     );
//   }
// }
