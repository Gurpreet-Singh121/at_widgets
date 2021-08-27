import 'package:at_onboarding_flutter/services/at_error_dialog.dart';
import 'package:at_onboarding_flutter/utils/app_constants.dart';
import 'package:at_onboarding_flutter/utils/strings.dart';
import 'package:at_onboarding_flutter/services/sdk_service.dart';
import 'package:at_onboarding_flutter/utils/color_constants.dart';
import 'package:flutter/material.dart';

/// Custom reset button widget is to reset an atsign from keychain list,

class CustomResetButton extends StatefulWidget {

  bool? loading;
  final String? buttonText;
  final double? width;
  final double? height;
  CustomResetButton(
      {Key? key,
        this.loading = false,
        this.buttonText,
        this.height,
        this.width,
      })
      : super(key: key);

  @override
  State<CustomResetButton> createState() => _CustomResetButtonState();
}

class _CustomResetButtonState extends State<CustomResetButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showResetDialog,
      child: Container(
        width: widget.width ,
        height: widget.height,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.grey[200]),
        child: Center(
          child: Text(
            widget.buttonText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
            //style: CustomTextStyles.fontBold16light,
          ),
        ),
      ),
    );
  }

  _showResetDialog() async {
    bool isSelectAtsign = false;
    bool isSelectAll = false;
    List<String>? atsignsList = await SDKService().getAtsignList();
    Map<String?,bool?>? atsignMap ;
    if(atsignsList != null && atsignMap != null){
      for (String atsign in atsignsList) {
        atsignMap[atsign] = false;
      }
    }
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (BuildContext context, void Function(void Function()) stateSet) {
            return AlertDialog(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(Strings.resetDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15)),
                    SizedBox(
                      height: 10,
                    ),
                    Divider(
                      thickness: 0.8,
                    )
                  ],
                ),
                content: atsignsList == null && atsignMap == null
                    ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(Strings.noAtsignToReset,
                      style: TextStyle(fontSize: 15)),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(AppConstants.closeButton,
                            style: TextStyle(
                                fontSize: 15,
                                color: Color.fromARGB(255, 240, 94, 62)))),
                  )
                ])
                    : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CheckboxListTile(
                        onChanged: (bool? value) {
                          isSelectAll = value!;
                          atsignMap != null ? atsignMap
                              .updateAll((String? key,bool? value1) => value1 = value):true;
                          // atsignMap[atsign] = value;
                          stateSet(() {});
                        },
                        value: isSelectAll,
                        checkColor: Colors.white,
                        activeColor: Color.fromARGB(255, 240, 94, 62),
                        title: Text('Select All',
                            style: TextStyle(
                              // fontSize: 14,
                              fontWeight: FontWeight.bold,
                            )),
                        // trailing: Checkbox,
                      ),
                      for (String atsign in atsignsList!)
                        CheckboxListTile(
                          onChanged: (bool? value) {
                            atsignMap != null ? atsignMap[atsign] = value : true;
                            stateSet(() {});
                          },
                          value: atsignMap != null ? atsignMap[atsign]:true,
                          checkColor: Colors.white,
                          activeColor: Color.fromARGB(255, 240, 94, 62),
                          title: Text('$atsign'),
                          // trailing: Checkbox,
                        ),
                      Divider(thickness: 0.8),
                      if (isSelectAtsign)
                        Text(Strings.resetErrorText,
                            style: TextStyle(
                                color: Colors.red, fontSize: 14)),
                      SizedBox(
                        height: 10,
                      ),
                      Text(Strings.resetWarningText,
                          style: TextStyle(
                              color: ColorConstants.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      SizedBox(
                        height: 10,
                      ),
                      Row(children:<Widget> [
                        TextButton(
                          onPressed: () {
                            Map<String?,bool?>? tempAtsignMap ;
                            tempAtsignMap != null ? tempAtsignMap.addAll(atsignMap!): true;
                            tempAtsignMap != null ? tempAtsignMap.removeWhere(
                                    (String? key, bool? value) => value == false) : true;
                            if(tempAtsignMap != null){
                              if (tempAtsignMap.keys.toList() != null) {
                              isSelectAtsign = true;
                              stateSet(() {});
                            } else {
                              isSelectAtsign = false;
                              _resetDevice(tempAtsignMap.keys.toList());
                            }
                          }},
                          child: Text(AppConstants.removeButton,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(255, 240, 94, 62))),
                        ),
                        Spacer(),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(AppConstants.cancelButton,
                                style: TextStyle(
                                    fontSize: 15, color: Colors.black)))
                      ])
                    ],
                  ),
                ));
          });
          // );
        });
  }
  _resetDevice(List<dynamic> checkedAtsigns) async {
    Navigator.of(context).pop();
    setState(() {
      widget.loading = true;
    });
    await SDKService().resetAtsigns(checkedAtsigns).then((void value) async {
      setState(() {
        widget.loading = false;
      });
    }).catchError((Object error) {
      setState(() {
        widget.loading = false;
      });
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AtErrorDialog.getAlertDialog(error, context);
          });
    });
  }
}
