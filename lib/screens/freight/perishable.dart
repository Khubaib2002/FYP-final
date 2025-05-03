// perishable.dart — final version with dew‑point thresholds & custom‑item support

import 'package:flutter/material.dart';
import 'item_detail_screen.dart';

class PerishableItemsScreen extends StatefulWidget {
  const PerishableItemsScreen({super.key});

  @override
  State<PerishableItemsScreen> createState() => _PerishableItemsScreenState();
}

class _PerishableItemsScreenState extends State<PerishableItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ─── master list (temps + dew‑points) ───
  List<Map<String, dynamic>> items = [
    {
      'name': 'Tomato',
      'image': 'assets/images/tomato.png',
      'temperatures': [10.0, 12.0, 21.0, 27.0],     // °C
      'dewPoints'  : [6.0,  8.0,  14.0, 18.0],
    },
    {
      'name': 'Potato',
      'image': 'assets/images/potato.png',
      'temperatures': [4.0, 7.0, 12.0, 15.0],
      'dewPoints'  : [2.0, 4.0, 10.0, 13.0],
    },
    {
      'name': 'Ladyfinger',
      'image': 'assets/images/ladyfinger.png',
      'temperatures': [7.0, 10.0, 25.0, 30.0],
      'dewPoints'  : [4.0, 6.0, 20.0, 25.0],
    },
    {
      'name': 'Lemon',
      'image': 'assets/images/lemon.png',
      'temperatures': [7.0, 10.0, 14.0, 20.0],
      'dewPoints'  : [3.0, 6.0, 10.0, 15.0],
    },
    {
      'name': 'Eggplant',
      'image': 'assets/images/eggplant.png',
      'temperatures': [10.0, 12.0, 20.0, 24.0],
      'dewPoints'  : [6.0, 8.0, 14.0, 18.0],
    },
    {
      'name': 'Watermelon',
      'image': 'assets/images/watermelon.png',
      'temperatures': [10.0, 12.0, 16.0, 20.0],
      'dewPoints'  : [5.0, 7.0, 13.0, 16.0],
    },
    {
      'name': 'Banana',
      'image': 'assets/images/banana.png',
      'temperatures': [13.0, 14.0, 18.0, 22.0],
      'dewPoints'  : [10.0, 12.0, 15.0, 19.0],
    },
    {
      'name': 'Onion',
      'image': 'assets/images/onion.png',
      'temperatures': [0.0, 2.0, 7.0, 10.0],
      'dewPoints'  : [0.0, 1.0, 4.0, 7.0],
    },
  ];

  List<Map<String, dynamic>> filteredItems = [];

  @override
  void initState() {
    super.initState();
    filteredItems = List.from(items);
    _searchController.addListener(_filter);
  }

  // ─── search filter ───
  void _filter() => setState(() {
        final q = _searchController.text.toLowerCase();
        filteredItems = q.isEmpty ? List.from(items) : items.where((e)=>e['name'].toLowerCase().contains(q)).toList();
      });

  // ─── add custom item ───
  void _addItem() {
    final nameCtl = TextEditingController();
    final tempCtl = List.generate(4, (_) => TextEditingController());
    final dewCtl  = List.generate(4, (_) => TextEditingController());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Custom Item'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(hintText: 'Item name')),
            const SizedBox(height: 10),
            ...List.generate(4, (i)=>TextField(controller: tempCtl[i], decoration: InputDecoration(hintText: 'Temperature ${i+1} (°C)'), keyboardType: TextInputType.number)),
            const SizedBox(height: 10),
            ...List.generate(4, (i)=>TextField(controller: dewCtl[i],  decoration: InputDecoration(hintText: 'Dew‑point ${i+1} (°C)'),  keyboardType: TextInputType.number)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () {
            try {
              final temps = tempCtl.map((c)=>double.tryParse(c.text)??0).toList();
              final dews  = dewCtl .map((c)=>double.tryParse(c.text)??0).toList();
              _validate(temps); _validate(dews);
              setState(() {
                items.add({'name': nameCtl.text, 'image': 'assets/images/add.png', 'temperatures': temps, 'dewPoints': dews});
                filteredItems = List.from(items);
              });
              Navigator.pop(context);
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid values!')));
            }
          }, child: const Text('Add')),
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _validate(List<double> vals) {
    if (vals.any((v)=>v==0) || vals[0]>=vals[1] || vals[1]>=vals[2] || vals[2]>=vals[3]) {
      throw Exception('bad progression');
    }
  }

  // ─── build ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: TextField(
        controller: _searchController,
        decoration: const InputDecoration(hintText:'Search Perishable Items', hintStyle: TextStyle(color: Colors.white), prefixIcon: Icon(Icons.search,color:Colors.white), border: InputBorder.none),
        style: const TextStyle(color: Colors.white),
      )),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          itemCount: filteredItems.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.9),
          itemBuilder: (_, i) => i == filteredItems.length ? _addCard() : _itemCard(filteredItems[i]),
        ),
      ),
    );
  }

  // ─── cards ───
  Widget _itemCard(Map<String,dynamic> item) {
    return GestureDetector(
      onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(itemName: item['name'], imagePath: item['image'], temperatures: List<double>.from(item['temperatures']), dewPoints: List<double>.from(item['dewPoints'])))),
      child: Card(
        elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), shadowColor: Colors.black54,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(height:120,width:120, decoration: BoxDecoration(image: DecorationImage(image: AssetImage(item['image']), fit: BoxFit.contain), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 10),
          Text(item['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _addCard() {
    return GestureDetector(onTap: _addItem, child: Card(
      elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), shadowColor: Colors.black54,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(height:120,width:120, decoration: BoxDecoration(image: const DecorationImage(image: AssetImage('assets/images/add.png'), fit: BoxFit.contain), borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 10), const Text('Add Custom', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ]),
    ));
  }
}