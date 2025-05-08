import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:agaahi/config.dart';

enum WeatherVariable { temperature, dewPoint, windSpeed, humidity }
enum RangeBand { cold, cool, moderate, warm, hot }

/// Shared colour ramp for both variables (blue → red)
const Map<RangeBand, Color> kBandColours = {
  RangeBand.cold: Colors.blue,
  RangeBand.cool: Colors.lightBlue,
  RangeBand.moderate: Colors.green,
  RangeBand.warm: Colors.orange,
  RangeBand.hot: Colors.red,
};

class TravelRouteScreen extends StatefulWidget {
  final List<double> temperatures; // 4 thresholds
  final List<double> dewPoints;    // 4 thresholds
  final List<double> windSpeeds;   // 4 thresholds
  final List<double> humidities;   // 4 thresholds

  const TravelRouteScreen({
    super.key, 
    required this.temperatures, 
    required this.dewPoints,
    this.windSpeeds = const [3, 6, 10, 15],  // Default thresholds m/s
    this.humidities = const [30, 50, 70, 90], // Default thresholds %
  });

  @override
  State<TravelRouteScreen> createState() => _TravelRouteScreenState();
}

class _TravelRouteScreenState extends State<TravelRouteScreen> {
  // ── Map & UI controllers
  GoogleMapController? _mapController;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController   = TextEditingController();

  // ── State
  WeatherVariable _selected = WeatherVariable.temperature;
  LatLng? _fromLocation;
  LatLng? _toLocation;
  Set<Polyline> _polylines = {};
  Set<Marker>   _markers   = {};
  List<dynamic> _placeSuggestions = [];
  bool isSelectingFrom = true;
  
  // Info window for segment details
  LatLng? _selectedSegmentPoint;
  String? _selectedSegmentDetails;

  // Weather API endpoint
  final String _weatherApiUrl = 'https://weather-db-b91w.onrender.com/api/v1/interpolation/by-location-and-timestamp';
  
  // Maximum distance for weather interpolation (in meters)
  final int _maxWeatherDistance = 10000;

  // Get thresholds based on currently selected weather variable
  List<double> get _thresholds {
    switch (_selected) {
      case WeatherVariable.temperature: return widget.temperatures;
      case WeatherVariable.dewPoint: return widget.dewPoints;
      case WeatherVariable.windSpeed: return widget.windSpeeds;
      case WeatherVariable.humidity: return widget.humidities;
    }
  }

  // Format number for display
  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  // Determine color based on value and current thresholds
  Color _colourFor(double value) {
    final t = _thresholds;
    if (value < t[0]) return kBandColours[RangeBand.cold]!;
    if (value < t[1]) return kBandColours[RangeBand.cool]!;
    if (value < t[2]) return kBandColours[RangeBand.moderate]!;
    if (value < t[3]) return kBandColours[RangeBand.warm]!;
    return kBandColours[RangeBand.hot]!;
  }

  // Get appropriate unit for current weather variable
  String get _unit {
    switch (_selected) {
      case WeatherVariable.temperature: return "°C";
      case WeatherVariable.dewPoint: return "°C";
      case WeatherVariable.windSpeed: return "m/s";
      case WeatherVariable.humidity: return "%";
    }
  }

  // Get legend labels based on current weather variable
  List<String> get _legendLabels => [
        'Cold (<${_fmt(_thresholds[0])}${_unit})',
        'Cool (${_fmt(_thresholds[0])}–${_fmt(_thresholds[1])}${_unit})',
        'Moderate (${_fmt(_thresholds[1])}–${_fmt(_thresholds[2])}${_unit})',
        'Warm (${_fmt(_thresholds[2])}–${_fmt(_thresholds[3])}${_unit})',
        'Hot (>${_fmt(_thresholds[3])}${_unit})',
      ];

  // Get title for current weather variable
  String get _variableTitle {
    switch (_selected) {
      case WeatherVariable.temperature: return "Temperature";
      case WeatherVariable.dewPoint: return "Dew Point";
      case WeatherVariable.windSpeed: return "Wind Speed";
      case WeatherVariable.humidity: return "Humidity";
    }
  }

  // Haversine for segment length (m)
  double _haversine(LatLng a, LatLng b) {
    const R = 6371e3;
    final lat1 = a.latitude  * pi / 180;
    final lat2 = b.latitude  * pi / 180;
    final dLat = (b.latitude  - a.latitude ) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final h    = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
    return 2 * R * atan2(sqrt(h), sqrt(1-h));
  }

  // Get weather data for a specific location and time
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
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

