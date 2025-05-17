import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:agaahi/config.dart';

class Eventer extends StatefulWidget {
  const Eventer({super.key});

  @override
  _EventerState createState() => _EventerState();
}

class _EventerState extends State<Eventer> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  List<dynamic> _placeSuggestions = [];

  // Weather data from API
  List<Map<String, dynamic>> _weatherData = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Current selected timestamp index
  int _selectedTimeIndex = 0;

  // For displaying the info box about the selected marker
  Map<String, dynamic>? _selectedWeatherPoint;

  // Timer to control how long the info box is visible
  Timer? infoBoxTimer;

  @override
  void initState() {
    super.initState();
  }

  // Get place suggestions using the Places API
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

  // Get coordinates for the given Place ID
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

  // Fetch weather data for the given location
  Future<void> _fetchWeatherData(LatLng coordinates) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _weatherData = [];
    });

    try {
      // Generate timestamps for the next 6 hours with 15-minute intervals
      final List<String> timestamps = _generateTimestamps();
      final List<Map<String, dynamic>> allWeatherData = [];

      // Make API requests for each timestamp
      for (String timestamp in timestamps) {
        final response = await _fetchWeatherForTimestamp(coordinates, timestamp);
        
        // Extract points from response and add timestamp info
        if (response != null && response.containsKey('points')) {
          final List<dynamic> points = response['points'];
          for (var point in points) {
            // Ensure the point has the timestamp
            point['display_timestamp'] = timestamp;
            allWeatherData.add(Map<String, dynamic>.from(point));
          }
        }
      }

      setState(() {
        _weatherData = allWeatherData;
        _isLoading = false;
        
        // Set the first weather point as selected if available
        if (_weatherData.isNotEmpty) {
          _selectedWeatherPoint = _findClosestWeatherPoint(coordinates, _weatherData.where(
            (point) => point['display_timestamp'] == timestamps[_selectedTimeIndex]
          ).toList());
          _updateMarkerInfo();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch weather data: $e';
      });
      print('Error fetching weather data: $e');
    }
  }

  // Generate timestamps for the next 6 hours with 15-minute intervals
  List<String> _generateTimestamps() {
    final List<String> timestamps = [];
    final now = DateTime.now();
    
    // Round to the nearest 15 minutes
    final minutes = (now.minute ~/ 15) * 15;
    final roundedNow = DateTime(now.year, now.month, now.day, now.hour, minutes);


    // // Round to nearest 15-minute interval
    // final minutes = ((now.minute + 7) ~/ 15) * 15;
    // final roundedNow = DateTime(now.year, now.month, now.day, now.hour, 0).add(Duration(minutes: minutes));

    // Subtract 1 year
    final adjustedTime = DateTime(roundedNow.year - 1, roundedNow.month, roundedNow.day-9, roundedNow.hour, roundedNow.minute);

    print(adjustedTime);  // Output: rounded time - 1 year
    
    for (int i = 0; i < 24; i++) { // 24 intervals of 15 minutes = 6 hours
      final timestamp = adjustedTime.add(Duration(minutes: 15 * i));
      timestamps.add(DateFormat("yyyy-MM-dd'T'HH:mm:00").format(timestamp));
    }
    
    return timestamps;
  }

  // Fetch weather data for a specific timestamp
  Future<Map<String, dynamic>?> _fetchWeatherForTimestamp(LatLng coordinates, String timestamp) async {
    try {
      final url = 'https://weather-db-b91w.onrender.com/api/v1/interpolation/by-location-and-timestamp';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'longitude': coordinates.longitude,
          'latitude': coordinates.latitude,
          'timestamp': timestamp,
          'max_distance': 10000
        })
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching data for timestamp $timestamp: $e');
      return null;
    }
  }

  // Find the closest weather point to the given coordinates
  Map<String, dynamic> _findClosestWeatherPoint(LatLng coordinates, List<Map<String, dynamic>> points) {
    if (points.isEmpty) {
      return {};
    }
    
    double minDistance = double.infinity;
    Map<String, dynamic> closestPoint = points.first;
    
    for (var point in points) {
      final pointLatLng = LatLng(point['latitude'], point['longitude']);
      final distance = _haversineDistance(coordinates, pointLatLng);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }
    
    return closestPoint;
  }

  // Calculate the haversine distance between two points
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
    return earthRadius * c;
  }

  // Update the marker with the selected weather point
  void _updateMarkerInfo() {
    if (_selectedLocation == null || _selectedWeatherPoint == null || _selectedWeatherPoint!.isEmpty) {
      return;
    }

    final formattedTime = _formatTimestamp(_selectedWeatherPoint!['display_timestamp']);
    final infoText = "📍 ${_searchController.text}\n"
        "🕒 Time: $formattedTime\n"
        "🌡️ Temperature: ${_selectedWeatherPoint!['temperature']?.toStringAsFixed(1)}°C\n"
        "💨 Wind Speed: ${_selectedWeatherPoint!['wind_speed']?.toStringAsFixed(1)} m/s\n"
        "💧 Dew Point: ${_selectedWeatherPoint!['dew_point']?.toStringAsFixed(1)}°C\n"
        "🌫️ Humidity: ${_selectedWeatherPoint!['humidity']?.toStringAsFixed(1)}%\n"
        "📏 Lat: ${_selectedLocation!.latitude.toStringAsFixed(3)}, "
        "Lng: ${_selectedLocation!.longitude.toStringAsFixed(3)}";

    // Create a marker with an onTap to re-display the info box
    final marker = Marker(
      markerId: const MarkerId('selected_location'),
      position: _selectedLocation!,
      infoWindow: InfoWindow(title: _searchController.text, snippet: formattedTime),
      onTap: () {
        showInfoBox(infoText, duration: 10);
      },
    );

    setState(() {
      _markers = {marker};
    });

    // Show the info box initially for 10 seconds
    showInfoBox(infoText, duration: 10);
  }

  // Format timestamp for display
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  // Shows the info box with details and makes sure it stays visible for [duration] seconds
  void showInfoBox(String info, {int duration = 10}) {
    // Cancel any previous timer
    infoBoxTimer?.cancel();
    setState(() {
      _infoMarkerDetails = info;
    });
    // Hide the info box after [duration] seconds
    infoBoxTimer = Timer(Duration(seconds: duration), () {
      setState(() {
        _infoMarkerDetails = null;
      });
    });
  }

  // For displaying the info box about the selected marker
  String? _infoMarkerDetails;

  // Called when a suggestion is selected from the search field
  Future<void> _onPlaceSelected(String placeId, String description) async {
    try {
      final coordinates = await _getCoordinates(placeId);
      
      setState(() {
        _selectedLocation = coordinates;
        _placeSuggestions = [];
        _searchController.text = description;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(coordinates, 14),
      );

      // Fetch weather data for the selected location
      await _fetchWeatherData(coordinates);
    } catch (e) {
      print('Error selecting place: $e');
    }
  }

  // Called when a timestamp is selected from the timeline
  void _onTimeSelected(int index, String timestamp) {
    if (_selectedLocation == null || _weatherData.isEmpty) return;
    
    setState(() {
      _selectedTimeIndex = index;
      
      // Filter weather data for the selected timestamp
      final timeData = _weatherData.where(
        (point) => point['display_timestamp'] == timestamp
      ).toList();
      
      if (timeData.isNotEmpty) {
        _selectedWeatherPoint = _findClosestWeatherPoint(_selectedLocation!, timeData);
        _updateMarkerInfo();
      }
    });
  }

  @override
  void dispose() {
    // Cancel the info box timer when disposing
    infoBoxTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Management Info'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(25.0, 67.0),
              zoom: 10,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
          ),
          // Search field and suggestion list at the top
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Material(
                  elevation: 5,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Location',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
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
                ),
                if (_placeSuggestions.isNotEmpty)
                  Container(
                    color: Colors.white,
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _placeSuggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title:
                              Text(_placeSuggestions[index]['description']),
                          onTap: () => _onPlaceSelected(
                            _placeSuggestions[index]['place_id'],
                            _placeSuggestions[index]['description'],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Time interval selector at the bottom
          if (_weatherData.isNotEmpty)
            Positioned(
              bottom: _infoMarkerDetails != null ? 170 : 20,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildTimeIntervalSelector(),
              ),
            ),
          // Loading indicator
          if (_isLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading weather data...'),
                  ],
                ),
              ),
            ),
          // Error message
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          // Info box at the bottom for the selected marker
          if (_infoMarkerDetails != null)
            Positioned(
              bottom: 130,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _infoMarkerDetails != null ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10),
                    ],
                  ),
                  child: Text(
                    _infoMarkerDetails!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build the time interval selector widget
  Widget _buildTimeIntervalSelector() {
    // Get unique timestamps
    final timestamps = _getUniqueTimestamps();
    
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timestamps.length,
        itemBuilder: (context, index) {
          final timestamp = timestamps[index];
          final isSelected = index == _selectedTimeIndex;
          final formattedTime = _formatTimestamp(timestamp);
          
          return GestureDetector(
            onTap: () => _onTimeSelected(index, timestamp),
            child: Container(
              width: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formattedTime.split(', ')[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  Text(
                    formattedTime.split(', ')[1],
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Get unique timestamps from the weather data
  List<String> _getUniqueTimestamps() {
    final timestamps = _weatherData
        .map((data) => data['display_timestamp'] as String)
        .toSet()
        .toList();
    
    // Sort timestamps chronologically
    timestamps.sort();
    
    return timestamps;
  }
}



// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:csv/csv.dart';
// import 'package:http/http.dart' as http;
// import 'package:agaahi/config.dart';
// // final String apiKey = AppConfig.goMapsApiKey;

// class Eventer extends StatefulWidget {
//   const Eventer({super.key});

//   @override
//   _EventerState createState() => _EventerState();
// }

// class _EventerState extends State<Eventer> {
//   GoogleMapController? _mapController;
//   final TextEditingController _searchController = TextEditingController();
//   LatLng? _selectedLocation;
//   Set<Marker> _markers = {};
//   List<dynamic> _placeSuggestions = [];

//   // For displaying the info box about the selected marker
//   String? _infoMarkerDetails;

//   // Timer to control how long the info box is visible
//   Timer? infoBoxTimer;

//   final List<Map<String, dynamic>> _temperatureData = [];

//   @override
//   void initState() {
//     super.initState();
//     loadTemperatureData();
//   }

//   Future<void> loadTemperatureData() async {
//     final rawData =
//         await rootBundle.loadString("assets/interpolated_points_17.csv");
//     List<List<dynamic>> csvTable =
//         const CsvToListConverter().convert(rawData);

//     _temperatureData.clear();

//     // Assuming the first row is a header
//     for (var i = 1; i < csvTable.length; i++) {
//       _temperatureData.add({
//         'Longitude': double.tryParse(csvTable[i][0].toString()) ?? 0.0,
//         'Latitude': double.tryParse(csvTable[i][1].toString()) ?? 0.0,
//         'Interpolated_Value':
//             double.tryParse(csvTable[i][2].toString()) ?? 0.0,
//       });
//     }
//   }

//   double _haversineDistance(LatLng point1, LatLng point2) {
//     const double earthRadius = 6371e3;
//     double lat1 = point1.latitude * pi / 180;
//     double lon1 = point1.longitude * pi / 180;
//     double lat2 = point2.latitude * pi / 180;
//     double lon2 = point2.longitude * pi / 180;

//     double dLat = lat2 - lat1;
//     double dLon = lon2 - lon1;

//     double a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
//     double c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return earthRadius * c;
//   }

//   // Returns the closest temperature value from the CSV data.
//   double _getTemperatureForLocation(LatLng point) {
//     double minDistance = double.infinity;
//     double closestTemp = 0.0;

//     for (var data in _temperatureData) {
//       LatLng tempPoint = LatLng(data['Latitude'], data['Longitude']);
//       double distance = _haversineDistance(point, tempPoint);
//       if (distance < minDistance) {
//         minDistance = distance;
//         closestTemp = data['Interpolated_Value'];
//       }
//     }
//     return closestTemp;
//   }

//   // Shows the info box with details and makes sure it stays visible for [duration] seconds.
//   void showInfoBox(String info, {int duration = 10}) {
//     // Cancel any previous timer.
//     infoBoxTimer?.cancel();
//     setState(() {
//       _infoMarkerDetails = info;
//     });
//     // Hide the info box after [duration] seconds.
//     infoBoxTimer = Timer(Duration(seconds: duration), () {
//       setState(() {
//         _infoMarkerDetails = null;
//       });
//     });
//   }

//   // Get place suggestions using the Places API.
//   Future<void> _getPlaceSuggestions(String input) async {
//     final String apiKey = AppConfig.goMapsApiKey;
//     final String requestUrl =
//         'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$apiKey';
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

//   // Get coordinates for the given Place ID.
//   Future<LatLng> _getCoordinates(String placeId) async {
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

//   // Called when a suggestion is selected from the search field.
//   Future<void> _onPlaceSelected(String placeId, String description) async {
//     try {
//       final coordinates = await _getCoordinates(placeId);
//       final temp = _getTemperatureForLocation(coordinates);
//       final infoText = "📍 $description\n"
//           "🌡️ Temperature: ${temp.toStringAsFixed(1)}°C\n"
//           "💧 Dew Point: 23.4°C\n"
//           "🌫️ Humidity: 16.3°C\n"
//           "📏 Lat: ${coordinates.latitude.toStringAsFixed(3)}, "
//           "Lng: ${coordinates.longitude.toStringAsFixed(3)}";

//       // Create a marker with an onTap to re-display the info box.
//       final marker = Marker(
//         markerId: const MarkerId('selected_location'),
//         position: coordinates,
//         infoWindow: InfoWindow(title: description, snippet: infoText),
//         onTap: () {
//           showInfoBox(infoText, duration: 10);
//         },
//       );

//       setState(() {
//         _selectedLocation = coordinates;
//         _markers = {marker};
//         _placeSuggestions = [];
//         _searchController.text = description;
//       });

//       _mapController?.animateCamera(
//         CameraUpdate.newLatLngZoom(coordinates, 14),
//       );

//       // Show the info box initially for 10 seconds.
//       showInfoBox(infoText, duration: 10);
//     } catch (e) {
//       print('Error selecting place: $e');
//     }
//   }

//   @override
//   void dispose() {
//     // Cancel the info box timer when disposing.
//     infoBoxTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Event Management Info'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Stack(
//         children: [
//           // GoogleMap is rendered without a GestureDetector since the double-tap feature is removed.
//           GoogleMap(
//             initialCameraPosition: const CameraPosition(
//               target: LatLng(25.0, 67.0),
//               zoom: 10,
//             ),
//             onMapCreated: (controller) {
//               _mapController = controller;
//             },
//             markers: _markers,
//           ),
//           // Search field and suggestion list at the top.
//           Positioned(
//             top: 10,
//             left: 10,
//             right: 10,
//             child: Column(
//               children: [
//                 Material(
//                   elevation: 5,
//                   borderRadius: BorderRadius.circular(8),
//                   child: TextField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       hintText: 'Search Location',
//                       prefixIcon: const Icon(Icons.location_on),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.white,
//                     ),
//                     onChanged: (value) {
//                       if (value.isNotEmpty) {
//                         _getPlaceSuggestions(value);
//                       } else {
//                         setState(() {
//                           _placeSuggestions = [];
//                         });
//                       }
//                     },
//                   ),
//                 ),
//                 if (_placeSuggestions.isNotEmpty)
//                   Container(
//                     color: Colors.white,
//                     constraints: const BoxConstraints(maxHeight: 150),
//                     child: ListView.builder(
//                       shrinkWrap: true,
//                       itemCount: _placeSuggestions.length,
//                       itemBuilder: (context, index) {
//                         return ListTile(
//                           title:
//                               Text(_placeSuggestions[index]['description']),
//                           onTap: () => _onPlaceSelected(
//                             _placeSuggestions[index]['place_id'],
//                             _placeSuggestions[index]['description'],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           // Info box at the bottom for the selected marker.
//           if (_infoMarkerDetails != null)
//             Positioned(
//               bottom: 50,
//               left: 20,
//               right: 20,
//               child: AnimatedOpacity(
//                 duration: const Duration(milliseconds: 500),
//                 opacity: _infoMarkerDetails != null ? 1.0 : 0.0,
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: const [
//                       BoxShadow(color: Colors.black26, blurRadius: 10),
//                     ],
//                   ),
//                   child: Text(
//                     _infoMarkerDetails!,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 16),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }






