import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2024/add.dart';
import 'package:flutter_application_2024/login.dart';
import 'package:flutter_application_2024/setting.dart';
import 'package:flutter_application_2024/info.dart';
import 'package:flutter_application_2024/detail.dart';
import 'package:flutter_application_2024/favorite.dart';
import 'package:flutter_application_2024/signup.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/intl.dart' as intl; 
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
        '/signup': (context) => SignUpScreen(),  // サインアップ画面を追加
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
  static const double _cardBorderRadius = 15.0;
  static const double _cardPadding = 8.0;
  
  List plants = [];
  List favoritePlants = [];
  List filteredPlants = [];
  TextEditingController searchController = TextEditingController();
  User? _user;
  String _sortBy = 'name';
  bool _isInitialized = false; // データ初期化フラグ

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    
    // データロードを非同期で開始し、初期化状態を更新
    _initializeData();
    
    searchController.addListener(() {
      _filterPlants(searchController.text);
    });
  }

  // データ初期化を別メソッドに分離して可読性を向上
  Future<void> _initializeData() async {
    if (!_isInitialized) {
      await loadPlantData();
      setState(() {
        _isInitialized = true;
      });
    }
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

  // ソート関数を改良
  void _sortPlants() {
    setState(() {
      if (_sortBy == 'name') {
        filteredPlants.sort((a, b) {
          String nameA = a['name'] as String;
          String nameB = b['name'] as String;
          // 日本語対応の比較（ひらがな・カタカナも正しく扱う）
          return _compareJapanese(nameA, nameB);
        });
      } else if (_sortBy == 'date') {
        filteredPlants.sort((a, b) {
          DateTime dateA = _parseDate(a['date'] as String);
          DateTime dateB = _parseDate(b['date'] as String);
          return dateB.compareTo(dateA); // 新しい順
        });
      }
    });
  }

  // 日本語の文字列比較（ひらがな・カタカナの正確な並べ替え）
  int _compareJapanese(String a, String b) {
    // カタカナをひらがなに変換
    String normalizedA = _normalizeJapanese(a);
    String normalizedB = _normalizeJapanese(b);
    
    // ロケールを使ってソート
    return normalizedA.compareTo(normalizedB);
  }

  // カタカナをひらがなに変換するマップ
  final Map<String, String> kanaMap = {
    'ァ': 'ぁ', 'ア': 'あ', 'ィ': 'ぃ', 'イ': 'い', 'ゥ': 'ぅ', 'ウ': 'う', 'ェ': 'ぇ', 'エ': 'え', 'ォ': 'ぉ', 'オ': 'お',
    'カ': 'か', 'ガ': 'が', 'キ': 'き', 'ギ': 'ぎ', 'ク': 'く', 'グ': 'ぐ', 'ケ': 'け', 'ゲ': 'げ', 'コ': 'こ', 'ゴ': 'ご',
    'サ': 'さ', 'ザ': 'ざ', 'シ': 'し', 'ジ': 'じ', 'ス': 'す', 'ズ': 'ず', 'セ': 'せ', 'ゼ': 'ぜ', 'ソ': 'そ', 'ゾ': 'ぞ',
    'タ': 'た', 'ダ': 'だ', 'チ': 'ち', 'ヂ': 'ぢ', 'ッ': 'っ', 'ツ': 'つ', 'ヅ': 'づ', 'テ': 'て', 'デ': 'で', 'ト': 'と', 'ド': 'ど',
    'ナ': 'な', 'ニ': 'に', 'ヌ': 'ぬ', 'ネ': 'ね', 'ノ': 'の',
    'ハ': 'は', 'バ': 'ば', 'パ': 'ぱ', 'ヒ': 'ひ', 'ビ': 'び', 'ピ': 'ぴ', 'フ': 'ふ', 'ブ': 'ぶ', 'プ': 'ぷ', 'ヘ': 'へ', 'ベ': 'べ', 'ペ': 'ぺ', 'ホ': 'ほ', 'ボ': 'ぼ', 'ポ': 'ぽ',
    'マ': 'ま', 'ミ': 'み', 'ム': 'む', 'メ': 'め', 'モ': 'も',
    'ャ': 'ゃ', 'ヤ': 'や', 'ュ': 'ゅ', 'ユ': 'ゆ', 'ョ': 'ょ', 'ヨ': 'よ',
    'ラ': 'ら', 'リ': 'り', 'ル': 'る', 'レ': 'れ', 'ロ': 'ろ',
    'ヮ': 'ゎ', 'ワ': 'わ', 'ヰ': 'ゐ', 'ヱ': 'ゑ', 'ヲ': 'を', 'ン': 'ん',
    'ヴ': 'ゔ', 'ヵ': 'か', 'ヶ': 'け'
  };

  // 日本語の文字列を正規化（カタカナをひらがなに変換）
  String _normalizeJapanese(String text) {
    final normalizedText = text.replaceAllMapped(
      RegExp(r'[ァ-ヶ]'),
      (Match m) => kanaMap[m.group(0)] ?? m.group(0)!
    );
    return normalizedText.toLowerCase();
  }

  // 日付文字列をDateTime型に変換
  DateTime _parseDate(String dateStr) {
    try {
      // "2024年3月15日" 形式の文字列をパース
      List<String> parts = dateStr
          .replaceAll('年', '-')
          .replaceAll('月', '-')
          .replaceAll('日', '')
          .split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return DateTime(1900); // エラー時はデフォルト値
    }
  }

  // 検索関数
  void _filterPlants(String query) {
    setState(() {
      filteredPlants = plants.where((plant) {
        final plantName = plant['name'].toLowerCase();
        final searchQuery = query.toLowerCase();
        return plantName.contains(searchQuery);
      }).toList();
      _sortPlants(); // 検索後にソート
    });
  }

  Future<void> loadPlantData() async {
    try {
      setState(() {
        plants = [];
        filteredPlants = [];
      });

      List<Map<String, dynamic>> mergedPlants = [];
      
      // 1. ローカルからデータをロード
      await _loadLocalPlants(mergedPlants);
      
      // 2. Firebase からデータをロード（可能であれば）
      await _loadFirebasePlants(mergedPlants);
      
      // 3. ローカルにデータを保存（キャッシュ）
      await _saveLocalPlants(mergedPlants);
      
      setState(() {
        plants = mergedPlants;
        filteredPlants = mergedPlants;
        _sortPlants();
      });
    } catch (e) {
      print("データ読み込み中にエラーが発生しました: $e");
      // エラーをUI上で表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました。再試行してください。')),
        );
      }
    }
  }

  // ローカルからデータを読み込む
  Future<void> _loadLocalPlants(List<Map<String, dynamic>> targetList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plantsJson = prefs.getString('plants_cache');
      
      if (plantsJson != null) {
        List<dynamic> loadedPlants = jsonDecode(plantsJson);
        for (var plant in loadedPlants) {
          // すでに同じIDのデータがなければ追加
          if (!targetList.any((p) => p['id'] == plant['id'])) {
            targetList.add(Map<String, dynamic>.from(plant));
          }
        }
        print('ローカルから ${loadedPlants.length} 件のデータを読み込みました');
      }
    } catch (e) {
      print("ローカルデータ読み込みエラー: $e");
    }
  }

  // Firebaseからデータを読み込む
  Future<void> _loadFirebasePlants(List<Map<String, dynamic>> targetList) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // ログイン中のユーザーのUIDを取得
      String currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          "5g7CsADD5qVb4TRgHTPbiN6AXmM2";

      // Firestoreからログイン中のユーザーのデータのみを取得
      QuerySnapshot querySnapshot = await firestore
          .collection('plants')
          .where('userId', isEqualTo: currentUserId)
          .get();

      print('Firebase から ${querySnapshot.docs.length} 件のデータを取得しました');

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> plantData = doc.data() as Map<String, dynamic>;
        plantData['id'] = doc.id;
        
        try {
          // 画像URLを取得
          if (plantData['images'] != null) {
            try {
              String imageUrl = await FirebaseStorage.instance
                  .ref(plantData['images'])
                  .getDownloadURL();
              plantData['images'] = imageUrl;
              // オプション：画像をローカルにキャッシュする処理を追加可
            } catch (e) {
              print('画像URL取得エラー ${plantData['name'] ?? 'Unknown'}: $e');
              plantData['images'] = 'https://placehold.jp/300x300.png';
            }
          }
          
          // 既存のデータを更新または新しいデータを追加
          int existingIndex = targetList.indexWhere((p) => p['id'] == plantData['id']);
          if (existingIndex >= 0) {
            // 既存データを更新
            targetList[existingIndex] = plantData;
          } else {
            // 新しいデータを追加
            targetList.add(plantData);
          }
        } catch (e) {
          print('植物データ処理エラー: $e');
        }
      }
    } catch (e) {
      print("Firebase読み込みエラー: $e");
      // エラー時はローカルデータだけで続行
    }
  }

  // 読み込んだデータをローカルに保存（キャッシュ）
  Future<void> _saveLocalPlants(List<Map<String, dynamic>> plantsList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plants_cache', jsonEncode(plantsList));
      print('${plantsList.length} 件のデータをローカルに保存しました');
    } catch (e) {
      print("ローカル保存エラー: $e");
    }
  }

  final menuList = ['ホーム', 'お気に入り', '設定'];
  final menuList1 = ['名前', 'ログアウト'];

  // BottomNavigationBarのタップ処理を最適化
  void _handleNavigationTap(int index) async {
    if (index == 0) {
      // ホームの場合は現在のデータを保持
      return;
    } else if (index == 1) {
      // お気に入り画面に遷移（データを保持）
      await Navigator.pushNamed(
        context, 
        '/favorite',
      );
    } else if (index == 2) {
      // 設定画面に遷移（データを保持）
      await Navigator.pushNamed(
        context, 
        '/setting',
      );
    }
  }

  // Drawerのナビゲーション処理を最適化
  Future<void> _handleDrawerNavigation(String title) async {
    if (title == 'ホーム') {
      Navigator.pop(context); // Drawerを閉じる
    } else if (title == 'お気に入り') {
      Navigator.pop(context); // Drawerを閉じる
      await Navigator.pushNamed(context, '/favorite');
    } else if (title == '設定') {
      Navigator.pop(context); // Drawerを閉じる
      await Navigator.pushNamed(context, '/setting');
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('草花の図鑑'),
        actions: [
          // ソートメニューを追加
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (String value) {
              setState(() {
                _sortBy = value;
                _sortPlants();
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      color: _sortBy == 'name' ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '名前順',
                      style: TextStyle(
                        color: _sortBy == 'name' ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: _sortBy == 'name' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _sortBy == 'date' ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '日付順',
                      style: TextStyle(
                        color: _sortBy == 'date' ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: _sortBy == 'date' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                : _buildGridView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateAddPlant,
        icon: Icon(Icons.add),
        label: Text('追加'),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: BottomNavigationBar(
          items: const [
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
          onTap: _handleNavigationTap,
        ),
      ),
    );
  }

  Widget listTile(String title) {
    return InkWell(
      onTap: () => _handleDrawerNavigation(title),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title == '名前'
                      ? '${title} ${MyApp.userName == "5g7CsADD5qVb4TRgHTPbiN6AXmM2" ? "ゲスト" : MyApp.userName}'
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

  Widget _buildPlantCard(Map plant) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_cardBorderRadius),
                child: Image.network(
                  plant['images'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error);
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: _cardPadding,
              left: _cardPadding,
              right: _cardPadding,
            ),
            child: Text(
              plant['name'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.crossAxisCount == 3 ? 12 : 17,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // GridViewのビルダーを分離
  Widget _buildGridView() {
    return GridView.builder(
      itemCount: filteredPlants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.crossAxisCount == 1 ? 2 : 1,
      ),
      itemBuilder: (context, index) {
        final plant = filteredPlants[index];
        return Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: GestureDetector(
            onTap: () => _navigateToDetail(plant),
            child: _buildPlantCard(plant),
          ),
        );
      },
    );
  }

  Future<void> _navigateToDetail(Map plant) async {
    final needsReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(plant: plant),
      ),
    );
    
    // 詳細画面で削除が行われた場合のみ再読み込み
    if (needsReload == true) {
      await loadPlantData();
    }
  }
}
