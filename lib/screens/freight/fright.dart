// fright.dart — full rewrite with working weather‑variable toggle, live legend refresh, coloured toggle button and placement above legend

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:agaahi/config.dart';
// final String apiKey = AppConfig.goMapsApiKey;

// ──────────────────────────────────────────────────────────────────────────
// ENUMS & CONSTANTS
// ──────────────────────────────────────────────────────────────────────────

enum WeatherVariable { temperature, dewPoint }
enum RangeBand { cold, cool, moderate, warm, hot }

/// Shared colour ramp for both variables (blue → red)
const Map<RangeBand, Color> kBandColours = {
  RangeBand.cold: Colors.blue,
  RangeBand.cool: Colors.lightBlue,
  RangeBand.moderate: Colors.green,
  RangeBand.warm: Colors.orange,
  RangeBand.hot: Colors.red,
};

// ──────────────────────────────────────────────────────────────────────────
// STATEFUL WIDGET
// ──────────────────────────────────────────────────────────────────────────

class TravelRouteScreen extends StatefulWidget {
  final List<double> temperatures; // 4 thresholds
  final List<double> dewPoints;    // 4 thresholds

  const TravelRouteScreen({super.key, required this.temperatures, required this.dewPoints});

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

  // ────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────

  double _randTemp () => 15 + Random().nextDouble() * 20;            // dummy °C
  double _randDewPt() =>  5 + Random().nextDouble() * 20;            // dummy °C

  List<double> get _thresholds =>
      _selected == WeatherVariable.temperature ? widget.temperatures : widget.dewPoints;

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Color _colourFor(double value) {
    final t = _thresholds;
    if (value < t[0]) return kBandColours[RangeBand.cold]!;
    if (value < t[1]) return kBandColours[RangeBand.cool]!;
    if (value < t[2]) return kBandColours[RangeBand.moderate]!;
    if (value < t[3]) return kBandColours[RangeBand.warm]!;
    return kBandColours[RangeBand.hot]!;
  }

  List<String> get _legendLabels => [
        'Cold (<${_fmt(_thresholds[0])}°C)',
        'Cool (${_fmt(_thresholds[0])}–${_fmt(_thresholds[1])}°C)',
        'Moderate (${_fmt(_thresholds[1])}–${_fmt(_thresholds[2])}°C)',
        'Warm (${_fmt(_thresholds[2])}–${_fmt(_thresholds[3])}°C)',
        'Hot (>${_fmt(_thresholds[3])}°C)',
      ];

  // ── Haversine for segment length (m)
  double _haversine(LatLng a, LatLng b) {
    const R = 6371e3;
    final lat1 = a.latitude  * pi / 180;
    final lat2 = b.latitude  * pi / 180;
    final dLat = (b.latitude  - a.latitude ) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final h    = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
    return 2 * R * atan2(sqrt(h), sqrt(1-h));
  }

  // ────────────────────────────────────────────────────────────────────────
  // ROUTE COLOURING
  // ────────────────────────────────────────────────────────────────────────

  void _createColourRoute(List<LatLng> pts) {
    _polylines.clear();
    const segLen = 10000; // 10 km
    List<List<LatLng>> segs = [];
    List<LatLng> current = [];
    double acc = 0;

    for (int i = 1; i < pts.length; i++) {
      acc += _haversine(pts[i-1], pts[i]);
      current.add(pts[i-1]);
      if (acc >= segLen) {
        current.add(pts[i]);
        segs.add(current);
        current = [pts[i]];
        acc = 0;
      }
    }
    if (current.isNotEmpty) segs.add(current);

    for (int i = 0; i < segs.length; i++) {
      final val = _selected == WeatherVariable.temperature ? _randTemp() : _randDewPt();
      _polylines.add(Polyline(
        polylineId: PolylineId('seg_$i'),
        points: segs[i],
        color: _colourFor(val),
        width: 8,
        startCap: i==0 ? Cap.roundCap : Cap.buttCap,
        endCap  : i==segs.length-1 ? Cap.roundCap : Cap.buttCap,
      ));
    }
    setState(() {});
  }

  // ────────────────────────────────────────────────────────────────────────
  // API CALLS (autocomplete, details, directions)
  // ────────────────────────────────────────────────────────────────────────

