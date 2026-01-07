/// フォームバリデーション用のユーティリティクラス
class Validators {
  Validators._();

  /// メールアドレスのバリデーション
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'メールアドレスの形式が正しくありません';
    }
    return null;
  }

  /// パスワードのバリデーション
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (value.length < 6) {
      return 'パスワードは6文字以上で入力してください';
    }
    return null;
  }

  /// 必須項目のバリデーション
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldNameを入力してください';
    }
    return null;
  }

  /// 植物名のバリデーション
  static String? validatePlantName(String? value) {
    return validateRequired(value, '植物名');
  }

  /// 説明のバリデーション（オプショナル）
  static String? validateDescription(String? value) {
    if (value != null && value.length > 500) {
      return '説明は500文字以内で入力してください';
    }
    return null;
  }

  /// URLのバリデーション
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // オプショナル
    }
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    );
    if (!urlRegex.hasMatch(value)) {
      return 'URLの形式が正しくありません';
    }
    return null;
  }

  /// 数値のバリデーション（0以上）
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return null; // オプショナル
    }
    final number = int.tryParse(value);
    if (number == null || number < 0) {
      return '$fieldNameは0以上の数値を入力してください';
    }
    return null;
  }
}
