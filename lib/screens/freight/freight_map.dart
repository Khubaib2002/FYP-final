import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:agaahi/config.dart';
// final String apiKey = AppConfig.goMapsApiKey;

class MapFreight extends StatefulWidget {
  final String fromLocation;
  final String toLocation;

  const MapFreight({
    super.key,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<MapFreight> createState() => MapFreightState();
}

class MapFreightState extends State<MapFreight> {
  GoogleMapController? _controller;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  List<dynamic> _placeList = [];
  String _sessionToken = Random().nextInt(100000000).toString();
  String _lastInput = '';
  LatLng _fromCoordinates =
      const LatLng(24.8607, 67.0011); // Default to Karachi
  LatLng _toCoordinates = const LatLng(24.8607, 69.0011); // Default to Karachi
  Set<Marker> _markers = {};


  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(25, 67),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _fromController.text = widget.fromLocation;
    _toController.text = widget.toLocation;
    _fromController.addListener(() => _onSearchChanged(_fromController));
    _toController.addListener(() => _onSearchChanged(_toController));
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _onSearchChanged(TextEditingController controller) {
    String currentInput = controller.text.trim();
    if (currentInput == _lastInput || currentInput.isEmpty) return;
    _lastInput = currentInput;

    if (_sessionToken.isEmpty) {
      setState(() {
        _sessionToken = Random().nextInt(100000000).toString();
      });
    }
    _getSuggestions(currentInput);
  }

  Future<void> _getSuggestions(String input) async {
    final String placesApiKey = AppConfig.goMapsApiKey;
    const String baseURL =
        'https://maps.gomaps.pro/maps/api/place/autocomplete/json';
    final String request =
        '$baseURL?input=$input&key=$placesApiKey&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(request));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _placeList = data['predictions'];
        });
      } else {
        throw Exception('Failed to load predictions');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<LatLng> _getCoordinates(String placeId) async {
    final String placesApiKey = AppConfig.goMapsApiKey;
    final String detailsURL =
        'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$placesApiKey';

    try {
      final response = await http.get(Uri.parse(detailsURL));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final location = data['result']['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      } else {
        throw Exception('Failed to fetch place details');
      }
    } catch (e) {
      print(e);
      return const LatLng(25, 67); // Default location in case of failure
    }
  }

  Future<void> _moveCameraToBounds(LatLng from, LatLng to) async {
    LatLngBounds bounds;
    if (from.latitude < to.latitude && from.longitude < to.longitude) {
      bounds = LatLngBounds(southwest: from, northeast: to);
    } else {
      bounds = LatLngBounds(southwest: to, northeast: from);
    }

    _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _setCoordinates(String from, String to) async {
    LatLng fromCoords = await _getCoordinates(from);
    LatLng toCoords = await _getCoordinates(to);

    setState(() {
      _fromCoordinates = fromCoords;
      _toCoordinates = toCoords;
      _markers = {
        Marker(
          markerId: const MarkerId('from'),
          position: _fromCoordinates,
          infoWindow: InfoWindow(title: 'From: ${widget.fromLocation}'),
        ),
        Marker(
          markerId: const MarkerId('to'),
          position: _toCoordinates,
          infoWindow: InfoWindow(title: 'To: ${widget.toLocation}'),
        ),
      };
    });
    _moveCameraToBounds(_fromCoordinates, _toCoordinates);
  }

  Widget _buildSearchBoxFrom() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Material(
            elevation: 6,
            shadowColor: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            child: TextField(
              controller: _fromController,
              decoration: InputDecoration(
                hintText: "From",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
          ),
          if (_placeList.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2), blurRadius: 6),
                ],
              ),
              child: ListView.builder(
                itemCount: _placeList.length,
                itemBuilder: (context, index) {
                  final place = _placeList[index];
                  return ListTile(
                    title: Text(
                      place['description'],
                      style: const TextStyle(color: Colors.black),
                    ),
                    onTap: () async {
                      LatLng coordinates =
                          await _getCoordinates(place['place_id']);
                      setState(() {
                        _fromCoordinates = coordinates;
                        _placeList.clear();
                        _fromController.clear();
                      });
                      _moveCameraToBounds(_fromCoordinates, _toCoordinates);
                                        },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBoxTo() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Material(
            elevation: 6,
            shadowColor: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            child: TextField(
              controller: _toController,
              decoration: InputDecoration(
                hintText: "To",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Colors.blueAccent, width: 1.5),
                ),
              ),
            ),
          ),
          if (_placeList.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2), blurRadius: 6),
                ],
              ),
              child: ListView.builder(
                itemCount: _placeList.length,
                itemBuilder: (context, index) {
                  final place = _placeList[index];
                  return ListTile(
                    title: Text(
                      place['description'],
                      style: const TextStyle(color: Colors.black),
                    ),
                    onTap: () async {
                      LatLng coordinates =
                          await _getCoordinates(place['place_id']);
                      setState(() {
                        _toCoordinates = coordinates;
                        _placeList.clear();
                        _toController.clear();
                      });
                      _moveCameraToBounds(_fromCoordinates, _toCoordinates);
                                        },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
            },
            markers: _markers,
          ),
          _buildSearchBoxFrom(),
          const SizedBox(height: 56),
          _buildSearchBoxTo(),
        ],
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;

