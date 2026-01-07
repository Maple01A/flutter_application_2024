/// アプリケーション全体で使用する定数
class AppConstants {
  AppConstants._();

  // Firebase Collection名
  static const String plantsCollection = 'plants';
  static const String usersCollection = 'users';
  static const String favoritesCollection = 'favorites';
  static const String calendarEventsCollection = 'calendarEvents';

  // Storage パス
  static const String plantImagesPath = 'plant_images';

  // 画像設定
  static const int maxImageSizeKB = 500;
  static const int imageMaxDimension = 1024;
  static const int imageQuality = 85;

  // デフォルト値
  static const String defaultImageUrl = 'https://placehold.jp/300x300.png';
  static const String guestUserName = 'ゲストユーザー';
  static const String defaultUserName = 'ゲスト';

  // ページネーション
  static const int plantsPerPage = 10;
  static const int plantsPerRow = 2;

  // アニメーション時間
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // タイムアウト
  static const Duration uploadTimeout = Duration(minutes: 2);
  static const Duration apiTimeout = Duration(seconds: 30);
}
