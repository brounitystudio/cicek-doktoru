import 'dart:convert';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/care_task.dart';
import 'language_service.dart';

enum NotificationPermissionState { authorized, denied, notDetermined }

class NotificationNavigationIntent {
  const NotificationNavigationIntent({
    required this.kind,
    this.taskId,
    this.plantId,
  });

  final String kind;
  final String? taskId;
  final String? plantId;

  bool get isCareReminder => kind == 'care';
}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initialization;
  ValueChanged<NotificationNavigationIntent>? _navigationHandler;
  NotificationNavigationIntent? _pendingNavigationIntent;
  static const _wateringCalculatorRemindersKey =
      'watering_calculator_reminders';
  static const _scheduledCareReminderIdsKey = 'scheduled_care_reminder_ids';
  static const _scheduledEngagementReminderIdsKey =
      'scheduled_engagement_reminder_ids_v1';

  Future<bool> ensureAutomaticReminders(List<CareTask> tasks) async {
    await initialize();
    var permission = await permissionState();
    if (permission == NotificationPermissionState.notDetermined) {
      final granted = await requestPermission();
      permission = granted
          ? NotificationPermissionState.authorized
          : NotificationPermissionState.denied;
    }
    if (permission != NotificationPermissionState.authorized) {
      return false;
    }

    await scheduleCareReminders(tasks);
    await _scheduleEngagementReminders();
    return true;
  }

  Future<void> initialize({
    ValueChanged<NotificationNavigationIntent>? onNotificationTap,
  }) async {
    if (onNotificationTap != null) {
      _navigationHandler = onNotificationTap;
      _flushPendingNavigationIntent();
    }
    if (_initialized) {
      return;
    }
    final currentInitialization = _initialization;
    if (currentInitialization != null) {
      await currentInitialization;
      return;
    }

    final initialization = _initializePlugin();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initializePlugin() async {
    tz.initializeTimeZones();
    await _configureDeviceTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    try {
      await registerDeviceToken();
    } catch (error) {
      debugPrint('Push token registration skipped: $error');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handlePayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<void> _configureDeviceTimezone() async {
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (error) {
      debugPrint('Device timezone lookup failed, using UTC: $error');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<NotificationPermissionState> permissionState() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => NotificationPermissionState.authorized,
      AuthorizationStatus.denied => NotificationPermissionState.denied,
      _ => NotificationPermissionState.notDetermined,
    };
  }

  Future<bool> requestPermission() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> openNotificationSettings() {
    return AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  Future<void> registerDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _sendTokenToBackend(token);
  }

  Future<void> _sendTokenToBackend(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('registerDeviceToken');
      await callable.call<Map<String, dynamic>>({
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
    } catch (error) {
      debugPrint('Push token backend registration failed: $error');
    }
  }

  Future<bool> scheduleCareReminders(
    List<CareTask> tasks, {
    bool requestPermissionIfNeeded = false,
  }) async {
    await initialize();
    var permission = await permissionState();
    if (permission != NotificationPermissionState.authorized &&
        requestPermissionIfNeeded) {
      final granted = await requestPermission();
      permission = granted
          ? NotificationPermissionState.authorized
          : NotificationPermissionState.denied;
    }
    if (permission != NotificationPermissionState.authorized) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final previousIds =
        prefs.getStringList(_scheduledCareReminderIdsKey) ?? const [];
    for (final value in previousIds) {
      final id = int.tryParse(value);
      if (id != null) {
        await _plugin.cancel(id: id);
      }
    }

    final now = DateTime.now();
    final localScheduleThreshold = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(minutes: 2));
    final upcoming = tasks
        .where((task) => !task.completed)
        .where(
          (task) =>
              _careReminderTime(task.dueDate).isAfter(localScheduleThreshold),
        )
        .take(20)
        .toList();

    for (final task in upcoming) {
      final notificationId = _notificationId(task);
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Çiçek Doktoru',
        body: task.title,
        scheduledDate: _careReminderTime(task.dueDate),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders',
            'Bakım hatırlatıcıları',
            channelDescription: 'Sulama, kontrol ve bitki bakım günleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({
          'kind': 'care',
          'taskId': task.id,
          'plantId': task.plantId,
        }),
      );
    }

    await prefs.setStringList(
      _scheduledCareReminderIdsKey,
      upcoming.map(_notificationId).map((id) => '$id').toList(),
    );

    await _scheduleSavedWateringCalculatorReminders(now);
    return true;
  }

  Future<bool> scheduleWateringCalculatorReminder({
    required String plantName,
    required DateTime dueDate,
    required int amountMl,
    required String intervalText,
  }) async {
    await initialize();
    final granted = await requestPermission();
    final prefs = await SharedPreferences.getInstance();
    final reminders =
        prefs.getStringList(_wateringCalculatorRemindersKey) ?? [];
    final id = _wateringCalculatorId(plantName);
    reminders.removeWhere((item) => item.startsWith('$id|'));
    reminders.add(
      [
        id,
        plantName.replaceAll('|', ' '),
        dueDate.toIso8601String(),
        amountMl.toString(),
        intervalText.replaceAll('|', ' '),
      ].join('|'),
    );
    await prefs.setStringList(_wateringCalculatorRemindersKey, reminders);
    if (!granted) {
      return false;
    }
    await _plugin.cancel(id: id);
    await _scheduleWateringCalculatorNotification(
      id: id,
      plantName: plantName,
      dueDate: dueDate,
      amountMl: amountMl,
      intervalText: intervalText,
    );
    return true;
  }

  Future<void> _scheduleSavedWateringCalculatorReminders(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders =
        prefs.getStringList(_wateringCalculatorRemindersKey) ?? [];
    final validReminders = <String>[];
    for (final item in reminders) {
      final parts = item.split('|');
      if (parts.length < 5) {
        continue;
      }
      final id = int.tryParse(parts[0]);
      final dueDate = DateTime.tryParse(parts[2]);
      final amountMl = int.tryParse(parts[3]);
      if (id == null ||
          dueDate == null ||
          amountMl == null ||
          !dueDate.isAfter(now.add(const Duration(minutes: 2)))) {
        continue;
      }
      validReminders.add(item);
      await _scheduleWateringCalculatorNotification(
        id: id,
        plantName: parts[1],
        dueDate: dueDate,
        amountMl: amountMl,
        intervalText: parts[4],
      );
    }
    if (!listEquals(reminders, validReminders)) {
      await prefs.setStringList(
        _wateringCalculatorRemindersKey,
        validReminders,
      );
    }
  }

  Future<void> _scheduleEngagementReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final previousIds =
        prefs.getStringList(_scheduledEngagementReminderIdsKey) ?? const [];
    for (final value in previousIds) {
      final id = int.tryParse(value);
      if (id != null) {
        await _plugin.cancel(id: id);
      }
    }

    final english = LanguageService.instance.isEnglish;
    final bodies = english
        ? const [
            'How are your plants today? Take a quick look at their leaves and soil.',
            'What does your plant need? Take a photo and find out now.',
            'Is the soil dry? Check the moisture before watering.',
            'A short care check can help you notice plant stress early.',
          ]
        : const [
            'Çiçekleriniz bugün nasıl? Yapraklarını ve toprağını kısaca kontrol edin.',
            'Bitkinizin neye ihtiyacı var? Fotoğrafını çekip hemen öğrenin.',
            'Toprak kurudu mu? Sulamadan önce nemini kontrol edin.',
            'Kısa bir bakım kontrolü, bitki stresini erken fark etmenizi sağlar.',
          ];
    final now = tz.TZDateTime.now(tz.local);
    final threshold = now.add(const Duration(minutes: 2));
    final scheduledIds = <int>[];

    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      final morning = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        11,
        15,
      );
      if (morning.isAfter(threshold)) {
        final id = _engagementNotificationId(morning, 1);
        await _scheduleEngagementNotification(
          id: id,
          scheduledDate: morning,
          body: bodies[dayOffset % bodies.length],
          english: english,
        );
        scheduledIds.add(id);
      }

      if (dayOffset.isOdd) {
        final evening = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          19,
          15,
        );
        if (evening.isAfter(threshold)) {
          final id = _engagementNotificationId(evening, 2);
          await _scheduleEngagementNotification(
            id: id,
            scheduledDate: evening,
            body: bodies[(dayOffset + 1) % bodies.length],
            english: english,
          );
          scheduledIds.add(id);
        }
      }
    }

    await prefs.setStringList(
      _scheduledEngagementReminderIdsKey,
      scheduledIds.map((id) => '$id').toList(),
    );
  }

  Future<void> _scheduleEngagementNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String body,
    required bool english,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: english ? 'Plant Doctor' : 'Çiçek Doktoru',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_check_reminders',
          english ? 'Plant check reminders' : 'Bitki kontrol hatırlatmaları',
          channelDescription: english
              ? 'Gentle reminders to check your plants'
              : 'Bitkilerinizi kontrol etmeniz için hafif hatırlatmalar',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'kind': 'engagement'}),
    );
  }

  Future<void> _scheduleWateringCalculatorNotification({
    required int id,
    required String plantName,
    required DateTime dueDate,
    required int amountMl,
    required String intervalText,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: 'Çiçek Doktoru',
      body:
          '$plantName için tahmini sulama zamanı. Öneri: $amountMl ml, $intervalText.',
      scheduledDate: tz.TZDateTime.from(dueDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'watering_calculator',
          'Su hesaplayıcı hatırlatmaları',
          channelDescription: 'Tahmini sulama zamanı hatırlatmaları',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'kind': 'watering-calculator'}),
    );
  }

  tz.TZDateTime _careReminderTime(DateTime dueDate) {
    final calendarDate = dueDate.isUtc ? dueDate : dueDate.toUtc();
    return tz.TZDateTime(
      tz.local,
      calendarDate.year,
      calendarDate.month,
      calendarDate.day,
      10,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    NotificationNavigationIntent intent;
    try {
      final data = jsonDecode(payload);
      if (data is! Map) {
        return;
      }
      intent = NotificationNavigationIntent(
        kind: data['kind']?.toString() ?? 'care',
        taskId: data['taskId']?.toString(),
        plantId: data['plantId']?.toString(),
      );
    } catch (_) {
      intent = NotificationNavigationIntent(kind: 'care', taskId: payload);
    }
    final handler = _navigationHandler;
    if (handler == null) {
      _pendingNavigationIntent = intent;
      return;
    }
    handler(intent);
  }

  void _flushPendingNavigationIntent() {
    final intent = _pendingNavigationIntent;
    final handler = _navigationHandler;
    if (intent == null || handler == null) {
      return;
    }
    _pendingNavigationIntent = null;
    handler(intent);
  }

  int _notificationId(CareTask task) {
    final source = task.id ?? '${task.title}-${task.dueDate.toIso8601String()}';
    return source.codeUnits
        .fold(17, (hash, unit) {
          return (hash * 37 + unit) & 0x7fffffff;
        })
        .clamp(1, pow(2, 31).toInt() - 1);
  }

  int _wateringCalculatorId(String plantName) {
    final source = 'watering-calculator-${plantName.trim().toLowerCase()}';
    return source.codeUnits
        .fold(7919, (hash, unit) {
          return (hash * 41 + unit) & 0x7fffffff;
        })
        .clamp(100000, pow(2, 31).toInt() - 1);
  }

  int _engagementNotificationId(tz.TZDateTime date, int slot) {
    return 700000000 +
        (date.year % 100) * 100000 +
        date.month * 1000 +
        date.day * 10 +
        slot;
  }
}
