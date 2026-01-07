import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Firebase Authentication操作を管理するサービス
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  /// 認証状態の変更をストリームで監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// メールアドレスとパスワードでログイン
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // ログイン情報を保存（オプション）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);

    return userCredential;
  }

  /// メールアドレスとパスワードでサインアップ
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // ユーザー情報を更新
    if (displayName != null) {
      await userCredential.user?.updateDisplayName(displayName);
    }

    // Firestoreにユーザー情報を保存
    if (userCredential.user != null) {
      await _saveUserToFirestore(
        userCredential.user!.uid,
        displayName ?? email.split('@')[0],
        email,
      );
    }

    return userCredential;
  }

  /// Googleアカウントでログイン
  Future<UserCredential> signInWithGoogle() async {
    // Googleサインインフローを開始
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Googleサインインがキャンセルされました');
    }

    // 認証情報を取得
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // 認証情報からクレデンシャルを作成
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Firebaseにサインイン
    final userCredential = await _auth.signInWithCredential(credential);

    // Firestoreにユーザー情報を保存
    if (userCredential.user != null) {
      await _saveUserToFirestore(
        userCredential.user!.uid,
        userCredential.user!.displayName ?? 'ユーザー',
        userCredential.user!.email ?? '',
      );

      // Google ログインフラグを保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_login', true);
    }

    return userCredential;
  }

  /// 匿名ログイン
  Future<UserCredential> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();

    // Firestoreにユーザー情報を保存
    if (userCredential.user != null) {
      await _saveUserToFirestore(
        userCredential.user!.uid,
        AppConstants.guestUserName,
        '',
      );

      // 匿名ログインフラグを保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('anonymous_login', true);
    }

    return userCredential;
  }

  /// ログアウト
  Future<void> signOut() async {
    // SharedPreferencesをクリア
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    await prefs.setBool('google_login', false);
    await prefs.setBool('anonymous_login', false);
    await prefs.remove('cachedUserName');

    // Googleサインアウト
    await _googleSignIn.signOut();

    // Firebaseサインアウト
    await _auth.signOut();
  }

  /// パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// ユーザー情報をFirestoreに保存
  Future<void> _saveUserToFirestore(
    String uid,
    String name,
    String email,
  ) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Firestoreからユーザー名を取得
  Future<String?> getUserName(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return doc.data()?['name'] as String?;
      }
    } catch (e) {
      print('ユーザー名取得エラー: $e');
    }
    return null;
  }

  /// ユーザー名を更新
  Future<void> updateUserName(String uid, String name) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 認証情報も更新
    await currentUser?.updateDisplayName(name);
  }

  /// アカウント削除
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('ユーザーが認証されていません');

    // Firestoreのユーザーデータを削除
    await _firestore.collection(AppConstants.usersCollection).doc(user.uid).delete();

    // ユーザーの植物データを削除
    final plantsSnapshot = await _firestore
        .collection(AppConstants.plantsCollection)
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var doc in plantsSnapshot.docs) {
      await doc.reference.delete();
    }

    // アカウントを削除
    await user.delete();
  }
}
