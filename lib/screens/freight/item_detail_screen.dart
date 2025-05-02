import 'package:flutter/material.dart';

class ItemDetailsScreen extends StatelessWidget {
  final String itemName;
  final String imagePath;
  final List<double> temperatures; // 4 thresholds
  final List<double> dewPoints; // 4 thresholds

  const ItemDetailsScreen({
    super.key,
    required this.itemName,
    required this.imagePath,
    required this.temperatures,
    required this.dewPoints,
  });

  // ───────────────────────── helpers ─────────────────────────
  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  List<String> get _tempLabels => [
        "Below ${_fmt(temperatures[0])}°C",
        "${_fmt(temperatures[0])}–${_fmt(temperatures[1])}°C",
        "${_fmt(temperatures[1])}–${_fmt(temperatures[2])}°C",
        "${_fmt(temperatures[2])}–${_fmt(temperatures[3])}°C",
        "Above ${_fmt(temperatures[3])}°C",
      ];

  List<String> get _dewLabels => [
        "Below ${_fmt(dewPoints[0])}°C",
        "${_fmt(dewPoints[0])}–${_fmt(dewPoints[1])}°C",
        "${_fmt(dewPoints[1])}–${_fmt(dewPoints[2])}°C",
        "${_fmt(dewPoints[2])}–${_fmt(dewPoints[3])}°C",
        "Above ${_fmt(dewPoints[3])}°C",
      ];

  // ───────────────────────── build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final TextEditingController startLocationController = TextEditingController();
    final TextEditingController stopLocationController = TextEditingController();

    return Scaffold(
<<<<<<< Updated upstream
<<<<<<< Updated upstream
      appBar: AppBar(
        title: const Text(
          'ROUTE',
          style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Raleway'),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Image.asset(imagePath, height: 150), // Display item image
                  const SizedBox(height: 15),
                  Text(
                    itemName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: startLocationController,
              decoration: const InputDecoration(
                labelText: 'Start Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stopLocationController,
              decoration: const InputDecoration(
                labelText: 'Stop Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Implement route showing logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route selected!')),
                  );
                },
                child: const Text('Show Route'),
=======
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        title: const Text('Item Selection'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
=======
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        title: const Text('Item Selection'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
>>>>>>> Stashed changes
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // ── Scrollable content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _imageBox(),
                        const SizedBox(height: 20),
                        Text(
                          itemName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _legendBox('Temperature Ranges:', _tempLabels),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _legendBox('Dew‑point Ranges:', _dewLabels),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Call‑to‑action button pinned to bottom ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _routeButton(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── widgets ─────────────────────────
  Widget _imageBox() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          imagePath,
          height: 250,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _legendBox(String title, List<String> labels) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...labels.asMap().entries.map((e) {
            final spoil = e.key == 0 || e.key == 4;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Text(
                '• ${e.value}',
                style: TextStyle(
                  fontSize: 15,
                  color: spoil ? Colors.red : Colors.black87,
                  fontWeight: spoil ? FontWeight.bold : FontWeight.normal,
                ),
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _routeButton(BuildContext ctx) {
    return GestureDetector(
      onTap: () => Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) =>
              TravelRouteScreen(temperatures: temperatures, dewPoints: dewPoints),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Colors.deepPurpleAccent],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🚀 Choose Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
<<<<<<< Updated upstream
=======

<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
