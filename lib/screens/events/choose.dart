import 'dart:convert';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agaahi/screens/events/details.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

class Choose extends StatefulWidget {
  const Choose({super.key});

  @override
  State<Choose> createState() => _ChooseState();
}

class _ChooseState extends State<Choose> {
  final TextEditingController _startLocationController = TextEditingController();
  List<List<dynamic>> _csvData = [];
  List<double> _selectedColumnData = [];
  List<String> _columns = [];
  String? _selectedColumn;

  final String _sessionToken = '1234567890';
  List<dynamic> _placeList = [];
  String _lastInput = "";

  @override
  void initState() {
    super.initState();
    _startLocationController.addListener(() {
      _onChanged();
    });
  }

  _onChanged() {
    String currentInput = _startLocationController.text.trim();
    if (currentInput == _lastInput || currentInput.isEmpty) {
      return;
    }
    _lastInput = currentInput;
    getSuggestion(currentInput);
  }

  void getSuggestion(String input) async {
    const String placesApiKey = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";
    try {
      String baseURL = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json';
      String request = '$baseURL?input=$input&key=$placesApiKey&sessiontoken=$_sessionToken';
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);

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

  Future<void> loadCsvAndPrepareColumns(String location) async {
    String formattedLocation = location.toLowerCase();
    String fileName;
    print(formattedLocation);
    if (formattedLocation == 'karachi') {
      fileName = 'assets/karachi.csv';
    } else if (formattedLocation == 'multan, pakistan') {
      fileName = 'assets/multan.csv';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid location!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final rawData = await rootBundle.loadString(fileName);
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(rawData);

      setState(() {
        _csvData = rowsAsListOfValues;
        _columns = List<String>.from(rowsAsListOfValues[0]);
        _selectedColumn = _columns.isNotEmpty ? _columns[1] : null;
        _selectedColumnData = extractColumnData(_selectedColumn!);
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

  List<double> extractColumnData(String columnName) {
    int columnIndex = _columns.indexOf(columnName);
    List<double> columnData = [];
    for (int i = 1; i < _csvData.length; i++) {
      var value = _csvData[i][columnIndex];
      double parsedValue = 0.0;
      if (value is String) {
        parsedValue = double.tryParse(value) ?? 0.0;
      } else if (value is num) {
        parsedValue = value.toDouble();
      }
      columnData.add(parsedValue);
    }
    return columnData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Choose Location',
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _startLocationController,
              decoration: InputDecoration(
                labelText: 'Search Location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _placeList.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        _placeList[index]['description'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        _startLocationController.text = _placeList[index]['description'];
                        _placeList.clear();
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  String location = _startLocationController.text.trim();
                  loadCsvAndPrepareColumns(location);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Load CSV',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_columns.isNotEmpty)
              DropdownButton<String>(
                value: _selectedColumn,
                items: _columns
                    .map((column) => DropdownMenuItem(
                          value: column,
                          child: Text(column),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedColumn = value;
                    _selectedColumnData = extractColumnData(_selectedColumn!);
                  });
                },
                hint: const Text('Select Column'),
                isExpanded: true,
              ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedColumnData.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Details(
                          selectedColumnData: _selectedColumnData,
                          columns: _columns,
                          selectedColumn: _selectedColumn!,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please load data first')),
                    );
                  }
                },
                child: const Text('Go to Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:agaahi/screens/events/details.dart';
// import 'package:csv/csv.dart';
// import 'package:http/http.dart' as http;

// class Choose extends StatefulWidget {
//   const Choose({super.key});

//   @override
//   State<Choose> createState() => _ChooseState();
// }

// class _ChooseState extends State<Choose> {
//   final TextEditingController _startLocationController = TextEditingController();
//   List<List<dynamic>> _csvData = [];
//   List<double> _selectedColumnData = [];
//   List<String> _columns = [];
//   String? _selectedColumn;

//   // Variables for Google Places API
//   final String _sessionToken = '1234567890';
//   List<dynamic> _placeList = [];
//   String _lastInput = ""; // To track the last processed input

//   @override
//   void initState() {
//     super.initState();
//     _startLocationController.addListener(() {
//       _onChanged();
//     });
//   }

//   // Trigger Places API on text change
//   _onChanged() {
//     String currentInput = _startLocationController.text.trim();
//     if (currentInput == _lastInput || currentInput.isEmpty) {
//       return; // Avoid duplicate or unnecessary API calls
//     }
//     _lastInput = currentInput;
//     getSuggestion(currentInput);
//   }

//   // Fetch suggestions from Places API
//   void getSuggestion(String input) async {
//     const String placesApiKey = "AlzaSymFDkQF5eE4o2ywQcMSLXTypzI0H_gqEEW";

//     try {
//       String baseURL = 'https://maps.gomaps.pro/maps/api/place/autocomplete/json';
//       String request = '$baseURL?input=$input&key=$placesApiKey&sessiontoken=$_sessionToken';
//       var response = await http.get(Uri.parse(request));
//       var data = json.decode(response.body);

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

//   // Load CSV data based on location
//   Future<void> loadCsvAndPrepareColumns(String location) async {
//     String formattedLocation = location.toLowerCase();
//     String fileName;
//     print(formattedLocation);
//     if (formattedLocation == 'karachi') {
//       fileName = 'assets/karachi.csv';
//     } else if (formattedLocation == 'multan, pakistan') {
//       fileName = 'assets/multan.csv';
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Invalid location!')),
//       );
//       return;
//     }

//     try {
//       final rawData = await rootBundle.loadString(fileName);
//       final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(rawData);

//       setState(() {
//         _csvData = rowsAsListOfValues;
//         _columns = List<String>.from(rowsAsListOfValues[0]);
//         _selectedColumn = _columns.isNotEmpty ? _columns[1] : null; // Default to second column
//         _selectedColumnData = extractColumnData(_selectedColumn!);
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading data: $e')),
//       );
//     }
//   }

//   List<double> extractColumnData(String columnName) {
//     int columnIndex = _columns.indexOf(columnName);
//     List<double> columnData = [];
//     for (int i = 1; i < _csvData.length; i++) {
//       var value = _csvData[i][columnIndex];
//       double parsedValue = 0.0;
//       if (value is String) {
//         parsedValue = double.tryParse(value) ?? 0.0;
//       } else if (value is num) {
//         parsedValue = value.toDouble();
//       }
//       columnData.add(parsedValue);
//     }
//     return columnData;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'LOCATION',
//           style: TextStyle(
//             fontSize: 25,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//             fontFamily: 'Raleway',
//           ),
//         ),
//         backgroundColor: Colors.blue,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 16),
//             TextField(
//               controller: _startLocationController,
//               decoration: const InputDecoration(
//                 labelText: 'Search Location',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Expanded(
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _placeList.length,
//                 itemBuilder: (context, index) {
//                   return ListTile(
//                     title: Text(_placeList[index]['description']),
//                     onTap: () {
//                       _startLocationController.text = _placeList[index]['description'];
//                       _placeList.clear(); // Clear suggestions on selection
//                       setState(() {});
//                     },
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   String location = _startLocationController.text.trim();
//                   loadCsvAndPrepareColumns(location);
//                 },
//                 child: const Text('Load CSV'),
//               ),
//             ),
//             const SizedBox(height: 16),
//             if (_columns.isNotEmpty)
//               DropdownButton<String>(
//                 value: _selectedColumn,
//                 items: _columns
//                     .map((column) => DropdownMenuItem(
//                           value: column,
//                           child: Text(column),
//                         ))
//                     .toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedColumn = value;
//                     _selectedColumnData = extractColumnData(_selectedColumn!);
//                   });
//                 },
//                 hint: const Text('Select Column'),
//               ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 if (_selectedColumnData.isNotEmpty) {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => Details(
//                         selectedColumnData: _selectedColumnData,
//                         columns: _columns,
//                         selectedColumn: _selectedColumn!,
//                       ),
//                     ),
//                   );
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please load data first')),
//                   );
//                 }
//               },
//               child: const Text('Go to Details'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }






