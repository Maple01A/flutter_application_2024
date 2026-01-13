import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

/// バックグラウンドメッセージハンドラー（トップレベル関数として定義）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('バックグラウンドメッセージを受信: ${message.messageId}');
}

/// 通知サービス
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// 通知サービスの初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // ローカル通知の初期化
    await _initializeLocalNotifications();

    // Firebase Messagingの初期化
    await _initializeFirebaseMessaging();

    _isInitialized = true;
  }

  /// ローカル通知の初期化
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Androidの通知チャンネルを作成
    const androidChannel = AndroidNotificationChannel(
      'plant_channel',
      '植物管理',
      description: '植物の管理に関する通知',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Firebase Messagingの初期化
  Future<void> _initializeFirebaseMessaging() async {
    // 通知権限のリクエスト
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('通知権限が許可されました');

      // FCMトークンの取得
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
      }

      // フォアグラウンドメッセージの処理
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // バックグラウンドメッセージの処理
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 通知タップ時の処理
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // アプリが終了状態から通知で開かれた場合の処理
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      print('通知権限が拒否されました');
    }
  }

  /// 通知タップ時の処理
  void _onNotificationTapped(NotificationResponse response) {
    print('通知がタップされました: ${response.payload}');
    // 必要に応じて画面遷移などの処理を追加
  }

  /// フォアグラウンドメッセージの処理
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('フォアグラウンドメッセージを受信: ${message.messageId}');

    if (message.notification != null) {
      await showNotification(
        title: message.notification!.title ?? '通知',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// メッセージ開封時の処理
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('通知から開かれました: ${message.messageId}');
    // 必要に応じて画面遷移などの処理を追加
  }

  /// 即座に通知を表示
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'plant_channel',
      '植物管理',
      channelDescription: '植物の管理に関する通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// スケジュール通知の設定
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'plant_schedule_channel',
      '植物スケジュール',
      channelDescription: '植物のお世話スケジュール通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('通知をスケジュール: $scheduledDate');
  }

  /// イベントに基づいて通知をスケジュール
  Future<void> scheduleEventNotification({
    required String eventId,
    required String plantName,
    required String eventTitle,
    required DateTime eventDate,
  }) async {
    // イベント当日の9時に通知
    final notificationDate = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      9, // 午前9時
      0,
    );

    // 過去の日付の場合はスケジュールしない
    if (notificationDate.isBefore(DateTime.now())) {
      print('過去の日付のため通知をスケジュールしませんでした');
      return;
    }

    await scheduleNotification(
      id: eventId.hashCode,
      title: '${plantName}のお世話',
      body: '今日は「$eventTitle」の予定です',
      scheduledDate: notificationDate,
      payload: eventId,
    );
  }

  /// 特定の通知をキャンセル
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// スケジュール済みの通知一覧を取得
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  /// FCMトークンを取得してFirestoreに保存
  Future<void> saveFCMToken(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCMトークンを保存しました: $token');
      }
    } catch (e) {
      print('FCMトークンの保存に失敗: $e');
    }
  }

  /// トークンの更新を監視
  void listenToTokenRefresh(String userId) {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('FCMトークンが更新されました: $newToken');
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': newToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    });
  }
}