import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'forecast_tile_provider.dart';

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  GoogleMapController? _controller;
  TileOverlay? _tileOverlay;
  DateTime _forecastDate = DateTime.now();
  String _currentMapType = 'TA2';
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placeList = [];
  String _sessionToken = '1234567890';
  String _lastInput = '';

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(25, 67),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String currentInput = _searchController.text.trim();
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
    const String PLACES_API_KEY = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";
    const String baseURL =
        'https://maps.gomaps.pro/maps/api/place/autocomplete/json';
    final String request =
        '$baseURL?input=$input&key=$PLACES_API_KEY&sessiontoken=$_sessionToken';

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
    const String PLACES_API_KEY = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";
    final String detailsURL =
        'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$PLACES_API_KEY';

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
      return LatLng(25, 67); // Default location in case of failure
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    _controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: 14),
    ));
  }

  Widget _buildSearchBox() {
    return Positioned(
      top: 50, // Adjusted to move the search bar slightly lower
      left: 20,
      right: 20,
      child: Column(
        children: [
          Material(
            elevation: 6,
            shadowColor: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20), // Rounded corners
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for places",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Colors.blueAccent,
                    width: 1.5,
                  ),
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
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                  ),
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
                      _moveCamera(coordinates);
                      setState(() {
                        _placeList.clear();
                        _searchController.clear();
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  _initTiles(DateTime date, String maptypes) async {
    final String overlayId = date.millisecondsSinceEpoch.toString();

    final TileOverlay tileOverlay = TileOverlay(
      tileOverlayId: TileOverlayId(overlayId),
      tileProvider: ForecastTileProvider(
        dateTime: date,
        mapType: maptypes,
        opacity: 0.6,
      ),
    );
    setState(() {
      _tileOverlay = tileOverlay;
    });
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
              _initTiles(_forecastDate, _currentMapType);
            },
            tileOverlays:
                _tileOverlay == null ? {} : <TileOverlay>{_tileOverlay!},
          ),
          _buildSearchBox(),

          // Custom elevated button with dropdown functionality
          Positioned(
            top: 120, // Adjust to position below the search bar
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  // Cycle through the map types on button press
                  if (_currentMapType == "TA2") {
                    _currentMapType = "WND";
                  } else if (_currentMapType == "WND") {
                    _currentMapType = "PAR0";
                  } else {
                    _currentMapType = "TA2";
                  }
                });
                _initTiles(_forecastDate,
                    _currentMapType); // Call with updated map type
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 10),
                    Text(
                      _currentMapType == "TA2"
                          ? "Temperature"
                          : _currentMapType == "WND"
                              ? "Wind Speed"
                              : "Precipitation",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            child: Container(
              height: 70,
              width: MediaQuery.of(context).size.width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 30,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _forecastDate =
                              _forecastDate.subtract(const Duration(hours: 3));
                        });
                        _initTiles(_forecastDate, _currentMapType);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color.fromARGB(255, 24, 156, 166),
                      ),
                    ),
                  ),
                  Center(
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.black,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${DateFormat('yyyy-MM-dd ha').format(_forecastDate)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 30,
                    child: ElevatedButton(
                      onPressed:
                          _forecastDate.difference(DateTime.now()).inDays >= 10
                              ? null
                              : () {
                                  setState(() {
                                    _forecastDate = _forecastDate
                                        .add(const Duration(hours: 3));
                                  });
                                  _initTiles(_forecastDate, _currentMapType);
                                },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color.fromARGB(255, 24, 156, 166),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Positioned legend widget
          Positioned(
            bottom: 120, // Position relative to the bottom
            left: 20, // Position relative to the right
            child: SizedBox(
              width: 80, // Ensure proper constraints
              child: HeatmapLegend(mapType: _currentMapType),
            ),
          ),
        ],
      ),
    );
  }
}

class HeatmapLegend extends StatelessWidget {
  final String mapType;

