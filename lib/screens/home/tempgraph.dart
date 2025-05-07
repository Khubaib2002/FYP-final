// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:agaahi/config.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});
  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TextEditingController _search = TextEditingController();
  List<dynamic> _suggestions = [];

  List<FlSpot> _spots = [];
  List<String> _labels = [];
  bool _loading = false;
  String? _error;
  String _currentLocation = '';
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Add debug info variables
  String _debugInfo = '';
  bool _showDebug = true; // Set to false in production

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Temperature Trend'),
          backgroundColor: Colors.blue,
          actions: [
            // Add debug toggle button
            if (_showDebug)
              IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Debug Info'),
                      content: SingleChildScrollView(
                        child: Text(_debugInfo),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            if (_currentLocation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentLocation,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildChart()),
          ],
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() {
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _onSearch(value),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  shrinkWrap: true,
                  itemBuilder: (_, i) {
                    final suggestion = _suggestions[i];
                    return ListTile(
                      title: Text(suggestion['description']),
                      onTap: () => _selectPlace(suggestion['place_id'], suggestion['description']),
                    );
                  },
                ),
              ),
          ],
        ),
      );

  Widget _buildChart() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading temperature data...'),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, 
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_spots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text('Search for a location to view temperature data',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Round min and max to nearest whole number for cleaner axis display
    double minY = (_spots.map((e) => e.y).reduce(min) - 1).floorToDouble();
    double maxY = (_spots.map((e) => e.y).reduce(max) + 1).ceilToDouble();
    
    // Ensure reasonable Y-axis range even with close values
    if (maxY - minY < 5) {
      minY = (minY - 2).floorToDouble();
      maxY = (maxY + 2).ceilToDouble();
    }

    // Calculate interval for Y-axis
    double yInterval = ((maxY - minY) / 5).ceilToDouble();
    if (yInterval < 1) yInterval = 1;

    // Calculate interval for X-axis labels (show fewer labels for readability)
    int xLabelInterval = max((_spots.length / 8).round(), 1);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < _labels.length) {
                    return LineTooltipItem(
                      '${_labels[index]}\n${spot.y.toStringAsFixed(1)}°C',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchSpotThreshold: 20,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yInterval,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${value.toInt()}°C',
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 40,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index >= 0 && index < _labels.length && index % xLabelInterval == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _labels[index],
                        style: const TextStyle(
                          color: Color(0xff68737d),
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xffe7e8ec),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: const Color(0xffe7e8ec),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xffd3d3d3)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _spots,
              isCurved: true,
              curveSmoothness: 0.35,
              barWidth: 3,
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.lightBlueAccent.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: FlDotData(
                show: false,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.blue,
                ),
              ),
              isStrokeCapRound: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    
    try {
      final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$query&key=${AppConfig.goMapsApiKey}';
      final r = await http.get(Uri.parse(url));
      
      if (r.statusCode == 200) {
        final decodedResponse = json.decode(r.body);
        if (decodedResponse['predictions'] != null) {
          setState(() => _suggestions = decodedResponse['predictions']);
        } else {
          setState(() => _suggestions = []);
        }
      } else {
        print('❌ Autocomplete API error: ${r.statusCode}');
        setState(() => _suggestions = []);
      }
    } catch (e) {
      print('❌ Search error: $e');
      setState(() => _suggestions = []);
    }
  }

  Future<void> _selectPlace(String placeId, String desc) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _currentLocation = desc;
      _suggestions = [];
      _debugInfo = ''; // Reset debug info
    });
    _search.text = desc;

    try {
      _addDebugInfo('📍 Resolving coordinates for: $desc');
      final r = await http.get(Uri.parse('https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=${AppConfig.goMapsApiKey}'));
      
      if (r.statusCode != 200) {
        throw Exception('Failed to get place details: ${r.statusCode}');
      }
      
      final decodedResponse = json.decode(r.body);
      if (decodedResponse['result'] == null || decodedResponse['result']['geometry'] == null) {
        throw Exception('Invalid place details response');
      }
      
      final loc = decodedResponse['result']['geometry']['location'];
      _addDebugInfo('📌 Resolved to lat=${loc['lat']}, lng=${loc['lng']}');
      await _fetchWeather(loc['lat'], loc['lng']);
    } catch (e) {
      _addDebugInfo('❌ Coordinate resolution failed: $e');
      setState(() {
        _loading = false;
        _error = 'Failed to load coordinates: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchWeather(double lat, double lng) async {
    try {
      _addDebugInfo('🌐 Fetching weather data for lat=$lat, lng=$lng');
      final r = await http.post(
        Uri.parse('https://weather-db-b91w.onrender.com/api/v1/stations/by-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"longitude": lng, "latitude": lat, "max_distance": 70000}),
      );

      _addDebugInfo('📥 Response status: ${r.statusCode}');
      if (r.statusCode != 200) throw Exception('API failed with status ${r.statusCode}');

      final stations = json.decode(r.body);
      _addDebugInfo('🛰️ Stations received: ${stations.length}');
      
      if (stations.isEmpty) {
        throw Exception('No weather stations found near this location');
      }

      // Store all temperature data points
      final Map<DateTime, List<double>> allTemps = {};
      int totalEntries = 0;
      
      for (var s in stations) {
        final List entries = s['entries'] ?? (s['entry'] != null ? [s['entry']] : []);
        _addDebugInfo('  Station has ${entries.length} entries');
        totalEntries += entries.length.toInt();
        
        for (var e in entries) {
          final ts = e['timestamp'];
          final temp = e['Temp - °C'] ?? e['Temp - Â°C'];
          if (ts == null || temp == null) continue;
          
          try {
            final dt = DateTime.parse(ts);
            final tempValue = double.tryParse(temp.toString());
            if (tempValue != null) {
              if (!allTemps.containsKey(dt)) {
                allTemps[dt] = [];
              }
              allTemps[dt]!.add(tempValue);
            }
          } catch (err) {
            _addDebugInfo('⚠️ Skipping bad timestamp: $ts');
          }
        }
      }

      _addDebugInfo('⏱️ Total entries: $totalEntries');
      _addDebugInfo('⏱️ Unique timestamps: ${allTemps.length}');
      
      // Convert multi-values at same timestamp to averages
      final Map<DateTime, double> tsMap = {};
      allTemps.forEach((dt, temps) {
        // Calculate average if multiple readings at same timestamp
        tsMap[dt] = temps.reduce((a, b) => a + b) / temps.length;
      });
      
      if (tsMap.isEmpty) {
        throw Exception('No temperature data available for this location');
      }
      
      // Get the sorted timestamps to understand our data range
      final sorted = tsMap.keys.toList()..sort();
      final earliestDate = sorted.first;
      final latestDate = sorted.last;
      
      _addDebugInfo('📅 Data range: ${DateFormat('yyyy-MM-dd HH:mm').format(earliestDate)} to ${DateFormat('yyyy-MM-dd HH:mm').format(latestDate)}');
      
      // MODIFIED: Use a date from one year ago as the "current" date
      final now = DateTime.now().subtract(const Duration(days: 365));
      _addDebugInfo('📅 Using date from one year ago: ${DateFormat('yyyy-MM-dd').format(now)}');
      
      DateTime start;
      DateTime end;
      
      // Same logic with adjusted "now" date
      if (now.isAfter(earliestDate) && now.isBefore(latestDate)) {
        // One-year-ago date is within data range - center around that date
        _addDebugInfo('📊 One-year-ago date is within data range - centering on that date');
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
        end = DateTime(now.year, now.month, now.day).add(const Duration(days: 4));
      } else if (now.isAfter(latestDate)) {
        // One-year-ago date is after our data - use most recent week
        _addDebugInfo('📊 One-year-ago date is after data range - using most recent week');
        end = latestDate;
        start = end.subtract(const Duration(days: 7));
      } else {
        // One-year-ago date is before our data - use earliest week
        _addDebugInfo('📊 One-year-ago date is before data range - using earliest week');
        start = earliestDate;
        end = start.add(const Duration(days: 7));
      }
      
      // Ensure we don't go beyond available data
      if (start.isBefore(earliestDate)) start = earliestDate;
      if (end.isAfter(latestDate)) end = latestDate;
      
      _addDebugInfo('📆 Selected window: ${DateFormat('yyyy-MM-dd').format(start)} to ${DateFormat('yyyy-MM-dd').format(end)}');
      
      // Store dates for display
      _startDate = start;
      _endDate = end;
      
      // Calculate hourly intervals for cleaner display
      List<FlSpot> spots = [];
      List<String> labels = [];
      int idx = 0;
      
      // Use hourly intervals instead of 15-minute intervals for cleaner display
      for (var t = _floorHour(start); t.isBefore(_ceilHour(end)); t = t.add(const Duration(hours: 3))) {
        final val = _getTemperatureForTimestamp(tsMap, t);
        if (val != null) {
          spots.add(FlSpot(idx.toDouble(), val));
          
          // Format based on whether this is a day boundary
          String label;
          if (t.hour == 0) {
            label = DateFormat('MM/dd').format(t);
          } else {
            label = DateFormat('HH:00').format(t);
          }
          
          labels.add(label);
          idx++;
        }
      }

      _addDebugInfo('📊 Points prepared for graph: ${spots.length}');
      if (spots.isEmpty) throw Exception('No data points available in the selected date range');

      setState(() {
        _spots = spots;
        _labels = labels;
        _loading = false;
      });
    } catch (e, s) {
      _addDebugInfo('❌ Error while fetching weather: $e\n$s');
      setState(() {
        _loading = false;
        _error = 'Failed to load temperature data: ${e.toString()}';
      });
    }
  }

  // IMPROVED: Better temperature lookup with wider time window
  double? _getTemperatureForTimestamp(Map<DateTime, double> tsMap, DateTime t) {
    // First try exact match
    if (tsMap.containsKey(t)) {
      return tsMap[t];
    }
    
    // Then look for nearby timestamps with increasing window size
    for (int minutes = 30; minutes <= 180; minutes += 30) {
      final window = Duration(minutes: minutes);
      final candidates = tsMap.entries
          .where((e) => (e.key.difference(t)).abs() <= window)
          .toList();
      
      if (candidates.isNotEmpty) {
        // Sort by closeness to target time
        candidates.sort((a, b) => 
            (a.key.difference(t)).abs().compareTo((b.key.difference(t)).abs()));
        
        // Use the closest reading
        return candidates.first.value;
      }
    }
    
    return null;
  }

  // Helper methods for timestamp rounding
  DateTime _floorHour(DateTime dt) => DateTime(dt.year, dt.month, dt.day, dt.hour);
  DateTime _ceilHour(DateTime dt) => _floorHour(dt.add(const Duration(minutes: 59)));
  
  // Debug helper
  void _addDebugInfo(String info) {
    print(info);  // Still print to console
    if (_showDebug) {
      _debugInfo += '$info\n';
    }
  }
}
















// // ignore_for_file: use_build_context_synchronously

// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:agaahi/config.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({super.key});
//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   final TextEditingController _search = TextEditingController();
//   List<dynamic> _suggestions = [];

//   List<FlSpot> _spots = [];
//   List<String> _labels = [];
//   bool _loading = false;
//   String? _error;
//   String _currentLocation = '';
//   DateTime? _startDate;
//   DateTime? _endDate;
  
//   // Add debug info variables
//   String _debugInfo = '';
//   bool _showDebug = true; // Set to false in production

//   @override
//   Widget build(BuildContext context) => Scaffold(
//         appBar: AppBar(
//           title: const Text('Temperature Trend'),
//           backgroundColor: Colors.blue,
//           actions: [
//             // Add debug toggle button
//             if (_showDebug)
//               IconButton(
//                 icon: const Icon(Icons.bug_report),
//                 onPressed: () {
//                   showDialog(
//                     context: context,
//                     builder: (context) => AlertDialog(
//                       title: const Text('Debug Info'),
//                       content: SingleChildScrollView(
//                         child: Text(_debugInfo),
//                       ),
//                       actions: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: const Text('Close'),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//           ],
//         ),
//         body: Column(
//           children: [
//             _buildSearchBar(),
//             if (_currentLocation.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.location_on, color: Colors.blue),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         _currentLocation,
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             if (_startDate != null && _endDate != null)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.date_range, color: Colors.blue),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}',
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ),
//             Expanded(child: _buildChart()),
//           ],
//         ),
//       );

