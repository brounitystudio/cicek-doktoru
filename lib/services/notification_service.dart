import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/care_task.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _wateringCalculatorRemindersKey =
      'watering_calculator_reminders';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await registerDeviceToken();
    } catch (error) {
      debugPrint('Push token registration skipped: $error');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);
    _initialized = true;
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
        'platform': 'android',
      });
    } catch (error) {
      debugPrint('Push token backend registration failed: $error');
    }
  }

  Future<void> scheduleCareReminders(List<CareTask> tasks) async {
    await initialize();
    await _plugin.cancelAll();

    final now = DateTime.now();
    final upcoming = tasks
        .where((task) => !task.completed)
        .where(
          (task) => task.dueDate.isAfter(now.add(const Duration(minutes: 2))),
        )
        .take(20);

    for (final task in upcoming) {
      await _plugin.zonedSchedule(
        id: _notificationId(task),
        title: 'Çiçek Doktoru',
        body: task.title,
        scheduledDate: tz.TZDateTime.from(task.dueDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'care_reminders',
            'Bakım hatırlatıcıları',
            channelDescription: 'Sulama, kontrol ve bitki bakım günleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id,
      );
    }

    await _scheduleSavedWateringCalculatorReminders(now);
  }

  Future<void> scheduleWateringCalculatorReminder({
    required String plantName,
    required DateTime dueDate,
    required int amountMl,
    required String intervalText,
  }) async {
    await initialize();
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
    await _plugin.cancel(id: id);
    await _scheduleWateringCalculatorNotification(
      id: id,
      plantName: plantName,
      dueDate: dueDate,
      amountMl: amountMl,
      intervalText: intervalText,
    );
  }

  Future<void> _scheduleSavedWateringCalculatorReminders(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final reminders =
        prefs.getStringList(_wateringCalculatorRemindersKey) ?? [];
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
      await _scheduleWateringCalculatorNotification(
        id: id,
        plantName: parts[1],
        dueDate: dueDate,
        amountMl: amountMl,
        intervalText: parts[4],
      );
    }
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
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'watering-calculator-$id',
    );
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
}
