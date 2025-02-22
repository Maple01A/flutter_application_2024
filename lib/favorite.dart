import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'detail.dart';

class FavoriteScreen extends StatefulWidget {
  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Map> favoritePlants = [];

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
      setState(() {
        favoritePlants = favoritePlantsList.map((item) => item as Map).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入りの植物'),
      ),
      body: favoritePlants.isEmpty
          ? const Center(child: Text('お気に入りはありません'))
          : ListView.builder(
              itemCount: favoritePlants.length,
              itemBuilder: (context, index) {
                final plant = favoritePlants[index];
                return ListTile(
                  leading: Image.network(
                    plant['images'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text(plant['name']),
                  subtitle: Text(plant['description']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlantDetailScreen(plant: plant),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}