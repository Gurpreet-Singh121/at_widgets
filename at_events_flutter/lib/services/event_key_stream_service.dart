// ignore_for_file: unused_local_variable, avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_contact/at_contact.dart';
import 'package:at_events_flutter/at_events_flutter.dart';
import 'package:at_events_flutter/models/enums_model.dart';
import 'package:at_events_flutter/models/event_key_location_model.dart';
import 'package:at_events_flutter/models/event_member_location.dart';
import 'package:at_events_flutter/models/event_notification.dart';
import 'package:at_events_flutter/services/at_event_notification_listener.dart';
import 'package:at_events_flutter/utils/constants.dart';
import 'package:at_location_flutter/location_modal/location_data_model.dart';
import 'package:at_location_flutter/service/send_location_notification.dart';
import 'package:at_location_flutter/utils/constants/init_location_service.dart';
import 'package:latlong2/latlong.dart';

import 'contact_service.dart';
import 'package:at_utils/at_logger.dart';

class EventKeyStreamService {
  EventKeyStreamService._();
  static final EventKeyStreamService _instance = EventKeyStreamService._();
  factory EventKeyStreamService() => _instance;

  final _logger = AtSignLogger('EventKeyStreamService');

  late AtClientManager atClientManager;
  AtContactsImpl? atContactImpl;
  AtContact? loggedInUserDetails;
  List<EventKeyLocationModel> allEventNotifications = [],
      allPastEventNotifications = [];
  String? currentAtSign;
  List<AtContact> contactList = [];

  // ignore: close_sinks
  StreamController atNotificationsController =
      StreamController<List<EventKeyLocationModel>>.broadcast();
  Stream<List<EventKeyLocationModel>> get atNotificationsStream =>
      atNotificationsController.stream as Stream<List<EventKeyLocationModel>>;
  StreamSink<List<EventKeyLocationModel>> get atNotificationsSink =>
      atNotificationsController.sink as StreamSink<List<EventKeyLocationModel>>;

  Function(List<EventKeyLocationModel>)? streamAlternative;

  void init({Function(List<EventKeyLocationModel>)? streamAlternative}) async {
    loggedInUserDetails = null;
    atClientManager = AtClientManager.getInstance();
    currentAtSign = atClientManager.atClient.getCurrentAtSign();
    allEventNotifications = [];
    allPastEventNotifications = [];
    this.streamAlternative = streamAlternative;

    atNotificationsController =
        StreamController<List<EventKeyLocationModel>>.broadcast();
    getAllEventNotifications();

    loggedInUserDetails = await getAtSignDetails(currentAtSign);
    getAllContactDetails(currentAtSign!);
  }

  void getAllContactDetails(String currentAtSign) async {
    atContactImpl = await AtContactsImpl.getInstance(currentAtSign);
    contactList = await atContactImpl!.listContacts();
  }

  /// adds all 'createevent' notifications to [atNotificationsSink]
  void getAllEventNotifications() async {
    AtClientManager.getInstance().syncService.sync();

    var response = await atClientManager.atClient.getKeys(
      regex: 'createevent-',
    );

    if (response.isEmpty) {
      SendLocationNotification().initEventData([]);
      notifyListeners();
      return;
    }

    for (var key in response) {
      var eventKeyLocationModel = EventKeyLocationModel(key: key);
      allEventNotifications.add(eventKeyLocationModel);
    }

    for (var notification in allEventNotifications) {
      var atKey = EventService().getAtKey(notification.key!);
      notification.atKey = atKey;
    }

    for (var i = 0; i < allEventNotifications.length; i++) {
      AtValue? value = await (getAtValue(allEventNotifications[i].atKey!));
      if (value != null) {
        allEventNotifications[i].atValue = value;
      }
    }

    convertJsonToEventModel();
    filterPastEventsFromList();

    await checkForPendingEvents();

    notifyListeners();

    calculateLocationSharingAllEvents(initLocationSharing: true);
  }

