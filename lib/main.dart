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
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'explore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebaseの初期化
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();

    // App Checkの初期化
    await FirebaseAppCheck.instance.activate(
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
  User? _user; 
  int _currentPageIndex = 0; // 現在のページインデックス

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
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

  // 現在のページインデックスを設定
  void _setCurrentPageIndex(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  // 現在のユーザー情報を確認
  Future<void> _checkCurrentUser() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      try {
        // Firestoreからユーザー名を取得
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['name'] != null) {
          setState(() {
            MyApp.userName = userDoc.data()?['name'];
          });
          print('Firestoreから取得したユーザー名: ${MyApp.userName}');
        } else if (_user!.displayName != null &&
            _user!.displayName!.isNotEmpty) {
          // Firestoreに情報がなければAuth情報のdisplayNameを使用
          setState(() {
            MyApp.userName = _user!.displayName!;
          });
          // ついでにFirestoreにも保存
          await _saveUserNameToFirestore(_user!.uid, _user!.displayName!);
          print('Auth情報から取得したユーザー名: ${MyApp.userName}');
        } else if (_user!.email != null) {
          // displayNameもなければメールアドレスから名前を推測
          setState(() {
            MyApp.userName = _user!.email!.split('@')[0];
          });
          // ついでにFirestoreにも保存
          await _saveUserNameToFirestore(
              _user!.uid, _user!.email!.split('@')[0]);
          print('メールアドレスから推測したユーザー名: ${MyApp.userName}');
        } else if (_user!.isAnonymous) {
          // 匿名ユーザーの場合
          setState(() {
            MyApp.userName = "ゲストユーザー";
          });
          await _saveUserNameToFirestore(_user!.uid, "ゲストユーザー");
          print('匿名ユーザー: ${MyApp.userName}');
        } else {
          // いずれも取得できなかった場合はデフォルト値
          setState(() {
            MyApp.userName = "ユーザー";
          });
          print('ユーザー名を特定できませんでした: ${MyApp.userName}');
        }
      } catch (e) {
        // エラー発生時はデフォルト値を使用
        setState(() {
          MyApp.userName = _user!.email?.split('@')[0] ?? "ユーザー";
        });
        print('ユーザー情報取得エラー: $e');
      }
      print('現在のユーザー: ${MyApp.userName} (ID: ${_user!.uid})');
    } else {
      setState(() {
        MyApp.userName = "ゲスト";
      });
      print('ユーザーはログインしていません');
    }
  }

  // ユーザー名をFirestoreに保存する補助メソッド
  Future<void> _saveUserNameToFirestore(String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('ユーザー名をFirestoreに保存しました: $name');
    } catch (e) {
      print('ユーザー名の保存に失敗しました: $e');
    }
  }

  // ログアウト機能を強化
  Future<void> _logout() async {
    try {
      // Firebaseからログアウト
      await FirebaseAuth.instance.signOut();
      
      // 保存された認証情報をすべて削除
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.setBool('google_login', false);
      await prefs.setBool('anonymous_login', false);
      
      // キャッシュもクリア
      await prefs.remove('cachedUserName');
      
      // アプリのユーザー名をリセット
      setState(() {
        MyApp.userName = "ゲスト";
      });
      
      // ログイン画面へ戻る (すべてのルートをクリア)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print('ログアウトエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ログアウトに失敗しました。もう一度お試しください。'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => MainNavigator(
              initialIndex: _currentPageIndex,
              themeColor: _themeColor,
              crossAxisCount: _crossAxisCount,
              onThemeColorChanged: _changeThemeColor,
              onCrossAxisCountChanged: _changeCrossAxisCount,
            ),
        // お気に入りと設定のルートを追加
        '/favorite': (context) => FavoriteScreen(),
        '/setting': (context) => Setting(
              onThemeColorChanged: _changeThemeColor,
              onCrossAxisCountChanged: _changeCrossAxisCount,
              initialColor: _themeColor,
              initialCrossAxisCount: _crossAxisCount,
            ),
        '/info': (context) => Info(),
        '/logout': (context) => LoginScreen(), // スラッシュを追加
      },
    );
  }
}

