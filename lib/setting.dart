import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Setting extends StatefulWidget {
  final Function(Color) onThemeColorChanged;
  final Function(int) onCrossAxisCountChanged;

  Setting({required this.onThemeColorChanged, required this.onCrossAxisCountChanged});

  @override
  _Setting createState() => _Setting();
}

class _Setting extends State<Setting> {
  Color _selectedColor = Colors.lightBlueAccent;
  int _crossAxisCount = 2;

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
            title: const Text('グリッド列数を選択'),
            trailing: DropdownButton<int>(
              value: _crossAxisCount,
              items: [2, 3, 4].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
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
              // ヘルプ画面へのナビゲーション
            },
          ),
        ],
      ),
    );
  }
}