  void convertJsonToEventModel() {
    var tempRemoveEventArray = <EventKeyLocationModel>[];

    for (var i = 0; i < allEventNotifications.length; i++) {
      try {
        // ignore: unrelated_type_equality_checks
        if (allEventNotifications[i].atValue != 'null' &&
            allEventNotifications[i].atValue != null) {
          var event = EventNotificationModel.fromJson(
              jsonDecode(allEventNotifications[i].atValue!.value));

          // ignore: unnecessary_null_comparison
          if (event != null && event.group!.members!.isNotEmpty) {
            event.key = allEventNotifications[i].key;

            allEventNotifications[i].eventNotificationModel = event;
          }
        } else {
          tempRemoveEventArray.add(allEventNotifications[i]);
        }
      } catch (e) {
        tempRemoveEventArray.add(allEventNotifications[i]);
      }
    }

    allEventNotifications
        .removeWhere((element) => tempRemoveEventArray.contains(element));
  }

  /// Removes past notifications and notification where data is null.
  void filterPastEventsFromList() {
    for (var i = 0; i < allEventNotifications.length; i++) {
      if (allEventNotifications[i]
              .eventNotificationModel!
              .event!
              .endTime!
              .difference(DateTime.now())
              .inMinutes <
          0) allPastEventNotifications.add(allEventNotifications[i]);
    }

    allEventNotifications
        .removeWhere((element) => allPastEventNotifications.contains(element));
  }

  /// Updates any received notification with [haveResponded] true, if already responded.
  Future<void> checkForPendingEvents() async {
    // ignore: avoid_function_literals_in_foreach_calls
    allEventNotifications.forEach((notification) async {
      notification.eventNotificationModel!.group!.members!
          // ignore: avoid_function_literals_in_foreach_calls
          .forEach((member) async {
        if ((member.atSign == currentAtSign) &&
            (member.tags!['isAccepted'] == false) &&
            (member.tags!['isExited'] == false)) {
          var atkeyMicrosecondId =
              notification.key!.split('createevent-')[1].split('@')[0];
          var acknowledgedKeyId = 'eventacknowledged-$atkeyMicrosecondId';
          var allRegexResponses =
              await atClientManager.atClient.getKeys(regex: acknowledgedKeyId);
          // ignore: unnecessary_null_comparison
          if ((allRegexResponses != null) && (allRegexResponses.isNotEmpty)) {
            notification.haveResponded = true;
          }
        }
      });
    });
  }

  isPastNotification(EventNotificationModel eventNotificationModel) {
    if (eventNotificationModel.event!.endTime!.isBefore(DateTime.now())) {
      return true;
    }

    return false;
  }

  /// Adds new [EventKeyLocationModel] data for new received notification
  Future<dynamic> addDataToList(EventNotificationModel eventNotificationModel,
      {String? receivedkey}) async {
    /// so, that we don't add any expired event
    if (isPastNotification(eventNotificationModel)) {
      return;
    }

    /// with rSDK we can get previous notification, this will restrict us to add one notification twice
    for (var _eventNotification in allEventNotifications) {
      if (_eventNotification.eventNotificationModel != null &&
          _eventNotification.eventNotificationModel!.key ==
              eventNotificationModel.key) {
        return;
      }
    }

    String newLocationDataKeyId;
    String? key;
    newLocationDataKeyId =
        eventNotificationModel.key!.split('createevent-')[1].split('@')[0];

    if (receivedkey != null) {
      key = receivedkey;
    } else {
      var keys = <String>[];
      keys = await atClientManager.atClient.getKeys(
        regex: 'createevent-',
      );

      for (var regex in keys) {
        if (regex.contains(newLocationDataKeyId)) {
          key = regex;
        }
      }

      if (key == null) {
        return;
      }
    }

    var tempEventKeyLocationModel = EventKeyLocationModel(key: key);
    // eventNotificationModel.key = key;
    tempEventKeyLocationModel.atKey = EventService().getAtKey(key);
    tempEventKeyLocationModel.atValue =
        await getAtValue(tempEventKeyLocationModel.atKey!);
    tempEventKeyLocationModel.eventNotificationModel = eventNotificationModel;
    allEventNotifications.add(tempEventKeyLocationModel);

    notifyListeners();

    /// Add in SendLocation map only if I am creator,
    /// for members, will be added on first action on the event
    if (compareAtSign(eventNotificationModel.atsignCreator!, currentAtSign!)) {
      await checkLocationSharingForEventData(
          tempEventKeyLocationModel.eventNotificationModel!);
    }

    return tempEventKeyLocationModel;
  }