//   Widget _buildSearchBar() => Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _search,
//               decoration: InputDecoration(
//                 hintText: 'Search location',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: BorderSide.none,
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey[100],
//                 suffixIcon: _search.text.isNotEmpty
//                     ? IconButton(
//                         icon: const Icon(Icons.clear),
//                         onPressed: () {
//                           _search.clear();
//                           setState(() {
//                             _suggestions = [];
//                           });
//                         },
//                       )
//                     : null,
//               ),
//               onChanged: (value) => _onSearch(value),
//             ),
//             if (_suggestions.isNotEmpty)
//               Container(
//                 margin: const EdgeInsets.only(top: 6),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
//                 ),
//                 constraints: const BoxConstraints(maxHeight: 200),
//                 child: ListView.builder(
//                   itemCount: _suggestions.length,
//                   shrinkWrap: true,
//                   itemBuilder: (_, i) {
//                     final suggestion = _suggestions[i];
//                     return ListTile(
//                       title: Text(suggestion['description']),
//                       onTap: () => _selectPlace(suggestion['place_id'], suggestion['description']),
//                     );
//                   },
//                 ),
//               ),
//           ],
//         ),
//       );

//   Widget _buildChart() {
//     if (_loading) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text('Loading temperature data...'),
//           ],
//         ),
//       );
//     }
    
//     if (_error != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 48),
//             const SizedBox(height: 16),
//             Text(_error!, 
//                 style: const TextStyle(color: Colors.red),
//                 textAlign: TextAlign.center),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _error = null;
//                 });
//               },
//               child: const Text('Try Again'),
//             ),
//           ],
//         ),
//       );
//     }
    
//     if (_spots.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.bar_chart, color: Colors.grey, size: 64),
//             SizedBox(height: 16),
//             Text('Search for a location to view temperature data',
//                 style: TextStyle(fontSize: 16),
//                 textAlign: TextAlign.center),
//           ],
//         ),
//       );
//     }

//     // Round min and max to nearest whole number for cleaner axis display
//     double minY = (_spots.map((e) => e.y).reduce(min) - 1).floorToDouble();
//     double maxY = (_spots.map((e) => e.y).reduce(max) + 1).ceilToDouble();
    
//     // Ensure reasonable Y-axis range even with close values
//     if (maxY - minY < 5) {
//       minY = (minY - 2).floorToDouble();
//       maxY = (maxY + 2).ceilToDouble();
//     }

//     // Calculate interval for Y-axis
//     double yInterval = ((maxY - minY) / 5).ceilToDouble();
//     if (yInterval < 1) yInterval = 1;

//     // Calculate interval for X-axis labels (show fewer labels for readability)
//     int xLabelInterval = max((_spots.length / 8).round(), 1);

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: LineChart(
//         LineChartData(
//           minY: minY,
//           maxY: maxY,
//           lineTouchData: LineTouchData(
//             touchTooltipData: LineTouchTooltipData(
//               // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
//               getTooltipItems: (List<LineBarSpot> touchedSpots) {
//                 return touchedSpots.map((spot) {
//                   final index = spot.x.toInt();
//                   if (index >= 0 && index < _labels.length) {
//                     return LineTooltipItem(
//                       '${_labels[index]}\n${spot.y.toStringAsFixed(1)}°C',
//                       const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                     );
//                   }
//                   return null;
//                 }).toList();
//               },
//             ),
//             handleBuiltInTouches: true,
//             touchSpotThreshold: 20,
//           ),
//           titlesData: FlTitlesData(
//             leftTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 reservedSize: 40,
//                 interval: yInterval,
//                 getTitlesWidget: (value, meta) => Padding(
//                   padding: const EdgeInsets.only(right: 8.0),
//                   child: Text(
//                     '${value.toInt()}°C',
//                     style: const TextStyle(
//                       color: Color(0xff68737d),
//                       fontSize: 11,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             bottomTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: 1,
//                 reservedSize: 40,
//                 getTitlesWidget: (value, _) {
//                   final index = value.toInt();
//                   if (index >= 0 && index < _labels.length && index % xLabelInterval == 0) {
//                     return Padding(
//                       padding: const EdgeInsets.only(top: 8.0),
//                       child: Text(
//                         _labels[index],
//                         style: const TextStyle(
//                           color: Color(0xff68737d),
//                           fontSize: 10,
//                         ),
//                       ),
//                     );
//                   }
//                   return const SizedBox.shrink();
//                 },
//               ),
//             ),
//             topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//             rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           ),
//           gridData: FlGridData(
//             show: true,
//             drawVerticalLine: true,
//             horizontalInterval: yInterval,
//             getDrawingHorizontalLine: (value) => FlLine(
//               color: const Color(0xffe7e8ec),
//               strokeWidth: 1,
//             ),
//             getDrawingVerticalLine: (value) => FlLine(
//               color: const Color(0xffe7e8ec),
//               strokeWidth: 1,
//             ),
//           ),
//           borderData: FlBorderData(
//             show: true,
//             border: Border.all(color: const Color(0xffd3d3d3)),
//           ),
//           lineBarsData: [
//             LineChartBarData(
//               spots: _spots,
//               isCurved: true,
//               curveSmoothness: 0.35,
//               barWidth: 3,
//               gradient: const LinearGradient(
//                 colors: [Colors.blue, Colors.lightBlueAccent],
//               ),
//               belowBarData: BarAreaData(
//                 show: true,
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.blue.withOpacity(0.3),
//                     Colors.lightBlueAccent.withOpacity(0.1),
//                   ],
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                 ),
//               ),
//               dotData: FlDotData(
//                 show: false,
//                 getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
//                   radius: 3,
//                   color: Colors.white,
//                   strokeWidth: 2,
//                   strokeColor: Colors.blue,
//                 ),
//               ),
//               isStrokeCapRound: true,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _onSearch(String query) async {
//     if (query.isEmpty) {
//       setState(() => _suggestions = []);
//       return;
//     }
    