// 共通のナビゲーション管理クラス
class MainNavigator extends StatefulWidget {
  final int initialIndex;
  final Color themeColor;
  final int crossAxisCount;
  final Function(Color) onThemeColorChanged;
  final Function(int) onCrossAxisCountChanged;

  MainNavigator({
    this.initialIndex = 0,
    required this.themeColor,
    required this.crossAxisCount,
    required this.onThemeColorChanged,
    required this.onCrossAxisCountChanged,
  });

  @override
  _MainNavigatorState createState() => _MainNavigatorState();
}

// _MainNavigatorState クラスを修正
class _MainNavigatorState extends State<MainNavigator> {
  late int _selectedIndex;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initPages();
  }

  void _initPages() {
    _pages = [
      PlantListScreen(
        crossAxisCount: widget.crossAxisCount,
      ),
      FavoriteScreen(),
      Setting(
        onThemeColorChanged: widget.onThemeColorChanged,
        onCrossAxisCountChanged: widget.onCrossAxisCountChanged,
        initialColor: widget.themeColor,
        initialCrossAxisCount: widget.crossAxisCount,
      ),
    ];
  }

  // ナビゲーションアイテムをタップした際の処理を正しく設定
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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
        currentIndex: _selectedIndex,
        selectedItemColor: widget.themeColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

class PlantListScreen extends StatefulWidget {
  final int crossAxisCount;

  PlantListScreen({required this.crossAxisCount});

  @override
  _PlantListScreenState createState() => _PlantListScreenState();
}

// プラントリスト画面に画像キャッシュを追加
class _PlantListScreenState extends State<PlantListScreen> {
  // 画像URLキャッシュを追加（IDをキーとしてURLを保存）
  final Map<String, String> _imageUrlCache = {};

  // 当日のイベントキャッシュ (plantId -> イベントあり)
  final Map<String, bool> _todayEventCache = {};

