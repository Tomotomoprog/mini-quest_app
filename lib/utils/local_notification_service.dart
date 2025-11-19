import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // 初期化処理
  static Future<void> init() async {
    // タイムゾーンの初期化
    tz.initializeTimeZones();
    // 日本時間に設定 (必要に応じて)
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android設定
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  // 毎日20時に通知をスケジュールする
  static Future<void> scheduleDailyNotification() async {
    // 通知の日時設定 (今日の20:00)
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 時 (20時)
      0, // 分
    );

    // もし今日の20時を過ぎていたら、明日の20時に設定
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 通知の詳細設定
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel', // チャンネルID
      'デイリーリマインダー', // チャンネル名
      channelDescription: '毎日の記録リマインダーです',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // スケジュール登録
    await _notifications.zonedSchedule(
      0, // 通知ID (同じIDを使うと上書きされる)
      'お疲れ様です！', // タイトル
      '今日の頑張りを記録しよう！', // 本文
      scheduledDate,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // ★ここ重要: 時間だけ一致したら毎日繰り返す
    );

    print("毎日20時の通知をセットしました: $scheduledDate");
  }
}
