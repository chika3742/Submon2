import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:submon/components/settings_ui.dart';
import 'package:submon/db/shared_prefs.dart';
import 'package:submon/method_channel/main.dart';
import 'package:submon/method_channel/notification.dart';
import 'package:submon/pages/sign_in_page.dart';
import 'package:submon/utils/ui.dart';
import 'package:submon/utils/utils.dart';

class FunctionsSettingsPage extends StatefulWidget {
  const FunctionsSettingsPage({Key? key}) : super(key: key);

  @override
  _FunctionsSettingsPageState createState() => _FunctionsSettingsPageState();
}

var _scopes = [calendar.CalendarApi.calendarEventsScope];
var googleSignIn = GoogleSignIn(scopes: _scopes);

class _FunctionsSettingsPageState extends State<FunctionsSettingsPage> {
  bool _pwEnabled = true;
  bool? _enableSE;
  TimeOfDay? _reminderTime;
  Timer? _signInStateCheckTimer;
  bool _signInStateCheckDelayed = false;

  bool? _signedInAndScopeGranted;
  StreamSubscription? _accountListener;

  @override
  void initState() {
    super.initState();
    SharedPrefs.use((prefs) {
      setState(() {
        _enableSE = prefs.enableSE;
        _reminderTime = prefs.reminderTime;
      });
    });

    googleSignIn.isSignedIn().then((signedIn) {
      if (signedIn) {
        _signInStateCheckTimer = Timer(const Duration(seconds: 5), () {
          setState(() {
            _signInStateCheckDelayed = true;
          });
        });
        _checkSignedInAndScopeGranted();
      } else {
        setState(() {
          _signedInAndScopeGranted = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _accountListener?.cancel();
    _signInStateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var auth = FirebaseAuth.instance;
    var displayName = auth.currentUser?.displayName;

    return SettingsListView(
      categories: [
        SettingsCategory(
          title: "リマインダー通知",
          tiles: [
            SettingsTile(
                subtitle: "設定した時刻にリマインダー通知をします。期限が近づいた提出物がある場合、その一覧を通知します。"),
            SettingsTile(
              title: "通知時刻",
              subtitle: _reminderTime != null
                  ? _reminderTime!.format(context)
                  : "タップして設定",
              leading: const Icon(Icons.schedule),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  SharedPrefs.use((prefs) {
                    prefs.reminderTime = null;
                  });
                  setState(() {
                    _reminderTime = null;
                  });
                  NotificationMethodChannel.unregisterReminder();
                },
              ),
              onTap: () async {
                if (await NotificationMethodChannel.isGranted() == false) {
                  showSnackBar(context, "通知の表示が許可されていません。本体設定から許可してください。");
                } else {
                  var result = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime ?? TimeOfDay.now(),
                  );
                  if (result != null) {
                    SharedPrefs.use((prefs) {
                      prefs.reminderTime = result;
                    });
                    setState(() {
                      _reminderTime = result;
                    });
                    NotificationMethodChannel.registerReminder();
                  }
                }
              },
            ),
          ],
        ),
        SettingsCategory(title: "アカウント", tiles: [
          SettingsTile(
            title: auth.currentUser != null ? "ログアウト" : "ログイン / 新規登録",
            onTap: () async {
              if (auth.currentUser == null) {
                await pushPage(context, const SignInPage());
                setState(() {});
              } else {
                showSimpleDialog(context, "確認", "ログアウトしますか？",
                    onOKPressed: () async {
                      await auth.signOut();
                  await GoogleSignIn().signOut();
                  updateWidgets();
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, "welcome");
                  showSnackBar(context, "ログアウトしました");
                }, showCancel: true);
              }
            },
          ),
          if (auth.currentUser != null)
            SettingsTile(
              title: emailChangeable() ? "メールアドレスの変更" : "メールアドレス",
              subtitle: auth.currentUser!.email,
              onTap: emailChangeable()
                  ? () async {
                      await Navigator.pushNamed(
                          context, "/account/changeEmail");
                      setState(() {});
                    }
                  : null,
            ),
          if (auth.currentUser != null && passwordChangeable() && _pwEnabled)
            SettingsTile(
              title: "パスワードの変更",
              onTap: () {
                _changePassword();
              },
            ),
          if (auth.currentUser != null)
            SettingsTile(
              title: "ユーザー名の変更",
              subtitle: displayName != null && displayName.isNotEmpty
                  ? displayName
                  : "未設定",
              onTap: () async {
                await Navigator.pushNamed(
                    context, "/account/changeDisplayName");
                setState(() {});
              },
            ),
          if (auth.currentUser != null)
            SettingsTile(
              title: "アカウントの削除",
              titleTextStyle: const TextStyle(color: Colors.red),
              onTap: () async {
                await Navigator.pushNamed(context, "/account/delete");
                setState(() {});
              },
            ),
        ]),
        SettingsCategory(title: "Googleカレンダー連携", tiles: [
          SettingsTile(
              title: _signedInAndScopeGranted != true
                  ? "Googleカレンダーと連携"
                  : "Googleカレンダー連携を解除",
              subtitle: _signedInAndScopeGranted != null
                  ? (_signedInAndScopeGranted != true
                      ? "Googleカレンダーへ提出物を同期します。"
                      : "カレンダー連携を解除します。")
                  : "連携状態を確認しています...${_signInStateCheckDelayed ? " (この処理に時間がかかっている場合は、アプリ再起動をお試しください。)" : ""}",
              enabled: _signedInAndScopeGranted != null,
              onTap: () async {
                if (_signedInAndScopeGranted == false) {
                  dynamic result;
                  if (googleSignIn.currentUser != null) {
                    result = await googleSignIn.requestScopes(_scopes);
                  } else {
                    result = await googleSignIn.signIn();
                  }
                  if ((result is bool && result) ||
                      (result is GoogleSignInAccount)) {
                    showSnackBar(context, "Googleカレンダーと連携しました。");
                    setState(() {
                      _signedInAndScopeGranted = true;
                    });
                  }
                } else {
                  await googleSignIn.signOut();
                  showSnackBar(context, "Googleカレンダー連携を解除しました");
                  setState(() {
                    _signedInAndScopeGranted = false;
                  });
                }
              })
        ]),
        SettingsCategory(title: "その他の機能", tiles: [
          if (_enableSE != null)
            SwitchSettingsTile(
              title: "SEを有効にする",
              subtitle: "一部操作時にサウンドを再生します",
              value: _enableSE!,
              onChanged: (value) {
                SharedPrefs.use((prefs) {
                  prefs.enableSE = value;
                });
                setState(() {
                  _enableSE = value;
                });
              },
            ),
          SettingsTile(
            title: "時間割表設定",
            onTap: () {
              Navigator.pushNamed(context, "/settings/timetable");
            },
          )
        ])
      ],
    );
  }

  void _changePassword() async {
    var auth = FirebaseAuth.instance;
    showLoadingModal(context);
    try {
      var provider =
          await auth.fetchSignInMethodsForEmail(auth.currentUser!.email!);
      if (provider.isEmpty) throw FirebaseAuthException(code: "user-not-found");
      Navigator.pop(context);
      if (provider.first == EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD) {
        await Navigator.pushNamed(context, "/account/changePassword");
        setState(() {});
      } else {
        setState(() {
          _pwEnabled = false;
        });
        showSnackBar(context, "パスワードレス アカウントでパスワードの変更はできません");
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      if (e.code == "user-not-found") {
        showSnackBar(context, "ユーザーが見つかりません。再度ログインしてください。");
      } else {
        showSnackBar(context, "アカウント状態の取得に失敗しました (Code: ${e.code})");
      }
    } catch (e) {
      showSnackBar(context, "エラーが発生しました");
    }
  }

  bool emailChangeable() {
    var providers = [
      EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD,
      EmailAuthProvider.EMAIL_LINK_SIGN_IN_METHOD
    ];
    var providerId =
        FirebaseAuth.instance.currentUser?.providerData.first.providerId;
    return providers.contains(providerId);
  }

  bool passwordChangeable() {
    return FirebaseAuth.instance.currentUser?.providerData.first.providerId ==
        EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD;
  }

  Future<void> _checkSignedInAndScopeGranted() async {
    Future<bool> canAccessCalendar() async {
      try {
        var client = await googleSignIn.authenticatedClient();
        await calendar.CalendarApi(client!)
            .events
            .list("primary", maxResults: 1);
        return true;
      } on AccessDeniedException catch (e, stackTrace) {
        if (e.message.contains("invalid_token")) {
          await googleSignIn.disconnect();
          return await canAccessCalendar();
        }

        debugPrint(e.toString());
        debugPrint(stackTrace.toString());
        return false;
      }
    }

    void setSignedInAndScopeGranted(bool value) {
      setState(() {
        _signedInAndScopeGranted = value;
      });
    }

    if (googleSignIn.currentUser == null) {
      _accountListener = googleSignIn.onCurrentUserChanged.listen((user) async {
        setSignedInAndScopeGranted(await canAccessCalendar());
        _accountListener?.cancel();
      });
      googleSignIn.signInSilently();
    } else {
      setSignedInAndScopeGranted(await canAccessCalendar());
    }

    // calendar.CalendarApi((await googleSignIn.authenticatedClient())!).calendars.get("primary").then((cal) {
    //   setState(() {
    //     _signedInAndScopeGranted = true;
    //   });
    // }).onError((error, stackTrace) {
    //   debugPrint(error.toString());
    //   debugPrintStack(stackTrace: stackTrace);
    //   setState(() {
    //     _signedInAndScopeGranted = false;
    //   });
    // });

    // if (user != null) {
    //   await user.clearAuthCache();
    //   var auth = await user.authentication;
    //   try {
    //     var tokenInfo = await Oauth2Api(http.Client()).tokeninfo(accessToken: auth.accessToken);
    //     print(tokenInfo.scope);
    //     setState(() {
    //       var scopes = tokenInfo.scope?.split(" ");
    //       _signedInAndScopeGranted = _scopes.every((e) => scopes?.contains(e) == true);
    //     });
    //   } on DetailedApiRequestError catch (e, stacktrace) {
    //     debugPrint(e.toString());
    //     debugPrintStack(stackTrace: stacktrace);
    //     setState(() {
    //       _signedInAndScopeGranted = false;
    //     });
    //   }
    // } else {
    //   setState(() {
    //     _signedInAndScopeGranted = false;
    //   });
    // }
  }
}
