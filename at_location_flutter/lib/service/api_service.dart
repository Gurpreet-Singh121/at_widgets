import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  Future<dynamic> getRequest(String url, [Map<String, String> header]) async {
    bool val = await ConnectivityService().checkConnectivity();
    if (val) {
      return http.get(url, headers: header).then((http.Response response) {
        final int statusCode = response.statusCode;
        print(statusCode);
        if (statusCode == 200) {
          return {
            'status': true,
            "body": utf8.decode(response.bodyBytes),
            'message': 'success',
            'header': response.headers,
            'code': statusCode,
          };
        } else {
          return {
            'status': false,
            'body': response.body,
            'message': (response.statusCode == 404)
                ? "Page not Found"
                : (response.statusCode == 401)
                    ? 'Unauthorized'
                    : 'Error occured while Fetching Data',
            'header': response.headers,
            'code': statusCode,
          };
        }
      });
    } else {
      return {
        'status': false,
        'message': 'No Internet',
      };
    }
  }

  Future<dynamic> postRequest(String url,
      {Map<String, String> headers, body, encoding}) async {
    bool val = await ConnectivityService().checkConnectivity();
    if (val) {
      return http
          .post(url,
              body: json.encode(body), headers: headers, encoding: encoding)
          .then((http.Response response) {
        final int statusCode = response.statusCode;
        print(statusCode);
        if (statusCode == 200) {
          return {
            'status': true,
            'body': utf8.decode(response.bodyBytes),
            'message': 'success',
            'header': response.headers,
            'code': statusCode,
          };
        } else if (statusCode == 201) {
          return {
            'status': true,
            'body': response.body,
            'message': 'created',
            'header': response.headers,
            'code': statusCode,
          };
        } else {
          return {
            'status': false,
            'body': response.body,
            'message': (response.statusCode == 404)
                ? "Page not Found"
                : (response.statusCode == 401)
                    ? 'Unauthorized'
                    : 'Error occured while Fetching Data',
            'header': response.headers,
            'code': statusCode,
          };
        }
      });
    } else {
      return {
        'status': false,
        'message': 'No Internet',
      };
    }
  }
}

class ConnectivityService {
  ConnectivityService._();
  static ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  Future<bool> checkConnectivity() async {
    Socket socket;
    bool connectivity;
    await Future.delayed(Duration(milliseconds: 100));
    try {
      socket =
          await Socket.connect("google.com", 80, timeout: Duration(seconds: 4));
      connectivity = true;
    } catch (e) {
      checkInternetConnection();
      connectivity = false;
    } finally {
      try {
        await socket?.close();
      } catch (e) {}
    }
    print("conn $connectivity");
    return connectivity;
  }

  checkInternetConnection() {
    // Fluttertoast.showToast(
    //     msg: "Check Internet Connection",
    //     toastLength: Toast.LENGTH_LONG,
    //     gravity: ToastGravity.SNACKBAR,
    //     timeInSecForIosWeb: 4,
    //     backgroundColor: MyColors().GREY_COLOR,
    //     textColor: MyColors().WHITE_TEXT_COLOR,
    //     fontSize: 16.0);
  }
}