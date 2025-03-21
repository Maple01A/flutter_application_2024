import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isEmailValid = true;

  Future<void> _signInWithGoogle() async {
    try {
      // Googleサインインフロー
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにログイン
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Googleアカウントからユーザー名を取得
      final displayName = userCredential.user?.displayName;

      // Firestoreにユーザー情報を保存
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': displayName ??
              googleUser.displayName ??
              googleUser.email.split('@')[0],
          'email': googleUser.email,
          'photoUrl': googleUser.photoUrl,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      MyApp.userName = displayName ?? googleUser.displayName ?? "ユーザー";
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('Googleログインエラー: $e');
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスとパスワードを入力してください'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // ログイン中の表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // ログイン成功したユーザーの情報をログ出力
      log("メールでログイン成功: ${userCredential.user?.uid}");
      log("メールアドレス: ${userCredential.user?.email}");

      if (userCredential.user != null) {
        // displayNameの代わりにFirestoreからユーザー情報を取得
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists && userDoc.data()?['name'] != null) {
            MyApp.userName = userDoc.data()?['name'];
          } else {
            // ユーザー情報がない場合はメールアドレスから名前を推測
            MyApp.userName = userCredential.user!.email?.split('@')[0] ?? "ゲスト";
          }
        } catch (e) {
          // Firestoreからの取得に失敗した場合はメールアドレスを使用
          MyApp.userName = userCredential.user!.email?.split('@')[0] ?? "ゲスト";
          print('ユーザー情報取得エラー: $e');
        }

        // ダイアログを閉じる
        Navigator.pop(context);

        // 画面遷移前にわかりやすいメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログイン成功！${MyApp.userName}さん、こんにちは！'),
            duration: const Duration(seconds: 3),
          ),
        );

        // 少し遅延を入れて画面遷移
        Future.delayed(Duration(milliseconds: 500), () {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        });
      }
    } on FirebaseAuthException catch (e) {
      // ダイアログを閉じる
      Navigator.pop(context);

      log("FirebaseAuthException: ${e.code} - ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(e)),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // ダイアログを閉じる
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      log("メールアドレスでのログインエラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('予期せぬエラーが発生しました: $e'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // エラーメッセージを日本語化するヘルパーメソッド
  String _getErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'アカウントが見つかりません';
        case 'wrong-password':
          return 'パスワードが間違っています';
        case 'invalid-email':
          return 'メールアドレスの形式が正しくありません';
        default:
          return 'ログインに失敗しました: ${e.message}';
      }
    }
    return 'エラーが発生しました: $e';
  }

  Future<void> _continueWithoutLogin() async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // 匿名認証でログイン
      UserCredential userCredential = await _auth.signInAnonymously();

      // ユーザー名の設定
      MyApp.userName = "ゲストユーザー";

      // 匿名ユーザーのUID取得
      String anonymousUid = userCredential.user!.uid;

      // デバッグログ
      print("匿名ログイン成功: $anonymousUid");

      // Firestoreにユーザー情報を保存
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(anonymousUid)
            .set({
          'name': 'ゲストユーザー',
          'isAnonymous': true,
          'createdAt': FieldValue.serverTimestamp(),
          //'referenceUserId': '5g7CsADD5qVb4TRgHTPbiN6AXmM2', // 参照用ID
        }, SetOptions(merge: true));
      } catch (e) {
        print("ゲストユーザー情報の保存エラー: $e");
      }

      // ローディング終了
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ゲストユーザーとしてログインしました'),
          duration: Duration(seconds: 3),
        ),
      );

      // ホーム画面に遷移
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // エラー時のローディング終了
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print("匿名ログインエラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ゲストログインに失敗しました: $e'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ログイン"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.eco,
                  size: 120,
                  color: Color.fromARGB(255, 20, 116, 70),
                ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "メールアドレス",
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    setState(() {
                      _isEmailValid =
                          value.contains('@') && value.contains('.');
                    });
                  },
                ),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "パスワード",
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _signInWithEmailAndPassword,
                  icon: const Icon(Icons.email),
                  label: const Text("メールでログイン"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shadowColor: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.account_circle),
                  label: const Text("Googleでログイン"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shadowColor: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _continueWithoutLogin,
                  child: const Text("ログインせずに続行"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                Container(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("アカウントをお持ちでない方は"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: const Text(
                        "新規登録",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
