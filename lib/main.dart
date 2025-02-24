import 'package:flutter/material.dart'; //flutterのインターフェース
import 'package:firebase_core/firebase_core.dart'; //firebaseの初期化
import 'package:cloud_firestore/cloud_firestore.dart'; //firestoreの操作
import 'package:firebase_storage/firebase_storage.dart'; //firebase storageの連携
import 'package:flutter_application_2024/add.dart';
import 'package:flutter_application_2024/login.dart';
import 'package:flutter_application_2024/setting.dart';
import 'package:flutter_application_2024/info.dart';
import 'package:flutter_application_2024/detail.dart';
import 'package:flutter_application_2024/favorite.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _themeColor = Colors.lightBlueAccent;
  int _crossAxisCount = 2;

  void _changeThemeColor(Color color) {
    setState(() {
      _themeColor = color;
    });
  }

  void _changeCrossAxisCount(int count) {
    setState(() {
      _crossAxisCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '草花の図鑑',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login', // ログイン画面を最初に表示
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => PlantListScreen(crossAxisCount: _crossAxisCount),
        '/setting': (context) => Setting(
          onThemeColorChanged: _changeThemeColor,
          onCrossAxisCountChanged: _changeCrossAxisCount,
        ),
        '/info': (context) => Info(),
        '/favorite': (context) => FavoriteScreen(),
        'logout': (context) => LoginScreen(),
      },
    );
  }
}

class PlantListScreen extends StatefulWidget {
  final int crossAxisCount;

  PlantListScreen({required this.crossAxisCount});

  @override
  _PlantListScreenState createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  List plants = [];
  List favoritePlants = []; // お気に入りリスト
  List filteredPlants = []; // 検索結果リスト
  TextEditingController searchController = TextEditingController();

  void _navigateAddPlant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlantScreen()),
    );

    if (result != null) {
      setState(() {
        plants.add(result);
        filteredPlants = plants;
      });
    }
  }

  void _toggleFavorite(Map plant) {
    setState(() {
      if (favoritePlants.contains(plant)) {
        favoritePlants.remove(plant);
      } else {
        favoritePlants.add(plant);
      }
    });
  }

  void _filterPlants(String query) {
    setState(() {
      filteredPlants = plants.where((plant) {
        final plantName = plant['name'].toLowerCase();
        final searchQuery = query.toLowerCase();
        return plantName.contains(searchQuery);
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    loadPlantData();
    searchController.addListener(() {
      _filterPlants(searchController.text);
    });
  }

  Future<void> loadPlantData() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, dynamic>> tempPlants = [];

      // Firestoreからデータを取得
      QuerySnapshot querySnapshot = await firestore.collection('plants').get();
      print('Total plants fetched: ${querySnapshot.docs.length}');

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> plantData = doc.data() as Map<String, dynamic>;
        plantData['id'] = doc.id; // ドキュメントIDを追加
        print('Plant Data: $plantData'); // デバッグ出力

        try {
          // Firebase Storageから画像URLを取得
          String imageUrl = await FirebaseStorage.instance
              .ref(plantData['images'])
              .getDownloadURL();
          plantData['images'] = imageUrl;
          tempPlants.add(plantData);
        } catch (e) {
          print(
              'Error getting image URL for ${plantData['name'] ?? 'Unknown'}: $e');
        }
      }

      setState(() {
        plants = tempPlants;
        filteredPlants = plants;
      });
    } catch (e) {
      print("エラーが発生しました: $e");
      if (e is FirebaseException) {
        print("エラーのコード: ${e.code}");
        print("エラーのメッセージ: ${e.message}");
      }
    }
  }

  final menuList = ['ホーム', 'お気に入り', '設定'];
  final menuList1 = ['名前', 'お問い合わせ', 'ログアウト'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('草花の図鑑'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Center(
                child: FlutterLogo(
                  size: 100, // アイコンのサイズを指定
                ),
              ),
            ),
            ...menuList1.map((e) => listTile(e)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: '名前で検索',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: filteredPlants.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    itemCount: filteredPlants.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.crossAxisCount,
                      childAspectRatio: widget.crossAxisCount == 1 ? 2 : 1,
                    ),
                    itemBuilder: (context, index) {
                      final plant = filteredPlants[index];
                      final isFavorite = favoritePlants.contains(plant);
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlantDetailScreen(plant: plant),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Flexible( // 追加
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        plant['images'],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        plant['name'],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateAddPlant,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(top:8.0), 
        child: BottomNavigationBar(
          items: menuList.map((title) {
            return BottomNavigationBarItem(
              icon: Icon(Icons.circle),
              label: title,
            );
          }).toList(),
          onTap: (index) {
            if (menuList[index] == 'ホーム') {
              Navigator.pushReplacementNamed(context, '/home'); 
            } else if (menuList[index] == 'お気に入り') {
              Navigator.pushNamed(context, '/favorite'); 
            } else if (menuList[index] == '設定') {
              Navigator.pushNamed(context, '/setting'); 
            }
          },
        ),
      ),
    );
  }

  Widget listTile(String title) {
    return InkWell(
      onTap: () {
        if (title == 'ホーム') {
          Navigator.pushNamed(context, '/main');
        } else if (title == 'お気に入り') {
          Navigator.pushNamed(context, '/favorite');
        } else if (title == '設定') {
          Navigator.pushNamed(context, '/setting');
        } else if (title == 'お問い合わせ') {
          Navigator.pushNamed(context, '/info');
        }
          else if (title == 'ログアウト') {
          Navigator.pushNamed(context, '/login');
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}