  // Create color-coded route based on weather data at 15-minute intervals
  Future<void> _createWeatherColoredRoute(List<LatLng> points, int totalDurationSeconds) async {
    if (points.isEmpty) return;
    
    _polylines.clear();
    
    // Calculate the entire route distance
    double entireRouteDistance = 0;
    for (int i = 1; i < points.length; i++) {
      entireRouteDistance += _haversine(points[i - 1], points[i]);
    }
    
    // Round total duration to nearest 15 minutes (900 seconds)
    int roundedDuration = (totalDurationSeconds ~/ 900) * 900;
    const int intervalSeconds = 900; // 15-minute chunk
    
    // Keep track of elapsed "time"
    double cumulativeTime = 0;
    
    // Create a fixed date starting point, 2 days from now
    DateTime now = DateTime.now();
    int roundedMinutes = (now.minute ~/ 15) * 15;
    DateTime startTime = DateTime(2024, now.month, now.day, now.hour, roundedMinutes, 0);
    
    // Create segments
    List<List<LatLng>> segments = [];
    List<DateTime> segmentTimes = [];
    List<LatLng> currentSegment = [points[0]];
    int segmentCounter = 0;
    
    for (int i = 1; i < points.length; i++) {
      LatLng prev = points[i - 1];
      LatLng curr = points[i];
      
      // Calculate segment distance and fraction of entire route
      double segmentDistance = _haversine(prev, curr);
      double fraction = segmentDistance / entireRouteDistance;
      
      // Calculate time for this segment
      double segmentTime = fraction * roundedDuration;
      
      // Add accumulated time
      cumulativeTime += segmentTime;
      
      // Add point to current segment
      currentSegment.add(curr);
      
      // If we've reached a 15-minute interval, start a new segment
      if (cumulativeTime >= intervalSeconds || i == points.length - 1) {
        segmentCounter++;
        segments.add(List.from(currentSegment));
        
        // Calculate time for this segment (always on 15-minute intervals)
        DateTime segmentTime = startTime.add(Duration(minutes: 15 * segmentCounter));
        segmentTimes.add(segmentTime);
        
        // Start new segment with last point
        currentSegment = [curr];
        
        // Reset accumulated time (keep remainder)
        cumulativeTime -= intervalSeconds;
      }
    }
    
    // For each segment, fetch weather data and create colored polyline
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].isEmpty) continue;
      
      // Use middle point of segment for weather data
      int midIndex = segments[i].length ~/ 2;
      LatLng midPoint = segments[i][midIndex];
      DateTime time = segmentTimes[i];
      
      // Fetch weather data
      final weatherData = await _getWeatherForLocationAndTime(midPoint, time);
      
      // Get value based on selected weather variable
      double value = 0;
      switch (_selected) {
        case WeatherVariable.temperature:
          value = weatherData['temperature'] ?? 20; // Default if missing
          break;
        case WeatherVariable.dewPoint:
          value = weatherData['dew_point'] ?? 10; // Default if missing
          break;
        case WeatherVariable.windSpeed:
          value = weatherData['wind_speed'] ?? 5; // Default if missing
          break;
        case WeatherVariable.humidity:
          value = weatherData['humidity'] ?? 50; // Default if missing
          break;
      }
      
      // Create weather info for this segment
      String infoSnippet = """
📌 Segment ${i+1}
Time ⏰ ${time.hour}:${time.minute.toString().padLeft(2, '0')}
Temperature 🌡️ ${weatherData['temperature'] != null ? weatherData['temperature'].toStringAsFixed(1) : 'N/A'}°C
Dew Point 🌧️ ${weatherData['dew_point'] != null ? weatherData['dew_point'].toStringAsFixed(1) : 'N/A'}°C
Wind Speed 💨 ${weatherData['wind_speed'] != null ? weatherData['wind_speed'].toStringAsFixed(1) : 'N/A'} m/s
Humidity 💧 ${weatherData['humidity'] != null ? weatherData['humidity'].toStringAsFixed(1) : 'N/A'}%
${_variableTitle} Value: ${value.toStringAsFixed(1)}${_unit}
""";
      
      // Create colored polyline
      _polylines.add(Polyline(
        polylineId: PolylineId('seg_$i'),
        points: segments[i],
        color: _colourFor(value),
        width: 8,
        startCap: i == 0 ? Cap.roundCap : Cap.buttCap,
        endCap: i == segments.length - 1 ? Cap.roundCap : Cap.buttCap,
        consumeTapEvents: true,
        onTap: () {
          setState(() {
            _selectedSegmentPoint = midPoint;
            _selectedSegmentDetails = infoSnippet;
          });
          // Auto-hide after 8 seconds
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) {
              setState(() {
                _selectedSegmentPoint = null;
                _selectedSegmentDetails = null;
              });
            }
          });
        },
      ));
    }
    
    setState(() {});
  }

  static const _apiKey = AppConfig.goMapsApiKey;

  // Get place suggestions for autocomplete
  Future<void> _suggest(String input) async {
    final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$_apiKey';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() => _placeSuggestions = json.decode(res.body)['predictions']);
      }
    } catch (_) {}
  }

  // Get coordinates for a selected place
  Future<LatLng> _coords(String placeId) async {
    final url = 'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('coord fail');
    final loc = json.decode(res.body)['result']['geometry']['location'];
    return LatLng(loc['lat'], loc['lng']);
  }

  // Fetch route data from API
  Future<void> _fetchRoute() async {
    if (_fromLocation == null || _toLocation == null) return;
    
    final url = 'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$_apiKey';
    final res = await http.get(Uri.parse(url));
    
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['routes'].isEmpty) return;
      
      final route = data['routes'][0];
      final points = _decodePolyline(route['overview_polyline']['points']);
      int totalDuration = route['legs'][0]['duration']['value']; // Total journey duration in seconds
      
      await _createWeatherColoredRoute(points, totalDuration);
      _setMarkersAndZoom();
    }
  }

  // Decode Google Maps polyline format
  List<LatLng> _decodePolyline(String e) {
    int idx = 0, lat = 0, lng = 0;
    List<LatLng> pts = [];
    while (idx < e.length) {
      int b, shift = 0, res = 0;
      do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      shift = 0; res = 0;
      do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      pts.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return pts;
  }

  // Set markers and zoom to show the route
  void _setMarkersAndZoom() {
    setState(() {
      _markers = {
        if (_fromLocation != null) 
          Marker(
            markerId: const MarkerId('from'), 
            position: _fromLocation!, 
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
          ),
        if (_toLocation != null) 
          Marker(
            markerId: const MarkerId('to'), 
            position: _toLocation!, 
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          ),
      };
    });
    
    if (_fromLocation != null && _toLocation != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          min(_fromLocation!.latitude, _toLocation!.latitude),
          min(_fromLocation!.longitude, _toLocation!.longitude)
        ),
        northeast: LatLng(
          max(_fromLocation!.latitude, _toLocation!.latitude),
          max(_fromLocation!.longitude, _toLocation!.longitude)
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set toggle button color based on selected variable
    Color toggleColor;
    switch (_selected) {
      case WeatherVariable.temperature: toggleColor = Colors.blue;
        break;
      case WeatherVariable.dewPoint: toggleColor = Colors.teal;
        break;
      case WeatherVariable.windSpeed: toggleColor = Colors.indigo;
        break;
      case WeatherVariable.humidity: toggleColor = Colors.purple;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Weather Route'),
        backgroundColor: toggleColor,
      ),
      body: Stack(children: [
        // GoogleMap(
        //   initialCameraPosition: const CameraPosition(target: LatLng(25.0,67.0), zoom: 10),
        //   onMapCreated: (c) => _mapController = c,
        //   polylines: _polylines,
        //   markers: _markers,
        // ),

        GoogleMap(
  initialCameraPosition: const CameraPosition(target: LatLng(25.0, 67.0), zoom: 10),
  onMapCreated: (GoogleMapController controller) async {
    await Future.delayed(const Duration(milliseconds: 300)); // allow native side to stabilize
    if (mounted) {
      setState(() => _mapController = controller);
    }
  },
  polylines: _polylines,
  markers: _markers,
),


        // ── Search boxes
        Positioned(
          top: 10, left: 10, right: 10,
          child: Column(children: [
            _searchField(_fromController,'From', true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _searchField(_toController,'To', false)),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchRoute, 
                style: ElevatedButton.styleFrom(backgroundColor: toggleColor),
                child: const Icon(Icons.search)
              ),
            ]),
            if (_placeSuggestions.isNotEmpty)
              Container(
                color: Colors.white, height: 150,
                child: ListView.builder(
                  itemCount: _placeSuggestions.length,
                  itemBuilder: (c,i)=>ListTile(
                    title: Text(_placeSuggestions[i]['description']),
                    onTap: () async {
                      final id = _placeSuggestions[i]['place_id'];
                      final loc = await _coords(id);
                      setState(() {
                        if (isSelectingFrom) {
                          _fromLocation = loc; 
                          _fromController.text = _placeSuggestions[i]['description'];
                        } else {
                          _toLocation = loc; 
                          _toController.text = _placeSuggestions[i]['description'];
                        }
                        _placeSuggestions = [];
                      });
                      _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
                      if (_fromLocation != null && _toLocation != null) {
                        _fetchRoute();
                      }
                    },
                  ),
                ),
              )
          ]),
        ),

        // ── Legend with title
        Positioned(
          bottom: 20, left: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_variableTitle Legend',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 10, thickness: 1),
                ...kBandColours.values.toList().asMap().entries.map(
                  (e) => _legendRow(_legendLabels[e.key], e.value)
                ).toList(),
              ],
            ),
          ),
        ),

        // ── Weather variable toggle
        Positioned(
          bottom: 200, // Above legend box
          left: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                backgroundColor: toggleColor,
                heroTag: 'toggleWeather',
                onPressed: () {
                  setState(() {
                    // Cycle through weather variables
                    switch (_selected) {
                      case WeatherVariable.temperature:
                        _selected = WeatherVariable.dewPoint;
                        break;
                      case WeatherVariable.dewPoint:
                        _selected = WeatherVariable.windSpeed;
                        break;
                      case WeatherVariable.windSpeed:
                        _selected = WeatherVariable.humidity;
                        break;
                      case WeatherVariable.humidity:
                        _selected = WeatherVariable.temperature;
                        break;
                    }
                  });
                  
                  // If we have route data, refresh the coloring
                  if (_polylines.isNotEmpty && _fromLocation != null && _toLocation != null) {
                    _fetchRoute();
                  }
                },
                child: const Icon(Icons.swap_horiz),
                tooltip: 'Toggle Weather Variable',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: toggleColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _variableTitle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // ── Segment details popup
        if (_selectedSegmentPoint != null)
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _selectedSegmentPoint != null ? 1.0 : 0.0,
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
                    Text(
                      "🚀 $_variableTitle Segment Details",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Text(
                      _selectedSegmentDetails ?? "",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }
  
  // Widget for search field
  Widget _searchField(TextEditingController c, String hint, bool from) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        controller: c,
        onTap: () => setState(()=>isSelectingFrom = from),
        onChanged: (v)=> v.isNotEmpty ? _suggest(v) : setState(()=>_placeSuggestions=[]),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.location_on),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // Widget for legend row
  Widget _legendRow(String text, Color colour) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20, 
            height: 20, 
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(4),
            ),
          ), 
          const SizedBox(width: 8), 
          Text(text)
        ],
      ),
    );
  }
}






