  const HeatmapLegend({Key? key, required this.mapType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final legendData = _getLegendData(mapType);

    if (legendData == null) return SizedBox.shrink(); // Skip rendering for WND

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            legendData['title'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(
                size: const Size(20, 125), // Width and height for vertical bar
                painter: GradientPainter(colors: legendData['colors']),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legendData['stops']
                    .map<Widget>(
                      (stop) => Text(
                        stop.toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getLegendData(String mapType) {
    switch (mapType) {
      case "TA2": // Temperature
        return {
          'title': "Temp (°C)",
          'colors': const [
            Color(0xFFFC8014),
            Color(0xFFFFC228),
            Color(0xFFFFF028),
            Color(0xFFC2FF28),
            Color(0xFF23DDDD),
            Color(0xFF20C4E8),
            Color(0xFF208CEC),
            Color(0xFF8257DB),
            Color(0xFF821692),
          ],
          'stops': [30, 25, 20, 10, 0, -10, -30, -65],
        };
      case "PAR0": // Rain
        return {
          'title': "Rain (mm)",
          'colors': const [
            Color(0xFF1414FF),
            Color(0xFF5050E1),
            Color(0xFF6E6ECD),
            Color(0xFF7878BE),
            Color(0xFF9696AA),
            Color(0xFFC89696),
            Color(0xFFE1C864),
          ],
          'stops': [140, 10, 1, 0.5, 0.2, 0.1, 0],
        };
      default: // Skip for windspeed or unknown types
        return null;
    }
  }
}

class GradientPainter extends CustomPainter {
  final List<Color> colors;

  GradientPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, // Corrected for desired direction
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'forecast_tile_provider.dart';

// class MapSample extends StatefulWidget {
//   const MapSample({super.key});

//   @override
//   State<MapSample> createState() => MapSampleState();
// }

// class MapSampleState extends State<MapSample> {
//   GoogleMapController? _controller;
//   TileOverlay? _tileOverlay;
//   DateTime _forecastDate = DateTime.now();
//   final TextEditingController _searchController = TextEditingController();
//   List<dynamic> _placeList = [];
//   String _sessionToken = '1234567890';
//   String _lastInput = '';

//   static const CameraPosition _initialPosition = CameraPosition(
//     target: LatLng(25, 67),
//     zoom: 10,
//   );

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(_onSearchChanged);
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged() {
//     String currentInput = _searchController.text.trim();
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
//     const String placesApiKey = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";
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
//     const String placesApiKey = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";
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

//   Future<void> _moveCamera(LatLng target) async {
//     _controller?.animateCamera(CameraUpdate.newCameraPosition(
//       CameraPosition(target: target, zoom: 14),
//     ));
//   }

//   Widget _buildSearchBox() {
//     return Positioned(
//       top: 50, // Adjusted to move the search bar slightly lower
//       left: 20,
//       right: 20,
//       child: Column(
//         children: [
//           Material(
//             elevation: 6,
//             shadowColor: Colors.black.withOpacity(0.3),
//             borderRadius: BorderRadius.circular(20), // Rounded corners
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: "Search for places",
//                 hintStyle: const TextStyle(color: Colors.grey),
//                 border: InputBorder.none,
//                 prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 15,
//                 ),
//                 filled: true,
//                 fillColor: Colors.white,
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide: BorderSide.none,
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   borderSide: const BorderSide(
//                     color: Colors.blueAccent,
//                     width: 1.5,
//                   ),
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
//                     color: Colors.black.withOpacity(0.2),
//                     blurRadius: 6,
//                   ),
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
//                       _moveCamera(coordinates);
//                       setState(() {
//                         _placeList.clear();
//                         _searchController.clear();
//                       });
//                     },
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   _initTiles(DateTime date) async {
//     final String overlayId = date.millisecondsSinceEpoch.toString();

//     final TileOverlay tileOverlay = TileOverlay(
//       tileOverlayId: TileOverlayId(overlayId),
//       tileProvider: ForecastTileProvider(
//         dateTime: date,
//         mapType: 'TA2',
//         opacity: 0.6,
//       ),
//     );
//     setState(() {
//       _tileOverlay = tileOverlay;
//     });
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
//               _initTiles(_forecastDate);
//             },
//             tileOverlays:
//                 _tileOverlay == null ? {} : <TileOverlay>{_tileOverlay!},
//           ),
//           _buildSearchBox(),
//           Positioned(
//             bottom: 30,
//             child: SizedBox(
//               height: 70,
//               width: MediaQuery.of(context).size.width,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   Positioned(
//                     left: 30,
//                     child: ElevatedButton(
//                       onPressed: () {
//                         setState(() {
//                           _forecastDate =
//                               _forecastDate.subtract(const Duration(hours: 3));
//                         });
//                         _initTiles(_forecastDate);
//                       },
//                       style: ElevatedButton.styleFrom(
//                         shape: const CircleBorder(),
//                         padding: const EdgeInsets.all(10),
//                       ),
//                       child: const Icon(
//                         Icons.arrow_back_rounded,
//                         color: Color.fromARGB(255, 24, 156, 166),
//                       ),
//                     ),
//                   ),
//                   Center(
//                     child: Card(
//                       elevation: 4,
//                       shadowColor: Colors.black,
//                       child: Container(
//                         padding: const EdgeInsets.all(10),
//                         child: Text(
//                           DateFormat('yyyy-MM-dd ha').format(_forecastDate),
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(
//                             color: Colors.blue,
//                             fontSize: 18,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   Positioned(
//                     right: 30,
//                     child: ElevatedButton(
//                       onPressed:
//                           _forecastDate.difference(DateTime.now()).inDays >= 10
//                               ? null
//                               : () {
//                                   setState(() {
//                                     _forecastDate = _forecastDate
//                                         .add(const Duration(hours: 3));
//                                   });
//                                   _initTiles(_forecastDate);
//                                 },
//                       style: ElevatedButton.styleFrom(
//                         shape: const CircleBorder(),
//                         padding: const EdgeInsets.all(10),
//                       ),
//                       child: const Icon(
//                         Icons.arrow_forward_rounded,
//                         color: Color.fromARGB(255, 24, 156, 166),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }