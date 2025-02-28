import 'package:flutter/material.dart'; //flutterのインターフェース
import 'package:firebase_core/firebase_core.dart'; //firebaseの初期化
import 'package:cloud_firestore/cloud_firestore.dart'; //firestoreの操作
import 'package:firebase_storage/firebase_storage.dart'; //firebase storageの連携
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authenticationをインポート
import 'package:flutter_application_2024/add.dart';
import 'package:flutter_application_2024/login.dart';
import 'package:flutter_application_2024/setting.dart';
import 'package:flutter_application_2024/info.dart';
import 'package:flutter_application_2024/detail.dart';
import 'package:flutter_application_2024/favorite.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();

    // App Checkの初期化
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.appAttest,
    );
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  static String userName = "ゲスト"; // ユーザー名を保持する変数

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _themeColor = Colors.lightBlueAccent;
  int _crossAxisCount = 2;
  User? _user; // ユーザー情報を保持する変数

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser; // 現在のユーザーを取得
    if (_user != null) {
      MyApp.userName = _user!.displayName ?? "ゲスト";
    }
  }

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
              initialColor: _themeColor,
              initialCrossAxisCount: _crossAxisCount,
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
  User? _user; // ユーザー情報を保持する変数

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser; // 現在のユーザーを取得
    loadPlantData();
    searchController.addListener(() {
      _filterPlants(searchController.text);
    });
  }

  void _navigateAddPlant() async {
    final needsReload = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlantScreen()),
    );

    if (needsReload == true) {
      // データを再読み込み
      await loadPlantData();
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

  Future<void> loadPlantData() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      List<Map<String, dynamic>> tempPlants = [];

      // ログイン中のユーザーのUIDを取得
      String currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          "5g7CsADD5qVb4TRgHTPbiN6AXmM2";

      // Firestoreからログイン中のユーザーのデータのみを取得
      QuerySnapshot querySnapshot = await firestore
          .collection('plants')
          .where('userId', isEqualTo: currentUserId) // userIdフィールドでフィルタリング
          .get();

      print('Total plants fetched: ${querySnapshot.docs.length}');

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> plantData = doc.data() as Map<String, dynamic>;
        plantData['id'] = doc.id;

        try {
          if (plantData['images'] != null) {
            String imageUrl = await FirebaseStorage.instance
                .ref(plantData['images'])
                .getDownloadURL();
            plantData['images'] = imageUrl;
          }
          tempPlants.add(plantData);
        } catch (e) {
          print(
              'Error getting image URL for ${plantData['name'] ?? 'Unknown'}: $e');
          plantData['images'] = 'https://placehold.jp/300x300.png';
          tempPlants.add(plantData);
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
  final menuList1 = ['名前', 'ログアウト'];

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
                  size: 100, 
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
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 177, 173, 173)),
                    ),
                  )
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
                          onTap: () async {
                            final needsReload = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PlantDetailScreen(plant: plant),
                              ),
                            );

                            if (needsReload == true) {
                              await loadPlantData();
                            }
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        plant['images'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(Icons.error);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 0.0,
                                      bottom: 8.0,
                                      left: 8.0,
                                      right: 8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        plant['name'],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: widget.crossAxisCount == 3
                                              ? 12
                                              : 17, 
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.only(top: 8.0),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'ホーム',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'お気に入り',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: '設定',
            ),
          ],
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/home');
            } else if (index == 1) {
              Navigator.pushNamed(context, '/favorite');
            } else if (index == 2) {
              Navigator.pushNamed(context, '/setting');
            }
          },
        ),
      ),
    );
  }

  Widget listTile(String title) {
    return InkWell(
      onTap: () async {
        if (title == 'ホーム') {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (title == 'お気に入り') {
          Navigator.pushNamed(context, '/favorite');
        } else if (title == '設定') {
          Navigator.pushNamed(context, '/setting');
        } else if (title == 'ログアウト') {
          try {
            await FirebaseAuth.instance.signOut();
            MyApp.userName = "ゲスト";
            Navigator.pushReplacementNamed(context, '/login');
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ログアウトに失敗しました: $e')),
            );
          }
        }
      },
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title == '名前'
                      ? '${title} ${MyApp.userName == "5g7CsADD5qVb4TRgHTPbiN6AXmM2" ? "ゲスト" : MyApp.userName}' // UIDが一致する場合は"ゲスト"と表示
                      : title,
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
