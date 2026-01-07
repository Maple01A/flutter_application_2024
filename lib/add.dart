import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'utils/validators.dart';
import 'utils/error_handler.dart';
import 'components/buttons/primary_button.dart';
import 'foundation/spacing.dart';

class AddPlantScreen extends StatefulWidget {
  @override
  _AddPlantScreenState createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  
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

      if (!mounted) return;

      setState(() {
        _image = imageFile;
        _isLoading = false;
      });
    } catch (e) {
      print('画像選択エラー: $e');

      if (!mounted) return;

      ErrorHandler.showError(context, e);

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

  // プラントデータのアップロード
  Future<void> _uploadPlant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      _showLoadingDialog();

      final user = _authService.currentUser;

      if (user == null) {
        throw Exception('ログインしてください');
      }

      String? imageUrl;

      if (_image != null) {
        imageUrl = await _storageService.uploadPlantImage(_image!, user.uid);
      }

      await _firebaseService.addPlant(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
      );

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

        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error in _uploadPlant: $e');

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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
                            decoration: const InputDecoration(
                              labelText: '名前',
                            ),
                            validator: Validators.validatePlantName,
                            enabled: !_isUploading,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          
                          // 説明入力フィールド
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: '説明',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            validator: (value) => Validators.validateRequired(value, '説明'),
                            enabled: !_isUploading,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // 日付入力フィールド
                          TextFormField(
                            controller: _dateController,
                            decoration: const InputDecoration(
                              labelText: '日付',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: _isUploading ? null : () {
                              FocusScope.of(context).requestFocus(FocusNode());
                              _selectDate(context);
                            },
                            validator: (value) => Validators.validateRequired(value, '日付'),
                          ),
                          const SizedBox(height: AppSpacing.md),

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
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            onPressed: (_isUploading || _isLoading) ? null : _showImageSourceDialog,
                            label: _image == null ? '写真を追加' : '写真を変更',
                            icon: Icons.add_photo_alternate,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '対応形式: JPG, PNG, GIF, HEIC',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 100), // 下部のボタン用のスペース
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
                  child: PrimaryButton(
                    onPressed: _isUploading ? null : _uploadPlant,
                    label: _isUploading ? '保存中...' : '植物を追加',
                    icon: _isUploading ? null : Icons.add,
                    isLoading: _isUploading,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
    );
  }
}
