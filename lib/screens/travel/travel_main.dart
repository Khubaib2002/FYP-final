import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:agaahi/config.dart';
// final String apiKey = AppConfig.goMapsApiKey;

class TravelRouteScreen extends StatefulWidget {
  const TravelRouteScreen({super.key});

  @override
  _TravelRouteScreenState createState() => _TravelRouteScreenState();
}

class _TravelRouteScreenState extends State<TravelRouteScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  LatLng? _fromLocation;
  LatLng? _toLocation;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<dynamic> _placeSuggestions = [];

  LatLng? _selectedWaypoint;
  String? _selectedWaypointDetails;

  bool isSelectingFrom = true;

  // Add waypoint markers
  final Set<Marker> _waypointMarkers = {};

  // Weather API endpoint
  final String _weatherApiUrl = 'https://weather-db-b91w.onrender.com/api/v1/interpolation/by-location-and-timestamp';
  
  // Maximum distance for weather interpolation (in meters)
  final int _maxWeatherDistance = 10000;

  double _haversineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371e3;
    double lat1 = point1.latitude * pi / 180;
    double lon1 = point1.longitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lon2 = point2.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in meters
  }

  // Update this function to round timestamps to nearest 15 minutes
Future<Map<String, dynamic>> _getWeatherForLocationAndTime(LatLng point, DateTime timestamp) async {
  try {
    // Round timestamp to nearest 15-minute interval (00, 15, 30, 45)
    int minutes = timestamp.minute;
    int roundedMinutes = (minutes ~/ 15) * 15;
    
    // Create a new DateTime with the rounded minutes and zero seconds
    DateTime roundedTimestamp = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      roundedMinutes,
      0  // Zero seconds
    );
    
    // Format timestamp as "2024-MM-DDThh:mm:00" with exactly 00 seconds
    String formattedTimestamp = "${roundedTimestamp.year}-${roundedTimestamp.month.toString().padLeft(2, '0')}-${roundedTimestamp.day.toString().padLeft(2, '0')}T${roundedTimestamp.hour.toString().padLeft(2, '0')}:${roundedTimestamp.minute.toString().padLeft(2, '0')}:00";
    
    print('Requesting weather data for: $formattedTimestamp at ${point.latitude},${point.longitude}');
    
    final response = await http.post(
      Uri.parse(_weatherApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'longitude': point.longitude,
        'latitude': point.latitude,
        'timestamp': formattedTimestamp,
        'max_distance': _maxWeatherDistance
      }),
    );

    print('Response status: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Debug print the response
      print('API Response: ${response.body}');
      
      // Return the first point's data (closest to the requested location)
      if (data['points'] != null && data['points'].isNotEmpty) {
        return data['points'][0];
      }
    }
    
    print('Error fetching weather data: ${response.statusCode}');
    return {};
  } catch (e) {
    print('Exception while fetching weather data: $e');
    return {};
  }
}




  void _calculateWaypoints(List<LatLng> points, int totalDurationSeconds) async {
  // Clear old markers
  _waypointMarkers.clear();

  //------------------------------
  // 1) First pass: total distance
  //------------------------------
  double entireRouteDistance = 0;
  for (int i = 1; i < points.length; i++) {
    entireRouteDistance += _haversineDistance(points[i - 1], points[i]);
  }

  //------------------------------
  // 2) Place waypoints every 15 min
  //------------------------------
  // Round total duration to nearest 15 minutes
  int roundedDuration = (totalDurationSeconds ~/ 900) * 900;
  int intervalSeconds = 900; // 15-minute chunk
  int waypointCounter = 0;

  // Keep track of how much "time" has elapsed
  double cumulativeTime = 0;

  // For distance from the previous waypoint
  double lastWaypointLat = points[0].latitude;
  double lastWaypointLng = points[0].longitude;

  // Create a fixed date in 2024, 2 days from now
  DateTime now = DateTime.now();
  
  // Start with a time that's already rounded to 15 minutes (00, 15, 30, 45)
  int roundedMinutes = (now.minute ~/ 15) * 15;
  DateTime startTime = DateTime(2024, now.month+4, now.day + 12, now.hour, roundedMinutes, 0);

  for (int i = 1; i < points.length; i++) {
    LatLng prev = points[i - 1];
    LatLng curr = points[i];

    // Fraction of entire trip for this segment
    double segmentDistance = _haversineDistance(prev, curr);
    double fraction = segmentDistance / entireRouteDistance;

    // How many seconds that fraction corresponds to
    double segmentTime = fraction * roundedDuration;

    // Add this segment's time to cumulativeTime
    cumulativeTime += segmentTime;

    // Each time we cross 900s (15 minutes), place a waypoint
    while (cumulativeTime >= intervalSeconds) {
      waypointCounter++;

      // Calculate exact time for this waypoint, ensuring it's always on 15-minute intervals
      DateTime estimatedTime = startTime.add(
        Duration(minutes: 15 * waypointCounter),
      );

      // Calculate distance from the last waypoint
      double distanceFromLastWaypoint = _haversineDistance(
        LatLng(lastWaypointLat, lastWaypointLng),
        curr,
      );

      // Fetch weather data for this location and timestamp
      final weatherData = await _getWeatherForLocationAndTime(curr, estimatedTime);

      // Create the info snippet based on weather data
      String infoSnippet = """
📌 Waypoint $waypointCounter
Temp 🌡️ ${weatherData['temperature'] != null ? weatherData['temperature'].toStringAsFixed(1) : 'N/A'}°C
Wind Speed 💨 ${weatherData['wind_speed'] != null ? weatherData['wind_speed'].toStringAsFixed(1) : 'N/A'} m/s
Humidity 💧 ${weatherData['humidity'] != null ? weatherData['humidity'].toStringAsFixed(1) : 'N/A'}%
Dew Point 🌧️ ${weatherData['dew_point'] != null ? weatherData['dew_point'].toStringAsFixed(1) : 'N/A'}°C
Time ⏰ ${estimatedTime.hour}:${estimatedTime.minute.toString().padLeft(2, '0')}
Distance 📏 ${(distanceFromLastWaypoint/1000).toStringAsFixed(1)} km
""";

      // Create a marker with an onTap callback
      final marker = Marker(
        markerId: MarkerId('waypoint_$waypointCounter'),
        position: curr,
        infoWindow: InfoWindow(
          title: '🚀 Route Checkpoint!',
          snippet: infoSnippet,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
        // When tapped, store details for the "enlarged info window"
        onTap: () {
          setState(() {
            _selectedWaypoint = curr;
            _selectedWaypointDetails = infoSnippet;
          });
          // Auto-hide after 5 seconds
          Future.delayed(const Duration(seconds: 15), () {
            if (mounted) {
              setState(() {
                _selectedWaypoint = null;
                _selectedWaypointDetails = null;
              });
            }
          });
        },
      );

      setState(() {
        _waypointMarkers.add(marker);
        _markers = {
          if (_fromLocation != null)
            Marker(
              markerId: const MarkerId('from'),
              position: _fromLocation!,
            ),
          if (_toLocation != null)
            Marker(
              markerId: const MarkerId('to'),
              position: _toLocation!,
            ),
          ..._waypointMarkers,
        };
      });

      // Print in console for debugging
      print(
        'Waypoint $waypointCounter → '
        'Lat=${curr.latitude}, Lng=${curr.longitude}, '
        'Temp=${weatherData['temperature']}°C, '
        'Time=${estimatedTime.hour}:${estimatedTime.minute.toString().padLeft(2, '0')}, '
        'DistFromLast=${(distanceFromLastWaypoint/1000).toStringAsFixed(1)} km',
      );

      // Update last waypoint position
      lastWaypointLat = curr.latitude;
      lastWaypointLng = curr.longitude;

      // Subtract 15 minutes from cumulativeTime
      cumulativeTime -= intervalSeconds;
    }
  }
}


  String _formatTime(DateTime time) {
    int minutes = time.minute;
    int remainder = minutes % 15;
    
    // Round up if remainder is 8 or more, otherwise round down
    if (remainder >= 8) {
      time = time.add(Duration(minutes: 15 - remainder));  // Round up
    } else {
      time = time.subtract(Duration(minutes: remainder));  // Round down
    }
    
    return "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _getPlaceSuggestions(String input) async {
    final String apiKey = AppConfig.goMapsApiKey;
    final String requestUrl =
        'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$apiKey';
    
    try {
      final response = await http.get(Uri.parse(requestUrl));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _placeSuggestions = data['predictions'];
        });
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
    }
  }

  Future<LatLng> _getCoordinates(String placeId) async {
    final String apiKey = AppConfig.goMapsApiKey;
    final String detailsUrl =
        'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    final response = await http.get(Uri.parse(detailsUrl));
    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      final location = data['result']['geometry']['location'];
      return LatLng(location['lat'], location['lng']);
    } else {
      throw Exception('Failed to fetch coordinates');
    }
  }

  Future<void> _fetchRoute() async {
    final String apiKey = AppConfig.goMapsApiKey;
    final String routeUrl =
        'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(routeUrl));
    final data = json.decode(response.body);
    
    if (response.statusCode == 200 && data['routes'].isNotEmpty) {
      final points = data['routes'][0]['overview_polyline']['points'];
      final decodedPoints = _decodePolyline(points);
      int totalDuration = data['routes'][0]['legs'][0]['duration']['value']; // Total journey duration in seconds
      _calculateWaypoints(decodedPoints, totalDuration);
      _setPolyline(points);
    } else {
      print('Error fetching route data');
    }
  }

  void _setPolyline(String encodedPolyline) {
    final List<LatLng> points = _decodePolyline(encodedPolyline);
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      };
      _markers = {
        if (_fromLocation != null)
          Marker(
            markerId: const MarkerId('from'),
            position: _fromLocation!,
          ),
        if (_toLocation != null)
          Marker(
            markerId: const MarkerId('to'),
            position: _toLocation!,
          ),
        ..._waypointMarkers,
      };
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  @override
  void initState() {
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather-Aware Route'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(25.0, 67.0),
              zoom: 10,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            polylines: _polylines,
            markers: _markers,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildSearchField(_fromController, 'From', true),
                const SizedBox(height: 10),
                _buildSearchField(_toController, 'To', false),
                if (_placeSuggestions.isNotEmpty)
                  Container(
                    color: Colors.white,
                    height: 150,
                    child: ListView.builder(
                      itemCount: _placeSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_placeSuggestions[index]['description']),
                          onTap: () async {
                            final placeId = _placeSuggestions[index]['place_id'];
                            final coordinates = await _getCoordinates(placeId);

                            setState(() {
                              if (isSelectingFrom) {
                                _fromLocation = coordinates;
                                _fromController.text =
                                    _placeSuggestions[index]['description'];
                              } else {
                                _toLocation = coordinates;
                                _toController.text =
                                    _placeSuggestions[index]['description'];
                              }
                              _placeSuggestions = [];
                            });

                            if (_fromLocation != null && _toLocation != null) {
                              _fetchRoute();
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedWaypoint != null)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _selectedWaypoint != null ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "🚀 Route Checkpoint",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      Text(
                        _selectedWaypointDetails ?? "",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
      TextEditingController controller, String hint, bool isFrom) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.location_on),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onTap: () {
          setState(() {
            isSelectingFrom = isFrom;
          });
        },
        onChanged: (value) {
          if (value.isNotEmpty) {
            _getPlaceSuggestions(value);
          } else {
            setState(() {
              _placeSuggestions = [];
            });
          }
        },
      ),
    );
  }
}














// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:csv/csv.dart';
// import 'package:http/http.dart' as http;
// import 'package:agaahi/config.dart';
// // final String apiKey = AppConfig.goMapsApiKey;

// class TravelRouteScreen extends StatefulWidget {
//   const TravelRouteScreen({super.key});

//   @override
//   _TravelRouteScreenState createState() => _TravelRouteScreenState();
// }

// class _TravelRouteScreenState extends State<TravelRouteScreen> {
//   GoogleMapController? _mapController;
//   final TextEditingController _fromController = TextEditingController();
//   final TextEditingController _toController = TextEditingController();
//   LatLng? _fromLocation;
//   LatLng? _toLocation;
//   Set<Polyline> _polylines = {};
//   Set<Marker> _markers = {};
//   List<dynamic> _placeSuggestions = [];


//   LatLng? _selectedWaypoint;
//   String? _selectedWaypointDetails;

//   bool isSelectingFrom = true;

//   // Add waypoint markers
//   final Set<Marker> _waypointMarkers = {};

//   final List<Map<String, dynamic>> _temperatureData = [];

// Future<void> loadTemperatureData() async {
//   final rawData = await rootBundle.loadString("assets/interpolated_points_17.csv");
//   List<List<dynamic>> csvTable = const CsvToListConverter().convert(rawData);