// // fright.dart — full rewrite with working weather‑variable toggle, live legend refresh, coloured toggle button and placement above legend

// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:agaahi/config.dart';

// enum WeatherVariable { temperature, dewPoint }
// enum RangeBand { cold, cool, moderate, warm, hot }

// /// Shared colour ramp for both variables (blue → red)
// const Map<RangeBand, Color> kBandColours = {
//   RangeBand.cold: Colors.blue,
//   RangeBand.cool: Colors.lightBlue,
//   RangeBand.moderate: Colors.green,
//   RangeBand.warm: Colors.orange,
//   RangeBand.hot: Colors.red,
// };

// class TravelRouteScreen extends StatefulWidget {
//   final List<double> temperatures; // 4 thresholds
//   final List<double> dewPoints;    // 4 thresholds

//   const TravelRouteScreen({super.key, required this.temperatures, required this.dewPoints});

//   @override
//   State<TravelRouteScreen> createState() => _TravelRouteScreenState();
// }

// class _TravelRouteScreenState extends State<TravelRouteScreen> {
//   // ── Map & UI controllers
//   GoogleMapController? _mapController;
//   final TextEditingController _fromController = TextEditingController();
//   final TextEditingController _toController   = TextEditingController();

//   // ── State
//   WeatherVariable _selected = WeatherVariable.temperature;
//   LatLng? _fromLocation;
//   LatLng? _toLocation;
//   Set<Polyline> _polylines = {};
//   Set<Marker>   _markers   = {};
//   List<dynamic> _placeSuggestions = [];
//   bool isSelectingFrom = true;

