import 'package:flutter/material.dart';
import 'dart:developer';
import 'main.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'utils/error_handler.dart';
import 'utils/validators.dart';
import 'components/buttons/primary_button.dart';
import 'components/buttons/secondary_button.dart';
import 'theme/app_colors.dart';
import 'foundation/spacing.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  // 保存されたログイン情報を確認
  Future<void> _checkSavedLogin() async {
    try {
      final user = _authService.currentUser;
      
      if (user != null) {
        // 既にログイン済み
        final userName = await _authService.getUserName(user.uid);
        MyApp.userName = userName ?? user.displayName ?? user.email?.split('@')[0] ?? "ユーザー";
        
        log("自動ログイン成功: ${user.uid}");
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }
    } catch (e) {
      log("自動ログインチェックエラー: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) return;
    
    setState(() => _isSigningIn = true);
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      final userName = await _authService.getUserName(userCredential.user!.uid);
      MyApp.userName = userName ?? userCredential.user!.displayName ?? userCredential.user!.email?.split('@')[0] ?? "ユーザー";
      
      // FCMトークンを保存
      await NotificationService().saveFCMToken(userCredential.user!.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログイン成功！${MyApp.userName}さん、ようこそ！'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    // フォームバリデーション
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_isSigningIn) return;
    
    setState(() => _isSigningIn = true);

    try {
      final userCredential = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userName = await _authService.getUserName(userCredential.user!.uid);
      MyApp.userName = userName ?? userCredential.user!.email?.split('@')[0] ?? "ユーザー";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログイン成功！${MyApp.userName}さん、ようこそ！'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _continueWithoutLogin() async {
    if (_isSigningIn) return;
    
    setState(() => _isSigningIn = true);

    try {
      await _authService.signInAnonymously();
      
      MyApp.userName = "ゲストユーザー";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ゲストユーザーとしてログインしました'),
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
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
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "メールアドレス",
                      hintText: "guest@flutter.com",
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                    enabled: !_isSigningIn,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: "パスワード",
                      hintText: "password",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: Validators.validatePassword,
                    enabled: !_isSigningIn,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    onPressed: _isSigningIn ? null : _signInWithEmailAndPassword,
                    label: "メールでログイン",
                    icon: Icons.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    onPressed: _isSigningIn ? null : _signInWithGoogle,
                    label: "Googleでログイン",
                    icon: Icons.account_circle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    onPressed: _isSigningIn ? null : _continueWithoutLogin,
                    label: "ログインせずに続行",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("アカウントをお持ちでない方は"),
                      TextButton(
                        onPressed: _isSigningIn ? null : () {
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
      ),
    );
  }
}
