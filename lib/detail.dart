import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

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
  List<String> defaultFields = ['description', 'watering', 'fertilizer'];
  List<String> customFields = [];
  final TextEditingController _newFieldNameController = TextEditingController();
  final TextEditingController _newFieldValueController =
      TextEditingController();

  // 水やりリマインダー
  DateTime? _nextWateringDate;
  String _wateringNote = '';
  bool _hasWateringReminder = false;

  // お気に入り関連
  String? _favoriteId;

  // 表示名マッピング
  final Map<String, String> fieldDisplayNames = {'description': '説明'};

  @override
  void initState() {
    super.initState();
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
        // 水やりリマインダー情報の取得
        _loadReminderData();

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

  void _loadReminderData() {
    if (widget.plant.containsKey('wateringReminder') &&
        widget.plant['wateringReminder'] != null) {
      final reminderData =
          widget.plant['wateringReminder'] as Map<String, dynamic>;
      setState(() {
        _nextWateringDate = DateTime.parse(reminderData['nextWateringDate']);
        _wateringNote = reminderData['wateringNote'] ?? '';
        _hasWateringReminder = true;
      });
    }
  }

  // _extractCustomFields メソッドを修正
  void _extractCustomFields() {
    // システムやメタデータフィールドのリスト
    final systemFields = [
      'id',
      'plantId',
      'name',
      'images',
      'imageUrl',
      'date',
      'userId',
      'wateringReminder',
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
      // favoriteIdがあれば、そのドキュメントを確認
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

      // plantIdで検索
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

    // 画像URLがあれば追加
    if (widget.plant['images'] != null) {
      favoriteData['images'] = widget.plant['images'];
    }

    // 説明があれば追加
    if (widget.plant['description'] != null) {
      favoriteData['description'] = widget.plant['description'];
    }

    // 日付があれば追加
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

  void _toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
      if (!isEditing) {
        _saveChanges();
      }
    });
  }

  Future<void> _saveChanges() async {
    final String plantId = widget.plant['id'] ?? '';
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

    try {
      Map<String, dynamic> updatedData = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      fieldControllers.forEach((field, controller) {
        updatedData[field] = controller.text;
      });

      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update(updatedData);

      widget.plant.addAll(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('変更を保存しました')),
      );
    } catch (e) {
      print('Firebase 保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('変更の保存に失敗しました')),
      );
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
    final List<String> suggestedFields = ['品種名', '高さ', '株張り', '形質', '時期'];

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
                    _saveNewField(fieldName, fieldValue);
                  }

                  Navigator.of(context).pop();
                },
                child: Text('追加'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _saveNewField(String fieldName, String fieldValue) async {
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
          .update({fieldName: fieldValue});

      setState(() {
        customFields.add(fieldName);
        fieldControllers[fieldName] = TextEditingController(text: fieldValue);
        widget.plant[fieldName] = fieldValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新しい項目を追加しました')),
      );
    } catch (e) {
      print('カスタムフィールド保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('項目の追加に失敗しました')),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

    try {
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update({fieldName: FieldValue.delete()});

      setState(() {
        customFields.remove(fieldName);
        fieldControllers[fieldName]?.dispose();
        fieldControllers.remove(fieldName);
        widget.plant.remove(fieldName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('項目を削除しました')),
      );
    } catch (e) {
      print('フィールド削除エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('項目の削除に失敗しました')),
      );
    }
  }

  // ===== リマインダー関連 =====

  void _showWateringReminderDialog() {
    DateTime selectedDate =
        _nextWateringDate ?? DateTime.now().add(Duration(days: 7));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    TextEditingController noteController =
        TextEditingController(text: _wateringNote);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('リマインダーの設定'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.plant['name']}の予定日を設定します'),
                    SizedBox(height: 20),

                    // 日付選択UI
                    Text('日付', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDatePicker(selectedDate, (picked) {
                      setState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                      });
                    }),

                    SizedBox(height: 20),
                    Text('時刻', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildTimePicker(selectedTime, (picked) {
                      setState(() {
                        selectedTime = picked;
                        selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }),

                    SizedBox(height: 20),
                    Text('メモ（任意）',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        hintText: '例：たっぷり水を与える',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    if (_hasWateringReminder) ...[
                      SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop('delete');
                        },
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        label: Text('リマインダーを削除',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'date': selectedDate,
                      'note': noteController.text,
                    });
                  },
                  child: Text('保存'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) async {
      if (value == 'delete') {
        await _deleteWateringReminder();
      } else if (value != null && value is Map) {
        setState(() {
          _nextWateringDate = value['date'];
          _wateringNote = value['note'];
          _hasWateringReminder = true;
        });
        await _saveWateringReminder();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リマインダーを設定しました')),
        );
      }
    });
  }

  Widget _buildDatePicker(
      DateTime selectedDate, Function(DateTime) onDateChanged) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 365)),
        );
        if (picked != null) {
          onDateChanged(picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('yyyy年MM月dd日').format(selectedDate)),
            Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
      TimeOfDay selectedTime, Function(TimeOfDay) onTimeChanged) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: selectedTime,
        );
        if (picked != null) {
          onTimeChanged(picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
            Icon(Icons.access_time),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWateringReminder() async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      Map<String, dynamic>? reminderData;

      if (_nextWateringDate != null) {
        reminderData = {
          'nextWateringDate': _nextWateringDate!.toIso8601String(),
          'wateringNote': _wateringNote,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update({'wateringReminder': reminderData});

      print('リマインダー情報を更新しました');
    } catch (e) {
      print('リマインダー保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リマインダーの保存に失敗しました')),
      );
    }
  }

  Future<void> _deleteWateringReminder() async {
    final String plantId = widget.plant['id'] ?? '';
    if (plantId.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .update({'wateringReminder': FieldValue.delete()});

      setState(() {
        _nextWateringDate = null;
        _wateringNote = '';
        _hasWateringReminder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リマインダーを削除しました')),
      );
    } catch (e) {
      print('リマインダー削除エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リマインダーの削除に失敗しました')),
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
      // Firestoreから削除
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(plantId)
          .delete();

      // 関連するお気に入りも削除
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

      // 前の画面に戻る
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
                          'assets/images/plant_loading.png', // プレースホルダー画像（追加必要）
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
                        // プレースホルダー画像が読み込めない場合
                        return _buildSkeletonLoader();
                      },
                      imageScale: 1.0, // 解像度スケール
                      // Removed unsupported cacheWidth and cacheHeight parameters
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
      period: Duration(milliseconds: 1500), // アニメーション速度
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
              icon: Icon(_hasWateringReminder
                  ? Icons.notifications_active
                  : Icons.notifications_none),
              color: _hasWateringReminder ? Colors.amber : null,
              onPressed: _showWateringReminderDialog,
              tooltip: 'リマインダー',
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
          if (_hasWateringReminder && !isEditing) _buildWateringStatusCard(),
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
          if (!isEditing && !_hasWateringReminder)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: OutlinedButton.icon(
                onPressed: _showWateringReminderDialog,
                icon: Icon(Icons.notifications),
                label: Text('リマインダーを設定'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.primary),
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
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.primary),
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

  Widget _buildWateringStatusCard() {
    if (_nextWateringDate == null) return SizedBox.shrink();

    final now = DateTime.now();
    final difference = _nextWateringDate!.difference(now).inDays;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (difference < 0) {
      statusColor = Colors.red;
      statusText = '緊急';
      statusIcon = Icons.warning_amber_rounded;
    } else if (difference == 0) {
      statusColor = Colors.orange;
      statusText = '今日が予定日です';
      statusIcon = Icons.notifications_active;
    } else {
      statusColor = Colors.green;
      statusText = '予定日はまだ先です';
      statusIcon = Icons.check_circle;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showWateringReminderDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Text(
                      '次回の予定日: ${DateFormat('yyyy年MM月dd日 HH:mm').format(_nextWateringDate!)}',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_wateringNote.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _wateringNote,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
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

// String拡張メソッド - 最初の文字を大文字にする
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
