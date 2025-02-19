import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
              size: 100, // アイコンのサイズを指定
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: "メールアドレス"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "パスワード"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              icon: const FlutterLogo(), // Flutterのアイコンを追加
              label: const Text("ログイン"),
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
          ],
        ),
      ),
    );
  }
}
