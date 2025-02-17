import 'package:at_common_flutter/services/size_config.dart';
import 'package:at_common_flutter/widgets/custom_input_field.dart';
import 'package:at_events_flutter/common_components/custom_toast.dart';
import 'package:at_events_flutter/common_components/location_tile.dart';
import 'package:at_events_flutter/screens/selected_location.dart';
import 'package:at_events_flutter/utils/text_styles.dart';
import 'package:at_events_flutter/utils/texts.dart';
import 'package:at_location_flutter/at_location_flutter.dart';
import 'package:at_location_flutter/location_modal/location_modal.dart';
import 'package:at_location_flutter/service/my_location.dart';
import 'package:flutter/material.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:latlong2/latlong.dart';

class SelectLocation extends StatefulWidget {
  const SelectLocation({Key? key}) : super(key: key);

  @override
  _SelectLocationState createState() => _SelectLocationState();
}

class _SelectLocationState extends State<SelectLocation> {
  String inputText = '';
  bool isLoader = false, loadingForPermission = true;
  bool nearMe = false; // checkbox state.
  LatLng? currentLocation;
  bool _isLocationServiceEnabled = false; // location permission state.

  @override
  void initState() {
    calculateLocation();
    super.initState();
  }

  /// nearMe == null => loading
  /// nearMe == false => dont search nearme
  /// nearMe == true => search nearme
  /// nearMe == false && currentLocation == null =>dont search nearme
  // ignore: always_declare_return_types
  calculateLocation() async {
    _isLocationServiceEnabled = await isLocationServiceEnabled();
    if (_isLocationServiceEnabled == true) {
      nearMe = true;
    } else {
      nearMe = false;
    }
    setState(() {
      loadingForPermission = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SizeConfig().screenHeight * 0.8,
      padding: EdgeInsets.fromLTRB(28.toWidth, 20.toHeight, 17.toWidth, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: CustomInputField(
                  hintText: AllText().SEARCH_AN_AREA_STREET_NAME,
                  height: 50.toHeight,
                  initialValue: inputText,
                  onSubmitted: (String str) async {
                    setState(() {
                      isLoader = true;
                    });
                    if (!nearMe) {
                      // ignore: await_only_futures
                      SearchLocationService().getAddressLatLng(str, null);
                    } else {
                      currentLocation = await getCurrentPosition();
                      // ignore: await_only_futures
                      SearchLocationService()
                          .getAddressLatLng(str, currentLocation);
                    }

                    setState(() {
                      isLoader = false;
                    });
                  },
                  value: (val) {
                    inputText = val;
                  },
                  icon: Icons.search,
                  onIconTap: () async {
                    setState(() {
                      isLoader = true;
                    });
                    if (!nearMe) {
                      // ignore: await_only_futures
                      SearchLocationService().getAddressLatLng(inputText, null);
                    } else {
                      currentLocation = await getCurrentPosition();
                      // ignore: await_only_futures
                      SearchLocationService()
                          .getAddressLatLng(inputText, currentLocation);
                    }
                    setState(() {
                      isLoader = false;
                    });
                  },
                ),
              ),
              SizedBox(width: 10.toWidth),
              Column(
                children: [
                  InkWell(
                      onTap: () => Navigator.pop(context),
                      child:
                          Text(AllText().CANCEL, style: CustomTextStyles().orange16)),
                ],
              ),
            ],
          ),
          SizedBox(height: 5.toHeight),
          loadingForPermission
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(AllText().GETTING_LOCATION_PERMISSION,
                      style: CustomTextStyles().red12),
                )
              : Row(
                  children: <Widget>[
                    Checkbox(
                      value: nearMe,
                      tristate: true,
                      onChanged: (value) async {
                        if (loadingForPermission) return;

                        setState(() {
                          loadingForPermission = true;
                        });

                        if (!nearMe) {
                          _isLocationServiceEnabled =
                              await isLocationServiceEnabled();
                        }

                        if (!_isLocationServiceEnabled) {
                          CustomToast().show(
                              AllText().UNABLE_TO_ACCESS_LOCATION, context,
                              isError: true);
                          setState(() {
                            nearMe = false;
                            loadingForPermission = false;
                          });
                          return;
                        }

                        setState(() {
                          nearMe = !nearMe;
                          loadingForPermission = false;
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AllText().NEAR_ME,
                              style: CustomTextStyles().greyLabel14),
                          (!_isLocationServiceEnabled)
                              ? Flexible(
                                  child: Text(
                                      AllText().CANNOT_ACCESS_LOCATION_PERMISSION,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: CustomTextStyles().red12),
                                )
                              : const SizedBox()
                        ],
                      ),
                    )
                  ],
                ),
          SizedBox(height: 5.toHeight),
          const Divider(),
          SizedBox(height: 18.toHeight),
          InkWell(
            onTap: () async {
              if (!_isLocationServiceEnabled) {
                CustomToast()
                    .show(AllText().UNABLE_TO_ACCESS_LOCATION, context, isError: true);
                return;
              }
              currentLocation = await getCurrentPosition();

              onLocationSelect(context, currentLocation!);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AllText().CURRENT_LOCATION, style: CustomTextStyles().greyLabel14),
                SizedBox(height: 5.toHeight),
                Text(AllText().USING_GPS, style: CustomTextStyles().greyLabel12),
              ],
            ),
          ),
          SizedBox(height: 20.toHeight),
          const Divider(),
          SizedBox(height: 20.toHeight),
          isLoader
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : const SizedBox(),
          StreamBuilder(
            stream: SearchLocationService().atLocationStream,
            builder: (BuildContext context,
                AsyncSnapshot<List<LocationModal>> snapshot) {
              return snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox()
                  : snapshot.hasData
                      // ignore: prefer_is_empty
                      ? snapshot.data!.length == 0
                          ? Text(AllText().NO_SUCH_LOCATION_FOUND)
                          : Expanded(
                              child: ListView.separated(
                                itemCount: snapshot.data!.length,
                                separatorBuilder: (context, index) {
                                  return Column(
                                    children: const [
                                      SizedBox(height: 20),
                                      Divider(),
                                    ],
                                  );
                                },
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () => onLocationSelect(
                                      context,
                                      LatLng(
                                          double.parse(
                                              snapshot.data![index].lat!),
                                          double.parse(
                                              snapshot.data![index].long!)),
                                      displayName:
                                          snapshot.data![index].displayName,
                                    ),
                                    child: LocationTile(
                                      icon: Icons.location_on,
                                      title: snapshot.data![index].city,
                                      subTitle:
                                          snapshot.data![index].displayName,
                                    ),
                                  );
                                },
                              ),
                            )
                      : snapshot.hasError
                          ? Text(AllText().SOMETHING_WENT_WRONG)
                          : const SizedBox();
            },
          ),
        ],
      ),
    );
  }
}

void onLocationSelect(BuildContext context, LatLng point,
    {String? displayName}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SelectedLocation(displayName ?? AllText().YOUR_LOCATION, point)));
}