//   double _randTemp () => 15 + Random().nextDouble() * 20;            // dummy °C
//   double _randDewPt() =>  5 + Random().nextDouble() * 20;            // dummy °C

//   List<double> get _thresholds =>
//       _selected == WeatherVariable.temperature ? widget.temperatures : widget.dewPoints;

//   String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

//   Color _colourFor(double value) {
//     final t = _thresholds;
//     if (value < t[0]) return kBandColours[RangeBand.cold]!;
//     if (value < t[1]) return kBandColours[RangeBand.cool]!;
//     if (value < t[2]) return kBandColours[RangeBand.moderate]!;
//     if (value < t[3]) return kBandColours[RangeBand.warm]!;
//     return kBandColours[RangeBand.hot]!;
//   }

//   List<String> get _legendLabels => [
//         'Cold (<${_fmt(_thresholds[0])}°C)',
//         'Cool (${_fmt(_thresholds[0])}–${_fmt(_thresholds[1])}°C)',
//         'Moderate (${_fmt(_thresholds[1])}–${_fmt(_thresholds[2])}°C)',
//         'Warm (${_fmt(_thresholds[2])}–${_fmt(_thresholds[3])}°C)',
//         'Hot (>${_fmt(_thresholds[3])}°C)',
//       ];

//   // ── Haversine for segment length (m)
//   double _haversine(LatLng a, LatLng b) {
//     const R = 6371e3;
//     final lat1 = a.latitude  * pi / 180;
//     final lat2 = b.latitude  * pi / 180;
//     final dLat = (b.latitude  - a.latitude ) * pi / 180;
//     final dLon = (b.longitude - a.longitude) * pi / 180;
//     final h    = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
//     return 2 * R * atan2(sqrt(h), sqrt(1-h));
//   }

