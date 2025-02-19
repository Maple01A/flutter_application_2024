import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Setting extends StatefulWidget {
  final Function(Color) onThemeColorChanged;

  Setting({required this.onThemeColorChanged});

  @override
  _Setting createState() => _Setting();
}

class _Setting extends State<Setting> {
  Color _selectedColor = Colors.greenAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('テーマカラーを選択'),
            trailing: CircleAvatar(
              backgroundColor: _selectedColor,
            ),
            onTap: () async {
              Color? pickedColor = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('テーマカラーを選択'),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: _selectedColor,
                      onColorChanged: (color) {
                        setState(() {
                          _selectedColor = color;
                        });
                        widget.onThemeColorChanged(color);
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
            leading: Icon(Icons.person),
            title: Text('プロフィール'),
            onTap: () {
              // プロフィール設定画面へのナビゲーション
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知設定'),
            onTap: () {
              // 通知設定画面へのナビゲーション
            },
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('プライバシー設定'),
            onTap: () {
              // プライバシー設定画面へのナビゲーション
            },
          ),
          ListTile(
            leading: Icon(Icons.help),
            title: Text('ヘルプ'),
            onTap: () {
              // ヘルプ画面へのナビゲーション
            },
          ),
        ],
      ),
    );
  }
}
