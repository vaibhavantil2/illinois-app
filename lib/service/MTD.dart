

import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:illinois/model/MTD.dart';
import 'package:illinois/service/Config.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rokwire_plugin/model/explore.dart';
import 'package:rokwire_plugin/service/app_livecycle.dart';
import 'package:rokwire_plugin/service/network.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/service.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class MTD with Service implements ExploreJsonHandler, NotificationsListener {

  static const String notifyStopsChanged = 'edu.illinois.rokwire.mtd.stops.changed';
  static const String _mtdStopsName = "mtdStops.json";

  late Directory _appDocDir;
  DateTime? _pausedDateTime;
  
  MTDStops? _stops;

  // Singleton Factory

  static final MTD _instance = MTD._internal();
  factory MTD() => _instance;
  MTD._internal();

  // Service

  void createService() {
    NotificationService().subscribe(this,[
      AppLivecycle.notifyStateChanged,
    ]);
    Explore.addJsonHandler(this);
    super.createService();
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
    Explore.removeJsonHandler(this);
    super.destroyService();
  }

  @override
  Future<void> initService() async {
    _appDocDir = await getApplicationDocumentsDirectory();
    
    // Init stops
    _stops = await _loadStopsFromCache();
    if (_stops != null) {
      _updateStops();
    }
    else {
      String? stopsJsonString = await _loadStopsStringFromNet();
      _stops = MTDStops.fromJson(JsonUtils.decodeMap(stopsJsonString));
      if (_stops != null) {
        _saveStopsStringToCache(stopsJsonString);
      }
    }

    await super.initService();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([Config()]);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param);
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState? state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime!);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _updateStops();
        }
      }
    }
  }

  // ExploreJsonHandler
  @override bool exploreCanJson(Map<String, dynamic>? json) => MTDStop.canJson(json);
  @override Explore? exploreFromJson(Map<String, dynamic>? json) => MTDStop.fromJson(json);

  // Stops

  MTDStops? get stops => _stops;

  List<MTDStop>? stopsByIds(LinkedHashSet<String>? stopIds) {
    return MTDStop.stopsInList2(_stops?.stops, stopIds: stopIds);
  }

  Future<void> refreshStops() => _updateStops();

  File _getStopsCacheFile() => File(join(_appDocDir.path, _mtdStopsName));

  Future<String?> _loadStopsStringFromCache() async {
    File stopsFile = _getStopsCacheFile();
    return await stopsFile.exists() ? await stopsFile.readAsString() : null;
  }

  Future<void> _saveStopsStringToCache(String? value) async {
    await _getStopsCacheFile().writeAsString(value ?? '', flush: true);
  }

  Future<MTDStops?> _loadStopsFromCache() async {
    return MTDStops.fromJson(JsonUtils.decodeMap(await _loadStopsStringFromCache()));
  }

  Future<String?> _loadStopsStringFromNet({ String? changesetId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url = "${Config().mtdUrl}/getstops?key=${Config().mtdApiKey}";
      if (changesetId != null) {
        url += "&changeset_id=$changesetId";
      }
      Response? response = await Network().get(url);
      return (response?.statusCode == 200) ? response?.body : null;
    }
    return null;
  }

  Future<void> _updateStops() async {
    String? stopsJsonString = await _loadStopsStringFromNet(changesetId: _stops?.changesetId);
    MTDStops? stops = MTDStops.fromJson(JsonUtils.decodeMap(stopsJsonString));
    if ((stops != null) && (stops.changesetId != _stops?.changesetId)) {
      _stops = stops;
      _saveStopsStringToCache(stopsJsonString);
      NotificationService().notify(notifyStopsChanged);
    }
  }

  // Routes

  Future<List<MTDRoute>?> getRoutes({String? stopId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url = StringUtils.isNotEmpty(stopId) ?
        "${Config().mtdUrl}/getroutesbystop?key=${Config().mtdApiKey}&stop_id=$stopId" :
        "${Config().mtdUrl}/getroutes?key=${Config().mtdApiKey}";
      Response? response = await Network().get(url);
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDRoute.listFromJson(JsonUtils.listValue(responseJson['routes'])) : null;
    }
    return null;
  }

  // Stop Times

  Future<List<MTDStopTime>?> getStopTimes({String? stopId, String? tripId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String? url;
      if (stopId != null) {
        url = "${Config().mtdUrl}/getroutesbystop?key=${Config().mtdApiKey}&stop_id=$stopId";
      }
      else if (tripId != null) {
        url = "${Config().mtdUrl}/getstoptimesbytrip?key=${Config().mtdApiKey}&trip_id=$tripId";
      }
      Response? response = (url != null) ? await Network().get(url) : null;
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDStopTime.listFromJson(JsonUtils.listValue(responseJson['stop_times'])) : null;
    }
    return null;
  }

  // Departures

  Future<List<MTDDeparture>?> getDepartures({required String stopId, String? routeId, int? previewTime, int? count}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url = "${Config().mtdUrl}/getdeparturesbystop?key=${Config().mtdApiKey}&stop_id=$stopId";
      if (routeId != null) {
        url += "&route_id=$routeId";
      }
      if (previewTime != null) {
        url += "&pt=$previewTime";
      }
      if (count != null) {
        url += "&count=$count";
      }
      Response? response = await Network().get(url);
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDDeparture.listFromJson(JsonUtils.listValue(responseJson['departures'])) : null;
    }
    return null;
  }

  // Shape

  Future<List<MTDShape>?> getShapes({required String shapeId, String? beginStopId, String? endStopId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url;
      if ((beginStopId != null) && (endStopId != null)) {
        url = "${Config().mtdUrl}/getshapebetweenstops?key=${Config().mtdApiKey}&shape_id=$shapeId&begin_stop_id=$beginStopId&end_stop_id=$endStopId";
      }
      else {
        url = "${Config().mtdUrl}/getshape?key=${Config().mtdApiKey}&shape_id=$shapeId";
      }
      Response? response = await Network().get(url);
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDShape.listFromJson(JsonUtils.listValue(responseJson['shapes'])) : null;
    }
    return null;
  }

  // Trip

  Future<List<MTDTrip>?> getTrips({String? tripId, String? blockId, String? routeId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String? url;
      if (tripId != null) {
        url = "${Config().mtdUrl}/gettrip?key=${Config().mtdApiKey}&trip_id=$tripId";
      }
      else if (blockId != null) {
        url = "${Config().mtdUrl}/gettripsbyblock?key=${Config().mtdApiKey}&block_id=$blockId";
      }
      else if (routeId != null) {
        url = "${Config().mtdUrl}/gettripsbyroute?key=${Config().mtdApiKey}&route_id=$routeId";
      }
      Response? response = (url != null) ? await Network().get(url) : null;
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDTrip.listFromJson(JsonUtils.listValue(responseJson['trips'])) : null;
    }
    return null;
  }

  // Vehicle

  Future<List<MTDVehicle>?> getVehicles({String? vehicleId, String? routeId}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url;
      if (vehicleId != null) {
        url = "${Config().mtdUrl}/getvehicle?key=${Config().mtdApiKey}&vehicle_id=$vehicleId";
      }
      else if (routeId != null) {
        url = "${Config().mtdUrl}/getvehiclesbyroute?key=${Config().mtdApiKey}&route_id=$routeId";
      }
      else {
        url = "${Config().mtdUrl}/getvehicles?key=${Config().mtdApiKey}";
      }
      Response? response = await Network().get(url);
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDVehicle.listFromJson(JsonUtils.listValue(responseJson['vehicles'])) : null;
    }
    return null;
  }

  // Planned Trips

  Future<List<MTDItinerary>?> getPlannedTrip({required MTDLocation origin, required MTDLocation destination}) async {
    if (StringUtils.isNotEmpty(Config().mtdUrl) && StringUtils.isNotEmpty(Config().mtdApiKey)) {
      String url = "${Config().mtdUrl}/getplannedtripsbylatlon?key=${Config().mtdApiKey}&origin_lat=${origin.latitude}&origin_lon=${origin.longitude}&destination_lat=${destination.latitude}&destination_lon=${destination.longitude}";
      Response? response = await Network().get(url);
      Map<String, dynamic>? responseJson = (response?.statusCode == 200) ? JsonUtils.decodeMap(response?.body)  : null;
      return (responseJson != null) ? MTDItinerary.listFromJson(JsonUtils.listValue(responseJson['itineraries'])) : null;
    }
    return null;
  }
}