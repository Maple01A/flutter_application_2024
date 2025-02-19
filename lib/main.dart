import 'package:flutter/material.dart'; //flutterのインターフェース
import 'package:firebase_core/firebase_core.dart'; //firebaseの初期化
import 'package:cloud_firestore/cloud_firestore.dart'; //firestoreの操作
import 'package:firebase_storage/firebase_storage.dart'; //firebase storageの連携
//import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
//import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter_application_2024/add.dart'; 
import 'package:flutter_application_2024/login.dart';
import 'package:flutter_application_2024/setting.dart';
import 'package:flutter_application_2024/info.dart';
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
  Color _themeColor = Colors.greenAccent;

  void _changeThemeColor(Color color) {
    setState(() {
      _themeColor = color;
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
        '/home': (context) => PlantListScreen(),
        '/setting': (context) => Setting(onThemeColorChanged: _changeThemeColor),
        '/info': (context) => Info(),
      },
    );
  }
}

class PlantListScreen extends StatefulWidget {
  @override
  _PlantListScreenState createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  List plants = [];

  void _navigateAddPlant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlantScreen()),
    );

    if (result != null) {
      setState(() {
        plants.add(result);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadPlantData();
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
      });
    } catch (e) {
      print("エラーが発生しました: $e");
      if (e is FirebaseException) {
        print("エラーのコード: ${e.code}");
        print("エラーのメッセージ: ${e.message}");
      }
    }
  }

  Future<void> _deletePlant(String id, int index) async {
    try {
      // Firestoreからデータを削除
      await FirebaseFirestore.instance.collection('plants').doc(id).delete();

      // ローカルのリストからも削除
      setState(() {
        plants.removeAt(index);
      });
    } catch (e) {
      print('Error deleting plant: $e');
    }
  }

  final menuList = ['ホーム', '設定', 'お問い合わせ'];
  final menuList1 = ['名前', 'レベル', 'お気に入り'];

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
          Expanded(
            child: plants.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    itemCount: plants.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    itemBuilder: (context, index) {
                      final plant = plants[index];
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
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.network(
                                      plant['images'],
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Text(
                                    plant['name'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    _deletePlant(plant['id'], index);
                                  },
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
      bottomNavigationBar: BottomNavigationBar(
        items: menuList.map((title) {
          return BottomNavigationBarItem(
            icon: Icon(Icons.circle),
            label: title,
          );
        }).toList(),
        onTap: (index) {
          if (menuList[index] == 'ホーム') {
            Navigator.pushNamed(context, '/login');
          } else if (menuList[index] == '設定') {
            Navigator.pushNamed(context, '/setting');
          } else if (menuList[index] == 'お問い合わせ') {
            Navigator.pushNamed(context, '/info');
          }
        },
      ),
    );
  }

  Widget listTile(String title) {
    return InkWell(  
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

class PlantDetailScreen extends StatelessWidget {
  final Map plant;

  PlantDetailScreen({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plant['name']),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.network(
                plant['images'],
                height: MediaQuery.of(context).size.height * 0.4,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 30),
              Text(
                plant['description'],
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
