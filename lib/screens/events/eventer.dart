import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:agaahi/config.dart';
// final String apiKey = AppConfig.goMapsApiKey;

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

  // For displaying the info box about the selected marker
  String? _infoMarkerDetails;

  // Timer to control how long the info box is visible
  Timer? infoBoxTimer;

  final List<Map<String, dynamic>> _temperatureData = [];

  @override
  void initState() {
    super.initState();
    loadTemperatureData();
  }

  Future<void> loadTemperatureData() async {
    final rawData =
        await rootBundle.loadString("assets/interpolated_points_17.csv");
    List<List<dynamic>> csvTable =
        const CsvToListConverter().convert(rawData);

    _temperatureData.clear();

    // Assuming the first row is a header
    for (var i = 1; i < csvTable.length; i++) {
      _temperatureData.add({
        'Longitude': double.tryParse(csvTable[i][0].toString()) ?? 0.0,
        'Latitude': double.tryParse(csvTable[i][1].toString()) ?? 0.0,
        'Interpolated_Value':
            double.tryParse(csvTable[i][2].toString()) ?? 0.0,
      });
    }
  }

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

  // Returns the closest temperature value from the CSV data.
  double _getTemperatureForLocation(LatLng point) {
    double minDistance = double.infinity;
    double closestTemp = 0.0;

    for (var data in _temperatureData) {
      LatLng tempPoint = LatLng(data['Latitude'], data['Longitude']);
      double distance = _haversineDistance(point, tempPoint);
      if (distance < minDistance) {
        minDistance = distance;
        closestTemp = data['Interpolated_Value'];
      }
    }
    return closestTemp;
  }

  // Shows the info box with details and makes sure it stays visible for [duration] seconds.
  void showInfoBox(String info, {int duration = 10}) {
    // Cancel any previous timer.
    infoBoxTimer?.cancel();
    setState(() {
      _infoMarkerDetails = info;
    });
    // Hide the info box after [duration] seconds.
    infoBoxTimer = Timer(Duration(seconds: duration), () {
      setState(() {
        _infoMarkerDetails = null;
      });
    });
  }

  // Get place suggestions using the Places API.
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

  // Get coordinates for the given Place ID.
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

  // Called when a suggestion is selected from the search field.
  Future<void> _onPlaceSelected(String placeId, String description) async {
    try {
      final coordinates = await _getCoordinates(placeId);
      final temp = _getTemperatureForLocation(coordinates);
      final infoText = "📍 $description\n"
          "🌡️ Temperature: ${temp.toStringAsFixed(1)}°C\n"
          "💧 Dew Point: 23.4°C\n"
          "🌫️ Humidity: 16.3°C\n"
          "📏 Lat: ${coordinates.latitude.toStringAsFixed(3)}, "
          "Lng: ${coordinates.longitude.toStringAsFixed(3)}";

      // Create a marker with an onTap to re-display the info box.
      final marker = Marker(
        markerId: const MarkerId('selected_location'),
        position: coordinates,
        infoWindow: InfoWindow(title: description, snippet: infoText),
        onTap: () {
          showInfoBox(infoText, duration: 10);
        },
      );

      setState(() {
        _selectedLocation = coordinates;
        _markers = {marker};
        _placeSuggestions = [];
        _searchController.text = description;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(coordinates, 14),
      );

      // Show the info box initially for 10 seconds.
      showInfoBox(infoText, duration: 10);
    } catch (e) {
      print('Error selecting place: $e');
    }
  }

  @override
  void dispose() {
    // Cancel the info box timer when disposing.
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
          // GoogleMap is rendered without a GestureDetector since the double-tap feature is removed.
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
          // Search field and suggestion list at the top.
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
          // Info box at the bottom for the selected marker.
          if (_infoMarkerDetails != null)
            Positioned(
              bottom: 50,
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
}







// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:csv/csv.dart';
// import 'package:http/http.dart' as http;

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
//     const String apiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
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
//     const String apiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
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





