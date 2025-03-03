import 'package:flutter/material.dart';
import 'package:flutter_application_2024/info.dart';
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
          ListTile(
            title: const Text('テーマカラー'),
            trailing: Container(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_getColorName(_selectedColor)),
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
            title: const Text('グリッド列数'),
            trailing: DropdownButton<int>(
              value: _crossAxisCount,
              items: [2, 3].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Container(
                    width: 60,
                    child: Text('${value}列表示'),
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
              // ヘルプ画面へのナビゲーション
            },
          ),
        ],
      ),
    );
  }

  String _getColorName(Color color) {
    if (color == Colors.lightBlueAccent) return 'ライトブルー';
    if (color == Colors.red) return '赤';
    if (color == Colors.pink) return 'ピンク';
    if (color == Colors.purple) return '紫';
    if (color == Colors.deepPurple) return 'ディープパープル';
    if (color == Colors.indigo) return 'インディゴ';
    if (color == Colors.blue) return '青';
    if (color == Colors.cyan) return 'シアン';
    if (color == Colors.teal) return 'ティール';
    if (color == Colors.green) return '緑';
    if (color == Colors.lightGreen) return 'ライトグリーン';
    if (color == Colors.orange) return 'オレンジ';
    if (color == Colors.deepOrange) return 'ディープオレンジ';
    if (color == Colors.brown) return '茶色';
    if (color == Colors.grey) return 'グレー';
    return 'カスタム';
  }
}