//     try {
//       final url = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json?input=$query&key=${AppConfig.goMapsApiKey}';
//       final r = await http.get(Uri.parse(url));
      
//       if (r.statusCode == 200) {
//         final decodedResponse = json.decode(r.body);
//         if (decodedResponse['predictions'] != null) {
//           setState(() => _suggestions = decodedResponse['predictions']);
//         } else {
//           setState(() => _suggestions = []);
//         }
//       } else {
//         print('❌ Autocomplete API error: ${r.statusCode}');
//         setState(() => _suggestions = []);
//       }
//     } catch (e) {
//       print('❌ Search error: $e');
//       setState(() => _suggestions = []);
//     }
//   }

//   Future<void> _selectPlace(String placeId, String desc) async {
//     FocusScope.of(context).unfocus();
//     setState(() {
//       _loading = true;
//       _error = null;
//       _currentLocation = desc;
//       _suggestions = [];
//       _debugInfo = ''; // Reset debug info
//     });
//     _search.text = desc;

//     try {
//       _addDebugInfo('📍 Resolving coordinates for: $desc');
//       final r = await http.get(Uri.parse('https://maps.gomaps.pro/maps/api/place/details/json?place_id=$placeId&key=${AppConfig.goMapsApiKey}'));
      
//       if (r.statusCode != 200) {
//         throw Exception('Failed to get place details: ${r.statusCode}');
//       }
      