//   _temperatureData.clear(); // Ensure fresh data

//   for (var i = 1; i < csvTable.length; i++) {
//     _temperatureData.add({
//       'Longitude': double.tryParse(csvTable[i][0].toString()) ?? 0.0,
//       'Latitude': double.tryParse(csvTable[i][1].toString()) ?? 0.0,
//       'Interpolated_Value': double.tryParse(csvTable[i][2].toString()) ?? 0.0,
//     });
//   }
// }


// double _haversineDistance(LatLng point1, LatLng point2) {
//   const double earthRadius = 6371e3;
//   double lat1 = point1.latitude * pi / 180;
//   double lon1 = point1.longitude * pi / 180;
//   double lat2 = point2.latitude * pi / 180;
//   double lon2 = point2.longitude * pi / 180;

//   double dLat = lat2 - lat1;
//   double dLon = lon2 - lon1;

//   double a = sin(dLat / 2) * sin(dLat / 2) +
//       cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
//   double c = 2 * atan2(sqrt(a), sqrt(1 - a));

//   return earthRadius * c; // Distance in meters
// }

// // Function to find the closest temperature data point
// double _getTemperatureForLocation(LatLng point) {
//   double minDistance = double.infinity;
//   double closestTemp = 0.0;

//   for (var data in _temperatureData) {
//     LatLng tempPoint = LatLng(data['Latitude'], data['Longitude']);
//     double distance = _haversineDistance(point, tempPoint);

