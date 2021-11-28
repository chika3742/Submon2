import 'dart:io';

import 'package:event_bus/event_bus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submon/events.dart';
import 'package:submon/local_db/shared_prefs.dart';
import 'package:submon/pages/home_tabs/tab_memorize_card.dart';
import 'package:submon/pages/home_tabs/tab_others.dart';
import 'package:submon/pages/home_tabs/tab_submissions.dart';
import 'package:submon/pages/home_tabs/tab_timetable.dart';
import 'package:submon/utils/ui.dart';

import '../fade_through_page_route.dart';
import '../utils/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _eventBus = EventBus();
  var tabIndex = 0;

  List<BottomNavigationBarItem> _bottomNavigationItems() => const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: "提出物",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.table_chart_outlined),
      label: "時間割表",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.school),
      label: "暗記カード",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.more_horiz),
      label: "その他",
    ),
  ];

  List<Widget> pages = [];

  @override
  void initState() {
    super.initState();
    initDynamicLinks();
    pages = [
      TabSubmissions(_eventBus),
      TabTimetable(),
      const TabMemorizeCard(),
      const TabOthers(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isMacOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
            middle: Text(_bottomNavigationItems()[tabIndex].label!)),
        child: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: _bottomNavigationItems(),
            currentIndex: tabIndex,
            onTap: onBottomNavTap,
          ),
          tabBuilder: (ctx, index) {
            return SafeArea(child: pages[index]);
          },
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text(_bottomNavigationItems()[tabIndex].label!),
        ),
        body: SafeArea(
          child: Navigator(
            key: _navigatorKey,
            onGenerateRoute: (settings) {
              return FadeThroughPageRoute(pages.first);
            },
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: tabIndex,
          items: _bottomNavigationItems(),
          onTap: onBottomNavTap,
        ),
      );
    }
  }

  void onBottomNavTap(int index) {
    if (tabIndex == index) {
      _eventBus.fire(BottomNavDoubleClickEvent(index));
      return;
    }
    setState(() {
      tabIndex = index;
    });
    _navigatorKey.currentState
        ?.pushReplacement(FadeThroughPageRoute(pages[index]));
  }

  void initDynamicLinks() {
    FirebaseDynamicLinks.instance.getInitialLink().then((linkData) {
      if (linkData != null) handleDynamicLink(linkData.link);
    });
    FirebaseDynamicLinks.instance.onLink(onSuccess: (linkData) async {
      if (linkData != null) handleDynamicLink(linkData.link);
    });
  }

  void handleDynamicLink(Uri url) async {
    var auth = FirebaseAuth.instance;
    var code = url.queryParameters["oobCode"];
    if (code == null) return;

    showLoadingModal(context);

    ActionCodeInfo codeInfo;
    try {
      codeInfo = await auth.checkActionCode(code);
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();
      switch (e.code) {
        case "invalid-action-code":
        case "firebase_auth/invalid-action-code":
          showSnackBar(context, "このリンクは無効です。期限が切れたか、形式が正しくありません。");
          break;
        default:
          handleAuthError(e, context);
          break;
      }
      return;
    }

    try {
      if (auth.isSignInWithEmailLink(url.toString())) {
        final pref = SharedPrefs(await SharedPreferences.getInstance());
        final email = pref.linkSignInEmail;
        if (email != null) {
          var result = await auth.signInWithEmailLink(
              email: email, emailLink: url.toString());
          Navigator.of(context)
              .pushNamed("/signIn", arguments: {"initialCred": result});
        } else {
          showSimpleDialog(
              context, "エラー", "メールアドレスが保存されていません。再度この端末でメールを送信してください。");
        }
      } else if (codeInfo.operation ==
          ActionCodeInfoOperation.verifyAndChangeEmail) {
        await auth.applyActionCode(code);
        await auth.signOut();
        showSnackBar(context, "メールアドレスの変更が完了しました。再度ログインが必要となります。");
        Navigator.pushNamed(context, "/signIn");
      }
    } on FirebaseAuthException catch (e) {
      handleAuthError(e, context);
    }
    Navigator.pop(context);
  }
}