//       final decodedResponse = json.decode(r.body);
//       if (decodedResponse['result'] == null || decodedResponse['result']['geometry'] == null) {
//         throw Exception('Invalid place details response');
//       }
      
//       final loc = decodedResponse['result']['geometry']['location'];
//       _addDebugInfo('📌 Resolved to lat=${loc['lat']}, lng=${loc['lng']}');
//       await _fetchWeather(loc['lat'], loc['lng']);
//     } catch (e) {
//       _addDebugInfo('❌ Coordinate resolution failed: $e');
//       setState(() {
//         _loading = false;
//         _error = 'Failed to load coordinates: ${e.toString()}';
//       });
//     }
//   }

//   Future<void> _fetchWeather(double lat, double lng) async {
//     try {
//       _addDebugInfo('🌐 Fetching weather data for lat=$lat, lng=$lng');
//       final r = await http.post(
//         Uri.parse('https://weather-db-b91w.onrender.com/api/v1/stations/by-location'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({"longitude": lng, "latitude": lat, "max_distance": 10000}),
//       );

//       _addDebugInfo('📥 Response status: ${r.statusCode}');
//       if (r.statusCode != 200) throw Exception('API failed with status ${r.statusCode}');

//       final stations = json.decode(r.body);
//       _addDebugInfo('🛰️ Stations received: ${stations.length}');
      