//     if (distance < minDistance) {
//       minDistance = distance;
//       closestTemp = data['Interpolated_Value'];
//     }
//   }

//   return closestTemp;
// }

// void _calculateWaypoints(List<LatLng> points, int totalDurationSeconds) {
//   // Clear old markers
//   _waypointMarkers.clear();

//   //------------------------------
//   // 1) First pass: total distance
//   //------------------------------
//   double entireRouteDistance = 0;
//   for (int i = 1; i < points.length; i++) {
//     entireRouteDistance += _haversineDistance(points[i - 1], points[i]);
//   }

//   //------------------------------
//   // 2) Place waypoints every 15 min
//   //------------------------------
//   // Round total duration to nearest 15 minutes
//   int roundedDuration = (totalDurationSeconds ~/ 900) * 900;
//   int intervalSeconds = 900; // 15-minute chunk
//   int waypointCounter = 0;

//   // Keep track of how much "time" has elapsed
//   double cumulativeTime = 0;

//   // For distance from the previous waypoint
//   double lastWaypointLat = points[0].latitude;
//   double lastWaypointLng = points[0].longitude;

//   // We'll assume the journey "starts now"
//   DateTime startTime = DateTime.now();

//   for (int i = 1; i < points.length; i++) {
//     LatLng prev = points[i - 1];
//     LatLng curr = points[i];

//     // Fraction of entire trip for this segment
//     double segmentDistance = _haversineDistance(prev, curr);
//     double fraction = segmentDistance / entireRouteDistance;

//     // How many seconds that fraction corresponds to
//     double segmentTime = fraction * roundedDuration;

//     // Add this segment’s time to cumulativeTime
//     cumulativeTime += segmentTime;

//     // Each time we cross 900s (15 minutes), place a waypoint
//     while (cumulativeTime >= intervalSeconds) {
//       waypointCounter++;

//       // Figure out the "clock time" for this waypoint
//       DateTime estimatedTime = startTime.add(
//         Duration(seconds: waypointCounter * intervalSeconds),
//       );

//       // Grab temperature at this location
//       double temp = _getTemperatureForLocation(curr);

