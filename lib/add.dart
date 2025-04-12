import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class AddPlantScreen extends StatefulWidget {
  @override
  _AddPlantScreenState createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  File? _image;
  bool _isUploading = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // 画像圧縮処理
  Future<File> _compressImage(File file) async {
    try {
      // ファイルサイズのチェック
      final fileSize = await file.length();
      if (fileSize <= 500 * 1024) {
        // 500KB以下の場合は圧縮不要
        print('画像サイズが小さいため圧縮をスキップ: ${fileSize ~/ 1024}KB');
        return file;
      }

      // 画像ファイルを読み込む
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        print('画像のデコードに失敗しました');
        return file;
      }

      // 画像リサイズ
      img.Image resizedImage = image;
      final maxDimension = 1024;

      if (image.width > maxDimension || image.height > maxDimension) {
        // アスペクト比を維持したまま最大サイズに制限
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;

        if (image.width > image.height) {
          newWidth = maxDimension;
          newHeight = (maxDimension / aspectRatio).round();
        } else {
          newHeight = maxDimension;
          newWidth = (maxDimension * aspectRatio).round();
        }

        resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
        );

        print(
            '画像リサイズ: ${image.width}x${image.height} → ${newWidth}x${newHeight}');
      }

      // 品質調整（大きな画像ほど圧縮率を上げる）
      final quality = fileSize > 2 * 1024 * 1024 ? 75 : 85;
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);

      // 圧縮した画像を一時ファイルとして保存
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      final newSize = await tempFile.length();
      print(
          '圧縮完了: ${fileSize ~/ 1024}KB → ${newSize ~/ 1024}KB (${(newSize / fileSize * 100).toStringAsFixed(1)}%)');

      return tempFile;
    } catch (e) {
      print('画像圧縮エラー: $e');
      return file; // エラー時は元のファイルを返す
    }
  }

  // 画像選択処理
  Future<void> _pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      File imageFile = File(pickedFile.path);
      File compressedFile = await _compressImage(imageFile);

      if (!mounted) return;

      setState(() {
        _image = compressedFile;
        _isLoading = false;
      });
    } catch (e) {
      print('画像選択エラー: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('画像の選択中にエラーが発生しました'),
              Text(
                '対応形式: JPG, PNG, GIF, HEIC',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  // 画像取得方法の選択ダイアログを表示
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '画像の選択方法',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                  title: Text('カメラで撮影'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(source: ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                  title: Text('ギャラリーから選択'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(source: ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Firebase Storageへのアップロード
  Future<String> _uploadImageToStorage(File image) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'images/${timestamp}.jpg';

      final ref = FirebaseStorage.instance.ref().child(path);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        },
      );

      await ref.putFile(image, metadata);

      final downloadUrl = await ref.getDownloadURL();
      print('画像アップロード成功: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('画像アップロードエラー: $e');
      throw '画像のアップロードに失敗しました';
    }
  }

  // プラントデータのアップロード
  Future<void> _uploadPlant() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        _showLoadingDialog();

        String? imageUrl;

        if (_image != null) {
          try {
            imageUrl = await _uploadImageToStorage(_image!);
          } catch (e) {
            print('画像アップロードエラー: $e');
            throw Exception('画像のアップロードに失敗しました: $e');
          }
        }

        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          throw Exception('ログインしてください');
        }

        final plantData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': _dateController.text,
          'images': imageUrl ?? 'https://placehold.jp/300x300.png',
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRef = await FirebaseFirestore.instance
            .collection('plants')
            .add(plantData);

        print('植物データが追加されました。ID: ${docRef.id}');

        // ローディングダイアログを閉じる
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_nameController.text}を追加しました'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        print('Error in _uploadPlant: $e');

        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラーが発生しました: ${e.toString()}'),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ローディングダイアログ表示
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  // 日付選択処理を修正した簡単なバージョン
  Future<void> _selectDate(BuildContext context) async {
    try {
      // ロケールを指定せずにDatePickerを使用（これが重要）
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
        // locale: const Locale('ja', 'JP'), // この行を削除または無効化
      );
      
      if (picked != null) {
        setState(() {
          // 日付フォーマットを維持
          _dateController.text = "${picked.year}年${picked.month}月${picked.day}日";
        });
      }
    } catch (e) {
      print('日付選択エラー: $e');
      
      // エラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日付を選択できませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('新しい植物を追加'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 16),

                          Text(
                            '植物情報の入力',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 16),

                          // 名前入力フィールド
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: '名前',
                              prefixIcon: Icon(Icons.local_florist),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '名前を入力してください';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),
                          
                          // 説明入力フィールド
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: '説明',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '説明を入力してください';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),

                          // 日付入力フィールド
                          TextFormField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: '日付',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                            readOnly: true,
                            onTap: () {
                              FocusScope.of(context).requestFocus(FocusNode());
                              _selectDate(context);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '日付を選択してください';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),

                          

                          // 画像アップロードセクション
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: 12),
                                if (_image != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _image!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image,
                                          size: 60,
                                          color: Colors.grey.shade400,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '写真がありません',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: (_isUploading || _isLoading)
                                      ? null
                                      : _showImageSourceDialog,
                                  label:
                                      Text(_image == null ? '写真を追加' : '写真を変更'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '対応形式: JPG, PNG, GIF, HEIC',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 100), // 下部のボタン用のスペース
                        ],
                      ),
                    ),
                  ),
                ),

                // 追加ボタン（固定）
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadPlant,
                      icon: _isUploading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.add),
                      label: Text(
                        _isUploading ? '保存中...' : '植物を追加',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
