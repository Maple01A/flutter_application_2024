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
  List<Map> favoritePlants = [];
  bool isFavorite = false;
  bool isEditing = false;
  Map<String, TextEditingController> fieldControllers = {};
  List<String> defaultFields = ['description', 'watering', 'fertilizer'];
  List<String> customFields = [];
  final TextEditingController _newFieldNameController = TextEditingController();
  final TextEditingController _newFieldValueController = TextEditingController();
  
  // 固定フィールドの日本語名マッピング
  final Map<String, String> fieldDisplayNames = {
    'description': '説明',
    'watering': '水やり',
    'fertilizer': '肥料',
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _initializeControllers();
    _loadCustomFields();
  }

  @override
  void dispose() {
    // コントローラーの解放
    fieldControllers.forEach((_, controller) => controller.dispose());
    _newFieldNameController.dispose();
    _newFieldValueController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    // 既存のフィールドに対してコントローラーを初期化
    [...defaultFields, ...customFields].forEach((field) {
      if (widget.plant.containsKey(field)) {
        fieldControllers[field] = TextEditingController(
            text: widget.plant[field]?.toString() ?? '');
      } else {
        fieldControllers[field] = TextEditingController();
      }
    });
    
    // その他のカスタムフィールドを検出
    widget.plant.forEach((key, value) {
      if (!defaultFields.contains(key) && 
          !['id', 'name', 'images', 'date', 'userId'].contains(key) &&
          !customFields.contains(key)) {
        customFields.add(key);
        fieldControllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });
  }

  // カスタムフィールドを読み込む
  Future<void> _loadCustomFields() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedCustomFields = prefs.getStringList('customFields_${widget.plant['id']}');
    if (savedCustomFields != null) {
      setState(() {
        customFields = savedCustomFields;
        _initializeControllers(); // コントローラーを再初期化
      });
    }
  }

  // カスタムフィールドを保存する
  Future<void> _saveCustomFields() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customFields_${widget.plant['id']}', customFields);
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

  // 編集モード切り替え
  void _toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
      if (!isEditing) {
        _saveChanges();
      }
    });
  }

  // 変更を保存
  Future<void> _saveChanges() async {
    try {
      // 更新データの作成
      Map<String, dynamic> updatedData = {
        'id': widget.plant['id'],
        'name': widget.plant['name'],
        'images': widget.plant['images'],
        'date': widget.plant['date'],
        'userId': widget.plant['userId'],
      };

      // 編集されたフィールドを追加
      fieldControllers.forEach((field, controller) {
        updatedData[field] = controller.text;
      });

      // 1. Firebase に保存（オンライン時）
      try {
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        await firestore.collection('plants').doc(widget.plant['id']).update(updatedData);
        print('Firebase に変更を保存しました');
      } catch (e) {
        print('Firebase 保存エラー: $e');
        // Firebase 保存に失敗しても続行
      }

      // 2. ローカルデータも更新
      await _updateLocalPlantData(updatedData);

      // ウィジェットの植物データを更新
      widget.plant.addAll(updatedData);

      // カスタムフィールドを保存
      await _saveCustomFields();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('変更を保存しました')),
      );
    } catch (e) {
      print("保存エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  // ローカルに保存されているデータを更新
  Future<void> _updateLocalPlantData(Map<String, dynamic> updatedPlant) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plantsJson = prefs.getString('plants_cache');
      
      if (plantsJson != null) {
        List<dynamic> plants = jsonDecode(plantsJson);
        
        // 対象の植物データを更新
        int index = plants.indexWhere((p) => p['id'] == updatedPlant['id']);
        if (index >= 0) {
          plants[index] = updatedPlant;
        } else {
          plants.add(updatedPlant);
        }
        
        // 更新したデータを保存
        await prefs.setString('plants_cache', jsonEncode(plants));
        print('ローカルデータを更新しました');
      }
    } catch (e) {
      print('ローカルデータ更新エラー: $e');
    }
  }

  // 新しいフィールドを追加
  void _addNewField() {
    final List<String> suggestedFields = ['日当たり', '剪定', '植え替え時期', '原産地', '購入場所', '病害虫対策'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('新しい項目を追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: '項目を選択するか、新しい項目名を入力',
                    ),
                    items: suggestedFields
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _newFieldNameController.text = newValue;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: _newFieldNameController,
                    decoration: InputDecoration(
                      labelText: 'カスタム項目名',
                      hintText: '例: 原産地、購入場所など',
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _newFieldValueController,
                    decoration: InputDecoration(
                      labelText: '内容',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              // アクションボタンは変更なし
            );
          }
        );
      },
    );
  }

  // フィールドを削除
  void _deleteField(String fieldName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('項目の削除'),
          content: Text('「$fieldName」を削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  customFields.remove(fieldName);
                  fieldControllers[fieldName]?.dispose();
                  fieldControllers.remove(fieldName);
                  _saveCustomFields();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('削除'),
            ),
          ],
        );
      },
    );
  }

  void _deletePlant() async {
    try {
      // 1. Firebase から削除（オンライン時）
      try {
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        await firestore.collection('plants').doc(widget.plant['id']).delete();
        print('Firebase からデータを削除しました');
      } catch (e) {
        print('Firebase 削除エラー: $e');
        // Firebase 削除に失敗しても続行
      }

      // 2. ローカルからも削除
      await _deleteLocalPlantData(widget.plant['id']);

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

  // ローカルデータから植物を削除
  Future<void> _deleteLocalPlantData(String plantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plantsJson = prefs.getString('plants_cache');
      
      if (plantsJson != null) {
        List<dynamic> plants = jsonDecode(plantsJson);
        
        // 対象の植物データを削除
        plants.removeWhere((p) => p['id'] == plantId);
        
        // 更新したデータを保存
        await prefs.setString('plants_cache', jsonEncode(plants));
        print('ローカルデータから削除しました');
      }
      
      // カスタムフィールドの設定も削除
      await prefs.remove('customFields_$plantId');
    } catch (e) {
      print('ローカルデータ削除エラー: $e');
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'plantImage_${widget.plant['id']}',
                    child: InteractiveViewer(
                      boundaryMargin: EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        widget.plant['images'],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 詳細項目表示/編集ウィジェット
  Widget _buildDetailItem(String fieldKey, String displayTitle) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // コントローラーがなければスキップ
    if (!fieldControllers.containsKey(fieldKey)) {
      return SizedBox.shrink();
    }

    // 編集モードでない場合、空の内容は表示しない
    if (!isEditing && fieldControllers[fieldKey]!.text.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              if (isEditing && customFields.contains(fieldKey))
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300], size: 20),
                  onPressed: () => _deleteField(fieldKey),
                  tooltip: '項目を削除',
                ),
            ],
          ),
          SizedBox(height: 8),
          if (isEditing)
            // 編集モード
            TextField(
              controller: fieldControllers[fieldKey],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
              maxLines: null, // 複数行対応
            )
          else
            // 表示モード
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                fieldControllers[fieldKey]!.text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 背景色とアクセント色を設定
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.plant['name'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          // 編集ボタン
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: _toggleEditMode,
            tooltip: isEditing ? '保存' : '編集',
          ),
          // お気に入りボタン
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red[300] : null,
            ),
            onPressed: () => _toggleFavorite(widget.plant),
            tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 画像セクション - タップ可能
            GestureDetector(
              onTap: _showFullScreenImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Hero(
                    tag: 'plantImage_${widget.plant['id']}',
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.network(
                        widget.plant['images'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  // タップを促すヒントアイコン
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'タップして拡大',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 詳細情報セクション
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名前
                  Text(
                    widget.plant['name'],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  
                  // 日付があれば表示
                  if (widget.plant['date'] != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          '登録日: ${widget.plant['date']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                  
                  // デフォルトフィールドを表示
                  ...defaultFields.map((field) => 
                    _buildDetailItem(field, fieldDisplayNames[field] ?? field.capitalize())
                  ),
                  
                  // カスタムフィールドを表示
                  ...customFields.map((field) => 
                    _buildDetailItem(field, field.capitalize())
                  ),

                  // 編集モードのときのみ「新しい項目を追加」ボタンを表示
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: OutlinedButton.icon(
                        onPressed: _addNewField,
                        icon: Icon(Icons.add),
                        label: Text('新しい項目を追加'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDeleteConfirmationDialog,
        icon: Icon(Icons.delete),
        label: Text('削除'),
        backgroundColor: Colors.red[300],
      ),
    );
  }
}

// String拡張メソッド - 最初の文字を大文字にする
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}