//       // Calculate distance from the last waypoint
//       double distanceFromLastWaypoint = _haversineDistance(
//         LatLng(lastWaypointLat, lastWaypointLng),
//         curr,
//       );

//       // Prepare snippet text
//       String infoSnippet = """
// 📌 Waypoint $waypointCounter
// 🌡️ ${temp.toStringAsFixed(1)}°C
// ⏰ ${_formatTime(estimatedTime)}
// 📏 ${(distanceFromLastWaypoint/1000).toStringAsFixed(1)} km
// """;

//       // Create a marker with an onTap callback
//       _waypointMarkers.add(
//         Marker(
//           markerId: MarkerId('waypoint_$waypointCounter'),
//           position: curr,
//           infoWindow: InfoWindow(
//             title: '🚀 Route Checkpoint!',
//             snippet: infoSnippet,
//           ),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueOrange,
//           ),
//           // When tapped, store details for the "enlarged info window"
//           onTap: () {
//             setState(() {
//               _selectedWaypoint = curr;
//               _selectedWaypointDetails = infoSnippet;
//             });
//             // Auto-hide after 3 seconds
//             Future.delayed(const Duration(seconds: 3), () {
//               setState(() {
//                 _selectedWaypoint = null;
//                 _selectedWaypointDetails = null;
//               });
//             });
//           },
//         ),
//       );

//       // Print in console for debugging
//       print(
//         'Waypoint $waypointCounter → '
//         'Lat=${curr.latitude}, Lng=${curr.longitude}, '
//         'Temp=$temp°C, Time=${_formatTime(estimatedTime)}, '
//         'DistFromLast=${(distanceFromLastWaypoint/1000).toStringAsFixed(1)} km',
//       );

//       // Update last waypoint position
//       lastWaypointLat = curr.latitude;
//       lastWaypointLng = curr.longitude;

//       // Subtract 15 minutes from cumulativeTime
//       cumulativeTime -= intervalSeconds;
//     }
//   }
// }

// String _formatTime(DateTime time) {
//   int minutes = time.minute;
//   int remainder = minutes % 15;
  
//   // Round up if remainder is 8 or more, otherwise round down
//   if (remainder >= 8) {
//     time = time.add(Duration(minutes: 15 - remainder));  // Round up
//   } else {
//     time = time.subtract(Duration(minutes: remainder));  // Round down
//   }
  
//   return "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
// }



//   Future<void> _getPlaceSuggestions(String input) async {
//     // const String apiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx"; 
//     final String apiKey = AppConfig.goMapsApiKey;
//     final String requestUrl =
//         'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$apiKey';
//     // print('Owais');
//     try {
//       final response = await http.get(Uri.parse(requestUrl));
//       final data = json.decode(response.body);

//       if (response.statusCode == 200) {
//         setState(() {
//           _placeSuggestions = data['predictions'];
//         });
//       }
//     } catch (e) {
//       print('Error fetching suggestions: $e');
//     }
//   }

//   Future<LatLng> _getCoordinates(String placeId) async {
//     // const String apiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
//     final String apiKey = AppConfig.goMapsApiKey;
//     final String detailsUrl =
//         'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

//     final response = await http.get(Uri.parse(detailsUrl));
//     final data = json.decode(response.body);

//     if (response.statusCode == 200) {
//       final location = data['result']['geometry']['location'];
//       return LatLng(location['lat'], location['lng']);
//     } else {
//       throw Exception('Failed to fetch coordinates');
//     }
//   }

//   Future<void> _fetchRoute() async {
//     // const String apiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
//     final String apiKey = AppConfig.goMapsApiKey;
//     final String routeUrl =
//         'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$apiKey';

//     final response = await http.get(Uri.parse(routeUrl));
//     final data = json.decode(response.body);
//     print(data);
    
//     if (response.statusCode == 200 && data['routes'].isNotEmpty) {
//       final points = data['routes'][0]['overview_polyline']['points'];
//       final decodedPoints = _decodePolyline(points);
//       int totalDuration = data['routes'][0]['legs'][0]['duration']['value']; // Total journey duration in seconds
//       _calculateWaypoints(decodedPoints, totalDuration);
//       // _calculateWaypoints(decodedPoints);
//       _setPolyline(points);
//     } else {
//       print('Error fetching route data');
//     }
//   }

