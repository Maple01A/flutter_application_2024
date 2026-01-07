import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';

/// Firebase Storage操作を管理するサービス
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 画像をアップロード
  Future<String> uploadPlantImage(File imageFile, String userId) async {
    try {
      // 画像を圧縮
      final compressedFile = await _compressImage(imageFile);

      // ファイル名を生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = '${userId}_$timestamp$extension';

      // Storageパスを生成
      final ref = _storage.ref().child(AppConstants.plantImagesPath).child(fileName);

      // アップロード
      final uploadTask = ref.putFile(compressedFile);

      // 進行状況を監視（オプション）
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // アップロード完了を待機
      final snapshot = await uploadTask.timeout(
        AppConstants.uploadTimeout,
        onTimeout: () {
          throw Exception('アップロードがタイムアウトしました');
        },
      );

      // ダウンロードURLを取得
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('画像アップロードエラー: $e');
      rethrow;
    }
  }

  /// 画像を削除
  Future<void> deletePlantImage(String imageUrl) async {
    try {
      // URLからStorageリファレンスを取得
      final ref = _storage.refFromURL(imageUrl);

      // 削除
      await ref.delete();
    } catch (e) {
      print('画像削除エラー: $e');
      // 画像が既に削除されている場合はエラーを無視
      if (e is FirebaseException && e.code == 'object-not-found') {
        return;
      }
      rethrow;
    }
  }

  /// 画像を圧縮
  Future<File> _compressImage(File imageFile) async {
    final filePath = imageFile.path;
    final lastIndex = filePath.lastIndexOf('.');
    final splitPath = filePath.substring(0, lastIndex);
    final outPath = '${splitPath}_compressed${path.extension(filePath)}';

    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      outPath,
      quality: AppConstants.imageQuality,
      minWidth: AppConstants.imageMaxDimension,
      minHeight: AppConstants.imageMaxDimension,
    );

    if (result == null) {
      throw Exception('画像の圧縮に失敗しました');
    }

    return File(result.path);
  }

  /// 画像サイズをチェック
  Future<bool> checkImageSize(File imageFile) async {
    final fileSize = await imageFile.length();
    final fileSizeInKB = fileSize / 1024;

    return fileSizeInKB <= AppConstants.maxImageSizeKB;
  }

  /// ファイルサイズを取得（KB単位）
  Future<double> getFileSizeInKB(File file) async {
    final bytes = await file.length();
    return bytes / 1024;
  }

  /// ファイルサイズを人間が読みやすい形式に変換
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Firebase Storageパスからダウンロ��ドURLを取得
  Future<String> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      print('ダウンロードURL取得エラー: $e');
      rethrow;
    }
  }
}