  /// Updates any [EventKeyLocationModel] data for updated data
  Future<void> mapUpdatedEventDataToWidget(EventNotificationModel eventData,
      {Map<dynamic, dynamic>? tags,
      String? tagOfAtsign,
      bool updateLatLng = false,
      bool updateOnlyCreator = false}) async {
    String neweventDataKeyId;
    neweventDataKeyId = eventData.key!
        .split('${MixedConstants.CREATE_EVENT}-')[1]
        .split('@')[0];

    for (var i = 0; i < allEventNotifications.length; i++) {
      if (allEventNotifications[i].key!.contains(neweventDataKeyId)) {
        /// if we want to update everything
        // allEventNotifications[i].eventNotificationModel = eventData;

        /// For events send tags of group members if we have and update only them
        if (updateOnlyCreator) {
          /// So that creator doesnt update group details
          eventData.group =
              allEventNotifications[i].eventNotificationModel!.group;
        }

        if ((tags != null) && (tagOfAtsign != null)) {
          allEventNotifications[i]
              .eventNotificationModel!
              .group!
              .members!
              .where((element) => element.atSign == tagOfAtsign)
              .forEach((element) {
            if (updateLatLng) {
              element.tags!['lat'] = tags['lat'];
              element.tags!['long'] = tags['long'];
            } else {
              element.tags = tags;
            }
          });
        } else {
          allEventNotifications[i].eventNotificationModel = eventData;
        }

        allEventNotifications[i].eventNotificationModel!.key =
            allEventNotifications[i].key;

        notifyListeners();

        await updateLocationDataForExistingEvent(eventData);

        break;
      }
    }
  }

  updateLocationDataForExistingEvent(EventNotificationModel eventData) async {
    var _allAtsigns = getAtsignsFromEvent(eventData);
    List<String> _atsignsToSend = [];

    for (var _atsign in _allAtsigns) {
      if (SendLocationNotification().allAtsignsLocationData[_atsign] != null) {
        var _locationSharingForMap =
            SendLocationNotification().allAtsignsLocationData[_atsign];
        var _fromAndTo = getFromAndToForEvent(eventData);

        var _locFor = _locationSharingForMap!
            .locationSharingFor[trimAtsignsFromKey(eventData.key!)];

        if (_locFor != null) {
          if (_locFor.from != _fromAndTo['from']) {
            SendLocationNotification()
                .allAtsignsLocationData[_atsign]!
                .locationSharingFor[trimAtsignsFromKey(eventData.key!)]!
                .from = _fromAndTo['from'];

            if (!_atsignsToSend.contains(_atsign)) {
              _atsignsToSend.add(_atsign);
            }
          }
          if (_locFor.to != _fromAndTo['to']) {
            SendLocationNotification()
                .allAtsignsLocationData[_atsign]!
                .locationSharingFor[trimAtsignsFromKey(eventData.key!)]!
                .to = _fromAndTo['to'];

            if (!_atsignsToSend.contains(_atsign)) {
              _atsignsToSend.add(_atsign);
            }
          }

          continue;
        }
      }

      /// add if doesn not exist
      var _newLocationDataModel =
          eventNotificationToLocationDataModel(eventData, [_atsign])[0];

      /// if exists, then get booleans from some already existing data
      for (var _existingAtsign in _allAtsigns) {
        if ((SendLocationNotification()
                    .allAtsignsLocationData[_existingAtsign] !=
                null) &&
            (SendLocationNotification()
                    .allAtsignsLocationData[_existingAtsign]!
                    .locationSharingFor[trimAtsignsFromKey(eventData.key!)] !=
                null)) {
          var _locFor = SendLocationNotification()
              .allAtsignsLocationData[_existingAtsign]!
              .locationSharingFor[trimAtsignsFromKey(eventData.key!)];

          _newLocationDataModel
              .locationSharingFor[trimAtsignsFromKey(eventData.key!)]!
              .isAccepted = _locFor!.isAccepted;
          _newLocationDataModel
              .locationSharingFor[trimAtsignsFromKey(eventData.key!)]!
              .isExited = _locFor.isExited;
          _newLocationDataModel
              .locationSharingFor[trimAtsignsFromKey(eventData.key!)]!
              .isSharing = _locFor.isSharing;

          break;
        }
      }

      /// add/append accordingly
      if (SendLocationNotification().allAtsignsLocationData[_atsign] != null) {
        /// if atsigns exists append locationSharingFor
        SendLocationNotification()
            .allAtsignsLocationData[_atsign]!
            .locationSharingFor = {
          ...SendLocationNotification()
              .allAtsignsLocationData[_atsign]!
              .locationSharingFor,
          ..._newLocationDataModel.locationSharingFor,
        };
      } else {
        SendLocationNotification().allAtsignsLocationData[_atsign] =
            _newLocationDataModel;
      }

      if (!_atsignsToSend.contains(_atsign)) {
        _atsignsToSend.add(_atsign);
      }
    }
    await SendLocationNotification()
        .sendLocationAfterDataUpdate(_atsignsToSend);
  }