//   void _createColourRoute(List<LatLng> pts) {
//     _polylines.clear();
//     const segLen = 10000; // 10 km
//     List<List<LatLng>> segs = [];
//     List<LatLng> current = [];
//     double acc = 0;

//     for (int i = 1; i < pts.length; i++) {
//       acc += _haversine(pts[i-1], pts[i]);
//       current.add(pts[i-1]);
//       if (acc >= segLen) {
//         current.add(pts[i]);
//         segs.add(current);
//         current = [pts[i]];
//         acc = 0;
//       }
//     }
//     if (current.isNotEmpty) segs.add(current);

//     for (int i = 0; i < segs.length; i++) {
//       final val = _selected == WeatherVariable.temperature ? _randTemp() : _randDewPt();
//       _polylines.add(Polyline(
//         polylineId: PolylineId('seg_$i'),
//         points: segs[i],
//         color: _colourFor(val),
//         width: 8,
//         startCap: i==0 ? Cap.roundCap : Cap.buttCap,
//         endCap  : i==segs.length-1 ? Cap.roundCap : Cap.buttCap,
//       ));
//     }
//     setState(() {});
//   }

//   static const _apiKey = AppConfig.goMapsApiKey;

//   Future<void> _suggest(String input) async {
//     final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$_apiKey';
//     try {
//       final res = await http.get(Uri.parse(url));
//       if (res.statusCode == 200) {
//         setState(() => _placeSuggestions = json.decode(res.body)['predictions']);
//       }
//     } catch (_) {}
//   }

//   Future<LatLng> _coords(String placeId) async {
//     final url = 'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';
//     final res = await http.get(Uri.parse(url));
//     if (res.statusCode != 200) throw Exception('coord fail');
//     final loc = json.decode(res.body)['result']['geometry']['location'];
//     return LatLng(loc['lat'], loc['lng']);
//   }

//   Future<void> _fetchRoute() async {
//     if (_fromLocation==null || _toLocation==null) return;
//     final url = 'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$_apiKey';
//     final res = await http.get(Uri.parse(url));
//     if (res.statusCode==200) {
//       final routes = json.decode(res.body)['routes'];
//       if (routes.isEmpty) return;
//       final pts = _decodePolyline(routes[0]['overview_polyline']['points']);
//       _createColourRoute(pts);
//       _setMarkersAndZoom();
//     }
//   }

//   List<LatLng> _decodePolyline(String e) {
//     int idx = 0, lat = 0, lng = 0;
//     List<LatLng> pts = [];
//     while (idx < e.length) {
//       int b, shift = 0, res = 0;
//       do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
//       lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       shift = 0; res = 0;
//       do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
//       lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       pts.add(LatLng(lat / 1E5, lng / 1E5));
//     }
//     return pts;
//   }

//   void _setMarkersAndZoom() {
//     setState(() {
//       _markers = {
//         if (_fromLocation!=null) Marker(markerId: const MarkerId('from'), position: _fromLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
//         if (_toLocation  !=null) Marker(markerId: const MarkerId('to'),   position: _toLocation!,   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
//       };
//     });
//     if (_fromLocation!=null && _toLocation!=null) {
//       final bounds = LatLngBounds(
//         southwest: LatLng(min(_fromLocation!.latitude,_toLocation!.latitude), min(_fromLocation!.longitude,_toLocation!.longitude)),
//         northeast: LatLng(max(_fromLocation!.latitude,_toLocation!.latitude), max(_fromLocation!.longitude,_toLocation!.longitude)),
//       );
//       _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final toggleColour = _selected == WeatherVariable.temperature ? Colors.orange : Colors.deepPurple;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Travel Route'), backgroundColor: Colors.blue),
//       body: Stack(children: [
//         GoogleMap(
//           initialCameraPosition: const CameraPosition(target: LatLng(25.0,67.0), zoom: 10),
//           onMapCreated: (c) => _mapController = c,
//           polylines: _polylines,
//           markers: _markers,
//         ),

