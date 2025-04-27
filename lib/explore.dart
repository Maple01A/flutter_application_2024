import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'detail.dart';

class ExploreScreen extends StatefulWidget {
  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // データ管理
  List<Map<String, dynamic>> _publicPlants = [];
  bool _isLoading = true;
  String _filterCategory = 'すべて';
  final List<String> _categories = ['すべて', '人気', '新着', 'お気に入り'];
  
  // ページネーション
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  int _pageSize = 20;
  bool _isLoadingMore = false;
  
  // スクロールコントローラー
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPublicPlants();
    _scrollController.addListener(_scrollListener);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_hasMoreData && !_isLoadingMore) {
        _loadMorePlants();
      }
    }
  }

  Future<void> _loadPublicPlants({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _publicPlants = [];
        _lastDocument = null;
        _hasMoreData = true;
      });
    }
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('plants')
          .where('isPublic', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .limit(_pageSize);
      
      // カテゴリーのフィルタリング
      if (_filterCategory != 'すべて' && 
          _filterCategory != '人気' && 
          _filterCategory != '新着' && 
          _filterCategory != 'お気に入り') {
        query = query.where('category', isEqualTo: _filterCategory);
      } else if (_filterCategory == '人気') {
        query = FirebaseFirestore.instance
            .collection('plants')
            .where('isPublic', isEqualTo: true)
            .orderBy('likesCount', descending: true)
            .limit(_pageSize);
      } else if (_filterCategory == 'お気に入り') {
        // 現在のユーザーがお気に入りした植物のIDを取得
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final favoriteSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('favorites')
              .get();
              
          List<String> favoritePlantIds = favoriteSnapshot.docs
              .map((doc) => doc.data()['plantId'] as String)
              .toList();
              
          if (favoritePlantIds.isEmpty) {
            setState(() {
              _isLoading = false;
              _publicPlants = [];
              _hasMoreData = false;
            });
            return;
          }
          
          // Firestoreは「in」クエリで最大10個までしかサポートしないため分割処理が必要
          List<Map<String, dynamic>> allFavoritePlants = [];
          for (int i = 0; i < favoritePlantIds.length; i += 10) {
            final end = (i + 10 < favoritePlantIds.length) ? i + 10 : favoritePlantIds.length;
            final batchIds = favoritePlantIds.sublist(i, end);
            
            final batchSnapshot = await FirebaseFirestore.instance
                .collection('plants')
                .where(FieldPath.documentId, whereIn: batchIds)
                .where('isPublic', isEqualTo: true)
                .get();
                
            allFavoritePlants.addAll(batchSnapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
          }
          
          setState(() {
            _isLoading = false;
            _publicPlants = allFavoritePlants;
            _hasMoreData = false;  // お気に入りは一度に全て取得するので追加読み込みなし
          });
          return;
        }
      }
      
      QuerySnapshot plantSnapshot = await query.get();
      if (plantSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMoreData = false;
        });
        return;
      }
      
      _lastDocument = plantSnapshot.docs.last;
      
      List<Map<String, dynamic>> loadedPlants = plantSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      setState(() {
        _publicPlants = loadedPlants;
        _isLoading = false;
      });
    } catch (e) {
      print('公開植物の読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました')),
      );
    }
  }
  
  Future<void> _loadMorePlants() async {
    if (!_hasMoreData || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('plants')
          .where('isPublic', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      
      // カテゴリーのフィルタリング
      if (_filterCategory != 'すべて' && 
          _filterCategory != '人気' && 
          _filterCategory != '新着' && 
          _filterCategory != 'お気に入り') {
        query = query.where('category', isEqualTo: _filterCategory);
      } else if (_filterCategory == '人気') {
        query = FirebaseFirestore.instance
            .collection('plants')
            .where('isPublic', isEqualTo: true)
            .orderBy('likesCount', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize);
      }
      
      QuerySnapshot plantSnapshot = await query.get();
      
      if (plantSnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      _lastDocument = plantSnapshot.docs.last;
      
      List<Map<String, dynamic>> morePlants = plantSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      setState(() {
        _publicPlants.addAll(morePlants);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('追加データ読み込みエラー: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  void _filterByCategory(String category) {
    if (_filterCategory != category) {
      setState(() {
        _filterCategory = category;
      });
      _loadPublicPlants(refresh: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('エクスプローラー'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // カテゴリーフィルター
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _filterCategory == category;
                
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _filterByCategory(category);
                      }
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 植物一覧
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _publicPlants.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadPublicPlants(refresh: true),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: MasonryGridView.count(
                            controller: _scrollController,
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            itemCount: _publicPlants.length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _publicPlants.length) {
                                return _buildLoadingIndicator();
                              }
                              return _buildPlantCard(_publicPlants[index]);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlantCard(Map<String, dynamic> plant) {
    final hasImage = plant['images'] != null && plant['images'].toString().isNotEmpty;
    final userName = plant['userName'] ?? '匿名ユーザー';
    final likesCount = plant['likesCount'] ?? 0;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToDetailScreen(plant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像
            AspectRatio(
              aspectRatio: 1.0,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: plant['images'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey[400], size: 50),
                    ),
            ),
            
            // テキスト情報
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant['name'] ?? '名称不明',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  if (plant['description'] != null) ...[
                    Text(
                      plant['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                  ],
                  
                  // ユーザー情報とお気に入り数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.favorite, size: 14, color: Colors.red[400]),
                          SizedBox(width: 4),
                          Text(
                            '$likesCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingGrid() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                height: index % 2 == 0 ? 250 : 200,
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            '公開されている植物がありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'カテゴリーを変更するか、後でもう一度お試しください',
            style: TextStyle(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadPublicPlants(refresh: true),
            icon: Icon(Icons.refresh),
            label: Text('再読み込み'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  void _navigateToDetailScreen(Map<String, dynamic> plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(plant: plant),
      ),
    ).then((_) {
      // 詳細画面から戻ってきた時、更新があるかもしれないので最新の状態を読み込む
      _loadPublicPlants();
    });
  }
}