  // 既存の変数はそのまま
  static const double _cardBorderRadius = 15.0;
  List<Map<String, dynamic>> plants = [];
  List<Map<String, dynamic>> filteredPlants = [];
  TextEditingController searchController = TextEditingController();
  String _sortBy = 'name';
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _forceReload = false; // 強制再読み込みフラグ

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      _filterPlants(searchController.text);
    });

    // ウィジェットがビルド完了後にデータロードを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
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
      // 新規追加時は強制再読み込み
      _forceReload = true;
      await loadPlantData();
    }
  }

  void _sortPlants() {
    setState(() {
      if (_sortBy == 'name') {
        filteredPlants.sort((a, b) {
          String nameA = a['name'] as String;
          String nameB = b['name'] as String;
          // 日本語対応の比較（ひらがな・カタカナも正しく扱う）
          return TextUtils.compareJapanese(nameA, nameB);
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
      _sortPlants();
    });
  }

  // loadPlantData 関数を最適化します
  Future<void> loadPlantData() async {
    if (_isLoading) return; // 既にロード中なら処理しない

    setState(() {
      _isLoading = true;
      plants = [];
      filteredPlants = [];
      _todayEventCache.clear(); // キャッシュをクリア
    });

    try {
      // 直接Firebaseから植物データを読み込む
      await _loadFirebasePlants();

      // イベント情報を一括で事前取得
      if (plants.isNotEmpty) {
        List<String> plantIds = plants.map((p) => p['id'].toString()).toList();
        await _prefetchTodayEvents(plantIds);
      }

      // 並び替えを適用
      _sortPlants();
    } catch (e) {
      print("データ読み込み中にエラーが発生しました: $e");
      // エラーをUI上で表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました。再試行してください。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Firebaseからデータを読み込む関数を修正
  Future<void> _loadFirebasePlants() async {
    // ユーザーチェック
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('認証されていません');
      if (mounted) {
        Future.microtask(() {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ログインが必要です')),
          );
        });
      }
      return;
    }

    try {
      // データ取得
      final querySnapshot = await FirebaseFirestore.instance
          .collection('plants')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // 一時データリスト
      List<Map<String, dynamic>> loadedPlants = [];

      // 結果処理
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> plantData = doc.data() as Map<String, dynamic>;
        plantData['id'] = doc.id;

        // 画像URLの処理を最適化
        await _processPlantImage(plantData, doc.id);

        // データを追加
        loadedPlants.add(plantData);
      }

      // 結果をステートに設定
      setState(() {
        plants = loadedPlants;
        filteredPlants = loadedPlants;
      });

      // 強制再読み込みフラグをリセット
      _forceReload = false;
    } catch (e) {
      print("Firebase読み込みエラー: $e");
      throw e; // 上位関数でハンドリングするために再スロー
    }
  }

  // 画像処理だけを行う関数に分離して可読性向上
  Future<void> _processPlantImage(
      Map<String, dynamic> plantData, String docId) async {
    if (plantData['images'] != null) {
      final imagePath = plantData['images'].toString();

      // 1. キャッシュ内に画像URLがあるか確認
      if (_imageUrlCache.containsKey(docId) && !_forceReload) {
        plantData['images'] = _imageUrlCache[docId];
        print('キャッシュから画像URLを使用: ${plantData['name']}');
      }
      // 2. 既にHTTPで始まるURLかチェック
      else if (imagePath.startsWith('http')) {
        // キャッシュに保存
        _imageUrlCache[docId] = imagePath;
      }
      // 3. Firebaseパスの場合のみ、URLに変換
      else {
        try {
          final downloadUrl =
              await FirebaseStorage.instance.ref(imagePath).getDownloadURL();

          plantData['images'] = downloadUrl;
          // キャッシュに保存
          _imageUrlCache[docId] = downloadUrl;
          print('新しい画像URLを取得: ${plantData['name']}');
        } catch (e) {
          print('画像URL取得エラー: $e');
          plantData['images'] = 'https://via.placeholder.com/150?text=No+Image';
          // エラー時もキャッシュに保存（再リクエスト防止）
          _imageUrlCache[docId] =
              'https://via.placeholder.com/150?text=No+Image';
        }
      }
    }
  }

  // 一括でイベント情報を事前に取得するメソッド
  Future<void> _prefetchTodayEvents(List<String> plantIds) async {
    if (plantIds.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 今日の日付範囲
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // plantIdsが10個以上の場合、バッチ処理が必要
      // Firestoreの'whereIn'は一度に最大10個までの値しかサポートしていないため
      List<List<String>> batches = [];
      for (int i = 0; i < plantIds.length; i += 10) {
        final end = (i + 10 < plantIds.length) ? i + 10 : plantIds.length;
        batches.add(plantIds.sublist(i, end));
      }

      // 各バッチを処理
      for (var batchIds in batches) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plantEvents')
            .where('plantId', whereIn: batchIds)
            .where('eventDate', isGreaterThanOrEqualTo: startOfDay)
            .where('eventDate', isLessThanOrEqualTo: endOfDay)
            .get();

        // 結果をキャッシュに格納
        for (var doc in querySnapshot.docs) {
          String plantId = doc.data()['plantId'];
          _todayEventCache[plantId] = true;
        }
      }

      print('今日のイベント情報を${_todayEventCache.length}件キャッシュしました');
    } catch (e) {
      print('イベント一括取得エラー: $e');
    }
  }

  final menuList = ['ホーム', 'お気に入り', '設定'];

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

  Future<void> _handleDrawerNavigation(String title) async {
    if (title == 'ホーム') {
      Navigator.pop(context);
    } else if (title == 'お気に入り') {
      Navigator.pop(context);
      await Navigator.pushNamed(context, '/favorite');
    } else if (title == '設定') {
      Navigator.pop(context);
      await Navigator.pushNamed(context, '/setting');
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
                      color: _sortBy == 'name'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '名前順',
                      style: TextStyle(
                        color: _sortBy == 'name'
                            ? Theme.of(context).colorScheme.primary
                            : null,
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
                      color: _sortBy == 'date'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '日付順',
                      style: TextStyle(
                        color: _sortBy == 'date'
                            ? Theme.of(context).colorScheme.primary
                            : null,
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
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Text(
                      _getUserInitial(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _isAnonymousUser() ? "ゲストユーザー" : MyApp.userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isAnonymousUser()
                        ? "ログインしてデータを保存"
                        : FirebaseAuth.instance.currentUser?.email ?? "",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // メニューアイテム
            ListTile(
              leading: Icon(Icons.home),
              title: Text('ホーム'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.favorite),
              title: Text('お気に入り'),
              onTap: () {
                Navigator.pop(context); // ドロワーを閉じる
                Navigator.pushNamed(context, '/favorite'); // 正しいルートで遷移
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('設定'),
              onTap: () {
                Navigator.pop(context); // ドロワーを閉じる
                Navigator.pushNamed(context, '/setting'); // 正しいルートで遷移
              },
            ),

            ListTile(
              leading: Icon(Icons.help),
              title: Text('お問い合わせ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/info');
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('ログアウト', style: TextStyle(color: Colors.red)),
              onTap: () => _confirmLogout(context),
            ),
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
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredPlants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.eco_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'データがありません',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '追加ボタンから植物を登録してください',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: _buildGridView(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateAddPlant,
        icon: Icon(Icons.add),
        label: Text('追加'),
      ),
    );
  }

  // リフレッシュ処理を修正
  Future<void> _handleRefresh() async {
    // 強制再読み込みフラグを設定
    _forceReload = true;
    await loadPlantData();
    return Future.value();
  }

  Widget listTile(String title) {
    return InkWell(
      onTap: () => _handleDrawerNavigation(title),
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
                      ? '${title} ${_isAnonymousUser() ? "ゲストユーザー" : MyApp.userName}'
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

  // 匿名ユーザーかどうかを判定するヘルパーメソッド
  bool _isAnonymousUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  // ユーザーのイニシャルを取得するヘルパーメソッド
  String _getUserInitial() {
    if (_isAnonymousUser()) return "G";

    if (MyApp.userName.isNotEmpty) {
      return MyApp.userName[0].toUpperCase();
    }
    return "U";
  }

  // ログアウト確認ダイアログ
  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ログアウト確認'),
        content: Text('本当にログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('ログアウト', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // ローディング表示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Firebase認証からログアウト
        await FirebaseAuth.instance.signOut();
        
        // SharedPreferencesの認証情報をクリア
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_email');
        await prefs.remove('user_password');
        await prefs.setBool('google_login', false);
        await prefs.setBool('anonymous_login', false);
        
        // アプリのユーザー名をリセット
        MyApp.userName = "ゲスト";
        
        // ローディングを閉じる
        Navigator.of(context).pop();
        
        // 確実にログイン画面に戻る
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        // エラー発生時
        print('ログアウトエラー: $e');
        
        // ローディングが表示されていれば閉じる
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        // エラーメッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログアウト中にエラーが発生しました。もう一度お試しください。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPlantCard(Map plant) {
    // キャッシュから取得（個別クエリを発行せず）
    bool hasTodayEvent = _todayEventCache[plant['id']] ?? false;

    // カードの中身を構築
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius),
      ),
      elevation: 4,
      margin: EdgeInsets.zero, // 外部でPaddingを適用するのでここはゼロに
      child: Stack(
        children: [
          // メインコンテンツ
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 画像部分（高さを固定）
              Expanded(
                flex: 3, // 画像部分のフレックス比率を調整
                child: Container(
                  padding: EdgeInsets.all(8.0), // 写真の周りにフリースペースを追加
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: plant['images'] != null
                        ? CachedNetworkImage(
                            imageUrl: plant['images'].toString(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                            errorWidget: (context, url, error) {
                              print('画像読み込みエラー: $error');
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: Icon(Icons.image_not_supported,
                                      size: 50, color: Colors.grey),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                          ),
                  ),
                ),
              ),

              // テキスト情報部分（中央寄せ）
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 今日のイベントがある場合のアイコンを表示（テキストの左）
                          if (hasTodayEvent)
                            Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(
                                Icons.event_available,
                                color: Colors.green,
                                size: 28,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              plant['name']?.toString() ?? '名称不明',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (plant['date'] != null)
                        Text(
                          plant['date'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 詳細画面への遷移処理を修正
  Future<void> _navigateToDetail(Map<String, dynamic> plant) async {
    // ディープコピーを作成
    Map<String, dynamic> plantCopy = Map<String, dynamic>.from(plant);

    // 詳細画面に遷移
    final needsReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(plant: plantCopy),
      ),
    );

    // 詳細画面で変更があった場合は全データ再読み込み
    if (needsReload == true) {
      _forceReload = true;
      await loadPlantData();
    } else {
      // 変更がなくても、イベント情報だけは最新化
      List<String> plantIds = plants.map((p) => p['id'].toString()).toList();
      await _prefetchTodayEvents(plantIds);
      setState(() {}); // UIを更新
    }
  }

  // GridViewのビルダーを分離
  Widget _buildGridView() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      physics: AlwaysScrollableScrollPhysics(), // スクロール可能な状態を維持
      padding: EdgeInsets.all(12.0), 
      itemCount: filteredPlants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: 0.8, // アスペクト比を少し調整
        crossAxisSpacing: 12, // 横の間隔を広げる
        mainAxisSpacing: 12, // 縦の間隔を広げる
      ),
      itemBuilder: (context, index) {
        final plant = filteredPlants[index];
        return GestureDetector(
          onTap: () => _navigateToDetail(plant),
          child: _buildPlantCard(plant),
        );
      },
    );
  }
}

class TextUtils {
  // カタカナをひらがなに変換するマップ
  static final Map<String, String> kanaMap = {
    'ァ': 'ぁ',
    'ア': 'あ',
    'ィ': 'ぃ',
    'イ': 'い',
    'ゥ': 'ぅ',
    'ウ': 'う',
    'ェ': 'ぇ',
    'エ': 'え',
    'ォ': 'ぉ',
    'オ': 'お',
    'カ': 'か',
    'ガ': 'が',
    'キ': 'き',
    'ギ': 'ぎ',
    'ク': 'く',
    'グ': 'ぐ',
    'ケ': 'け',
    'ゲ': 'げ',
    'コ': 'こ',
    'ゴ': 'ご',
    'サ': 'さ',
    'ザ': 'ざ',
    'シ': 'し',
    'ジ': 'じ',
    'ス': 'す',
    'ズ': 'ず',
    'セ': 'せ',
    'ゼ': 'ぜ',
    'ソ': 'そ',
    'ゾ': 'ぞ',
    'タ': 'た',
    'ダ': 'だ',
    'チ': 'ち',
    'ヂ': 'ぢ',
    'ッ': 'っ',
    'ツ': 'つ',
    'ヅ': 'づ',
    'テ': 'て',
    'デ': 'で',
    'ト': 'と',
    'ド': 'ど',
    'ナ': 'な',
    'ニ': 'に',
    'ヌ': 'ぬ',
    'ネ': 'ね',
    'ノ': 'の',
    'ハ': 'は',
    'バ': 'ば',
    'パ': 'ぱ',
    'ヒ': 'ひ',
    'ビ': 'び',
    'ピ': 'ぴ',
    'フ': 'ふ',
    'ブ': 'ぶ',
    'プ': 'ぷ',
    'ヘ': 'へ',
    'ベ': 'べ',
    'ペ': 'ぺ',
    'ホ': 'ほ',
    'ボ': 'ぼ',
    'ポ': 'ぽ',
    'マ': 'ま',
    'ミ': 'み',
    'ム': 'む',
    'メ': 'め',
    'モ': 'も',
    'ャ': 'ゃ',
    'ヤ': 'や',
    'ュ': 'ゅ',
    'ユ': 'ゆ',
    'ョ': 'ょ',
    'ヨ': 'よ',
    'ラ': 'ら',
    'リ': 'り',
    'ル': 'る',
    'レ': 'れ',
    'ロ': 'ろ',
    'ヮ': 'ゎ',
    'ワ': 'わ',
    'ヰ': 'ゐ',
    'ヱ': 'ゑ',
    'ヲ': 'を',
    'ン': 'ん',
    'ヴ': 'ゔ',
    'ヵ': 'か',
    'ヶ': 'け'
  };

  // 日本語の文字列を正規化
  static String normalizeJapanese(String text) {
    final normalizedText = text.replaceAllMapped(
        RegExp(r'[ァ-ヶ]'), (Match m) => kanaMap[m.group(0)] ?? m.group(0)!);
    return normalizedText.toLowerCase();
  }

  // 日本語の文字列比較
  static int compareJapanese(String a, String b) {
    return normalizeJapanese(a).compareTo(normalizeJapanese(b));
  }
}