//       if (stations.isEmpty) {
//         throw Exception('No weather stations found near this location');
//       }

//       // Store all temperature data points
//       final Map<DateTime, List<double>> allTemps = {};
//       int totalEntries = 0;
      
//       for (var s in stations) {
//         final List entries = s['entries'] ?? (s['entry'] != null ? [s['entry']] : []);
//         _addDebugInfo('  Station has ${entries.length} entries');
//         totalEntries += entries.length.toInt();
        
//         for (var e in entries) {
//           final ts = e['timestamp'];
//           final temp = e['Temp - °C'] ?? e['Temp - Â°C'];
//           if (ts == null || temp == null) continue;
          
//           try {
//             final dt = DateTime.parse(ts);
//             final tempValue = double.tryParse(temp.toString());
//             if (tempValue != null) {
//               if (!allTemps.containsKey(dt)) {
//                 allTemps[dt] = [];
//               }
//               allTemps[dt]!.add(tempValue);
//             }
//           } catch (err) {
//             _addDebugInfo('⚠️ Skipping bad timestamp: $ts');
//           }
//         }
//       }

//       _addDebugInfo('⏱️ Total entries: $totalEntries');
//       _addDebugInfo('⏱️ Unique timestamps: ${allTemps.length}');
      
//       // Convert multi-values at same timestamp to averages
//       final Map<DateTime, double> tsMap = {};
//       allTemps.forEach((dt, temps) {
//         // Calculate average if multiple readings at same timestamp
//         tsMap[dt] = temps.reduce((a, b) => a + b) / temps.length;
//       });
      
//       if (tsMap.isEmpty) {
//         throw Exception('No temperature data available for this location');
//       }
      
//       // Get the sorted timestamps to understand our data range
//       final sorted = tsMap.keys.toList()..sort();
//       final earliestDate = sorted.first;
//       final latestDate = sorted.last;
      
//       _addDebugInfo('📅 Data range: ${DateFormat('yyyy-MM-dd HH:mm').format(earliestDate)} to ${DateFormat('yyyy-MM-dd HH:mm').format(latestDate)}');
      
//       // Use today's date as reference for centered window
//       final now = DateTime.now();
//       _addDebugInfo('📅 Current date: ${DateFormat('yyyy-MM-dd').format(now)}');
      
//       DateTime start;
//       DateTime end;
      
//       // FIXED: More robust date window selection logic
//       if (now.isAfter(earliestDate) && now.isBefore(latestDate)) {
//         // Current date is within data range - center around today
//         _addDebugInfo('📊 Current date is within data range - centering on today');
//         start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
//         end = DateTime(now.year, now.month, now.day).add(const Duration(days: 4));
//       } else if (now.isAfter(latestDate)) {
//         // Current date is after our data - use most recent week
//         _addDebugInfo('📊 Current date is after data range - using most recent week');
//         end = latestDate;
//         start = end.subtract(const Duration(days: 7));
//       } else {
//         // Current date is before our data - use earliest week
//         _addDebugInfo('📊 Current date is before data range - using earliest week');
//         start = earliestDate;
//         end = start.add(const Duration(days: 7));
//       }
      
//       // Ensure we don't go beyond available data
//       if (start.isBefore(earliestDate)) start = earliestDate;
//       if (end.isAfter(latestDate)) end = latestDate;
      
//       _addDebugInfo('📆 Selected window: ${DateFormat('yyyy-MM-dd').format(start)} to ${DateFormat('yyyy-MM-dd').format(end)}');
      
//       // Store dates for display
//       _startDate = start;
//       _endDate = end;
      
//       // Calculate hourly intervals for cleaner display
//       List<FlSpot> spots = [];
//       List<String> labels = [];
//       int idx = 0;
      
//       // Use hourly intervals instead of 15-minute intervals for cleaner display
//       for (var t = _floorHour(start); t.isBefore(_ceilHour(end)); t = t.add(const Duration(hours: 3))) {
//         final val = _getTemperatureForTimestamp(tsMap, t);
//         if (val != null) {
//           spots.add(FlSpot(idx.toDouble(), val));
          
