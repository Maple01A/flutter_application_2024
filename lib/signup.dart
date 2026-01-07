import 'package:flutter/material.dart';
import 'main.dart';
import 'services/auth_service.dart';
import 'utils/error_handler.dart';
import 'utils/validators.dart';
import 'components/buttons/primary_button.dart';
import 'theme/app_colors.dart';
import 'foundation/spacing.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        MyApp.userName = _nameController.text.trim();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('アカウントを作成しました！'),
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント登録'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco,
                          size: 120,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "お名前",
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) => Validators.validateRequired(value, 'ユーザー名'),
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "メールアドレス",
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: "パスワード",
                            prefixIcon: const Icon(Icons.lock),
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
                          validator: Validators.validatePassword,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        PrimaryButton(
                          onPressed: _isLoading ? null : _signUp,
                          label: "アカウント登録",
                          icon: Icons.person_add,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("すでにアカウントをお持ちの方は"),
                            TextButton(
                              onPressed: _isLoading ? null : () {
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
            ),
    );
  }
}
