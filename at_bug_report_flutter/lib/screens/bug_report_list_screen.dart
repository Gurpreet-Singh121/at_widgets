import 'package:at_bug_report_flutter/models/bug_report_model.dart';
import 'package:at_bug_report_flutter/services/bug_report_service.dart';
import 'package:at_bug_report_flutter/utils/strings.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/services/size_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'bug_report_tab.dart';

class ListBugReportScreen extends StatefulWidget {
  final String title;
  final String? atSign;
  final String? authorAtSign;

  const ListBugReportScreen({
    Key? key,
    this.title = 'List Reported Issues',
    this.atSign = '',
    this.authorAtSign = '',
  }) : super(key: key);

  @override
  _ListBugReportScreenState createState() => _ListBugReportScreenState();
}

class _ListBugReportScreenState extends State<ListBugReportScreen>
    with SingleTickerProviderStateMixin {
  TabController? _controller;

  GlobalKey<ScaffoldState>? scaffoldKey;
  late BugReportService _bugReportService;

  @override
  void initState() {
    super.initState();

    _controller = TabController(length: 2, vsync: this, initialIndex: 0);
    scaffoldKey = GlobalKey<ScaffoldState>();
    _bugReportService = BugReportService();
    _bugReportService.setAuthorAtSign(widget.authorAtSign);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.black,
          ),
          onPressed: () async {
            Navigator.of(context).pop();
          },
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          height: SizeConfig().screenHeight,
          child: Column(
            children: [
              Container(
                height: 50,
                child: TabBar(
                  onTap: (index) {},
                  labelColor: Colors.black,
                  indicatorWeight: 3.toHeight,
                  indicatorColor: Colors.black,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 14.toFont,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 14.toFont,
                      fontWeight: FontWeight.normal),
                  controller: _controller,
                  tabs: [
                    Text(
                      Strings.sentTitle,
                    ),
                    Text(
                      Strings.receivedTitle,
                    )
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _controller,
                  children: [
                    ListBugReportTab(
                      bugReportService: _bugReportService,
                      isAuthorAtSign: false,
                      atSign: widget.atSign,
                    ),
                    ListBugReportTab(
                      bugReportService: _bugReportService,
                      isAuthorAtSign: true,
                      atSign: widget.atSign,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}