//           // Format based on whether this is a day boundary
//           String label;
//           if (t.hour == 0) {
//             label = DateFormat('MM/dd').format(t);
//           } else {
//             label = DateFormat('HH:00').format(t);
//           }
          
//           labels.add(label);
//           idx++;
//         }
//       }

//       _addDebugInfo('📊 Points prepared for graph: ${spots.length}');
//       if (spots.isEmpty) throw Exception('No data points available in the selected date range');

//       setState(() {
//         _spots = spots;
//         _labels = labels;
//         _loading = false;
//       });
//     } catch (e, s) {
//       _addDebugInfo('❌ Error while fetching weather: $e\n$s');
//       setState(() {
//         _loading = false;
//         _error = 'Failed to load temperature data: ${e.toString()}';
//       });
//     }
//   }

//   // IMPROVED: Better temperature lookup with wider time window
//   double? _getTemperatureForTimestamp(Map<DateTime, double> tsMap, DateTime t) {
//     // First try exact match
//     if (tsMap.containsKey(t)) {
//       return tsMap[t];
//     }
    
//     // Then look for nearby timestamps with increasing window size
//     for (int minutes = 30; minutes <= 180; minutes += 30) {
//       final window = Duration(minutes: minutes);
//       final candidates = tsMap.entries
//           .where((e) => (e.key.difference(t)).abs() <= window)
//           .toList();
      
//       if (candidates.isNotEmpty) {
//         // Sort by closeness to target time
//         candidates.sort((a, b) => 
//             (a.key.difference(t)).abs().compareTo((b.key.difference(t)).abs()));
        
//         // Use the closest reading
//         return candidates.first.value;
//       }
//     }
    
//     return null;
//   }

//   // Helper methods for timestamp rounding
//   DateTime _floorHour(DateTime dt) => DateTime(dt.year, dt.month, dt.day, dt.hour);
//   DateTime _ceilHour(DateTime dt) => _floorHour(dt.add(const Duration(minutes: 59)));
  
//   // Debug helper
//   void _addDebugInfo(String info) {
//     print(info);  // Still print to console
//     if (_showDebug) {
//       _debugInfo += '$info\n';
//     }
//   }
// }




































// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({super.key});

//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   List<double> _temperatureData = [];
//   final Map<String, String> _csvFiles = {
//     'SARIMA X': 'assets/kk.csv',
//     'PROPHET': 'assets/pp.csv',
//   };
//   String? _selectedCsv;

//   Future<void> loadTemperatureData(String csvPath) async {
//     try {
//       final rawData = await rootBundle.loadString(csvPath);
//       final List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);

//       // Identify the 'temp' column index
//       int tempIndex = csvData[0].indexWhere((header) => header.toString().toLowerCase() == 'temp');
//       if (tempIndex == -1) {
//         throw Exception('Temp column not found in the CSV file.');
//       }

//       setState(() {
//         _temperatureData = csvData
//             .skip(1)
//             .map((row) {
//               var value = row[tempIndex];
//               if (value is num) {
//                 return value.toDouble();
//               } else if (value is String) {
//                 return double.tryParse(value) ?? 0.0;
//               }
//               return 0.0;
//             })
//             .toList()
//             .cast<double>();
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading data: $e'),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//     }
//   }

//   double getMaxValue(List<double> data) {
//     return data.isNotEmpty ? data.reduce((a, b) => a > b ? a : b) : 0.0;
//   }

//   double getMinValue(List<double> data) {
//     return data.isNotEmpty ? data.reduce((a, b) => a < b ? a : b) : 0.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     double maxY = getMaxValue(_temperatureData);
//     maxY = (maxY + 1).ceilToDouble();
//     double minY = getMinValue(_temperatureData);
//     minY = (minY - 2).ceilToDouble();

