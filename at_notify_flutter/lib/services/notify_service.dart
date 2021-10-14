/// A service to handle save and retrieve operation on notify

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_notify_flutter/models/notify_model.dart';
import 'package:at_notify_flutter/utils/notify_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ignore: implementation_imports
import 'package:at_client/src/service/notification_service.dart';

class NotifyService {
  NotifyService._();

  static final NotifyService _instance = NotifyService._();

  factory NotifyService() => _instance;

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late InitializationSettings initializationSettings;

  final String storageKey = 'at_notify';

  late AtClientManager atClientManager;
  late AtClient atClient;

  String? rootDomain;
  int? rootPort;
  String? currentAtSign;

  List<Notify> notifies = [];

  StreamController<List<Notify>> notifyStreamController =
      StreamController<List<Notify>>.broadcast();

  Sink get notifySink => notifyStreamController.sink;

  Stream<List<Notify>> get notifyStream => notifyStreamController.stream;

  void disposeControllers() {
    notifyStreamController.close();
  }

  void initNotifyService(
      AtClientPreference atClientPreference,
      String currentAtSignFromApp,
      String rootDomainFromApp,
      int rootPortFromApp) async {
    currentAtSign = currentAtSignFromApp;
    rootDomain = rootDomainFromApp;
    rootPort = rootPortFromApp;
    atClientManager = AtClientManager.getInstance();
    AtClientManager.getInstance().setCurrentAtSign(
        currentAtSignFromApp, atClientPreference.namespace, atClientPreference);
    atClient = AtClientManager.getInstance().atClient;
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    atClientManager.notificationService
        .subscribe(regex: '.${atClientPreference.namespace}')
        .listen((notification) {
      _notificationCallback(notification);
    });

    if (Platform.isIOS) {
      _requestIOSPermission();
    }
    await initializePlatformSpecifics();
  }

  /// Initialized Notification Settings
  initializePlatformSpecifics() async {
    var initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        var receivedNotification = ReceivedNotification(
          id: id,
          title: title!,
          body: body!,
          payload: payload!,
        );
        print('receivedNotification: ${receivedNotification?.toString()}');
        //     didReceivedLocalNotificationSubject.add(receivedNotification);
      },
    );
    initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (payload) async {},
    );
  }

  /// Request Alert, Badge, Sound Permission for IOS
  _requestIOSPermission() {
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()!
        .requestPermissions(
          alert: false,
          badge: true,
          sound: true,
        );
  }

  /// Listen Notification
  void _notificationCallback(dynamic notification) async {
    print('_notificationCallback called in at_notify_flutter');
    AtNotification atNotification = notification;
    var notificationKey = atNotification.key;
    var fromAtsign = atNotification.from;
    var toAtsign = atNotification.to;

    // remove from and to atsigns from the notification key
    if (notificationKey.contains(':')) {
      notificationKey = notificationKey.split(':')[1];
    }
    notificationKey = notificationKey.replaceFirst(fromAtsign, '').trim();
    print('notificationKey = $notificationKey');

    if (atNotification.id == -1) {
      return;
    }

    if ((notificationKey.startsWith(storageKey) && toAtsign == currentAtSign)) {
      var message = atNotification.value ?? '';
      print('notify message => $message $fromAtsign');
      if (message.isNotEmpty && message != 'null') {
        var decryptedMessage = await atClient.encryptionService!
            .decrypt(message, fromAtsign)
            .catchError((e) {
          print('error in decrypting notify $e');
        });
        print('notify decryptedMessage => $decryptedMessage $fromAtsign');
        await showNotification(decryptedMessage, fromAtsign);
      }
    }
  }

  /// Get Notify List From AtClient
  Future<void> getNotifies({String? atsign}) async {
    try {
      notifies = [];
      var notifications =
          await atClient.notifyList(regex: storageKey, fromDate: '2021-10-14');

      var _jsonData = (json.decode(notifications.replaceFirst('data:', '')));

      await Future.forEach(_jsonData, (_data) async {
        var decryptedMessage = await atClient.encryptionService!
            .decrypt((_data! as Map<String, dynamic>)["value"],
                (_data! as Map<String, dynamic>)['from'])
            .catchError((e) {
          print('error in decrypting notify $e');
        });
        print('decryptedMessage ${decryptedMessage}');

        var _newNotifyObj = Notify.fromJson(decryptedMessage);
        notifies.insert(0, _newNotifyObj);
        notifySink.add(notifies);
      });
    } catch (error) {
      print('Error in getting bug Report -> $error');
    }
  }

  /// Call Notify in NotificationService, send notify to others
  Future<bool> sendNotify(
      String sendToAtSign, Notify notify, NotifyEnum notifyType,
      {int noOfDays = 30}) async {
    var notificationResponse;
    notificationResponse = await atClientManager.notificationService
        .notify(NotificationParams.forText(notify.message ?? '', sendToAtSign));
    var metadata = Metadata();
    metadata.ttr = -1;
    metadata.ttl = 30 * 24 * 60 * 60000; // in milliseconds
    var key = AtKey()
      ..key = storageKey
      ..sharedBy = currentAtSign
      ..sharedWith = sendToAtSign
      ..metadata = metadata;
    notificationResponse = await atClientManager.notificationService.notify(
      NotificationParams.forUpdate(key, value: notify.toJson()),
    );

    if (notificationResponse.notificationStatusEnum ==
        NotificationStatusEnum.delivered) {
      print(notificationResponse.toString());
    } else {
      print(notificationResponse.atClientException.toString());
      return false;
    }
    return true;
  }

  void _onSuccessCallback(notificationResult) {
    print(notificationResult);
  }

  void _onErrorCallback(notificationResult) {
    print(notificationResult.atClientException.toString());
  }

  /// Show Local Notification in Device
  Future<void> showNotification(String decryptedMessage, String atSign) async {
    List<dynamic>? valuesJson = [];
    Notify notify = Notify.fromJson((decryptedMessage));
    print('showNotification => ${notify.message} ${notify.atSign}');

    var androidChannelSpecifics = AndroidNotificationDetails(
      'notify_id',
      'notify',
      "notify_description",
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      timeoutAfter: 50000,
      styleInformation: DefaultStyleInformation(true, true),
    );
    var iosChannelSpecifics = IOSNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
        android: androidChannelSpecifics, iOS: iosChannelSpecifics);
    await _notificationsPlugin.show(
      0,
      '${atSign}',
      '${notify.message}',
      platformChannelSpecifics,
      payload: notify.message,
    );
  }

  /// Cancel All notification
  void cancelNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });
}