// class MapFreight extends StatefulWidget {
//   final String fromLocation;
//   final String toLocation;

//   const MapFreight({
//     super.key,
//     required this.fromLocation,
//     required this.toLocation,
//   });

//   @override
//   State<MapFreight> createState() => MapFreightState();
// }

// class MapFreightState extends State<MapFreight> {
//   GoogleMapController? _controller;
//   final TextEditingController _fromController = TextEditingController();
//   final TextEditingController _toController = TextEditingController();
//   List<dynamic> _placeList = [];
//   String _sessionToken = Random().nextInt(100000000).toString();
//   String _lastInput = '';
//   LatLng _fromCoordinates =
//       const LatLng(24.8607, 67.0011); // Default to Karachi
//   LatLng _toCoordinates = const LatLng(24.8607, 69.0011); // Default to Karachi
//   Set<Marker> _markers = {};


//   static const CameraPosition _initialPosition = CameraPosition(
//     target: LatLng(25, 67),
//     zoom: 10,
//   );

//   @override
//   void initState() {
//     super.initState();
//     _fromController.text = widget.fromLocation;
//     _toController.text = widget.toLocation;
//     _fromController.addListener(() => _onSearchChanged(_fromController));
//     _toController.addListener(() => _onSearchChanged(_toController));
//   }

//   @override
//   void dispose() {
//     _fromController.dispose();
//     _toController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged(TextEditingController controller) {
//     String currentInput = controller.text.trim();
//     if (currentInput == _lastInput || currentInput.isEmpty) return;
//     _lastInput = currentInput;

//     if (_sessionToken.isEmpty) {
//       setState(() {
//         _sessionToken = Random().nextInt(100000000).toString();
//       });
//     }
//     _getSuggestions(currentInput);
//   }

//   Future<void> _getSuggestions(String input) async {
//     const String placesApiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
//     const String baseURL =
//         'https://maps.gomaps.pro/maps/api/place/autocomplete/json';
//     final String request =
//         '$baseURL?input=$input&key=$placesApiKey&sessiontoken=$_sessionToken';

//     try {
//       final response = await http.get(Uri.parse(request));
//       final data = json.decode(response.body);

//       if (response.statusCode == 200) {
//         setState(() {
//           _placeList = data['predictions'];
//         });
//       } else {
//         throw Exception('Failed to load predictions');
//       }
//     } catch (e) {
//       print(e);
//     }
//   }

//   Future<LatLng> _getCoordinates(String placeId) async {
//     const String placesApiKey = "AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx";
//     final String detailsURL =
//         'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$placesApiKey';

//     try {
//       final response = await http.get(Uri.parse(detailsURL));
//       final data = json.decode(response.body);

//       if (response.statusCode == 200) {
//         final location = data['result']['geometry']['location'];
//         return LatLng(location['lat'], location['lng']);
//       } else {
//         throw Exception('Failed to fetch place details');
//       }
//     } catch (e) {
//       print(e);
//       return const LatLng(25, 67); // Default location in case of failure
//     }
//   }

//   Future<void> _moveCameraToBounds(LatLng from, LatLng to) async {
//     LatLngBounds bounds;
//     if (from.latitude < to.latitude && from.longitude < to.longitude) {
//       bounds = LatLngBounds(southwest: from, northeast: to);
//     } else {
//       bounds = LatLngBounds(southwest: to, northeast: from);
//     }

//     _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
//   }

//   Future<void> _setCoordinates(String from, String to) async {
//     LatLng fromCoords = await _getCoordinates(from);
//     LatLng toCoords = await _getCoordinates(to);

