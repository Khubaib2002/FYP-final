import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  List<double> _temperatureData = [];
  final Map<String, String> _csvFiles = {
    'SARIMA X': 'assets/kk.csv',
    'PROPHET': 'assets/pp.csv',
  };
  String? _selectedCsv;

  Future<void> loadTemperatureData(String csvPath) async {
    try {
      final rawData = await rootBundle.loadString(csvPath);
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);

      // Identify the 'temp' column index
      int tempIndex = csvData[0].indexWhere((header) => header.toString().toLowerCase() == 'temp');
      if (tempIndex == -1) {
        throw Exception('Temp column not found in the CSV file.');
      }

      setState(() {
        _temperatureData = csvData
            .skip(1)
            .map((row) {
              var value = row[tempIndex];
              if (value is num) {
                return value.toDouble();
              } else if (value is String) {
                return double.tryParse(value) ?? 0.0;
              }
              return 0.0;
            })
            .toList()
            .cast<double>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  double getMaxValue(List<double> data) {
    return data.isNotEmpty ? data.reduce((a, b) => a > b ? a : b) : 0.0;
  }

  double getMinValue(List<double> data) {
    return data.isNotEmpty ? data.reduce((a, b) => a < b ? a : b) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    double maxY = getMaxValue(_temperatureData);
    maxY = (maxY + 1).ceilToDouble();
    double minY = getMinValue(_temperatureData);
    minY = (minY - 2).ceilToDouble();

    return Scaffold(
      appBar: AppBar(
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Temperature Graph',
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the MODEL:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedCsv,
              items: _csvFiles.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.value,
                      child: Text(entry.key),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCsv = value;
                  _temperatureData = [];
                });
              },
              hint: const Text('Select a Model'),
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_selectedCsv != null) {
                  loadTemperatureData(_selectedCsv!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a Model first.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Load Data'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _temperatureData.isNotEmpty
                  ? LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: _temperatureData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 4,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: const LinearGradient(
                                colors: [Colors.redAccent, Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false), // Disable top X-axis
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false), // Disable right Y-axis
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index < 0 || index >= _temperatureData.length) return const Text('');
                                if (index % 25 != 0) return const Text(''); // Show only at intervals of 25
                                return Text(
                                  (index ~/ 25).toString(),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          horizontalInterval: 10,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Colors.blueGrey,
                              strokeWidth: 0.5,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.blueGrey,
                            width: 1,
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                return LineTooltipItem(
                                  'Temp: ${spot.y.toStringAsFixed(2)} °C',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                        ),
                        minY: minY,
                        maxY: maxY,
                        minX: 0,
                        maxX: _temperatureData.length.toDouble() - 1,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 60,
                            color: Colors.redAccent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No data available. Load data first.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({Key? key}) : super(key: key);

//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   List<double> _temperatureData = [];
//   List<int> _dateLabels = [];
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

//         // Auto-generate dates
//         _dateLabels = List.generate(
//           _temperatureData.length,
//           (index) => (index % 5 == 0) ? index : -1,
//         );
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading CSV data: $e'),
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
//                   _dateLabels = [];
//                 });
//               },
//               hint: const Text('Select a CSV'),
//               isExpanded: true,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedCsv != null) {
//                   loadTemperatureData(_selectedCsv!);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a CSV file first.')),
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
//                           topTitles: AxisTitles(
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
//                           rightTitles: AxisTitles(
//                             sideTitles: SideTitles(showTitles: false), // Disable right Y-axis
//                           ),
//                           bottomTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               getTitlesWidget: (value, meta) {
//                                 int index = value.toInt();
//                                 if (index < 0 || index >= _dateLabels.length) return const Text('');
//                                 if (_dateLabels[index] == -1) return const Text('');
//                                 return Text(
//                                   _dateLabels[index].toString(),
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
//                             'No data available. Load a CSV file.',
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













// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({Key? key}) : super(key: key);

//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   List<double> _temperatureData = [];
//   List<int> _dateLabels = []; // Store auto-generated dates for X-axis
//   final Map<String, String> _csvFiles = {
//     'SARIMA X': 'assets/karachi.csv',
//     'PROPHET': 'assets/multan.csv',
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

//       // Extract the temperature column and generate dates
//       setState(() {
//         _temperatureData = csvData
//             .skip(1) // Skip the header row
//             .map((row) {
//               var value = row[tempIndex];
//               if (value is num) {
//                 return value.toDouble();
//               } else if (value is String) {
//                 return double.tryParse(value) ?? 0.0;
//               }
//               return 0.0; // Default to 0.0 for invalid entries
//             })
//             .toList()
//             .cast<double>();

//         // Auto-generate dates at intervals (e.g., 1, 5, 10, 15, 20, ...)
//         _dateLabels = List.generate(
//           _temperatureData.length,
//           (index) => (index % 5 == 0) ? index : -1, // Only show specific intervals
//         );
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading CSV data: $e'),
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
//                   _temperatureData = []; // Clear previous data
//                   _dateLabels = [];
//                 });
//               },
//               hint: const Text('Select a CSV'),
//               isExpanded: true,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedCsv != null) {
//                   loadTemperatureData(_selectedCsv!);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a CSV file first.')),
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
//                             dotData: const FlDotData(show: false), // Disable points
//                           ),
//                         ],
//                         titlesData: FlTitlesData(
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
//                           rightTitles: AxisTitles(
//                             sideTitles: SideTitles(showTitles: false), // Disable right Y-axis
//                           ),
//                           bottomTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               getTitlesWidget: (value, meta) {
//                                 int index = value.toInt();
//                                 if (index < 0 || index >= _dateLabels.length) return const Text('');
//                                 if (_dateLabels[index] == -1) return const Text(''); // Skip non-labeled points
//                                 return Text(
//                                   _dateLabels[index].toString(), // Display auto-generated dates
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
//                             'No data available. Load a CSV file.',
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








// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({Key? key}) : super(key: key);

//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   List<double> _temperatureData = [];
//   List<int> _dateLabels = []; // Store auto-generated dates for X-axis
//   final Map<String, String> _csvFiles = {
//     'SARIMA X': 'assets/karachi.csv',
//     'PROPHET': 'assets/multan.csv',
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

//       // Extract the temperature column and generate dates
//       setState(() {
//         _temperatureData = csvData
//             .skip(1) // Skip the header row
//             .map((row) {
//               var value = row[tempIndex];
//               if (value is num) {
//                 return value.toDouble();
//               } else if (value is String) {
//                 return double.tryParse(value) ?? 0.0;
//               }
//               return 0.0; // Default to 0.0 for invalid entries
//             })
//             .toList()
//             .cast<double>();

//         // Auto-generate dates at intervals (e.g., 1, 5, 10, 15, 20, ...)
//         _dateLabels = List.generate(
//           _temperatureData.length,
//           (index) => (index % 5 == 0) ? index : -1, // Only show specific intervals
//         );
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading CSV data: $e'),
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
//                   _temperatureData = []; // Clear previous data
//                   _dateLabels = [];
//                 });
//               },
//               hint: const Text('Select a CSV'),
//               isExpanded: true,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedCsv != null) {
//                   loadTemperatureData(_selectedCsv!);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a CSV file first.')),
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
//                               colors: [Colors.blue, Colors.cyan],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             barWidth: 4,
//                             belowBarData: BarAreaData(
//                               show: true,
//                               gradient: const LinearGradient(
//                                 colors: [Colors.blueAccent, Colors.transparent],
//                                 begin: Alignment.topCenter,
//                                 end: Alignment.bottomCenter,
//                               ),
//                             ),
//                             dotData: const FlDotData(show: false), // Disable points
//                           ),
//                         ],
//                         titlesData: FlTitlesData(
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
//                           rightTitles: AxisTitles(
//                             sideTitles: SideTitles(showTitles: false), // Disable right Y-axis
//                           ),
//                           bottomTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               getTitlesWidget: (value, meta) {
//                                 int index = value.toInt();
//                                 if (index < 0 || index >= _dateLabels.length) return const Text('');
//                                 if (_dateLabels[index] == -1) return const Text(''); // Skip non-labeled points
//                                 return Text(
//                                   _dateLabels[index].toString(), // Display auto-generated dates
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
//                                   'Day ${_dateLabels[spot.x.toInt()]}\nTemp: ${spot.y.toStringAsFixed(2)}',
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
//                             'No data available. Load a CSV file.',
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






// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/services.dart';
// import 'package:csv/csv.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class GraphScreen extends StatefulWidget {
//   const GraphScreen({Key? key}) : super(key: key);

//   @override
//   State<GraphScreen> createState() => _GraphScreenState();
// }

// class _GraphScreenState extends State<GraphScreen> {
//   List<double> _temperatureData = [];
//   final Map<String, String> _csvFiles = {
//     'SARIMA X': 'assets/karachi.csv',
//     'PROPHET': 'assets/multan.csv',
//     // 'XGBoost': 'assets/lahore.csv',
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

//       // Extract the temperature column
//      setState(() {
//   _temperatureData = csvData
//       .skip(1) // Skip the header row
//       .map((row) {
//         var value = row[tempIndex];
//         if (value is num) {
//           return value.toDouble(); // Convert numeric values to double
//         } else if (value is String) {
//           return double.tryParse(value) ?? 0.0; // Parse string to double
//         }
//         return 0.0; // Default to 0.0 for invalid entries
//       })
//       .toList()
//       .cast<double>(); // Ensure the list is explicitly a List<double>
// });

//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading CSV data: $e'),
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
//                   _temperatureData = []; // Clear previous data
//                 });
//               },
//               hint: const Text('Select a CSV'),
//               isExpanded: true,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedCsv != null) {
//                   loadTemperatureData(_selectedCsv!);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please select a CSV file first.')),
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
//                               colors: [Colors.blue, Colors.cyan],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             barWidth: 4,
//                             belowBarData: BarAreaData(
//                               show: true,
//                               gradient: const LinearGradient(
//                                 colors: [Colors.blueAccent, Colors.transparent],
//                                 begin: Alignment.topCenter,
//                                 end: Alignment.bottomCenter,
//                               ),
//                             ),
//                             dotData: const FlDotData(show: true),
//                           ),
//                         ],
//                         titlesData: FlTitlesData(
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
//                           bottomTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               getTitlesWidget: (value, meta) {
//                                 return Text(
//                                   'Point ${(value).toInt()}',
//                                   style: const TextStyle(
//                                     color: Colors.blueGrey,
//                                     fontSize: 12,
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
//                                   'Point ${spot.x.toInt()}\nValue: ${spot.y.toStringAsFixed(2)}',
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
//                             'No data available. Load a CSV file.',
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



