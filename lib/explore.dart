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
  List<Map<String, dynamic>> _filteredPlants = [];
  bool _isLoading = true;
  
  // 検索機能
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
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
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterPlants();
    });
  }
  
  void _filterPlants() {
    if (_searchQuery.isEmpty) {
      _filteredPlants = List.from(_publicPlants);
    } else {
      _filteredPlants = _publicPlants.where((plant) {
        final name = (plant['name'] ?? '').toString().toLowerCase();
        final userName = (plant['userName'] ?? '').toString().toLowerCase();
        final category = (plant['category'] ?? '').toString().toLowerCase();
        final location = (plant['location'] ?? '').toString().toLowerCase();
        
        return name.contains(_searchQuery) ||
               userName.contains(_searchQuery) ||
               category.contains(_searchQuery) ||
               location.contains(_searchQuery);
      }).toList();
    }
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
      print('🔍 公開植物を検索中...');
      
      // orderByを削除してシンプルなクエリに変更（インデックス不要）
      Query query = FirebaseFirestore.instance
          .collection('plants')
          .where('isPublic', isEqualTo: true)
          .limit(_pageSize);
    
      QuerySnapshot plantSnapshot = await query.get();
      
      print('📊 取得した公開植物の数: ${plantSnapshot.docs.length}');
      
      if (plantSnapshot.docs.isEmpty) {
        print('⚠️ 公開植物が見つかりません');
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
        print('✅ 植物: ${data['name']}, isPublic: ${data['isPublic']}, ユーザー: ${data['userName']}');
        return data;
      }).toList();
      
      // ローカルでソート（lastUpdatedがあれば使用）
      loadedPlants.sort((a, b) {
        final aTime = a['lastUpdated'];
        final bTime = b['lastUpdated'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        final aTimestamp = (aTime as Timestamp).toDate();
        final bTimestamp = (bTime as Timestamp).toDate();
        
        return bTimestamp.compareTo(aTimestamp);
      });
      
      setState(() {
        _publicPlants = loadedPlants;
        _filteredPlants = List.from(loadedPlants);
        _isLoading = false;
      });
      
      print('✨ 公開植物の表示完了');
    } catch (e) {
      print('❌ 公開植物の読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadMorePlants() async {
    if (!_hasMoreData || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // orderByを削除してシンプルに
      Query query = FirebaseFirestore.instance
          .collection('plants')
          .where('isPublic', isEqualTo: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      
      
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
        _filterPlants();
        _isLoadingMore = false;
      });
    } catch (e) {
      print('追加データ読み込みエラー: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('探索'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '植物名、ユーザー名で検索...',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // カテゴリーフィルター
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          
          // 植物一覧
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _filteredPlants.isEmpty
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
                            itemCount: _filteredPlants.length + (_hasMoreData && _searchQuery.isEmpty ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _filteredPlants.length) {
                                return _buildLoadingIndicator();
                              }
                              return _buildPlantCard(_filteredPlants[index]);
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
                  
                  // ユーザー情報
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
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
            _searchQuery.isEmpty ? Icons.search_off : Icons.search,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
                ? '公開されている植物がありません'
                : '「$_searchQuery」に一致する植物が見つかりません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '別のキーワードで検索してみてください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
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