//   void _setPolyline(String encodedPolyline) {
//     final List<LatLng> points = _decodePolyline(encodedPolyline);
//     setState(() {
//       _polylines = {
//         Polyline(
//           polylineId: const PolylineId('route'),
//           points: points,
//           color: Colors.blue,
//           width: 5,
//         ),
//       };
//       _markers = {
//         if (_fromLocation != null)
//           Marker(
//             markerId: const MarkerId('from'),
//             position: _fromLocation!,
//           ),
//         if (_toLocation != null)
//           Marker(
//             markerId: const MarkerId('to'),
//             position: _toLocation!,
//           ),
//         ..._waypointMarkers,
//       };
//     });
//   }


//   List<LatLng> _decodePolyline(String encoded) {
//     List<LatLng> poly = [];
//     int index = 0, len = encoded.length;
//     int lat = 0, lng = 0;

//     while (index < len) {
//       int b, shift = 0, result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
//       lat += dlat;

//       shift = 0;
//       result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
//       lng += dlng;

//       poly.add(LatLng(lat / 1E5, lng / 1E5));
//     }
//     return poly;
//   }

//   @override
//   void initState() {
//   super.initState();
//   loadTemperatureData();
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Travel Route'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: const CameraPosition(
//               target: LatLng(25.0, 67.0),
//               zoom: 10,
//             ),
//             onMapCreated: (controller) {
//               _mapController = controller;
//             },
//             polylines: _polylines,
//             markers: _markers,
//           ),
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 10,
//             child: Column(
//               children: [
//                 _buildSearchField(_fromController, 'From', true),
//                 const SizedBox(height: 10),
//                 _buildSearchField(_toController, 'To', false),
//                 if (_placeSuggestions.isNotEmpty)
//                   Container(
//                     color: Colors.white,
//                     height: 150,
//                     child: ListView.builder(
//                       itemCount: _placeSuggestions.length,
//                       itemBuilder: (context, index) {
//                         return ListTile(
//                           title: Text(_placeSuggestions[index]['description']),
//                           onTap: () async {
//                             final placeId = _placeSuggestions[index]['place_id'];
//                             final coordinates = await _getCoordinates(placeId);

//                             setState(() {
//                               if (isSelectingFrom) {
//                                 _fromLocation = coordinates;
//                                 _fromController.text =
//                                     _placeSuggestions[index]['description'];
//                               } else {
//                                 _toLocation = coordinates;
//                                 _toController.text =
//                                     _placeSuggestions[index]['description'];
//                               }
//                               _placeSuggestions = [];
//                             });

//                             if (_fromLocation != null && _toLocation != null) {
//                               _fetchRoute();
//                             }
//                           },
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           if (_selectedWaypoint != null)
//   Positioned(
//     bottom: 50,
//     left: 20,
//     right: 20,
//     child: AnimatedOpacity(
//       duration: const Duration(milliseconds: 500),
//       opacity: _selectedWaypoint != null ? 1.0 : 0.0,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: const [
//             BoxShadow(color: Colors.black26, blurRadius: 10),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               "🚀 Route Checkpoint",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const Divider(),
//             Text(
//               _selectedWaypointDetails ?? "",
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     ),
//   ),

//         ],
//       ),
//     );
//   }

//   Widget _buildSearchField(
//       TextEditingController controller, String hint, bool isFrom) {
//     return Material(
//       elevation: 5,
//       borderRadius: BorderRadius.circular(8),
//       child: TextField(
//         controller: controller,
//         decoration: InputDecoration(
//           hintText: hint,
//           prefixIcon: const Icon(Icons.location_on),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(8),
//             borderSide: BorderSide.none,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         onTap: () {
//           setState(() {
//             isSelectingFrom = isFrom;
//           });
//         },
//         onChanged: (value) {
//           if (value.isNotEmpty) {
//             _getPlaceSuggestions(value);
//           } else {
//             setState(() {
//               _placeSuggestions = [];
//             });
//           }
//         },
//       ),
//     );
//   }
// }