  bool isEventSharedWithMe(EventNotificationModel eventData) {
    for (var i = 0; i < allEventNotifications.length; i++) {
      if (allEventNotifications[i].key!.contains(eventData.key!)) {
        return true;
      }
    }
    return false;
  }

  /// Checks current status of [currentAtSign] in an event and updates [SendLocationNotification] location sending list.
  Future<void> checkLocationSharingForEventData(
      EventNotificationModel eventNotificationModel) async {
    if ((eventNotificationModel.atsignCreator == currentAtSign)) {
      if (eventNotificationModel.isSharing!) {
        // ignore: unawaited_futures
        await calculateLocationSharingForSingleEvent(eventNotificationModel);
      } else {
        List<String> atsignsToremove = [];
        for (var member in eventNotificationModel.group!.members!) {
          atsignsToremove.add(member.atSign!);
        }
        SendLocationNotification().removeMember(
            eventNotificationModel.key!, atsignsToremove,
            isAccepted: !eventNotificationModel.isCancelled!,
            isExited: eventNotificationModel.isCancelled!);
      }
    } else {
      await calculateLocationSharingForSingleEvent(eventNotificationModel);
    }
  }

  Future<dynamic> updateEvent(
      EventNotificationModel eventData, AtKey key) async {
    try {
      var notification =
          EventNotificationModel.convertEventNotificationToJson(eventData);

      var result = await atClientManager.atClient.put(
        key,
        notification,
      );
      if (result is bool) {
        if (result) {}
        _logger.finer('event acknowledged:$result');
        return result;
        // ignore: unnecessary_null_comparison
      } else if (result != null) {
        return result.toString();
      } else {
        return result;
      }
    } catch (e) {
      _logger.severe('error in updating notification:$e');
      return false;
    }
  }

  /// Processes any kind of update in an event and notifies creator/members
  Future<bool> actionOnEvent(
      EventNotificationModel event, ATKEY_TYPE_ENUM keyType,
      {required bool isAccepted,
      required bool isSharing,
      required bool isExited,
      bool? isCancelled}) async {
    var eventData = EventNotificationModel.fromJson(jsonDecode(
        EventNotificationModel.convertEventNotificationToJson(event)));

    try {
      if (isCancelled == true) {
        await updateEventMemberInfo(eventData,
            isAccepted: false, isExited: true, isSharing: false);
      } else {
        await updateEventMemberInfo(eventData,
            isAccepted: isAccepted, isExited: isExited, isSharing: isSharing);
      }

      notifyListeners();

      return true;
    } catch (e) {
      _logger.severe('error in updating event $e');
      return false;
    }
  }

  List<String> getAtsignsFromEvent(EventNotificationModel _event) {
    List<String> _allAtsignsInEvent = [];

    if (!compareAtSign(_event.atsignCreator!,
        AtClientManager.getInstance().atClient.getCurrentAtSign()!)) {
      _allAtsignsInEvent.add(_event.atsignCreator!);
    }

    if (_event.group!.members!.isNotEmpty) {
      Set<AtContact>? groupMembers = _event.group!.members!;

      // ignore: avoid_function_literals_in_foreach_calls
      groupMembers.forEach((member) {
        if (!compareAtSign(member.atSign!,
            AtClientManager.getInstance().atClient.getCurrentAtSign()!)) {
          _allAtsignsInEvent.add(member.atSign!);
        }
      });
    }

    return _allAtsignsInEvent;
  }

