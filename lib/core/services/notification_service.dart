import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:voycontigo/core/router/app_router.dart';
import 'package:voycontigo/core/utils/date_format.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

/// Datos mínimos para programar el recordatorio de un viaje.
class TripReminder {
  final String tripId;
  final DateTime scheduleTime;
  final String routeLabel; // Ej: "Machachi ➔ Quito"

  const TripReminder({
    required this.tripId,
    required this.scheduleTime,
    required this.routeLabel,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String _matchesChannelId = 'voycontigo_matches';
  static const String _remindersChannelId = 'voycontigo_reminders';
  static const String _rewardsChannelId = 'voycontigo_rewards';

  /// Preferencia del usuario (Configuración → Notificaciones). Se sincroniza
  /// desde el estado global; cuando está en false no se muestra ni programa
  /// ninguna notificación local y no se re-guarda el token FCM.
  bool _notificationsEnabled = true;

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  /// Minutos de antelación por defecto para el recordatorio de salida.
  static const int defaultReminderMinutes = 30;

  Future<void> initialize() async {
    // 0. Zona horaria (Ecuador) para poder programar notificaciones locales.
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Guayaquil'));
    } catch (_) {
      // Si fallara la zona, quedará en UTC; el recordatorio seguirá funcionando.
    }

    // 1. Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // 2. Setup background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Setup local notifications for foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS: pedir permisos de alerta/sonido/badge para notificaciones locales.
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(Map<String, dynamic>.from(data));
          } catch (e) {
            print("Error parsing payload: $e");
          }
        }
      },
    );

    // Canal de coincidencias (background FCM messages, Android 8.0+)
    const AndroidNotificationChannel matchesChannel = AndroidNotificationChannel(
      _matchesChannelId,
      'Coincidencias',
      description: 'Notificaciones sobre coincidencias de viajes',
      importance: Importance.max,
    );

    // Canal de recordatorios de viajes programados.
    const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
      _remindersChannelId,
      'Recordatorios de viaje',
      description: 'Avisos antes de la salida de tus viajes programados',
      importance: Importance.max,
    );

    // Canal de recompensas desbloqueadas (Club de Beneficios).
    const AndroidNotificationChannel rewardsChannel = AndroidNotificationChannel(
      _rewardsChannelId,
      'Recompensas',
      description: 'Avisos cuando desbloqueas una nueva recompensa',
      importance: Importance.max,
    );

    final androidImpl = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(matchesChannel);
    await androidImpl?.createNotificationChannel(remindersChannel);
    await androidImpl?.createNotificationChannel(rewardsChannel);

    // 4. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle background taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Handle terminated state taps
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Delay navigation slightly to let the app build the router completely
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage.data);
      });
    }

    // 5. Update token in Firestore
    await updateToken();

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });
  }

  // ---------------------------------------------------------------------------
  // Recordatorios locales de viajes programados
  // ---------------------------------------------------------------------------

  int _reminderId(String tripId) => tripId.hashCode & 0x7fffffff;

  /// Programa un recordatorio local [minutesBefore] antes de la salida.
  /// Si ya pasó ese instante, no programa nada.
  Future<void> scheduleTripReminder(
    TripReminder trip, {
    int minutesBefore = defaultReminderMinutes,
  }) async {
    if (!_notificationsEnabled) return;
    final fireAt = trip.scheduleTime.subtract(Duration(minutes: minutesBefore));
    if (fireAt.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(fireAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _remindersChannelId,
      'Recordatorios de viaje',
      channelDescription: 'Avisos antes de la salida de tus viajes programados',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode({'tripId': trip.tripId, 'type': 'reminder'});
    final title = 'Tu viaje sale pronto 🚗';
    final body = '${trip.routeLabel} · Salida ${VoyDate.time(trip.scheduleTime)}';

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id: _reminderId(trip.tripId),
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      // Sin permiso de alarma exacta (Android 12+): reintentar de forma inexacta.
      try {
        await _localNotificationsPlugin.zonedSchedule(
          id: _reminderId(trip.tripId),
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        print('No se pudo programar recordatorio: $e2');
      }
    }
  }

  /// Cancela el recordatorio de un viaje (al cancelar/eliminar el viaje).
  Future<void> cancelTripReminder(String tripId) async {
    await _localNotificationsPlugin.cancel(id: _reminderId(tripId));
  }

  /// Reprograma los recordatorios de la lista de viajes próximos del usuario.
  /// Idempotente: reusar el mismo id sobrescribe el recordatorio previo.
  Future<void> syncUpcomingReminders(
    List<TripReminder> trips, {
    int minutesBefore = defaultReminderMinutes,
  }) async {
    for (final t in trips) {
      await scheduleTripReminder(t, minutesBefore: minutesBefore);
    }
  }

  // ---------------------------------------------------------------------------
  // Recompensas del Club de Beneficios
  // ---------------------------------------------------------------------------

  /// Notificación local inmediata cuando el usuario desbloquea una recompensa.
  /// Al tocarla se abre la sección de recompensas.
  Future<void> showRewardUnlocked({
    required String title,
    required String body,
  }) async {
    if (!_notificationsEnabled) return;
    const androidDetails = AndroidNotificationDetails(
      _rewardsChannelId,
      'Recompensas',
      channelDescription: 'Avisos cuando desbloqueas una nueva recompensa',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _localNotificationsPlugin.show(
        id: (title + body).hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode({'type': 'reward'}),
      );
    } catch (e) {
      print('No se pudo mostrar notificación de recompensa: $e');
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (!_notificationsEnabled) return;
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      _matchesChannelId,
      'Coincidencias',
      channelDescription: 'Notificaciones sobre coincidencias de viajes',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);

    await _localNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    // Los recordatorios abren la agenda; el resto, el seguimiento del viaje.
    if (data['type'] == 'reminder') {
      GoRouter.of(context).push('/my-trips');
      return;
    }

    // Las recompensas abren el Club de Beneficios.
    if (data['type'] == 'reward') {
      GoRouter.of(context).go('/rewards');
      return;
    }

    final tripId = data['tripId'] ?? data['matchId'];
    if (tripId != null) {
      GoRouter.of(context).push('/tracking/$tripId');
    }
  }

  Future<void> updateToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      print("Error getting FCM token: $e");
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    if (!_notificationsEnabled) return;
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    }
  }

  /// Al desactivar las notificaciones: borra el token FCM (el servidor deja
  /// de enviar push) y cancela los recordatorios locales ya programados.
  Future<void> disablePushAndReminders() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': FieldValue.delete()});
      }
      await _localNotificationsPlugin.cancelAll();
    } catch (e) {
      print('Error al desactivar notificaciones: $e');
    }
  }
}
