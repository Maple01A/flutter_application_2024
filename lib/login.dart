import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';
import 'main.dart'; // MyAppクラスをインポート

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _signInWithGoogle() async {
    try {
      // Googleサインインを実行
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return; // ユーザーがキャンセルした場合
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebaseの認証用Credentialを取得
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにログイン
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      log("Googleユーザーとしてログイン: ${userCredential.user?.displayName}");
      MyApp.userName = userCredential.user?.displayName ?? "ゲスト"; // ユーザー名を設定
      Navigator.pushReplacementNamed(context, '/home'); // ホーム画面に遷移
    } catch (e) {
      log("Googleログインエラー: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("ログインエラー"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      log("メールアドレスでログイン: ${userCredential.user?.email}");
      MyApp.userName = userCredential.user?.email ?? "ゲスト"; // ユーザー名を設定
      Navigator.pushReplacementNamed(context, '/home'); // ホーム画面に遷移
    } catch (e) {
      log("メールアドレスでのログインエラー: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("ログインエラー"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void _continueWithoutLogin() {
    MyApp.userName = "ゲスト"; // ユーザー名を「ゲスト」に設定
    Navigator.pushReplacementNamed(context, '/home'); // ホーム画面に遷移
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
              decoration: const InputDecoration(labelText: "メールアドレス"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "パスワード"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _signInWithEmailAndPassword,
              icon: const Icon(Icons.email), // メールアイコンを追加
              label: const Text("メールでログイン"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shadowColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 16, width: 16,),
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
          ],
        ),
      ),
    );
  }
}
