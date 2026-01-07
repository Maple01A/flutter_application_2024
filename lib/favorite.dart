import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detail.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'utils/error_handler.dart';

class FavoriteScreen extends StatefulWidget {
  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final _authService = AuthService();
  final _firebaseService = FirebaseService();
  final _storageService = StorageService();
  
  List<Map<String, dynamic>> favoritePlants = [];
  bool _isLoading = false;
  bool _isAuthenticated = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuthAndLoadFavorites();
  }

  // ===== データ読み込み関連 =====

  // 認証状態を確認してからお気に入りを読み込む
  Future<void> _checkAuthAndLoadFavorites() async {
    final user = _authService.currentUser;
    setState(() {
      _currentUser = user;
      _isAuthenticated = user != null;
    });

    if (_isAuthenticated) {
      await _loadFavorites();
    } else {
      setState(() {
        favoritePlants = [];
      });
    }
  }

  // Firebaseからお気に入りリストを読み込む
  Future<void> _loadFavorites() async {
    if (_isLoading || !_isAuthenticated || _currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final loadedPlants = await _firebaseService.getFavoritePlantsWithDetails(_currentUser!.uid);

      if (mounted) {
        setState(() => favoritePlants = loadedPlants);
      }
    } catch (e) {
      print('お気に入りの読み込みエラー: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
        setState(() => favoritePlants = []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 植物の詳細情報を取得してマージする
  Future<void> _addPlantDetails(Map<String, dynamic> data) async {
    try {
      final plantDoc = await FirebaseFirestore.instance
          .collection('plants')
          .doc(data['plantId'])
          .get();

      if (plantDoc.exists) {
        final plantData = Map<String, dynamic>.from(plantDoc.data()!);
        String favoriteId = data['id'];

        data.clear();
        data.addAll(plantData);
        data['id'] = favoriteId;
        data['plantId'] = plantData['id'];
      }
    } catch (e) {
      print('植物詳細情報の取得エラー: $e');
    }
  }

  // ===== お気に入り操作関連 =====

  // お気に入りを削除する機能
  Future<void> _removeFavorite(Map<String, dynamic> plant) async {
    if (!_isAuthenticated || _currentUser == null) {
      _showLoginPrompt();
      return;
    }

    final shouldRemove = await _showRemoveConfirmationDialog(plant);
    if (shouldRemove != true) return;

    setState(() => _isLoading = true);

    try {
      String favoriteId = plant['id'] ?? '';

      if (favoriteId.isNotEmpty) {
        await _firebaseService.removeFavorite(_currentUser!.uid, favoriteId);
      } else if (plant['plantId'] != null) {
        await _firebaseService.removeFavoriteByPlantId(_currentUser!.uid, plant['plantId']);
      }

      setState(() {
        favoritePlants.removeWhere((item) =>
            item['id'] == plant['id'] || item['plantId'] == plant['plantId']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('お気に入りから削除しました')),
        );
      }
    } catch (e) {
      print('お気に入り削除エラー: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 詳細画面への遷移
  Future<void> _navigateToDetailScreen(Map<String, dynamic> plant) async {
    Map<String, dynamic> plantData = Map<String, dynamic>.from(plant);

    // お気に入り情報を設定
    plantData['isFavorite'] = true;
    if (plant.containsKey('id')) {
      plantData['favoriteId'] = plant['id'];
    }

    // 画像URLが不足している場合は補完
    await _ensureImageUrl(plantData);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(plant: plantData),
      ),
    );

    if (result == true) {
      await _loadFavorites();
    }
  }

  // 画像URLが存在することを確認
  Future<void> _ensureImageUrl(Map<String, dynamic> plantData) async {
    if (plantData['images'] == null || plantData['images'].toString().isEmpty) {
      if (plantData['plantId'] != null) {
        try {
          final plant = await _firebaseService.getPlant(plantData['plantId'].toString());
          if (plant != null && plant.imageUrl != null) {
            plantData['images'] = plant.imageUrl;
          }
        } catch (e) {
          print('画像URL補完エラー: $e');
        }
      }
    }
  }

  // ===== UI表示関連 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入りの植物'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isAuthenticated ? _loadFavorites : null,
            tooltip: 'データを更新',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : !_isAuthenticated
              ? _buildNotAuthenticatedView()
              : favoritePlants.isEmpty
                  ? _buildEmptyFavoritesView()
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: _buildFavoritesListView(),
                    ),
    );
  }

  // 未ログイン時の表示
  Widget _buildNotAuthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'ログインが必要です',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'お気に入り機能を使用するにはログインしてください',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
            child: Text('ログイン'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // お気に入りが空の場合の表示
  Widget _buildEmptyFavoritesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'お気に入りはありません',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            '植物の詳細画面からお気に入りに追加できます',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // お気に入り一覧の表示
  Widget _buildFavoritesListView() {
    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: favoritePlants.length,
      itemBuilder: (context, index) {
        final plant = favoritePlants[index];
        return _buildPlantListItem(plant);
      },
    );
  }

  // 植物リストアイテム
  Widget _buildPlantListItem(Map<String, dynamic> plant) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Dismissible(
        key: Key(plant['id']?.toString() ?? UniqueKey().toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          await _removeFavorite(plant);
          return false;
        },
        child: ListTile(
          contentPadding: EdgeInsets.all(12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(plant),
          ),
          title: Text(
            plant['name'] ?? 'タイトルなし',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plant['date'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '登録日: ${plant['date']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _navigateToDetailScreen(plant),
        ),
      ),
    );
  }

  // 画像表示ウィジェット
  Widget _buildImageWidget(Map<String, dynamic> plant) {
    String? imageUrl = _getImageUrl(plant);

    if (imageUrl == null) {
      return _buildImagePlaceholder();
    }

    // Firebase Storageのパスの場合
    if (!imageUrl.startsWith('http') && imageUrl.startsWith('images/')) {
      return FutureBuilder<String?>(
        future: _getDownloadUrlFromPath(imageUrl, plant),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null) {
            return _buildNetworkImage(snapshot.data!);
          } else {
            return _buildImageLoading();
          }
        },
      );
    }

    // 既にHTTP(S)で始まるURL
    return _buildNetworkImage(imageUrl);
  }

  // 画像URL取得ヘルパー
  String? _getImageUrl(Map<String, dynamic> plant) {
    if (plant.containsKey('images') &&
        plant['images'] != null &&
        plant['images'].toString().isNotEmpty) {
      return plant['images'].toString();
    }

    if (plant.containsKey('imageUrl') &&
        plant['imageUrl'] != null &&
        plant['imageUrl'].toString().isNotEmpty) {
      return plant['imageUrl'].toString();
    }

    return null;
  }

  // 画像プレースホルダー
  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // 画像読み込み中表示
  Widget _buildImageLoading() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[100],
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.0),
      ),
    );
  }

  // ネットワーク画像表示
  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImageLoading();
      },
      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
    );
  }

  // Firebase Storageからダウンロードリンクを取得
  Future<String?> _getDownloadUrlFromPath(
      String path, Map<String, dynamic> plant) async {
    try {
      final url = await _storageService.getDownloadUrl(path);

      // キャッシュのため、オブジェクトを更新
      plant['images'] = url;

      return url;
    } catch (e) {
      print('ダウンロードURL取得エラー: $e');
      return null;
    }
  }

  // ===== ダイアログとプロンプト =====

  // ログインプロンプト表示
  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ログインが必要です'),
        action: SnackBarAction(
          label: 'ログイン',
          onPressed: () {
            Navigator.of(context).pushNamed('/login');
          },
        ),
      ),
    );
  }

  // 削除確認ダイアログ表示
  Future<bool?> _showRemoveConfirmationDialog(Map<String, dynamic> plant) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('お気に入りから削除'),
        content: Text('「${plant['name']}」をお気に入りから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
