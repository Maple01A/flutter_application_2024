import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadPlant() async {
    if (_formKey.currentState!.validate() && _image != null) {
      try {
        // Firebase Storageに画像をアップロード
        String fileName = _image!.path.split('/').last;
        Reference storageRef = FirebaseStorage.instance.ref().child('plants/$fileName');
        UploadTask uploadTask = storageRef.putFile(_image!);
        TaskSnapshot taskSnapshot = await uploadTask;
        String imageUrl = await taskSnapshot.ref.getDownloadURL();

        // Firestoreにデータを保存
        await FirebaseFirestore.instance.collection('plants').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': _dateController.text,
          'images': imageUrl,
        });

        Navigator.pop(context, {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': _dateController.text,
          'images': imageUrl,
        });
      } catch (e) {
        print('Error uploading plant: $e');
      }
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
              ),
              const SizedBox(height: 16),
              _image == null
                  ? Text('画像を選択してください')
                  : Image.file(_image!, height: 200),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('画像を選択'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _uploadPlant,
                child: Text('追加'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
