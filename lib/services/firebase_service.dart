import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant.dart';
import '../utils/constants.dart';

/// Firebase Firestore操作を管理するサービス
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// 植物データの取得
  Future<List<Plant>> getPlants() async {
    final user = currentUser;
    if (user == null) throw Exception('未認証です');

    final snapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList();
  }

  /// 植物データのストリーム取得
  Stream<List<Plant>> getPlantsStream() {
    final user = currentUser;
    if (user == null) throw Exception('未認証です');

    return _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList());
  }

  /// 特定の植物データを取得
  Future<Plant?> getPlant(String plantId) async {
    final doc = await _firestore
        .collection(AppConstants.plantsCollection)
        .doc(plantId)
        .get();

    if (!doc.exists) return null;
    return Plant.fromFirestore(doc);
  }

  /// 植物データの追加
  Future<String> addPlant({
    required String name,
    String? description,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('未認証です');

    final plant = Plant(
      id: '',
      name: name,
      description: description,
      imageUrl: imageUrl,
      userId: user.uid,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    final docRef = await _firestore
        .collection(AppConstants.plantsCollection)
        .add(plant.toMap());

    return docRef.id;
  }

  /// 植物データの更新
  Future<void> updatePlant(String plantId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection(AppConstants.plantsCollection)
        .doc(plantId)
        .update(updates);
  }

  /// 植物データの削除
  Future<void> deletePlant(String plantId) async {
    await _firestore
        .collection(AppConstants.plantsCollection)
        .doc(plantId)
        .delete();
  }

  /// お気に入り状態の切り替え
  Future<void> toggleFavorite(String plantId, bool isFavorite) async {
    await updatePlant(plantId, {'isFavorite': !isFavorite});
  }

  /// お気に入り植物の取得
  Future<List<Plant>> getFavoritePlants() async {
    final user = currentUser;
    if (user == null) throw Exception('未認証です');

    final snapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: user.uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList();
  }

  /// カレンダーイベントの取得
  Future<Map<DateTime, List<dynamic>>> getCalendarEvents(String plantId) async {
    final snapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .doc(plantId)
        .collection(AppConstants.calendarEventsCollection)
        .get();

    final Map<DateTime, List<dynamic>> events = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final dateKey = DateTime(date.year, date.month, date.day);

      if (events[dateKey] == null) {
        events[dateKey] = [];
      }
      events[dateKey]!.add(data);
    }

    return events;
  }

  /// カレンダーイベントの追加
  Future<void> addCalendarEvent(
    String plantId,
    DateTime date,
    Map<String, dynamic> eventData,
  ) async {
    eventData['date'] = Timestamp.fromDate(date);
    eventData['createdAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection(AppConstants.plantsCollection)
        .doc(plantId)
        .collection(AppConstants.calendarEventsCollection)
        .add(eventData);
  }

  /// 植物の検索
  Future<List<Plant>> searchPlants(String query) async {
    final user = currentUser;
    if (user == null) throw Exception('未認証です');

    final snapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('name')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .get();

    return snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList();
  }

  /// ユーザー名の取得
  Future<String?> getUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['name'] != null) {
        return doc.data()?['name'];
      }
      return null;
    } catch (e) {
      print('ユーザー名取得エラー: $e');
      return null;
    }
  }

  /// ユーザー名の保存
  Future<void> saveUserName(String uid, String name) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 植物データの取得（Map形式）- main.dartとの互換性のため
  Future<List<Map<String, dynamic>>> getPlantsAsMap(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// 今日のイベント一括取得
  Future<List<Map<String, dynamic>>> getTodayEvents(
    String userId,
    List<String> plantIds,
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('plantEvents')
        .where('plantId', whereIn: plantIds)
        .where('eventDate', isGreaterThanOrEqualTo: startOfDay)
        .where('eventDate', isLessThanOrEqualTo: endOfDay)
        .get();

    return querySnapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  /// お気に入り削除
  Future<void> removeFavorite(String userId, String favoriteId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(favoriteId)
        .delete();
  }

  /// PlantIDでお気に入り削除
  Future<void> removeFavoriteByPlantId(String userId, String plantId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .where('plantId', isEqualTo: plantId)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// お気に入り植物の詳細付き取得
  Future<List<Map<String, dynamic>>> getFavoritePlantsWithDetails(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();

    final List<Map<String, dynamic>> loadedPlants = [];

    for (var doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;

      // 植物の詳細情報を取得
      if (data['plantId'] != null) {
        try {
          final plantDoc = await _firestore
              .collection('plants')
              .doc(data['plantId'])
              .get();

          if (plantDoc.exists) {
            final plantData = Map<String, dynamic>.from(plantDoc.data()!);
            String favoriteId = data['id'];

            data.clear();
            data.addAll(plantData);
            data['id'] = favoriteId;
            data['plantId'] = plantData['id'] ?? plantDoc.id;
          }
        } catch (e) {
          print('植物詳細情報の取得エラー: $e');
        }
      }

      loadedPlants.add(data);
    }

    return loadedPlants;
  }

  /// 植物のイベント取得
  Future<List<Map<String, dynamic>>> getPlantEvents(
    String userId,
    String plantId, {
    bool sortByDate = true,
  }) async {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('plantEvents')
        .where('plantId', isEqualTo: plantId);

    if (sortByDate) {
      query = query.orderBy('eventDate', descending: false);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      
      // Timestamp変換
      if (data['eventDate'] is Timestamp) {
        data['eventDate'] = (data['eventDate'] as Timestamp).toDate();
      }
      
      return data;
    }).toList();
  }

  /// お気に入りの存在確認
  Future<bool> checkFavoriteExists(String userId, String favoriteId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(favoriteId)
        .get();
    return doc.exists;
  }

  /// PlantIDからFavoriteIDを取得
  Future<String?> getFavoriteIdByPlantId(String userId, String plantId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .where('plantId', isEqualTo: plantId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  /// お気に入りに追加
  Future<DocumentReference> addToFavorites(String userId, Map<String, dynamic> favoriteData) async {
    return await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .add(favoriteData);
  }
}