//         // ── Search boxes
//         Positioned(
//           top: 10, left: 10, right: 10,
//           child: Column(children: [
//             _searchField(_fromController,'From', true),
//             const SizedBox(height: 10),
//             Row(children: [
//               Expanded(child: _searchField(_toController,'To', false)),
//               const SizedBox(width: 8),
//               ElevatedButton(onPressed: _fetchRoute, child: const Icon(Icons.search)),
//             ]),
//             if (_placeSuggestions.isNotEmpty)
//               Container(
//                 color: Colors.white, height: 150,
//                 child: ListView.builder(
//                   itemCount: _placeSuggestions.length,
//                   itemBuilder: (c,i)=>ListTile(
//                     title: Text(_placeSuggestions[i]['description']),
//                     onTap: () async {
//                       final id  = _placeSuggestions[i]['place_id'];
//                       final loc = await _coords(id);
//                       setState(() {
//                         if (isSelectingFrom) {_fromLocation=loc; _fromController.text=_placeSuggestions[i]['description'];}
//                         else {_toLocation=loc; _toController.text=_placeSuggestions[i]['description'];}
//                         _placeSuggestions=[];
//                       });
//                       _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
//                       _fetchRoute();
//                     },
//                   ),
//                 ),
//               )
//           ]),
//         ),

//         // ── Legend
//         Positioned(
//           bottom: 20, left: 10,
//           child: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: _legendLabels.asMap().entries.map((e)=>_legendRow(e.value, kBandColours.values.elementAt(e.key))).toList(),
//             ),
//           ),
//         ),

//         // ── Toggle button (just **above** legend)
//         Positioned(
//           bottom: 150, // ~90px above legend box
//           left: 10,
//           child: FloatingActionButton(
//             backgroundColor: toggleColour,
//             heroTag: 'toggleWeather',
//             onPressed: () {
//               setState(() {
//                 _selected = _selected == WeatherVariable.temperature ? WeatherVariable.dewPoint : WeatherVariable.temperature;
//               });
//               _createColourRoute(_polylines.isNotEmpty ? _polylines.first.points : []); // refresh polyline colours
//             },
//             child: const Icon(Icons.swap_horiz),
//             tooltip: 'Toggle Weather Variable',
//           ),
//         ),
//       ]),
//     );
//   }

//   Widget _searchField(TextEditingController c, String hint, bool from) {
//     return Material(
//       elevation: 5,
//       borderRadius: BorderRadius.circular(8),
//       child: TextField(
//         controller: c,
//         onTap: () => setState(()=>isSelectingFrom = from),
//         onChanged: (v)=> v.isNotEmpty ? _suggest(v) : setState(()=>_placeSuggestions=[]),
//         decoration: InputDecoration(
//           hintText: hint,
//           prefixIcon: const Icon(Icons.location_on),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//       ),
//     );
//   }

//   Widget _legendRow(String text, Color colour) {
//     return Row(children: [Container(width: 20, height: 20, color: colour), const SizedBox(width: 8), Text(text)]);
//   }
// }


































// // fright.dart — full rewrite with working weather‑variable toggle, live legend refresh, coloured toggle button and placement above legend

// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;

// // ──────────────────────────────────────────────────────────────────────────
// // ENUMS & CONSTANTS
// // ──────────────────────────────────────────────────────────────────────────

// enum WeatherVariable { temperature, dewPoint }
// enum RangeBand { cold, cool, moderate, warm, hot }

// /// Shared colour ramp for both variables (blue → red)
// const Map<RangeBand, Color> kBandColours = {
//   RangeBand.cold: Colors.blue,
//   RangeBand.cool: Colors.lightBlue,
//   RangeBand.moderate: Colors.green,
//   RangeBand.warm: Colors.orange,
//   RangeBand.hot: Colors.red,
// };

// // ──────────────────────────────────────────────────────────────────────────
// // STATEFUL WIDGET
// // ──────────────────────────────────────────────────────────────────────────

// class TravelRouteScreen extends StatefulWidget {
//   final List<double> temperatures; // 4 thresholds
//   final List<double> dewPoints;    // 4 thresholds

//   const TravelRouteScreen({super.key, required this.temperatures, required this.dewPoints});

//   @override
//   State<TravelRouteScreen> createState() => _TravelRouteScreenState();
// }

// class _TravelRouteScreenState extends State<TravelRouteScreen> {
//   // ── Map & UI controllers
//   GoogleMapController? _mapController;
//   final TextEditingController _fromController = TextEditingController();
//   final TextEditingController _toController   = TextEditingController();

//   // ── State
//   WeatherVariable _selected = WeatherVariable.temperature;
//   LatLng? _fromLocation;
//   LatLng? _toLocation;
//   Set<Polyline> _polylines = {};
//   Set<Marker>   _markers   = {};
//   List<dynamic> _placeSuggestions = [];
//   bool isSelectingFrom = true;

