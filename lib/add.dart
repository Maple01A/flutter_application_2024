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

  Future<File> _compressImage(File file) async {
    // 画像ファイルを読み込む
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return file;

    // 画像が1000px以上の場合にリサイズ
    img.Image resizedImage;
    if (image.width > 1024 || image.height > 1024) {
      resizedImage = img.copyResize(
        image,
        width: image.width > image.height ? 1024 : null,
        height: image.height >= image.width ? 1024 : null,
      );
    } else {
      resizedImage = image;
    }

    // JPEGとして圧縮（品質85%）
    final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

    // 圧縮した画像を一時ファイルとして保存
    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/compressed.jpg');
    await tempFile.writeAsBytes(compressedBytes);

    return tempFile;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        // 画像を圧縮
        File compressedFile = await _compressImage(imageFile);

        setState(() {
          _image = compressedFile;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('画像の選択中にエラーが発生しました。\n対応している画像形式: JPG, PNG, GIF, HEIC'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _uploadPlant() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
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

        String? imageUrl;

        if (_image != null) {
          try {
            // オリジナルのファイル名と拡張子を取得
            String originalFileName = _image!.path.split('/').last;
            String extension = originalFileName.split('.').last.toLowerCase();
            String fileName = originalFileName;

            // 対応している拡張子をチェック
            if (!['jpg', 'jpeg', 'png', 'gif', 'heic'].contains(extension)) {
              throw Exception('未対応の画像形式です。JPG, PNG, GIF, HEICのみ対応しています。');
            }

            // ファイルサイズをチェック
            int fileSize = await _image!.length();
            if (fileSize > 5 * 1024 * 1024) {
              throw Exception('画像サイズを5MB以下にしてください');
            }

            // 同名ファイルの場合、タイムスタンプを追加
            if (await _checkFileExists(fileName)) {
              String nameWithoutExtension = fileName.split('.').first;
              fileName =
                  'images/${nameWithoutExtension}_${DateTime.now().millisecondsSinceEpoch}.$extension';
            } else {
              fileName = 'images/$fileName';
            }

            final Reference storageRef =
                FirebaseStorage.instance.ref().child(fileName);

            // コンテンツタイプを設定
            String contentType;
            switch (extension) {
              case 'jpg':
              case 'jpeg':
                contentType = 'image/jpeg';
                break;
              case 'png':
                contentType = 'image/png';
                break;
              case 'gif':
                contentType = 'image/gif';
                break;
              case 'heic':
                contentType = 'image/heic';
                break;
              default:
                contentType = 'image/jpeg';
            }

            // メタデータを設定
            final metadata = SettableMetadata(
              contentType: contentType,
              customMetadata: {
                'originalFileName': originalFileName,
                'uploaded_by':
                    FirebaseAuth.instance.currentUser?.uid ?? 'guest',
              },
            );

            // アップロードタスクを作成して実行
            final UploadTask uploadTask = storageRef.putFile(_image!, metadata);

            // アップロード完了を待つ
            final TaskSnapshot snapshot = await uploadTask;

            // 画像のダウンロードURLを取得
            imageUrl = fileName; // Firestoreには相対パスを保存
            print('Image uploaded successfully. Path: $imageUrl');
          } catch (e) {
            print('Error uploading image: $e');
            throw Exception('画像のアップロードに失敗しました: $e');
          }
        }

        // 現在のユーザーIDを取得
        final String userId = FirebaseAuth.instance.currentUser?.uid ??
            "5g7CsADD5qVb4TRgHTPbiN6AXmM2";

        // Firestoreにデータを保存
        await FirebaseFirestore.instance.collection('plants').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': _dateController.text,
          'images': imageUrl ?? 'https://placehold.jp/300x300.png',
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ローディングダイアログを閉じる
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // 追加完了のメッセージを表示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_nameController.text}を追加しました')),
          );
        }

        // 少し待ってからホーム画面に戻る
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        print('Error in _uploadPlant: $e');

        // ローディングダイアログを閉じる
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラーが発生しました: ${e.toString()}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }

        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // 同名ファイルの存在チェック
  Future<bool> _checkFileExists(String fileName) async {
    try {
      await FirebaseStorage.instance.ref('images/$fileName').getDownloadURL();
      return true; // ファイルが存在する
    } catch (e) {
      return false; // ファイルが存在しない
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}年${picked.month}月${picked.day}日";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新しい植物を追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: '名前'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '名前を入力してください';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: '説明'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '説明を入力してください';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(labelText: '日付'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '日付を入力してください';
                        }
                        return null;
                      },
                      onTap: () async {
                        FocusScope.of(context).requestFocus(new FocusNode());
                        await _selectDate(context);
                      },
                    ),
                    const SizedBox(height: 16),
                    _image == null
                        ? Column(
                            children: const [
                              Text('画像を選択してください'),
                              SizedBox(height: 8),
                            ],
                          )
                        : Image.file(_image!, height: 200),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _pickImage,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_isUploading ? '画像選択中...' : '画像を選択'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56, // ボタンの高さを固定
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadPlant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 3, // 影の深さ
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28), // より丸みを持たせる
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 24.0,
                      ),
                    ),
                    child: Text(
                      _isUploading ? 'アップロード中...' : '追加',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2, // 文字間隔を少し広げる
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
