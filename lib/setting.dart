import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2024/main.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Setting extends StatefulWidget {
  final Function(Color) onThemeColorChanged;
  final Function(int) onCrossAxisCountChanged;
  final Color initialColor;
  final int initialCrossAxisCount;

  Setting({
    required this.onThemeColorChanged,
    required this.onCrossAxisCountChanged,
    required this.initialColor,
    required this.initialCrossAxisCount,
  });

  @override
  _Setting createState() => _Setting();
}

class _Setting extends State<Setting> {
  late Color _selectedColor;
  late int _crossAxisCount;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _crossAxisCount = widget.initialCrossAxisCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // ユーザー名変更ボタン
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('ユーザー名の変更'),
            onTap: () => _showChangeUsernameDialog(context),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: _selectedColor),
            title: const Text(
              'テーマカラー',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Container(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  //Text(_getColorName(_selectedColor)),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _selectedColor,
                    radius: 15,
                  ),
                ],
              ),
            ),
            onTap: () async {
              Color? pickedColor = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('テーマカラー'),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: _selectedColor,
                      onColorChanged: (color) {
                        _updateThemeColor(color);
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              );
            },
          ),

          ListTile(
            title: const Text('グリッド列数'),
            trailing: DropdownButton<int>(
              value: _crossAxisCount,
              items: [2, 3].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Container(
                    width: 35,
                    alignment: Alignment.center,
                    child: Text('${value}列'),
                  ),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _crossAxisCount = newValue;
                  });
                  widget.onCrossAxisCountChanged(newValue);
                }
              },
            ),
          ),

          ListTile(
            leading: Icon(Icons.help),
            title: Text('ヘルプ'),
            onTap: () {
              Navigator.pushNamed(context, '/info');
            },
          ),

          // 区切り線を追加
          Divider(thickness: 1),

          // ログアウトボタン
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('ログアウト', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  // ログアウト確認ダイアログを表示する関数
  Future<void> _confirmLogout(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ログアウト確認'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('本当にログアウトしますか？'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ログアウト', style: TextStyle(color: Colors.red)),
              onPressed: () {
                // ここでログアウト処理を実行
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  // ログアウト処理
  void _logout(BuildContext context) {
    // ログアウト処理をここに実装
    // 例: 認証情報のクリア、SharedPreferencesの削除など

    // ログアウト後、ログイン画面に遷移
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

    // ログアウト成功メッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ログアウトしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _updateThemeColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
    widget.onThemeColorChanged(color);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('テーマカラーを変更しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // String _getColorName(Color color) {
  //   if (color == Colors.lightBlueAccent) return '';
  //   if (color == Colors.red) return '';
  //   if (color == Colors.pink) return '';
  //   if (color == Colors.purple) return '';
  //   if (color == Colors.deepPurple) return '';
  //   if (color == Colors.indigo) return '';
  //   if (color == Colors.blue) return '';
  //   if (color == Colors.cyan) return '';
  //   if (color == Colors.teal) return '';
  //   if (color == Colors.green) return '';
  //   if (color == Colors.lightGreen) return '';
  //   if (color == Colors.orange) return '';
  //   if (color == Colors.deepOrange) return '';
  //   if (color == Colors.brown) return '';
  //   if (color == Colors.grey) return '';
  //   return 'カスタム';
  // }

  // ユーザー名変更ダイアログを表示
  Future<void> _showChangeUsernameDialog(BuildContext context) async {
    final TextEditingController usernameController =
        TextEditingController(text: MyApp.userName);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ユーザー名の変更'),
        content: TextField(
          controller: usernameController,
          decoration: InputDecoration(labelText: '新しいユーザー名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              // 入力が空でなければ更新
              if (usernameController.text.trim().isNotEmpty) {
                await _updateUsername(usernameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('更新'),
          ),
        ],
      ),
    );
  }

  // ユーザー名を更新
  Future<void> _updateUsername(String newUsername) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Firebaseユーザープロフィールを更新
      await user.updateDisplayName(newUsername);

      // 2. Firestoreのユーザードキュメントを更新
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': newUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. アプリ内のユーザー名を更新
      setState(() {
        MyApp.userName = newUsername;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザー名を更新しました')),
      );
    } catch (e) {
      print('ユーザー名の更新に失敗しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザー名の更新に失敗しました')),
      );
    }
  }
}
