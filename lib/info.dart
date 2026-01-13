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
  bool _isLoading = false; // ローディング状態の管理用変数

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // メール送信機能のセキュリティ強化
  Future<void> _sendEmail(String name, String email, String message) async {
    // ローディング状態を開始
    setState(() {
      _isLoading = true;
    });

    // 機密情報をコード内に含めないよう注意
    // 環境変数や安全な認証方法を使用すべき
    final smtpServer =
        gmail('your-email@gmail.com', 'your-email-password');

    try {
      // メール送信処理
      final mailMessage = Message()
        ..from = Address(email, name)
        ..recipients.add('dendounglau@gmail.com')
        ..subject = 'お問い合わせ'
        ..text = '名前: $name\nメールアドレス: $email\nメッセージ:\n$message';

      final sendReport = await send(mailMessage, smtpServer);

      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お問い合わせを送信しました')),
      );

      // フォームをリセット
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
    } catch (e) {
      // エラーメッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    } finally {
      // ローディング状態を終了
      setState(() {
        _isLoading = false;
      });
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お問い合わせ'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 120,
                          color: Color.fromARGB(255, 20, 116, 70),
                        ),

                        SizedBox(height: 24),

                        // 名前入力フィールド
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "お名前",
                            prefixIcon: Icon(Icons.person),
                            border: InputBorder.none,
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '名前を入力してください';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 16),

                        // メール入力フィールド
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "メールアドレス",
                            prefixIcon: Icon(Icons.email),
                            border: InputBorder.none,
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'メールアドレスを入力してください';
                            }
                            return null;
                          },
                        ),

                        SizedBox(height: 16),

                        // メッセージ入力フィールド
                        TextFormField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: "メッセージ",
                            prefixIcon: Icon(Icons.message),
                            border: InputBorder.none,
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                          ),
                          maxLines: 3, // 縦の高さを変更
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'メッセージを入力してください';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _submitForm,
                            icon: Icon(Icons.send),
                            label: const Text("送信する"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shadowColor: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