  // static const _apiKey = 'AlzaSycQcnKmuMIDRTqGNJ2tTBlVkUFv7YKKHRx';
  // final String apiKey = AppConfig.goMapsApiKey;

  static const _apiKey = AppConfig.goMapsApiKey;

  Future<void> _suggest(String input) async {
    final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$input&key=$_apiKey';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() => _placeSuggestions = json.decode(res.body)['predictions']);
      }
    } catch (_) {}
  }

  Future<LatLng> _coords(String placeId) async {
    final url = 'https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('coord fail');
    final loc = json.decode(res.body)['result']['geometry']['location'];
    return LatLng(loc['lat'], loc['lng']);
  }

  Future<void> _fetchRoute() async {
    if (_fromLocation==null || _toLocation==null) return;
    final url = 'https://maps.gomaps.pro/maps/api/directions/json?origin=${_fromLocation!.latitude},${_fromLocation!.longitude}&destination=${_toLocation!.latitude},${_toLocation!.longitude}&key=$_apiKey';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode==200) {
      final routes = json.decode(res.body)['routes'];
      if (routes.isEmpty) return;
      final pts = _decodePolyline(routes[0]['overview_polyline']['points']);
      _createColourRoute(pts);
      _setMarkersAndZoom();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // POLYLINE DECODE & MARKERS
  // ────────────────────────────────────────────────────────────────────────

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

  void _setMarkersAndZoom() {
    setState(() {
      _markers = {
        if (_fromLocation!=null) Marker(markerId: const MarkerId('from'), position: _fromLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
        if (_toLocation  !=null) Marker(markerId: const MarkerId('to'),   position: _toLocation!,   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      };
    });
    if (_fromLocation!=null && _toLocation!=null) {
      final bounds = LatLngBounds(
        southwest: LatLng(min(_fromLocation!.latitude,_toLocation!.latitude), min(_fromLocation!.longitude,_toLocation!.longitude)),
        northeast: LatLng(max(_fromLocation!.latitude,_toLocation!.latitude), max(_fromLocation!.longitude,_toLocation!.longitude)),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final toggleColour = _selected == WeatherVariable.temperature ? Colors.orange : Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Route'), backgroundColor: Colors.blue),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(25.0,67.0), zoom: 10),
          onMapCreated: (c) => _mapController = c,
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
              ElevatedButton(onPressed: _fetchRoute, child: const Icon(Icons.search)),
            ]),
            if (_placeSuggestions.isNotEmpty)
              Container(
                color: Colors.white, height: 150,
                child: ListView.builder(
                  itemCount: _placeSuggestions.length,
                  itemBuilder: (c,i)=>ListTile(
                    title: Text(_placeSuggestions[i]['description']),
                    onTap: () async {
                      final id  = _placeSuggestions[i]['place_id'];
                      final loc = await _coords(id);
                      setState(() {
                        if (isSelectingFrom) {_fromLocation=loc; _fromController.text=_placeSuggestions[i]['description'];}
                        else {_toLocation=loc; _toController.text=_placeSuggestions[i]['description'];}
                        _placeSuggestions=[];
                      });
                      _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
                      _fetchRoute();
                    },
                  ),
                ),
              )
          ]),
        ),

        // ── Legend
        Positioned(
          bottom: 20, left: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _legendLabels.asMap().entries.map((e)=>_legendRow(e.value, kBandColours.values.elementAt(e.key))).toList(),
            ),
          ),
        ),

        // ── Toggle button (just **above** legend)
        Positioned(
          bottom: 150, // ~90px above legend box
          left: 10,
          child: FloatingActionButton(
            backgroundColor: toggleColour,
            heroTag: 'toggleWeather',
            onPressed: () {
              setState(() {
                _selected = _selected == WeatherVariable.temperature ? WeatherVariable.dewPoint : WeatherVariable.temperature;
              });
              _createColourRoute(_polylines.isNotEmpty ? _polylines.first.points : []); // refresh polyline colours
            },
            child: const Icon(Icons.swap_horiz),
            tooltip: 'Toggle Weather Variable',
          ),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ────────────────────────────────────────────────────────────────────────

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

  Widget _legendRow(String text, Color colour) {
    return Row(children: [Container(width: 20, height: 20, color: colour), const SizedBox(width: 8), Text(text)]);
  }
}


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