import 'package:cloud_firestore/cloud_firestore.dart';

/// 植物データモデル
class Plant {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isFavorite;
  final Map<String, dynamic>? metadata;

  Plant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.metadata,
  });

  /// Firestoreドキュメントから植物オブジェクトを作成
  factory Plant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Plant(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      imageUrl: data['imageUrl'],
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isFavorite: data['isFavorite'] ?? false,
      metadata: data['metadata'],
    );
  }

  /// MapからPlantオブジェクトを作成
  factory Plant.fromMap(Map<String, dynamic> map, String id) {
    return Plant(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      imageUrl: map['imageUrl'],
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isFavorite: map['isFavorite'] ?? false,
      metadata: map['metadata'],
    );
  }

  /// Firestore保存用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isFavorite': isFavorite,
      'metadata': metadata,
    };
  }

  /// 植物オブジェクトのコピーを作成（一部のフィールドを更新）
  Plant copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    Map<String, dynamic>? metadata,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Plant(id: $id, name: $name, userId: $userId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Plant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
