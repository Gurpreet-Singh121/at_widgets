import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_onboarding_flutter/utils/app_constants.dart';
import 'package:http/io_client.dart';

class FreeAtsignService {
  static final freeAtsignService = FreeAtsignService._internal();
  FreeAtsignService._internal() {
    _init();
  }

  factory FreeAtsignService() => freeAtsignService;

  var _http;
  bool initialized = false;
  var api;
  var path = '/api/app/v1/';

  _init() {
    final ioc = new HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    _http = new IOClient(ioc);
    initialized = true;
    setApi();
  }

  setApi() {
    // for prod
    if (AppConstants.serverDomain == 'root.atsign.org') {
      api = 'my.atsign.com';
    }

    // api for dev environment
    if (AppConstants.serverDomain == 'root.atsign.wtf') {
      api = 'my.atsign.wtf';
    }
  }


//To get free @sign from the server
  Future<dynamic> getFreeAtsigns() async {
    // if init was not called earlier, call here to initialize the http
    if (!initialized) {
      _init();
    }
    var url = Uri.https(api, '${path}get-free-atsign');

    var response = await _http.get(url, headers: {
      "Authorization": "477b-876u-bcez-c42z-6a3d",
      "Content-Type": "application/json"
    });

    return response;
  }

//To register the person with the provided atsign and email
//It will send an OTP to the registered email
  Future<dynamic> registerPerson(String atsign, String email) async {
    if (!initialized) {
      _init();
    }

    var url = Uri.https(api, '${path}register-person');

    Map data = {'email': '$email', 'atsign': "$atsign"};

    String body = json.encode(data);
    var response = await _http.post(url, body: body, headers: {
      'Authorization': '477b-876u-bcez-c42z-6a3d',
      'Content-Type': 'application/json'
    });
    return response;
  }

//It will validate the person with atsign, email and the OTP.
//If the validation is successful, it will return a cram secret for the user to login
  Future<dynamic> validatePerson(
      String atsign, String email, String otp) async {
    if (!initialized) {
      _init();
    }

    var url = Uri.https(api, '${path}validate-person');

    Map data = {'email': '$email', 'atsign': "$atsign", 'otp': '$otp'};

    String body = json.encode(data);
    var response = await _http.post(url, body: body, headers: {
      'Authorization': '477b-876u-bcez-c42z-6a3d',
      'Content-Type': 'application/json'
    });

    return response;
  }
}