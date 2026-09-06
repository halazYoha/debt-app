import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  void Function(String? debtorId)? _onSelectNotification;

  Future<void> initialize({void Function(String? debtorId)? onSelectNotification}) async {
    if (onSelectNotification != null) {
      _onSelectNotification = onSelectNotification;
    }

    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _onSelectNotification?.call(response.payload);
        }
      },
    );

    // Check if app was launched by tapping a notification
    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        // Delay slightly to ensure Router navigation context is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _onSelectNotification?.call(payload);
        });
      }
    }

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }

  Future<void> showDebtorReminder({
    required int id,
    required String debtorId,
    required String name,
    required double remainingBalance,
    required int daysSincePayment,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'debt_reminders_channel',
      'የክፍያ ማስታወሻዎች',
      channelDescription: 'ላልከፈሉ ተበዳሪዎች የሚላክ ማስታወሻ',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final title = '⏰ የክፍያ ማስታወሻ — $name';
    final body =
        '$name $daysSincePayment ቀን ሆኖት ምንም አልከፈለም። ቀሪ ዕዳ: ${remainingBalance.toStringAsFixed(2)} ETB';

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: debtorId,
    );
  }
}