//     return Scaffold(
//       appBar: AppBar(
//         title: AnimatedTextKit(
//           animatedTexts: [
//             TypewriterAnimatedText(
//               'Temperature Graph',
//               textStyle: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//           ],
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blueAccent, Colors.lightBlue],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Select the MODEL:',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.blueAccent,
//               ),
//             ),
//             const SizedBox(height: 16),
//             DropdownButton<String>(
//               value: _selectedCsv,
//               items: _csvFiles.entries
//                   .map(
//                     (entry) => DropdownMenuItem(
//                       value: entry.value,
//                       child: Text(entry.key),
//                     ),
//                   )
//                   .toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedCsv = value;
//                   _temperatureData = [];
//                 });
//               },
//               hint: const Text('Select a Model'),
//               isExpanded: true,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedCsv != null) {
//                   loadTemperatureData(_selectedCsv!);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a Model first.')),
//                   );
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text('Load Data'),
//             ),
//             const SizedBox(height: 16),
//             Expanded(
//               child: _temperatureData.isNotEmpty
//                   ? LineChart(
//                       LineChartData(
//                         lineBarsData: [
//                           LineChartBarData(
//                             spots: _temperatureData
//                                 .asMap()
//                                 .entries
//                                 .map((e) => FlSpot(e.key.toDouble(), e.value))
//                                 .toList(),
//                             isCurved: true,
//                             gradient: const LinearGradient(
//                               colors: [Colors.red, Colors.redAccent],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             barWidth: 4,
//                             belowBarData: BarAreaData(
//                               show: true,
//                               gradient: const LinearGradient(
//                                 colors: [Colors.redAccent, Colors.transparent],
//                                 begin: Alignment.topCenter,
//                                 end: Alignment.bottomCenter,
//                               ),
//                             ),
//                             dotData: const FlDotData(show: false),
//                           ),
//                         ],
//                         titlesData: FlTitlesData(
//                           topTitles: const AxisTitles(
//                             sideTitles: SideTitles(showTitles: false), // Disable top X-axis
//                           ),
//                           leftTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               reservedSize: 40,
//                               getTitlesWidget: (value, meta) {
//                                 return Text(
//                                   value.toStringAsFixed(1),
//                                   style: const TextStyle(
//                                     color: Colors.blueGrey,
//                                     fontSize: 12,
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                           rightTitles: const AxisTitles(
//                             sideTitles: SideTitles(showTitles: false), // Disable right Y-axis
//                           ),
//                           bottomTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               getTitlesWidget: (value, meta) {
//                                 int index = value.toInt();
//                                 if (index < 0 || index >= _temperatureData.length) return const Text('');
//                                 if (index % 25 != 0) return const Text(''); // Show only at intervals of 25
//                                 return Text(
//                                   (index ~/ 25).toString(),
//                                   style: const TextStyle(
//                                     color: Colors.blueGrey,
//                                     fontSize: 10,
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                         ),
//                         gridData: FlGridData(
//                           show: true,
//                           drawHorizontalLine: true,
//                           horizontalInterval: 10,
//                           getDrawingHorizontalLine: (value) {
//                             return const FlLine(
//                               color: Colors.blueGrey,
//                               strokeWidth: 0.5,
//                               dashArray: [5, 5],
//                             );
//                           },
//                         ),
//                         borderData: FlBorderData(
//                           show: true,
//                           border: Border.all(
//                             color: Colors.blueGrey,
//                             width: 1,
//                           ),
//                         ),
//                         lineTouchData: LineTouchData(
//                           touchTooltipData: LineTouchTooltipData(
//                             tooltipPadding: const EdgeInsets.all(8),
//                             tooltipRoundedRadius: 8,
//                             getTooltipItems: (spots) {
//                               return spots.map((spot) {
//                                 return LineTooltipItem(
//                                   'Temp: ${spot.y.toStringAsFixed(2)} °C',
//                                   const TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 );
//                               }).toList();
//                             },
//                           ),
//                           handleBuiltInTouches: true,
//                         ),
//                         minY: minY,
//                         maxY: maxY,
//                         minX: 0,
//                         maxX: _temperatureData.length.toDouble() - 1,
//                       ),
//                     )
//                   : const Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.warning_amber_rounded,
//                             size: 60,
//                             color: Colors.redAccent,
//                           ),
//                           SizedBox(height: 16),
//                           Text(
//                             'No data available. Load data first.',
//                             style: TextStyle(
//                               color: Colors.blueGrey,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


