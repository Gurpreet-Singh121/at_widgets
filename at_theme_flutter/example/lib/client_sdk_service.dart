import 'dart:async';
import 'dart:io';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:example/src/utils/constants.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class ClientSdkService {
  static final ClientSdkService _singleton = ClientSdkService._internal();
  ClientSdkService._internal();

  factory ClientSdkService.getInstance() {
    return _singleton;
  }
  AtClientService? atClientServiceInstance;

  late AtClientPreference atClientPreference;
  String? _atsign;
  String? get currentAtsign => _atsign;
  set setCurrentAtsign(String? atsign) {
    _atsign = atsign;
  }

  set setAtsign(String atSign) {
    _atsign = atSign;
  }

  Future<bool> onboard({String? atsign}) async {
    atClientServiceInstance = AtClientService();
    Directory? downloadDirectory;
    if (Platform.isIOS) {
      downloadDirectory =
          await path_provider.getApplicationDocumentsDirectory();
    } else {
      downloadDirectory = await path_provider.getExternalStorageDirectory();
    }

    final appSupportDirectory =
        await path_provider.getApplicationSupportDirectory();
    var path = appSupportDirectory.path;
    atClientPreference = AtClientPreference();

    atClientPreference.isLocalStoreRequired = true;
    atClientPreference.commitLogPath = path;
    atClientPreference.rootDomain = MixedConstants.ROOT_DOMAIN;
    atClientPreference.hiveStoragePath = path;
    atClientPreference.downloadPath = downloadDirectory!.path;
    var result = await atClientServiceInstance!
        .onboard(atClientPreference: atClientPreference, atsign: atsign)
        .catchError((e) {
      print('Error in Onboarding: $e');
    });
    if (result) {
      _atsign = AtClientManager.getInstance().atClient.getCurrentAtSign();
    }
    return result;
  }

  ///Fetches atsign from device keychain.
  Future<String?> getAtSign() async {
    return KeychainUtil.getAtSign();
  }
}
