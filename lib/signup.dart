import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // パスワード表示の切り替え
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // サインアップ処理を修正（プロファイル更新をスキップ）
  Future<void> _signUp() async {
    // バリデーションチェック（既存のコード）
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お名前を入力してください')),
      );
      return;
    }

    // メールとパスワードのチェック（既存のコード）
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メールアドレスを入力してください')),
      );
      return;
    }

    if (_passwordController.text.isEmpty ||
        _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('パスワードは6文字以上で入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebaseでユーザー登録
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // ユーザープロフィールを更新
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      print('Firebase認証ユーザー登録成功: ${userCredential.user!.uid}');

      // ユーザー情報をFirestoreに保存
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        print('Firestoreにユーザー情報を保存しました');
      } catch (firestoreError) {
        print('Firestoreへの保存エラー: $firestoreError');
        // Firestoreへの保存に失敗してもアカウント自体は作成されているので続行
      }

      // グローバルなユーザー名を更新
      MyApp.userName = _nameController.text.trim();

      // 成功したらログイン画面に戻る
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アカウントを作成しました！'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 少し待ってから遷移
      await Future.delayed(Duration(milliseconds: 1000));

      // すべての画面をクリアしてログイン画面に遷移（最も確実）
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase認証エラー: ${e.code} - ${e.message}');
      // エラーメッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getErrorMessage(e))),
        );
      }
    } catch (e) {
      print('予期せぬエラー詳細: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // エラーメッセージを日本語化
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'weak-password':
        return 'パスワードは6文字以上で設定してください';
      default:
        return '登録中にエラーが発生しました: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('アカウント登録'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
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

                      SizedBox(height: 16),

                      // 名前入力フィールド
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "お名前",
                          prefixIcon: Icon(Icons.person),
                          border: InputBorder.none,
                          filled: true, // 背景色を設定
                          fillColor: Color(0xFFF5F5F5),
                        ),
                      ),

                      SizedBox(height: 16),

                      // メール入力フィールド
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "メールアドレス",
                          prefixIcon: Icon(Icons.email),
                          border: InputBorder.none,
                          filled: true, // 背景色を設定
                          fillColor: Color(0xFFF5F5F5),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),

                      SizedBox(height: 16),

                      // パスワード入力フィールド
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "パスワード",
                          prefixIcon: Icon(Icons.lock),
                          border: InputBorder.none,
                          filled: true, // 背景色を設定
                          fillColor: Color(0xFFF5F5F5),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscureText,
                      ),

                      const SizedBox(height: 16),

                      // ボタンをセンタリング
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _signUp,
                          label: const Text("アカウント登録"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shadowColor: Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ログイン画面へのリンク
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("すでにアカウントをお持ちの方は"),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "ログイン",
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
