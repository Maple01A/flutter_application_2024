import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

class PlantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plant;

  PlantDetailScreen({required this.plant}) {
    _normalizePlantData(plant);
  }

  // データ構造の差異を吸収する静的メソッド
  static void _normalizePlantData(Map<String, dynamic> plant) {
    // お気に入り情報を保持
    final bool explicitFavorite = plant['isFavorite'] == true;
    final String? favoriteId = plant['favoriteId']?.toString();

    // 1. IDフィールドの統一
    if (plant.containsKey('plantId') && !plant.containsKey('id')) {
      plant['id'] = plant['plantId'];
    } else if (plant.containsKey('id') && !plant.containsKey('plantId')) {
      plant['plantId'] = plant['id'];
    }

    // 2. 必須フィールドの初期化
    final requiredFields = ['name', 'description', 'date'];
    for (var field in requiredFields) {
      if (!plant.containsKey(field) || plant[field] == null) {
        plant[field] = '';
      }
    }

    // 3. 画像URLフィールドの統一
    if (plant.containsKey('imageUrl') &&
        (!plant.containsKey('images') || plant['images'] == null)) {
      plant['images'] = plant['imageUrl'];
    }

    // 4. お気に入り状態を保持
    plant['isFavorite'] = explicitFavorite;
    if (favoriteId != null) {
      plant['favoriteId'] = favoriteId;
    }
  }

  @override
  _PlantDetailScreenState createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  // UI状態管理
  bool isFavorite = false;
  bool isEditing = false;
  bool _isLoading = false;
  bool _isCheckingFavorite = false;
  bool _favoriteChanged = false;

  // フィールド管理
  Map<String, TextEditingController> fieldControllers = {};
  List<String> defaultFields = ['description', 'height', 'width'];
  List<String> customFields = [];
  final TextEditingController _newFieldNameController = TextEditingController();
  final TextEditingController _newFieldValueController = TextEditingController();

  // カレンダー連携用の変数
  List<Map<String, dynamic>> _plantEvents = [];

  // お気に入り関連
  String? _favoriteId;

  // 表示名マッピング
  final Map<String, String> fieldDisplayNames = {'description': '説明', 'height': '高さ', 'width': '株張り'};

  @override
  void initState() {
    super.initState();
    // 日本語のロケールを初期化
    initializeDateFormatting('ja_JP', null);
    
    _initializeData();

    // お気に入りの初期状態を設定
    if (widget.plant['isFavorite'] == true) {
      isFavorite = true;
      _favoriteId = widget.plant['favoriteId']?.toString();
    } else {
      _checkIfFavorite();
    }
  }

  @override
  void dispose() {
    // コントローラーの解放
    fieldControllers.forEach((_, controller) => controller.dispose());
    _newFieldNameController.dispose();
    _newFieldValueController.dispose();

    // 前の画面に変更があったことを通知
    if (_favoriteChanged) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pop(false);
    }
    super.dispose();
  }

  // ===== データ初期化処理 =====

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      final String plantId =
          widget.plant['id'] ?? widget.plant['plantId'] ?? '';
      if (plantId.isEmpty) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // カレンダーイベントの読み込み
        await _loadCalendarEvents();

        // カスタムフィールドを抽出
        _extractCustomFields();
      }
    } catch (e) {
      print('データ初期化エラー: $e');
    } finally {
      _initializeControllers();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final String plantId = widget.plant['id'] ?? widget.plant['plantId'] ?? '';
      if (plantId.isEmpty) {
        print('有効なplantIdがありません');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ユーザーがログインしていません');
        return;
      }

      print('イベント読み込み開始: plantId=$plantId');
      
      try {
        // ソート付きクエリを試行（インデックスが作成済みの場合はこれが成功）
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plantEvents')
            .where('plantId', isEqualTo: plantId)
            .orderBy('eventDate', descending: false)
            .get();
            
        _processEventsSnapshot(eventsSnapshot);
      } catch (indexError) {
        // インデックスエラーが発生した場合、ソートなしでクエリを実行（一時的な対策）
        print('インデックスエラー: $indexError');
        print('ソートなしクエリで再試行中...');
        
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plantEvents')
            .where('plantId', isEqualTo: plantId)
            .get();
        
        _processEventsSnapshot(eventsSnapshot);
      }
    } catch (e) {
      print('カレンダーイベント読み込みエラー: $e');
    }
  }

  // イベントデータを処理する分離メソッド
  void _processEventsSnapshot(QuerySnapshot eventsSnapshot) {
    print('取得したイベント数: ${eventsSnapshot.docs.length}');

    final events = eventsSnapshot.docs
        .map((doc) {
          try {
            final eventData = doc.data() as Map<String, dynamic>;
            final eventDate = eventData['eventDate'];
            
            // Timestampの変換処理を改善
            DateTime convertedDate;
            if (eventDate is Timestamp) {
              convertedDate = eventDate.toDate();
            } else if (eventDate is DateTime) {
              convertedDate = eventDate;
            } else {
              convertedDate = DateTime.now();
              print('不明な日付形式: $eventDate');
            }
            
            return {
              'id': doc.id,
              'title': eventData['title'] ?? '',
              'description': eventData['description'] ?? '',
              'eventDate': convertedDate,
              'eventType': eventData['eventType'] ?? '予定',
            };
          } catch (e) {
            print('イベントデータの解析エラー: $e');
            return null;
          }
        })
        .where((event) => event != null)
        .cast<Map<String, dynamic>>()
        .toList();

    // ローカルでソート（インデックスがなくてもUIはソートされる）
    events.sort((a, b) => (a['eventDate'] as DateTime).compareTo(b['eventDate'] as DateTime));

    if (mounted) {
      setState(() {
        _plantEvents = events;
      });
    }
  }

  void _extractCustomFields() {
    final systemFields = [
      'id',
      'plantId',
      'name',
      'images',
      'imageUrl',
      'date',
      'userId',
      'createdAt',
      'updatedAt',
      'addedAt',
      'lastUpdated',
      'isFavorite',
      'favoriteId',
      'timestamp'
    ];

    final List<String> loadedCustomFields = [];
    widget.plant.forEach((key, value) {
      if (!defaultFields.contains(key) && !systemFields.contains(key)) {
        loadedCustomFields.add(key);
      }
    });

    setState(() {
      customFields = loadedCustomFields;
    });
  }

  void _initializeControllers() {
    [...defaultFields, ...customFields].forEach((field) {
      if (widget.plant.containsKey(field)) {
        fieldControllers[field] =
            TextEditingController(text: widget.plant[field]?.toString() ?? '');
      } else {
        fieldControllers[field] = TextEditingController();
      }
    });
  }

  // ===== お気に入り機能 =====

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isFavorite = false);
      return;
    }

    setState(() => _isCheckingFavorite = true);

    try {
      if (widget.plant['favoriteId'] != null) {
        final favoriteId = widget.plant['favoriteId'].toString();
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .doc(favoriteId)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            isFavorite = true;
            _favoriteId = favoriteId;
          });
          return;
        }
      }

      final String plantId =
          widget.plant['plantId'] ?? widget.plant['id'] ?? '';
      if (plantId.isEmpty) {
        setState(() {
          isFavorite = false;
          _isCheckingFavorite = false;
        });
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('plantId', isEqualTo: plantId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          isFavorite = true;
          _favoriteId = querySnapshot.docs.first.id;
          widget.plant['favoriteId'] = _favoriteId;
        });
      } else {
        setState(() {
          isFavorite = false;
          _favoriteId = null;
        });
      }
    } catch (e) {
      print('お気に入り状態の確認エラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingFavorite = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りの登録にはログインが必要です')),
      );
      return;
    }

    setState(() => _isCheckingFavorite = true);

    try {
      final String plantId =
          widget.plant['plantId'] ?? widget.plant['id'] ?? '';
      if (plantId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('植物IDが見つかりません')),
        );
        return;
      }

      if (isFavorite) {
        await _removeFromFavorites(user);
      } else {
        await _addToFavorites(user, plantId);
      }
    } catch (e) {
      print('お気に入り状態の変更エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました')),
      );
    } finally {
      setState(() => _isCheckingFavorite = false);
    }
  }

  Future<void> _removeFromFavorites(User user) async {
    if (_favoriteId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(_favoriteId)
          .delete();

      setState(() {
        isFavorite = false;
        _favoriteId = null;
        widget.plant['isFavorite'] = false;
        widget.plant.remove('favoriteId');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.favorite_border, color: Colors.white),
              SizedBox(width: 8),
              Text('お気に入りから削除しました'),
            ],
          ),
        ),
      );
      _favoriteChanged = true;
    }
  }

  Future<void> _addToFavorites(User user, String plantId) async {
    final favoriteData = {
      'plantId': plantId,
      'name': widget.plant['name'] ?? '名称不明',
      'addedAt': FieldValue.serverTimestamp(),
    };

    if (widget.plant['images'] != null) {
      favoriteData['images'] = widget.plant['images'];
    }

    if (widget.plant['description'] != null) {
      favoriteData['description'] = widget.plant['description'];
    }

    if (widget.plant['date'] != null) {
      favoriteData['date'] = widget.plant['date'];
    }

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .add(favoriteData);

    setState(() {
      isFavorite = true;
      _favoriteId = docRef.id;
      widget.plant['isFavorite'] = true;
      widget.plant['favoriteId'] = docRef.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Text('お気に入りに追加しました'),
          ],
        ),
      ),
    );
    _favoriteChanged = true;
  }

  // ===== 編集機能 =====

  void _toggleEditMode() async {
    if (isEditing) {
      // 編集モードから通常モードへの切り替え時に保存
      final success = await _saveChanges();
      if (success) {
        setState(() {
          isEditing = false;
        });
      }
    } else {
      // 通常モードから編集モードへの切り替え
      setState(() {
        isEditing = true;
      });
    }
  }

  Future<bool> _saveChanges() async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有効な植物IDがありません')),
      );
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt();
      return false;
    }

    // 保存中の表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('変更を保存中...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      Map<String, dynamic> updatedData = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      fieldControllers.forEach((field, controller) {
        updatedData[field] = controller.text;
        widget.plant[field] = controller.text; // すぐにウィジェットデータも更新
      });

      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('変更を保存しました')),
      );
      return true;
    } catch (e) {
      print('Firebase 保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('変更の保存に失敗しました')),
      );
      return false;
    }
  }

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ログインすると変更を保存できます'),
        action: SnackBarAction(
          label: 'ログイン',
          onPressed: () {
            Navigator.of(context).pushNamed('/login');
          },
        ),
      ),
    );
  }

  // ===== カスタムフィールド管理 =====

  void _addNewField() {
    final List<String> suggestedFields = ['品種名', '高さ', '株張り', '形質', '時期', '育成環境', '入手先'];

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
                    labelText: '項目を選択してください',
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  final fieldName = _newFieldNameController.text.trim();
                  final fieldValue = _newFieldValueController.text.trim();

                  if (fieldName.isNotEmpty) {
                    Navigator.of(context).pop(); // ダイアログを閉じる
                    _saveNewField(fieldName, fieldValue); // 保存処理を実行
                  }
                },
                child: Text('追加'),
              ),
            ],
          );
        });
      },
    ).then((_) {
      // ダイアログを閉じた後にフィールドをクリア
      _newFieldNameController.clear();
      _newFieldValueController.clear();
    });
  }

  Future<void> _saveNewField(String fieldName, String fieldValue) async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有効な植物IDがありません')),
      );
      return;
    }

    // 保存中の表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('新しい項目を追加中...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // まず状態を更新して即時反映
      setState(() {
        customFields.add(fieldName);
        fieldControllers[fieldName] = TextEditingController(text: fieldValue);
        widget.plant[fieldName] = fieldValue;
      });

      // その後、Firestoreに保存
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update({fieldName: fieldValue});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('新しい項目を追加しました'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('カスタムフィールド保存エラー: $e');
      
      // エラー時は状態を元に戻す
      setState(() {
        customFields.remove(fieldName);
        fieldControllers[fieldName]?.dispose();
        fieldControllers.remove(fieldName);
        widget.plant.remove(fieldName);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('項目の追加に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                _deleteFieldFromFirebase(fieldName);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
              child: Text('削除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFieldFromFirebase(String fieldName) async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) return;

    // 削除中の表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('項目を削除中...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // まず状態を更新して即時反映
      setState(() {
        if (customFields.contains(fieldName)) {
          customFields.remove(fieldName);
        }
        
        // height や width の場合はdefaultFieldsからは削除しないが、値をクリアする
        if (fieldName == 'height' || fieldName == 'width') {
          fieldControllers[fieldName]?.text = '';
          widget.plant[fieldName] = '';
        } else {
          fieldControllers[fieldName]?.dispose();
          fieldControllers.remove(fieldName);
          widget.plant.remove(fieldName);
        }
      });

      // Firestoreにも反映
      if (fieldName == 'height' || fieldName == 'width') {
        // 標準フィールドの場合は空文字列を設定
        await FirebaseFirestore.instance
            .collection('plants')
            .doc(plantId)
            .update({fieldName: ''});
      } else {
        // カスタムフィールドの場合はフィールド自体を削除
        await FirebaseFirestore.instance
            .collection('plants')
            .doc(plantId)
            .update({fieldName: FieldValue.delete()});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('項目を削除しました'),
            ],
          ),
        ),
      );
    } catch (e) {
      print('フィールド削除エラー: $e');
      
      // エラー時は元の状態に戻す
      _initializeData(); // 全データを再取得
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('項目の削除に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== カレンダーイベント管理 =====

  Future<void> _addCalendarEvent(Map<String, dynamic> eventData) async {
    try {
      final String plantId = widget.plant['id'] ?? widget.plant['plantId'] ?? '';
      if (plantId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('有効な植物IDがありません')),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      // 処理中のインジケータを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('保存中...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // 日付の形式に注意
      DateTime eventDate = eventData['eventDate'];
      
      // Firestoreに保存するデータ形式を厳密に定義
      Map<String, dynamic> saveData = {
        'plantId': plantId,
        'plantName': widget.plant['name'] ?? '名称不明',
        'title': eventData['title'],
        'description': eventData['description'] ?? '',
        // ここでDateTimeをそのまま保存すると問題が起きる可能性があるため、明示的にTimestampに変換
        'eventDate': Timestamp.fromDate(eventDate),
        'eventType': eventData['eventType'] ?? '予定',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Firestoreに保存
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plantEvents')
          .add(saveData);

      print('イベント保存完了: ${docRef.id}');

      // UIに即時反映（ローカルデータをより確実に処理）
      setState(() {
        _plantEvents.add({
          'id': docRef.id,
          'title': eventData['title'],
          'description': eventData['description'] ?? '',
          'eventDate': eventDate, // DateTime型で保持
          'eventType': eventData['eventType'] ?? '予定',
        });
        
        // ソートを確実に行う
        _plantEvents.sort((a, b) => 
            (a['eventDate'] as DateTime).compareTo(b['eventDate'] as DateTime));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('イベントを追加しました'),
          backgroundColor: Colors.green,
        ),
      );

      // データの整合性を保つため、念のために全データを再読み込み
      await Future.delayed(Duration(milliseconds: 500));
      await _loadCalendarEvents();
      
    } catch (e) {
      print('イベント追加エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateCalendarEvent(Map<String, dynamic> eventData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      // 処理中のインジケータ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('更新中...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // 日付の形式に注意
      DateTime eventDate = eventData['eventDate'];

      // Firestoreに保存するデータ形式を厳密に定義
      Map<String, dynamic> updateData = {
        'title': eventData['title'],
        'description': eventData['description'] ?? '',
        // 明示的にTimestampに変換
        'eventDate': Timestamp.fromDate(eventDate),
        'eventType': eventData['eventType'] ?? '予定',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Firestoreでドキュメントを更新
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plantEvents')
          .doc(eventData['id'])
          .update(updateData);

      print('イベント更新完了: ${eventData['id']}');

      // UIに即時反映
      setState(() {
        final index = _plantEvents.indexWhere((e) => e['id'] == eventData['id']);
        if (index != -1) {
          _plantEvents[index] = {
            'id': eventData['id'],
            'title': eventData['title'],
            'description': eventData['description'] ?? '',
            'eventDate': eventDate, // DateTime型で保持
            'eventType': eventData['eventType'] ?? '予定',
          };
        }
        
        // ソートを確実に行う
        _plantEvents.sort((a, b) => 
            (a['eventDate'] as DateTime).compareTo(b['eventDate'] as DateTime));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('イベントを更新しました'),
          backgroundColor: Colors.green,
        ),
      );

      // データの整合性を保つため、念のために全データを再読み込み
      await Future.delayed(Duration(milliseconds: 500));
      await _loadCalendarEvents();
      
    } catch (e) {
      print('イベント更新エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    
    // 現在の日付を初期選択
    DateTime selectedDate = DateTime.now();
    
    // カレンダーの表示月
    DateTime focusedDay = DateTime.now();
    
    // 既存のイベントをカレンダーマーカー用に変換
    Map<DateTime, List<Map<String, dynamic>>> events = {};
    
    for (var event in _plantEvents) {
      final eventDate = event['eventDate'] as DateTime;
      final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
      
      if (events[dateKey] == null) {
        events[dateKey] = [];
      }
      
      events[dateKey]!.add({
        'id': event['id'],
        'title': event['title'],
      });
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // カレンダー用のイベントマーカー取得関数
            List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
              final dateKey = DateTime(day.year, day.month, day.day);
              return events[dateKey] ?? [];
            }
            
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ヘッダー
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'イベントを追加',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // カレンダー表示
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TableCalendar(
                                    firstDay: DateTime.now().subtract(Duration(days: 365)),
                                    lastDay: DateTime.now().add(Duration(days: 365)),
                                    focusedDay: focusedDay,
                                    selectedDayPredicate: (day) {
                                      return isSameDay(selectedDate, day);
                                    },
                                    onDaySelected: (selectedDay, focusedDayChanged) {
                                      setState(() {
                                        selectedDate = selectedDay;
                                        focusedDay = focusedDayChanged;
                                      });
                                    },
                                    calendarFormat: CalendarFormat.month,
                                    eventLoader: _getEventsForDay,
                                    calendarStyle: CalendarStyle(
                                      todayDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      selectedDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      markerDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                    ),
                                    locale: 'ja_JP',
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // 選択した日付の表示
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    '選択日: ${DateFormat('yyyy年MM月dd日').format(selectedDate)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 24),
                              
                              // イベント名入力
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'イベント名',
                                  hintText: '例：水やり、肥料など',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.event_note),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // メモ入力
                              TextField(
                                controller: descriptionController,
                                decoration: InputDecoration(
                                  labelText: 'メモ（任意）',
                                  hintText: '例：多めに水をあげる',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.note),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // ボタン
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('キャンセル'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('追加'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop({
                                'title': titleController.text.isEmpty
                                    ? '${widget.plant['name']}のイベント'
                                    : titleController.text,
                                'description': descriptionController.text,
                                'eventDate': selectedDate,
                                'eventType': '予定',
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) async {
      if (value != null && value is Map<String, dynamic>) {
        await _addCalendarEvent(value);
      }
    });
  }

  void _showEditEventDialog(Map<String, dynamic> event) {
    final titleController = TextEditingController(text: event['title']);
    final descriptionController = TextEditingController(text: event['description']);
    
    // 既存のイベント日付を初期選択
    DateTime selectedDate = event['eventDate'];
    
    // カレンダーの表示月
    DateTime focusedDay = selectedDate;
    
    // 既存のイベントをカレンダーマーカー用に変換
    Map<DateTime, List<Map<String, dynamic>>> events = {};
    
    for (var e in _plantEvents) {
      final eventDate = e['eventDate'] as DateTime;
      final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
      
      if (events[dateKey] == null) {
        events[dateKey] = [];
      }
      
      events[dateKey]!.add({
        'id': e['id'],
        'title': e['title'],
      });
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // カレンダー用のイベントマーカー取得関数
            List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
              final dateKey = DateTime(day.year, day.month, day.day);
              return events[dateKey] ?? [];
            }
            
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ヘッダー
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'イベントを編集',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // カレンダー表示
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TableCalendar(
                                    firstDay: DateTime.now().subtract(Duration(days: 365)),
                                    lastDay: DateTime.now().add(Duration(days: 365)),
                                    focusedDay: focusedDay,
                                    selectedDayPredicate: (day) {
                                      return isSameDay(selectedDate, day);
                                    },
                                    onDaySelected: (selectedDay, focusedDayChanged) {
                                      setState(() {
                                        selectedDate = selectedDay;
                                        focusedDay = focusedDayChanged;
                                      });
                                    },
                                    calendarFormat: CalendarFormat.month,
                                    eventLoader: _getEventsForDay,
                                    calendarStyle: CalendarStyle(
                                      todayDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      selectedDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      markerDecoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                    ),
                                    locale: 'ja_JP',
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // 選択した日付の表示
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    '選択日: ${DateFormat('yyyy年MM月dd日').format(selectedDate)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 24),
                              
                              // イベント名入力
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'イベント名',
                                  hintText: '例：水やり、肥料など',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.event_note),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // メモ入力
                              TextField(
                                controller: descriptionController,
                                decoration: InputDecoration(
                                  labelText: 'メモ（任意）',
                                  hintText: '例：多めに水をあげる',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.note),
                                ),
                                maxLines: 3,
                              ),
                              
                              SizedBox(height: 20),
                              
                              // 削除ボタン
                              OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('イベントの削除'),
                                      content: Text('このイベントを削除してもよろしいですか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            Navigator.of(context).pop('delete');
                                          },
                                          child: Text('削除する', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(Icons.delete_outline, color: Colors.red),
                                label: Text('イベントを削除', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red),
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // ボタン
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('キャンセル'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: Icon(Icons.save),
                            label: Text('更新'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop({
                                'id': event['id'],
                                'title': titleController.text.isEmpty
                                    ? '${widget.plant['name']}のイベント'
                                    : titleController.text,
                                'description': descriptionController.text,
                                'eventDate': selectedDate,
                                'eventType': event['eventType'] ?? '予定',
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) async {
      if (value == 'delete') {
        await _deleteCalendarEvent(event['id']);
      } else if (value != null && value is Map<String, dynamic>) {
        await _updateCalendarEvent(value);
      }
    });
  }

  Future<void> _deleteCalendarEvent(String eventId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plantEvents')
          .doc(eventId)
          .delete();

      setState(() {
        _plantEvents.removeWhere((event) => event['id'] == eventId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('イベントを削除しました')),
      );
    } catch (e) {
      print('イベント削除エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('イベントの削除に失敗しました')),
      );
    }
  }

  // ===== 削除機能 =====

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

  void _deletePlant() async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有効な植物IDがありません')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .delete();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final favorites = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .where('plantId', isEqualTo: plantId)
            .get();

        for (var doc in favorites.docs) {
          await doc.reference.delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.plant['name']}を削除しました')),
      );

      _handlePlantDelete();
    } catch (e) {
      print("削除エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除できませんでした')),
      );
    }
  }

  void _handlePlantDelete() async {
    Navigator.of(context).pop(true);
  }

  // ===== 画像表示関連 =====

  Widget _buildImageSection(dynamic imageUrl) {
    return GestureDetector(
      onTap: imageUrl != null ? _showFullScreenImage : null,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Hero(
            tag: 'plantImage_${widget.plant['id'] ?? "unknown"}',
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
              child: imageUrl != null
                  ? FadeInImage.assetNetwork(
                      placeholder:
                          'assets/images/plant_loading.png',
                      image: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration(milliseconds: 300),
                      fadeOutDuration: Duration(milliseconds: 100),
                      imageErrorBuilder: (context, error, stackTrace) {
                        print('画像読み込みエラー: $error');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                '画像を読み込めませんでした',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                      placeholderErrorBuilder: (context, error, stackTrace) {
                        return _buildSkeletonLoader();
                      },
                      imageScale: 1.0,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 80, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '画像がありません',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (imageUrl != null)
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
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: Duration(milliseconds: 1500),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
      ),
    );
  }

  void _showFullScreenImage() {
    final imageUrl = widget.plant['images'];
    if (imageUrl == null) return;

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
              color: Colors.black.withOpacity(0.9),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'plantImage_${widget.plant['id'] ?? "unknown"}',
                    child: InteractiveViewer(
                      boundaryMargin: EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => _buildFullscreenLoader(),
                        errorWidget: (context, url, error) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    color: Colors.white, size: 100),
                                SizedBox(height: 16),
                                Text(
                                  '画像を表示できません',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        },
                        fadeInDuration: Duration(milliseconds: 300),
                        memCacheWidth:
                            MediaQuery.of(context).size.width.toInt(),
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

  Widget _buildFullscreenLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '画像を読み込み中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ===== UI構築関連 =====

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isEditing) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('変更を破棄しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('破棄する'),
                ),
              ],
            ),
          );

          if (shouldDiscard != true) {
            return false;
          }

          setState(() {
            isEditing = false;
          });
        }

        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.plant['name'] ?? '詳細',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.event_note),
              onPressed: _showAddEventDialog,
              tooltip: 'イベント追加',
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: isEditing ? '保存' : '編集',
            ),
            IconButton(
              icon: _isCheckingFavorite
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
              onPressed: _isCheckingFavorite ? null : _toggleFavorite,
              tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showDeleteConfirmationDialog,
          icon: Icon(Icons.delete),
          label: Text('削除'),
          backgroundColor: Colors.red[300],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final imageUrl = widget.plant['images'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageSection(imageUrl),
          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.plant['name'],
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 10),
          if (_plantEvents.isNotEmpty) _buildEventsSection(),
          if (widget.plant['date'] != null &&
              widget.plant['date'].toString().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  '登録日: ${widget.plant['date']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
          ...defaultFields.map((field) => _buildDetailItem(
              field, fieldDisplayNames[field] ?? field.capitalize())),
          ...customFields
              .map((field) => _buildDetailItem(field, field.capitalize())),
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: OutlinedButton.icon(
                onPressed: _showAddEventDialog,
                icon: Icon(Icons.add),
                label: Text('カレンダーイベントを追加'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: OutlinedButton.icon(
                onPressed: _addNewField,
                icon: Icon(Icons.add),
                label: Text('新しい項目を追加'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final pastEvents = _plantEvents
        .where((e) => (e['eventDate'] as DateTime).isBefore(today))
        .toList();
    final upcomingEvents = _plantEvents
        .where((e) => !(e['eventDate'] as DateTime).isBefore(today))
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'スケジュール',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 12),
          if (upcomingEvents.isNotEmpty) ...[
            Text(
              '予定されているイベント',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 8),
            ...upcomingEvents.map((event) => _buildEventCard(event)),
            SizedBox(height: 16),
          ],
          if (pastEvents.isNotEmpty) ...[
            Text(
              '過去のイベント',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            ...pastEvents.take(3).map((event) => _buildEventCard(event)),
            if (pastEvents.length > 3)
              TextButton(
                onPressed: _showAllPastEvents,
                child: Text('すべての過去イベントを表示'),
              ),
          ],
          if (_plantEvents.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  'まだイベントがありません。「カレンダーイベントを追加」ボタンから予定を設定できます。',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllPastEvents() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final pastEvents = _plantEvents
        .where((e) => (e['eventDate'] as DateTime).isBefore(today))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '過去のイベント',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Divider(),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: pastEvents.map((event) => _buildEventCard(event)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final eventDate = DateTime(
      (event['eventDate'] as DateTime).year,
      (event['eventDate'] as DateTime).month,
      (event['eventDate'] as DateTime).day,
    );
    final bool isToday = eventDate.isAtSameMomentAs(today);
    final bool isPast = eventDate.isBefore(today);
    final Color eventColor = Colors.teal;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isToday ? eventColor : Colors.grey[300]!,
          width: isToday ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showEditEventDialog(event),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: eventColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_note, color: eventColor, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPast ? Colors.grey[600] : Colors.black87,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy年MM月dd日')
                              .format(event['eventDate']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (event['description'] != null && event['description'].isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        event['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String fieldKey, String displayTitle) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (!fieldControllers.containsKey(fieldKey)) {
      return SizedBox.shrink();
    }

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
              if (isEditing && (customFields.contains(fieldKey) || fieldKey == 'height' || fieldKey == 'width'))
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300], size: 20),
                  onPressed: () => _deleteField(fieldKey),
                  tooltip: '項目を削除',
                ),
            ],
          ),
          SizedBox(height: 8),
          if (isEditing)
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
              maxLines: null,
            )
          else
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
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