//   // ────────────────────────────────────────────────────────────────────────
//   // HELPERS
//   // ────────────────────────────────────────────────────────────────────────

//   double _randTemp () => 15 + Random().nextDouble() * 20;            // dummy °C
//   double _randDewPt() =>  5 + Random().nextDouble() * 20;            // dummy °C

//   List<double> get _thresholds =>
//       _selected == WeatherVariable.temperature ? widget.temperatures : widget.dewPoints;

//   String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

//   Color _colourFor(double value) {
//     final t = _thresholds;
//     if (value < t[0]) return kBandColours[RangeBand.cold]!;
//     if (value < t[1]) return kBandColours[RangeBand.cool]!;
//     if (value < t[2]) return kBandColours[RangeBand.moderate]!;
//     if (value < t[3]) return kBandColours[RangeBand.warm]!;
//     return kBandColours[RangeBand.hot]!;
//   }

//   List<String> get _legendLabels => [
//         'Cold (<${_fmt(_thresholds[0])}°C)',
//         'Cool (${_fmt(_thresholds[0])}–${_fmt(_thresholds[1])}°C)',
//         'Moderate (${_fmt(_thresholds[1])}–${_fmt(_thresholds[2])}°C)',
//         'Warm (${_fmt(_thresholds[2])}–${_fmt(_thresholds[3])}°C)',
//         'Hot (>${_fmt(_thresholds[3])}°C)',
//       ];

//   // ── Haversine for segment length (m)
//   double _haversine(LatLng a, LatLng b) {
//     const R = 6371e3;
//     final lat1 = a.latitude  * pi / 180;
//     final lat2 = b.latitude  * pi / 180;
//     final dLat = (b.latitude  - a.latitude ) * pi / 180;
//     final dLon = (b.longitude - a.longitude) * pi / 180;
//     final h    = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
//     return 2 * R * atan2(sqrt(h), sqrt(1-h));
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // ROUTE COLOURING
//   // ────────────────────────────────────────────────────────────────────────

//   void _createColourRoute(List<LatLng> pts) {
//     _polylines.clear();
//     const segLen = 10000; // 10 km
//     List<List<LatLng>> segs = [];
//     List<LatLng> current = [];
//     double acc = 0;

//     for (int i = 1; i < pts.length; i++) {
//       acc += _haversine(pts[i-1], pts[i]);
//       current.add(pts[i-1]);
//       if (acc >= segLen) {
//         current.add(pts[i]);
//         segs.add(current);
//         current = [pts[i]];
//         acc = 0;
//       }
//     }
//     if (current.isNotEmpty) segs.add(current);

//     for (int i = 0; i < segs.length; i++) {
//       final val = _selected == WeatherVariable.temperature ? _randTemp() : _randDewPt();
//       _polylines.add(Polyline(
//         polylineId: PolylineId('seg_$i'),
//         points: segs[i],
//         color: _colourFor(val),
//         width: 8,
//         startCap: i==0 ? Cap.roundCap : Cap.buttCap,
//         endCap  : i==segs.length-1 ? Cap.roundCap : Cap.buttCap,
//       ));
//     }
//     setState(() {});
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // API CALLS (autocomplete, details, directions)
//   // ────────────────────────────────────────────────────────────────────────

//   static const _apiKey = 'AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx';

//   Future<void> _suggest(String input) async {
//     final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$_apiKey';
//     try {
//       final res = await http.get(Uri.parse(url));
//       if (res.statusCode == 200) {
//         setState(() => _placeSuggestions = json.decode(res.body)['predictions']);
//       }
//     } catch (_) {}
//   }

//   Future<LatLng> _coords(String placeId) async {
//     final url = 'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';
//     final res = await http.get(Uri.parse(url));
//     if (res.statusCode != 200) throw Exception('coord fail');
//     final loc = json.decode(res.body)['result']['geometry']['location'];
//     return LatLng(loc['lat'], loc['lng']);
//   }

//   Future<void> _fetchRoute() async {
//     if (_fromLocation==null || _toLocation==null) return;
//     final url = 'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$_apiKey';
//     final res = await http.get(Uri.parse(url));
//     if (res.statusCode==200) {
//       final routes = json.decode(res.body)['routes'];
//       if (routes.isEmpty) return;
//       final pts = _decodePolyline(routes[0]['overview_polyline']['points']);
//       _createColourRoute(pts);
//       _setMarkersAndZoom();
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // POLYLINE DECODE & MARKERS
//   // ────────────────────────────────────────────────────────────────────────