  updateEventMemberInfo(EventNotificationModel _event,
      {required bool isAccepted,
      required bool isSharing,
      required bool isExited}) async {
    String _id = trimAtsignsFromKey(_event.key!);

    List<String> _allAtsignsInEvent = getAtsignsFromEvent(_event);

    for (var _atsign in _allAtsignsInEvent) {
      if (SendLocationNotification().allAtsignsLocationData[_atsign] != null) {
        if (SendLocationNotification()
                .allAtsignsLocationData[_atsign]!
                .locationSharingFor[_id] !=
            null) {
          SendLocationNotification()
              .allAtsignsLocationData[_atsign]!
              .locationSharingFor[_id]!
              .isAccepted = isAccepted;

          SendLocationNotification()
              .allAtsignsLocationData[_atsign]!
              .locationSharingFor[_id]!
              .isSharing = isSharing;

          SendLocationNotification()
              .allAtsignsLocationData[_atsign]!
              .locationSharingFor[_id]!
              .isExited = isExited;
        } else {
          var _fromAndTo = getFromAndToForEvent(_event);
          SendLocationNotification()
                  .allAtsignsLocationData[_atsign]!
                  .locationSharingFor[_id] =
              LocationSharingFor(_fromAndTo['from'], _fromAndTo['to'],
                  LocationSharingType.Event, isAccepted, isExited, isSharing);
        }
      } else {
        var _fromAndTo = getFromAndToForEvent(_event);
        SendLocationNotification().allAtsignsLocationData[_atsign] =
            LocationDataModel({
          trimAtsignsFromKey(_event.key!): LocationSharingFor(
              _fromAndTo['from'],
              _fromAndTo['to'],
              LocationSharingType.Event,
              isAccepted,
              isExited,
              isSharing),
        }, null, null, DateTime.now(), currentAtSign!, _atsign);
      }
    }

    await SendLocationNotification()
        .sendLocationAfterDataUpdate(_allAtsignsInEvent);
  }

  Map<String, DateTime> getFromAndToForEvent(EventNotificationModel eventData) {
    DateTime? _from;
    DateTime? _to;

    if (compareAtSign(eventData.atsignCreator!,
        AtEventNotificationListener().currentAtSign!)) {
      _from = eventData.event!.startTime;
      _to = eventData.event!.endTime;
    } else {
      late AtContact currentGroupMember;
      // ignore: avoid_function_literals_in_foreach_calls
      eventData.group!.members!.forEach((groupMember) {
        // sending location to other group members
        if (compareAtSign(groupMember.atSign!,
            AtEventNotificationListener().currentAtSign!)) {
          currentGroupMember = groupMember;
        }
      });

      _from = startTimeEnumToTimeOfDay(
              currentGroupMember.tags!['shareFrom'].toString(),
              eventData.event!.startTime) ??
          eventData.event!.startTime;
      _to = endTimeEnumToTimeOfDay(
              currentGroupMember.tags!['shareTo'].toString(),
              eventData.event!.endTime) ??
          eventData.event!.endTime;
    }

    return {
      'from': _from ?? eventData.event!.startTime!,
      'to': _to ?? eventData.event!.endTime!,
    };
  }

  void updatePendingStatus(EventNotificationModel notificationModel) async {
    for (var i = 0; i < allEventNotifications.length; i++) {
      if (allEventNotifications[i]
          .eventNotificationModel!
          .key!
          .contains(notificationModel.key!)) {
        allEventNotifications[i].haveResponded = true;
      }
    }
  }

  // ignore: missing_return
  AtKey? formAtKey(ATKEY_TYPE_ENUM keyType, String atkeyMicrosecondId,
      String? sharedWith, String sharedBy, EventNotificationModel eventData) {
    switch (keyType) {
      case ATKEY_TYPE_ENUM.CREATEEVENT:
        AtKey? atKey;

        // ignore: avoid_function_literals_in_foreach_calls
        allEventNotifications.forEach((event) {
          if (event.eventNotificationModel!.key == eventData.key) {
            atKey = EventService().getAtKey(event.key!);
          }
        });
        return atKey;

      case ATKEY_TYPE_ENUM.ACKNOWLEDGEEVENT:
        var key = AtKey()
          ..metadata = Metadata()
          ..metadata!.ttr = -1
          ..metadata!.ccd = true
          ..sharedWith = sharedWith
          ..sharedBy = sharedBy;

        key.key = 'eventacknowledged-$atkeyMicrosecondId';
        return key;
    }
  }

