import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';

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

    // JPEGとして圧縮（品質80%）
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
        maxWidth: 1024,  // ピッカーの段階で制限を設定
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
        SnackBar(
          content: Text('画像の選択中にエラーが発生しました。'),
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
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        String? imageUrl;

        if (_image != null) {
          // ファイルサイズをチェック
          int fileSize = await _image!.length();
          if (fileSize > 5 * 1024 * 1024) { // 5MB以上の場合
            throw Exception('画像サイズを5MB以下にしてください）');
          }

          String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
          Reference storageRef = FirebaseStorage.instance.ref().child('plants/$fileName');
          
          // アップロード進捗を表示
          UploadTask uploadTask = storageRef.putFile(_image!);
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('アップロード中: ${progress.toStringAsFixed(1)}%'),
                duration: Duration(seconds: 1),
              ),
            );
          });

          TaskSnapshot taskSnapshot = await uploadTask;
          imageUrl = await taskSnapshot.ref.getDownloadURL();
        }

        // 現在のユーザーIDを取得
        String userId = FirebaseAuth.instance.currentUser?.uid ?? "5g7CsADD5qVb4TRgHTPbiN6AXmM2";

        // Firestoreにデータを保存
        await FirebaseFirestore.instance.collection('plants').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': _dateController.text,
          'images': imageUrl ?? 'https://placehold.jp/300x300.png',
          'userId': userId,
        });

        // 進捗表示を閉じる
        Navigator.pop(context);

        // 追加完了のメッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameController.text}を追加しました')),
        );

        // ホーム画面に戻り、再読み込みを指示
        Navigator.of(context).pop(true);  // trueを返して再読み込みを指示

      } catch (e) {
        // エラー時は進捗表示を閉じる
        Navigator.pop(context);
        
        print('Error uploading plant: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: ${e.toString()}')),
        );

        setState(() {
          _isUploading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('すべての必須入力項目を正しく入力してください')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        _dateController.text = "${picked.toLocal()}".split(' ')[0];
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
                        ? Text('画像')
                        : Image.file(_image!, height: 200),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: SizedBox(
                        width: 200, // ボタンの幅を変更
                        child: ElevatedButton(
                          onPressed: _pickImage,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('画像を選択'),
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
                  width: double.infinity, // ボタンの幅を画面いっぱいに変更
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadPlant,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_isUploading ? 'アップロード中...' : '追加'),
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
