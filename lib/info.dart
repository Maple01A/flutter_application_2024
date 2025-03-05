import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class Info extends StatefulWidget {
  @override
  _Info createState() => _Info();
}

class _Info extends State<Info> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // 改善点1: メール送信機能のセキュリティ強化
  Future<void> _sendEmail(String name, String email, String message) async {
    // 機密情報をコード内に含めないよう注意
    // 環境変数や安全な認証方法を使用すべき
    final smtpServer = gmail(
        'your-email@gmail.com', 'your-email-password'); // セキュリティリスク！

    // 改善案: LoadingIndicatorを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("送信中..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      // メール送信処理
      final mailMessage = Message()
        ..from = Address(email, name)
        ..recipients.add('dendounglau@gmail.com')
        ..subject = 'お問い合わせ'
        ..text = '名前: $name\nメールアドレス: $email\nメッセージ:\n$message';

      final sendReport = await send(mailMessage, smtpServer);
      Navigator.pop(context); // ローディング閉じる

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お問い合わせを送信しました')),
      );

      // フォームをリセット
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();

    } catch (e) {
      Navigator.pop(context); // ローディング閉じる

      // エラーメッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // フォームが有効な場合、問い合わせ内容を送信する処理を追加
      final name = _nameController.text;
      final email = _emailController.text;
      final message = _messageController.text;

      // メールを送信
      _sendEmail(name, email, message);

      // フォームをリセット
      _formKey.currentState!.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お問い合わせ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名前'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'メッセージ'),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メッセージを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('送信'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