  Future<dynamic> geteventData(String regex) async {
    var acknowledgedAtKey = EventService().getAtKey(regex);

    var result = await atClientManager.atClient
        .get(acknowledgedAtKey)
        // ignore: return_of_invalid_type_from_catch_error
        .catchError((e) => print('error in get $e'));

    // ignore: unnecessary_null_comparison
    if ((result == null) || (result.value == null)) {
      return;
    }

    var eventData = EventMemberLocation.fromJson(jsonDecode(result.value));
    var obj = EventUserLocation(eventData.fromAtSign, eventData.getLatLng);

    return obj;
  }

  bool compareEvents(
      EventNotificationModel eventOne, EventNotificationModel eventTwo) {
    var isDataSame = true;

    // ignore: avoid_function_literals_in_foreach_calls
    eventOne.group!.members!.forEach((groupOneMember) {
      // ignore: avoid_function_literals_in_foreach_calls
      eventTwo.group!.members!.forEach((groupTwoMember) {
        if (groupOneMember.atSign == groupTwoMember.atSign) {
          if (groupOneMember.tags!['isAccepted'] !=
                  groupTwoMember.tags!['isAccepted'] ||
              groupOneMember.tags!['isSharing'] !=
                  groupTwoMember.tags!['isSharing'] ||
              groupOneMember.tags!['isExited'] !=
                  groupTwoMember.tags!['isExited'] ||
              groupOneMember.tags!['lat'] != groupTwoMember.tags!['lat'] ||
              groupOneMember.tags!['long'] != groupTwoMember.tags!['long']) {
            isDataSame = false;
          }
        }
      });
    });

    return isDataSame;
  }

  Future<dynamic> getAtValue(AtKey key) async {
    try {
      var atvalue = await atClientManager.atClient.get(key).catchError(
          // ignore: invalid_return_type_for_catch_error
          (e) => _logger.severe('error in in key_stream_service get $e'));

      // ignore: unnecessary_null_comparison
      if (atvalue != null) {
        return atvalue;
      } else {
        return null;
      }
    } catch (e) {
      _logger.severe('error in key_stream_service getAtValue:$e');
      return null;
    }
  }

  void notifyListeners() {
    if (streamAlternative != null) {
      streamAlternative!(allEventNotifications);
    }

    EventsMapScreenData().updateEventdataFromList(allEventNotifications);
    atNotificationsSink.add(allEventNotifications);
  }

  /// will calculate [LocationDataModel] for [allEventNotifications] if [listOfEvents] is not provided
  calculateLocationSharingAllEvents(
      {List<EventKeyLocationModel>? listOfEvents,
      bool initLocationSharing = false}) async {
    List<String> atsignToShareLocWith = [];
    List<LocationDataModel> locationToShareWith = [];

    for (var eventKeyLocationModel in (listOfEvents ?? allEventNotifications)) {
      if ((eventKeyLocationModel.eventNotificationModel == null) ||
          (eventKeyLocationModel.eventNotificationModel!.isCancelled == true)) {
        continue;
      }

      var eventNotificationModel =
          eventKeyLocationModel.eventNotificationModel!;

      /// calculate atsigns to share loc with
      atsignToShareLocWith = [];

      if (!compareAtSign(
          eventKeyLocationModel.eventNotificationModel!.atsignCreator!,
          AtClientManager.getInstance().atClient.getCurrentAtSign()!)) {
        atsignToShareLocWith
            .add(eventKeyLocationModel.eventNotificationModel!.atsignCreator!);
      }

      if (eventKeyLocationModel
          .eventNotificationModel!.group!.members!.isNotEmpty) {
        Set<AtContact>? groupMembers =
            eventKeyLocationModel.eventNotificationModel!.group!.members!;

        // ignore: avoid_function_literals_in_foreach_calls
        groupMembers.forEach((member) {
          if (!compareAtSign(member.atSign!,
              AtClientManager.getInstance().atClient.getCurrentAtSign()!)) {
            atsignToShareLocWith.add(member.atSign!);
          }
        });
      }

      // converting event data to locationDataModel
      locationToShareWith = [
        ...locationToShareWith,
        ...eventNotificationToLocationDataModel(
            eventKeyLocationModel.eventNotificationModel!, atsignToShareLocWith)
      ];
    }

    if (initLocationSharing) {
      SendLocationNotification().initEventData(locationToShareWith);
    } else {
      await Future.forEach(locationToShareWith,
          (LocationDataModel _locationDataModel) async {
        await SendLocationNotification().addMember(_locationDataModel);
      });
    }
  }

