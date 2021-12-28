import 'package:at_common_flutter/services/size_config.dart';
import 'package:at_contacts_flutter/utils/colors.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class DesktopCustomInputField extends StatelessWidget {
  final String hintText, initialValue;
  final double width, height;
  final IconData? icon;
  final Function()? onTap, onIconTap;
  final Function? onSubmitted;
  final Color? iconColor, backgroundColor;
  final ValueChanged<String>? value;
  final bool isReadOnly;

  TextEditingController textController = TextEditingController();

  DesktopCustomInputField(
      {this.hintText = '',
      this.height = 50,
      this.width = 300,
      this.iconColor,
      this.icon,
      this.onTap,
      this.onIconTap,
      this.value,
      this.initialValue = '',
      this.onSubmitted,
      this.backgroundColor,
      this.isReadOnly = false});

  @override
  Widget build(BuildContext context) {
    textController = TextEditingController.fromValue(TextEditingValue(
        text: initialValue != null ? initialValue : '',
        selection: TextSelection.collapsed(
            offset: initialValue != null ? initialValue.length : -1)));
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: backgroundColor ?? ColorConstants.inputFieldColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Color(0xFFBFBFBF))),
      padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: TextField(
                readOnly: isReadOnly,
                style: TextStyle(
                  fontSize: 15.toFont,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  enabledBorder: InputBorder.none,
                  border: InputBorder.none,
                  hintStyle:
                      TextStyle(color: Color(0xFFBFBFBF), fontSize: 15.toFont),
                ),
                onTap: onTap ?? () {},
                onChanged: (val) {
                  value!(val);
                },
                controller: textController,
                onSubmitted: (str) {
                  if (onSubmitted != null) {
                    onSubmitted!(str);
                  }
                },
              ),
            ),
            icon != null
                ? InkWell(
                    onTap: onIconTap ?? onTap ?? () {},
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(
                        icon,
                        color: iconColor ?? ColorConstants.fadedText,
                      ),
                    ),
                  )
                : SizedBox()
          ],
        ),
      ),
    );
  }
}