//   List<LatLng> _decodePolyline(String e) {
//     int idx = 0, lat = 0, lng = 0;
//     List<LatLng> pts = [];
//     while (idx < e.length) {
//       int b, shift = 0, res = 0;
//       do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
//       lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       shift = 0; res = 0;
//       do { b = e.codeUnitAt(idx++) - 63; res |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
//       lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       pts.add(LatLng(lat / 1E5, lng / 1E5));
//     }
//     return pts;
//   }

//   void _setMarkersAndZoom() {
//     setState(() {
//       _markers = {
//         if (_fromLocation!=null) Marker(markerId: const MarkerId('from'), position: _fromLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
//         if (_toLocation  !=null) Marker(markerId: const MarkerId('to'),   position: _toLocation!,   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
//       };
//     });
//     if (_fromLocation!=null && _toLocation!=null) {
//       final bounds = LatLngBounds(
//         southwest: LatLng(min(_fromLocation!.latitude,_toLocation!.latitude), min(_fromLocation!.longitude,_toLocation!.longitude)),
//         northeast: LatLng(max(_fromLocation!.latitude,_toLocation!.latitude), max(_fromLocation!.longitude,_toLocation!.longitude)),
//       );
//       _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
//     }
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // BUILD
//   // ────────────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     final toggleColour = _selected == WeatherVariable.temperature ? Colors.orange : Colors.deepPurple;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Travel Route'), backgroundColor: Colors.blue),
//       body: Stack(children: [
//         GoogleMap(
//           initialCameraPosition: const CameraPosition(target: LatLng(25.0,67.0), zoom: 10),
//           onMapCreated: (c) => _mapController = c,
//           polylines: _polylines,
//           markers: _markers,
//         ),

//         // ── Search boxes
//         Positioned(
//           top: 10, left: 10, right: 10,
//           child: Column(children: [
//             _searchField(_fromController,'From', true),
//             const SizedBox(height: 10),
//             Row(children: [
//               Expanded(child: _searchField(_toController,'To', false)),
//               const SizedBox(width: 8),
//               ElevatedButton(onPressed: _fetchRoute, child: const Icon(Icons.search)),
//             ]),
//             if (_placeSuggestions.isNotEmpty)
//               Container(
//                 color: Colors.white, height: 150,
//                 child: ListView.builder(
//                   itemCount: _placeSuggestions.length,
//                   itemBuilder: (c,i)=>ListTile(
//                     title: Text(_placeSuggestions[i]['description']),
//                     onTap: () async {
//                       final id  = _placeSuggestions[i]['place_id'];
//                       final loc = await _coords(id);
//                       setState(() {
//                         if (isSelectingFrom) {_fromLocation=loc; _fromController.text=_placeSuggestions[i]['description'];}
//                         else {_toLocation=loc; _toController.text=_placeSuggestions[i]['description'];}
//                         _placeSuggestions=[];
//                       });
//                       _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
//                       _fetchRoute();
//                     },
//                   ),
//                 ),
//               )
//           ]),
//         ),

//         // ── Legend
//         Positioned(
//           bottom: 20, left: 10,
//           child: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: _legendLabels.asMap().entries.map((e)=>_legendRow(e.value, kBandColours.values.elementAt(e.key))).toList(),
//             ),
//           ),
//         ),

//         // ── Toggle button (just **above** legend)
//         Positioned(
//           bottom: 150, // ~90px above legend box
//           left: 10,
//           child: FloatingActionButton(
//             backgroundColor: toggleColour,
//             heroTag: 'toggleWeather',
//             onPressed: () {
//               setState(() {
//                 _selected = _selected == WeatherVariable.temperature ? WeatherVariable.dewPoint : WeatherVariable.temperature;
//               });
//               _createColourRoute(_polylines.isNotEmpty ? _polylines.first.points : []); // refresh polyline colours
//             },
//             child: const Icon(Icons.swap_horiz),
//             tooltip: 'Toggle Weather Variable',
//           ),
//         ),
//       ]),
//     );
//   }

//   // ────────────────────────────────────────────────────────────────────────
//   // WIDGET HELPERS
//   // ────────────────────────────────────────────────────────────────────────

//   Widget _searchField(TextEditingController c, String hint, bool from) {
//     return Material(
//       elevation: 5,
//       borderRadius: BorderRadius.circular(8),
//       child: TextField(
//         controller: c,
//         onTap: () => setState(()=>isSelectingFrom = from),
//         onChanged: (v)=> v.isNotEmpty ? _suggest(v) : setState(()=>_placeSuggestions=[]),
//         decoration: InputDecoration(
//           hintText: hint,
//           prefixIcon: const Icon(Icons.location_on),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//       ),
//     );
//   }

//   Widget _legendRow(String text, Color colour) {
//     return Row(children: [Container(width: 20, height: 20, color: colour), const SizedBox(width: 8), Text(text)]);
//   }
// }