  calculateLocationSharingForSingleEvent(
      EventNotificationModel eventData) async {
    await calculateLocationSharingAllEvents(listOfEvents: [
      EventKeyLocationModel(eventNotificationModel: eventData)
    ]);
  }

  List<LocationDataModel> eventNotificationToLocationDataModel(
      EventNotificationModel eventData, List<String> atsignList) {
    DateTime? _from;
    DateTime? _to;
    late LocationSharingFor locationSharingFor;

    /// calculate DateTime from and to
    if (compareAtSign(eventData.atsignCreator!,
        AtEventNotificationListener().currentAtSign!)) {
      _from = eventData.event!.startTime;
      _to = eventData.event!.endTime;
      locationSharingFor = LocationSharingFor(
          _from,
          _to,
          LocationSharingType.Event,
          !(eventData.isCancelled ?? false),
          eventData.isCancelled ?? false,
          eventData.isSharing ?? false);
    } else {
      late AtContact currentGroupMember;
      // ignore: avoid_function_literals_in_foreach_calls
      eventData.group!.members!.forEach((groupMember) {
        // sending location to other group members
        if (compareAtSign(groupMember.atSign!,
            AtEventNotificationListener().currentAtSign!)) {
          currentGroupMember = groupMember;
        }
      });

      _from = startTimeEnumToTimeOfDay(
              currentGroupMember.tags!['shareFrom'].toString(),
              eventData.event!.startTime) ??
          eventData.event!.startTime;
      _to = endTimeEnumToTimeOfDay(
              currentGroupMember.tags!['shareTo'].toString(),
              eventData.event!.endTime) ??
          eventData.event!.endTime;

      locationSharingFor = LocationSharingFor(
          _from,
          _to,
          LocationSharingType.Event,
          currentGroupMember.tags!['isAccepted'],
          currentGroupMember.tags!['isExited'],
          currentGroupMember.tags!['isSharing']);
    }

    // if (atsignList == null) {
    //   return [locationDataModel];
    // }

    List<LocationDataModel> locationToShareWith = [];
    // ignore: avoid_function_literals_in_foreach_calls
    atsignList.forEach((element) {
      LocationDataModel locationDataModel = LocationDataModel(
        {
          trimAtsignsFromKey(eventData.key!): locationSharingFor,
        },
        null,
        null,
        DateTime.now(),
        AtClientManager.getInstance().atClient.getCurrentAtSign()!,
        element,
      );
      // locationDataModel.receiver = element;
      locationToShareWith.add(locationDataModel);
    });

    return locationToShareWith;
  }

  EventNotificationModel getUpdatedEventData(
      EventNotificationModel originalEvent, EventNotificationModel ackEvent) {
    return originalEvent;
  }

  /// Removes a notification from list
  void removeData(String? key) {
    /// received key Example:
    ///  key: sharelocation-1637059616606602@26juststay
    ///
    if (key == null) {
      return;
    }

    EventNotificationModel? _eventNotificationModel;

    List<String> atsignsToRemove = [];
    allEventNotifications.removeWhere((notification) {
      if (key.contains(
          trimAtsignsFromKey(notification.eventNotificationModel!.key!))) {
        atsignsToRemove =
            getAtsignsFromEvent(notification.eventNotificationModel!);
        _eventNotificationModel = notification.eventNotificationModel;
      }
      return key.contains(
          trimAtsignsFromKey(notification.eventNotificationModel!.key!));
    });
    notifyListeners();
    // Remove location sharing
    if (_eventNotificationModel != null)
    // && (compareAtSign(locationNotificationModel.atsignCreator!, currentAtSign!))
    {
      SendLocationNotification().removeMember(key, atsignsToRemove,
          isExited: true, isAccepted: false, isSharing: false);
    }
  }

  deleteData(EventNotificationModel _eventNotificationModel) async {
    var key = _eventNotificationModel.key!;
    var keyKeyword = key.split('-')[0];
    var atkeyMicrosecondId = key.split('-')[1].split('@')[0];
    var response = await AtClientManager.getInstance().atClient.getKeys(
          regex: '$keyKeyword-$atkeyMicrosecondId',
        );
    if (response.isEmpty) {
      return;
    }

    var atkey = getAtKey(response[0]);
    await AtClientManager.getInstance().atClient.delete(atkey);
    removeData(key);
  }
}

class EventUserLocation {
  String? atsign;
  LatLng latLng;

  EventUserLocation(this.atsign, this.latLng);
}
