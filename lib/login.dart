import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      // Googleサインインを実行
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return; // ユーザーがキャンセルした場合
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebaseの認証用Credentialを取得
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにログイン
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      log("Googleユーザーとしてログイン: ${userCredential.user?.displayName}");
      MyApp.userName = userCredential.user?.displayName ?? "ゲスト"; // ユーザー名を設定
      Navigator.pushReplacementNamed(context, '/home'); 
    } on FirebaseAuthException catch (e) {
      // FirebaseAuth特有のエラー処理
      log("Googleログインエラー (Firebase): ${e.code} - ${e.message}");
      _showErrorDialog("認証エラー", e.message ?? "認証に失敗しました");
    } catch (e) {
      // その他の例外処理
      log("Googleログインエラー: $e");
      _showErrorDialog("ログインエラー", "ログイン処理中にエラーが発生しました");
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスとパスワードを入力してください'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // ユーザー名の設定を修正
      MyApp.userName = userCredential.user?.email?.split('@')[0] ??
          "ゲスト"; // メールアドレスのユーザー名部分を使用

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      log("メールアドレスでのログインエラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(e)),
          duration: const Duration(seconds: 3),
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

  void _continueWithoutLogin() {
    MyApp.userName = "5g7CsADD5qVb4TRgHTPbiN6AXmM2"; // 指定されたUIDを設定
    Navigator.pushReplacementNamed(context, '/home');
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(
              size: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "メールアドレス",
                prefixIcon: Icon(Icons.email),
                errorStyle: TextStyle(color: Colors.red),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                setState(() {
                  _isEmailValid = value.contains('@') && value.contains('.');
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
            const SizedBox(
              height: 16,
              width: 16,
            ),
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
            
            // サインアップボタンを追加
            const SizedBox(height: 24),
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
    );
  }
}
