import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// エラーハンドリング用のユーティリティクラス
class ErrorHandler {
  ErrorHandler._();

  /// エラーメッセージを表示
  static void showError(BuildContext context, dynamic error) {
    final message = getErrorMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 成功メッセージを表示
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 情報メッセージを表示
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// エラーメッセージの取得
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    }

    if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    }

    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    return error.toString();
  }

  /// FirebaseAuth エラーメッセージの取得
  static String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'ユーザーが見つかりません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上推奨）';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく時間をおいてから再度お試しください';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました';
      case 'invalid-credential':
        return '認証情報が無効です';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の方法で既に登録されています';
      default:
        return error.message ?? '認証エラーが発生しました';
    }
  }

  /// Firebase エラーメッセージの取得
  static String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'アクセス権限がありません';
      case 'unavailable':
        return 'サービスが利用できません。しばらく時間をおいてから再度お試しください';
      case 'not-found':
        return 'データが見つかりません';
      case 'already-exists':
        return 'データが既に存在します';
      case 'resource-exhausted':
        return 'リソースの上限に達しました';
      case 'cancelled':
        return '操作がキャンセルされました';
      case 'data-loss':
        return 'データの破損が検出されました';
      case 'unauthenticated':
        return '認証が必要です';
      case 'deadline-exceeded':
        return 'タイムアウトしました';
      default:
        return error.message ?? 'エラーが発生しました';
    }
  }
}