//     setState(() {
//       _fromCoordinates = fromCoords;
//       _toCoordinates = toCoords;
//       _markers = {
//         Marker(
//           markerId: const MarkerId('from'),
//           position: _fromCoordinates,
//           infoWindow: InfoWindow(title: 'From: ${widget.fromLocation}'),
//         ),
//         Marker(
//           markerId: const MarkerId('to'),
//           position: _toCoordinates,
//           infoWindow: InfoWindow(title: 'To: ${widget.toLocation}'),
//         ),
//       };
//     });
//     _moveCameraToBounds(_fromCoordinates, _toCoordinates);
//   }

//   Widget _buildSearchBoxFrom() {
//     return Positioned(
//       top: 50,
//       left: 20,
//       right: 20,
//       child: Column(
//         children: [
//           Material(
//             elevation: 6,
//             shadowColor: Colors.black.withOpacity(0.3),
//             borderRadius: BorderRadius.circular(20),
//             child: TextField(
//               controller: _fromController,
//               decoration: InputDecoration(
//                 hintText: "From",
//                 hintStyle: const TextStyle(color: Colors.grey),
//                 border: InputBorder.none,
//                 prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
//                 contentPadding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                 filled: true,
//                 fillColor: Colors.white,
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide: BorderSide.none,
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide:
//                       const BorderSide(color: Colors.blueAccent, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//           if (_placeList.isNotEmpty)
//             Container(
//               margin: const EdgeInsets.only(top: 10),
//               height: 200,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(15),
//                 boxShadow: [
//                   BoxShadow(
//                       color: Colors.black.withOpacity(0.2), blurRadius: 6),
//                 ],
//               ),
//               child: ListView.builder(
//                 itemCount: _placeList.length,
//                 itemBuilder: (context, index) {
//                   final place = _placeList[index];
//                   return ListTile(
//                     title: Text(
//                       place['description'],
//                       style: const TextStyle(color: Colors.black),
//                     ),
//                     onTap: () async {
//                       LatLng coordinates =
//                           await _getCoordinates(place['place_id']);
//                       setState(() {
//                         _fromCoordinates = coordinates;
//                         _placeList.clear();
//                         _fromController.clear();
//                       });
//                       _moveCameraToBounds(_fromCoordinates, _toCoordinates);
//                                         },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBoxTo() {
//     return Positioned(
//       top: 120,
//       left: 20,
//       right: 20,
//       child: Column(
//         children: [
//           Material(
//             elevation: 6,
//             shadowColor: Colors.black.withOpacity(0.3),
//             borderRadius: BorderRadius.circular(20),
//             child: TextField(
//               controller: _toController,
//               decoration: InputDecoration(
//                 hintText: "To",
//                 hintStyle: const TextStyle(color: Colors.grey),
//                 border: InputBorder.none,
//                 prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
//                 contentPadding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                 filled: true,
//                 fillColor: Colors.white,
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide: BorderSide.none,
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide:
//                       const BorderSide(color: Colors.blueAccent, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//           if (_placeList.isNotEmpty)
//             Container(
//               margin: const EdgeInsets.only(top: 10),
//               height: 200,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(15),
//                 boxShadow: [
//                   BoxShadow(
//                       color: Colors.black.withOpacity(0.2), blurRadius: 6),
//                 ],
//               ),
//               child: ListView.builder(
//                 itemCount: _placeList.length,
//                 itemBuilder: (context, index) {
//                   final place = _placeList[index];
//                   return ListTile(
//                     title: Text(
//                       place['description'],
//                       style: const TextStyle(color: Colors.black),
//                     ),
//                     onTap: () async {
//                       LatLng coordinates =
//                           await _getCoordinates(place['place_id']);
//                       setState(() {
//                         _toCoordinates = coordinates;
//                         _placeList.clear();
//                         _toController.clear();
//                       });
//                       _moveCameraToBounds(_fromCoordinates, _toCoordinates);
//                                         },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           GoogleMap(
//             zoomControlsEnabled: false,
//             mapType: MapType.normal,
//             initialCameraPosition: _initialPosition,
//             onMapCreated: (GoogleMapController controller) {
//               _controller = controller;
//             },
//             markers: _markers,
//           ),
//           _buildSearchBoxFrom(),
//           const SizedBox(height: 56),
//           _buildSearchBoxTo(),
//         ],
//       ),
//     );
//   }
// }
