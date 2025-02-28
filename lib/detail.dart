import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlantDetailScreen extends StatefulWidget {
  final Map plant;

  PlantDetailScreen({required this.plant});

  @override
  _PlantDetailScreenState createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  List<Map> favoritePlants = []; // お気に入りリスト
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? favoritePlantsString = prefs.getString('favoritePlants');
    if (favoritePlantsString != null) {
      List<dynamic> favoritePlantsList = jsonDecode(favoritePlantsString);
      favoritePlants = favoritePlantsList.map((item) => item as Map).toList();
      setState(() {
        isFavorite =
            favoritePlants.any((plant) => plant['id'] == widget.plant['id']);
      });
    }
  }

  Future<void> _saveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String favoritePlantsString = jsonEncode(favoritePlants);
    await prefs.setString('favoritePlants', favoritePlantsString);
  }

  void _toggleFavorite(Map plant) {
    setState(() {
      if (favoritePlants.any((p) => p['id'] == plant['id'])) {
        favoritePlants.removeWhere((p) => p['id'] == plant['id']);
        isFavorite = false;
      } else {
        favoritePlants.add(plant);
        isFavorite = true;
      }
      _saveFavorites();
    });
  }

  void _deletePlant() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('plants').doc(widget.plant['id']).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.plant['name']}を削除しました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print("エラーが発生しました: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除できませんでした')),
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('削除の確認'),
          content: Text('本当にこの植物を削除しますか？'),
          actions: <Widget>[
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('削除'),
              onPressed: () {
                Navigator.of(context).pop();
                _deletePlant();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant['name']),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      widget.plant['images'],
                      height: MediaQuery.of(context).size.height * 0.4,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.plant['name'],
                    style: const TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, 
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.plant['description'],
                    style: const TextStyle(
                      fontSize: 20, 
                      color: Colors.black54, 
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red[300] : null,
                      ),
                      onPressed: () {
                        _toggleFavorite(widget.plant);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDeleteConfirmationDialog,
        child: const Icon(Icons.delete),
        backgroundColor: Colors.red[300],
      ),
    );
  }
}
