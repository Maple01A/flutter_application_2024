import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // アプリ起動時に自動ログインを試みる
    _checkSavedLogin();
  }

  // 保存されたログイン情報を確認
  Future<void> _checkSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('user_email');
      final savedPassword = prefs.getString('user_password');

      // 匿名ユーザーとしてログイン済みかチェック
      if (prefs.getBool('anonymous_login') == true) {
        if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
          log("匿名ユーザーとして自動ログイン");
          MyApp.userName = "ゲストユーザー";
          setState(() => _isLoading = false);
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }

      // Google認証で既にログイン済みかチェック
      if (prefs.getBool('google_login') == true) {
        final currentUser = _auth.currentUser;
        if (currentUser != null && !currentUser.isAnonymous) {
          try {
            // Firestoreからユーザー情報を取得
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

            if (userDoc.exists && userDoc.data()?['name'] != null) {
              MyApp.userName = userDoc.data()?['name'];
            } else {
              MyApp.userName = currentUser.displayName ??
                  currentUser.email?.split('@')[0] ??
                  "ユーザー";
            }

            log("Google認証による自動ログイン成功: ${currentUser.uid}");
            setState(() => _isLoading = false);
            Navigator.pushReplacementNamed(context, '/home');
            return;
          } catch (e) {
            log("保存されたGoogle認証情報の取得エラー: $e");
          }
        }
      }

      // メールとパスワードが保存されている場合は自動ログイン
      if (savedEmail != null && savedPassword != null) {
        log("保存されたログイン情報を発見、自動ログインを試みます");

        try {
          final UserCredential userCredential =
              await _auth.signInWithEmailAndPassword(
            email: savedEmail,
            password: savedPassword,
          );

          if (userCredential.user != null) {
            // Firestoreからユーザー情報を取得
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

            if (userDoc.exists && userDoc.data()?['name'] != null) {
              MyApp.userName = userDoc.data()?['name'];
            } else {
              MyApp.userName =
                  userCredential.user!.email?.split('@')[0] ?? "ユーザー";
            }

            log("保存された認証情報による自動ログイン成功: ${userCredential.user?.uid}");
            Navigator.pushReplacementNamed(context, '/home');
            return;
          }
        } catch (e) {
          log("自動ログイン失敗: $e");
          // 認証情報が無効な場合は保存データを削除
          await prefs.remove('user_email');
          await prefs.remove('user_password');
        }
      }
    } catch (e) {
      log("自動ログインチェックエラー: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ログイン情報を保存する関数
  Future<void> _saveLoginInfo(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_password', password);
    await prefs.setBool('anonymous_login', false);
    await prefs.setBool('google_login', false);
    log("ログイン情報を保存しました");
  }

  // Googleログイン情報を保存
  Future<void> _saveGoogleLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_login', true);
    await prefs.setBool('anonymous_login', false);
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    log("Googleログイン情報を保存しました");
  }

  // 匿名ログイン情報を保存
  Future<void> _saveAnonymousLoginInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('anonymous_login', true);
    await prefs.setBool('google_login', false);
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    log("匿名ログイン情報を保存しました");
  }

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
      // Googleログイン情報の保存
      await _saveGoogleLoginInfo();
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

      // ログイン情報を保存
      await _saveLoginInfo(_emailController.text, _passwordController.text);

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
            content: Text('ログイン成功！${MyApp.userName}さん、ようこそ！'),
            duration: const Duration(seconds: 2),
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
    } catch (e) {
      // ダイアログを閉じる
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      log("メールアドレスでのログインエラー: $e");    }
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

      // 匿名ログイン情報を保存
      await _saveAnonymousLoginInfo();

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
          duration: Duration(seconds: 2),
        ),
      );

      // ホーム画面に遷移
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // エラー時のローディング終了
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("ログイン状態を確認中...")
            ],
          ),
        ),
      );
    }
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
                    labelText: "DEMOの場合：guest@flutter.com",
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
                    labelText: "DEMOの場合：password",
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
