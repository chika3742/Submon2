import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:submon/local_db/shared_prefs.dart';
import 'package:submon/utils/ui.dart';

import '../utils/utils.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({Key? key, this.reAuth = false}) : super(key: key);

  final bool reAuth;

  @override
  State<StatefulWidget> createState() => EmailLoginPageState();
}

class EmailLoginPageState extends State<EmailLoginPage>
    with SingleTickerProviderStateMixin {
  var enableEmailForm = true;
  var enablePWForm = false;
  var processing = false;
  var visiblePW = false;
  var emailController = TextEditingController();
  var pwController = TextEditingController();
  AnimationController? pwAnimController;
  var pwOpacity = 0.0;
  String? emailError;
  String? pwError;
  String? message = msgEmail;

  static const msgEmail = "メールアドレスを入力してください";
  static const msgPW = "パスワードを入力してください";

  @override
  void initState() {
    super.initState();
    pwAnimController = AnimationController(vsync: this);
    if (widget.reAuth) {
      message = "本人確認のため、再度ログインをお願いします。";
      emailController.text = FirebaseAuth.instance.currentUser!.email!;
      enableEmailForm = false;
      enablePWForm = true;
      switchPasswordForm(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: const Text("メールアドレスを使用")),
      body: SafeArea(
        child: Stack(
          children: [
            Visibility(
              visible: processing,
              child: const LinearProgressIndicator(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(message!),
                  const SizedBox(height: 16),
                  TextFormField(
                      enabled: enableEmailForm,
                      controller: emailController,
                      decoration: InputDecoration(
                          labelText: "メールアドレス",
                          border: const OutlineInputBorder(),
                          errorText: emailError)),
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween(
                            begin: const Offset(0, -0.4),
                            end: const Offset(0, 0))
                        .animate(pwAnimController!),
                    child: IgnorePointer(
                      ignoring: pwOpacity == 0,
                      child: AnimatedOpacity(
                        opacity: pwOpacity,
                        curve: Curves.easeInOut,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            TextFormField(
                                obscureText: !visiblePW,
                                enabled: enablePWForm,
                                controller: pwController,
                                decoration: InputDecoration(
                                  labelText: "パスワード",
                                  suffixIcon: IconButton(
                                    icon: Icon(visiblePW
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () {
                                      setState(() {
                                        visiblePW = !visiblePW;
                                      });
                                    },
                                  ),
                                  border: const OutlineInputBorder(),
                                  errorText: pwError,
                                )),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              child: const Text("パスワードを忘れた場合"),
                              onPressed: onPWForgot,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Visibility(
                      visible: widget.reAuth,
                      child: SizedBox(
                        width: 80,
                        child: OutlinedButton(
                          child: const Text("戻る"),
                          onPressed: processing
                              ? null
                              : () {
                                  if (pwOpacity != 0) {
                                    switchPasswordForm(false);
                                    setState(() {
                                      message = msgEmail;
                                      enableEmailForm = true;
                                    });
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      child: const Text("次へ"),
                      onPressed: processing ? null : next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void next() async {
    // フォームエラーハンドリング
    if (emailController.text.isEmpty) {
      setState(() {
        emailError = msgEmail;
      });
      return;
    }
    if (pwOpacity != 0 && pwController.text.isEmpty) {
      setState(() {
        pwError = msgPW;
      });
      return;
    }
    setState(() {
      emailError = null;
      processing = true;
      enableEmailForm = false;
      enablePWForm = false;
    });

    // 処理
    var auth = FirebaseAuth.instance;
    try {
      if (pwOpacity == 0) {
        // サインイン方法別の処理
        var result =
            await auth.fetchSignInMethodsForEmail(emailController.text);

        setState(() {
          enablePWForm = true;
          processing = false;
        });

        if (result.isEmpty) {
          // アカウント新規作成
          setState(() {
            enableEmailForm = true;
          });
          showSelectSheet(
              context,
              "ログイン方法の選択",
              "メールアドレスで新規登録を行います。\nメールアドレスでのログイン方法は2種類存在します。どちらか選択してください。(現状、以後変更できません)\n\n"
                  "・パスワードレス：登録したメールアドレスに送信されたリンクを踏むことでログインできます。(推奨)\n"
                  "・一般的なログイン：パスワードを利用してログインします。",
              [
                SelectSheetAction("パスワードレス(推奨)", () async {
                  Navigator.pop(context);
                  setState(() {
                    processing = true;
                    enableEmailForm = false;
                  });

                  try {
                    await sendSignInEmail();
                  } catch (e) {
                    showSnackBar(context, "エラーが発生しました。");
                  }

                  setState(() {
                    processing = false;
                    enableEmailForm = true;
                  });
                }),
                SelectSheetAction("一般的なログイン", () async {
                  Navigator.pop(context);
                  var result = await pushPage(
                      context, EmailRegisterPage(email: emailController.text));
                  if (result != null) {
                    Navigator.pop(context, result);
                  }
                }),
              ]);
        } else if (result.first ==
            EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD) {
          // パスワードサインイン
          switchPasswordForm(true);
          setState(() {
            message = msgPW;
          });
        } else if (result.first ==
            EmailAuthProvider.EMAIL_LINK_SIGN_IN_METHOD) {
          // パスワードレスサインイン
          await sendSignInEmail();
        } else {
          // その他(ソーシャルログイン)
          setState(() {
            enableEmailForm = true;
          });
          showSimpleDialog(context, "エラー",
              "このアカウントは既にGoogleログインを利用して作成されています。\n前の画面に戻り、「Google でログイン」からログインしてください。",
              onOKPressed: () {});
        }
      } else {
        // パスワードを用いたログイン処理
        UserCredential result;

        if (widget.reAuth) {
          result = await auth.currentUser!.reauthenticateWithCredential(
              EmailAuthProvider.credential(
                  email: emailController.text, password: pwController.text));
        } else {
          result = await auth.signInWithEmailAndPassword(
              email: emailController.text, password: pwController.text);
        }

        if (result.user != null) {
          Navigator.of(context).pop(result);
        }
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          setState(() {
            processing = false;
            enableEmailForm = true;
            emailError = "メールアドレスの形式が正しくありません";
          });
          break;
        case 'wrong-password':
          setState(() {
            processing = false;
            enablePWForm = true;
            pwError = "パスワードが間違っています";
          });
          break;
        default:
          setState(() {
            processing = false;
            enableEmailForm = false;
            enablePWForm = false;
          });
          handleAuthError(e, context);
          break;
      }
    }
  }

  void switchPasswordForm(bool show) {
    setState(() {
      pwOpacity = show ? 1 : 0;
    });
    pwAnimController?.animateTo(show ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: show ? Curves.easeOutQuint : Curves.easeInQuint);
  }

  Future<void> sendSignInEmail() async {
    showLoadingModal(context);

    await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: emailController.text,
        actionCodeSettings:
            actionCodeSettings("https://chikach.net/submon-signin/"));

    SharedPrefs.use((prefs) {
      prefs.linkSignInEmail = emailController.text;
    });

    Navigator.pop(context);

    showSimpleDialog(
        context,
        "完了",
        "メールを入力されたアドレスに送信しました。受信したメールのリンクをタップしてログインしてください。\n\n"
            "※メールは「chikach.net」ドメインから送信されます。迷惑メールに振り分けられていないかご確認ください。",
        onOKPressed: () {
      Navigator.pop(context);
      Navigator.pop(context);
    }, allowCancel: false);
  }

  void onPWForgot() {
    showSimpleDialog(context, "パスワードを忘れた場合",
        "下のOKボタンを押すと入力されたメールアドレス宛にパスワードリセット用のURLを送信します。そのURLを開いてパスワードをリセットしてください。\n\n※メールは「chikach.net」というドメインから届きます。迷惑メール設定をしている場合はご注意ください。",
        onOKPressed: () async {
      setState(() {
        processing = true;
        enablePWForm = false;
      });
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
            email: emailController.text,
            actionCodeSettings: actionCodeSettings());
        showSnackBar(context, "送信しました。ご確認ください。");
      } on FirebaseAuthException catch (e) {
        handleAuthError(e, context);
      } finally {
        setState(() {
          processing = false;
          enablePWForm = true;
        });
      }
    }, showCancel: true);
  }
}

class EmailRegisterPage extends StatefulWidget {
  const EmailRegisterPage({Key? key, this.email}) : super(key: key);

  final String? email;

  @override
  _EmailRegisterPageState createState() => _EmailRegisterPageState();
}

class _EmailRegisterPageState extends State<EmailRegisterPage> {
  final _pwController = TextEditingController();
  String? _pwError = null;
  final _pwReenterController = TextEditingController();
  String? _pwReenterError = null;

  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("新規登録"),
      ),
      body: Stack(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              Text("メールアドレス: ${widget.email}"),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pwController,
                obscureText: true,
                enabled: !_loading,
                decoration: InputDecoration(
                  label: const Text("パスワード"),
                  errorText: _pwError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pwReenterController,
                obscureText: true,
                enabled: !_loading,
                decoration: InputDecoration(
                    label: const Text("パスワード(再入力)"),
                    errorText: _pwReenterError,
                    border: const OutlineInputBorder()),
              ),
            ]),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton.extended(
                label: const Text("登録"),
                icon: const Icon(Icons.how_to_reg),
                onPressed: register,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void register() async {
    setState(() {
      if (_pwController.text.isEmpty) {
        _pwError = "入力してください";
      } else {
        _pwError = null;
      }
      if (_pwReenterController.text.isEmpty) {
        _pwReenterError = "入力してください";
        return;
      } else {
        _pwReenterError = null;
      }
      if (_pwReenterController.text != _pwController.text) {
        _pwReenterError = "パスワードが一致しません";
      } else {
        _pwReenterError = null;
      }
    });
    if (_pwError != null || _pwReenterError != null) return;

    setState(() {
      _loading = true;
    });
    try {
      var result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: widget.email!, password: _pwController.text);

      showSnackBar(context, "アカウントを作成しました");
      Navigator.pop(context, result);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
      });
      switch (e.code) {
        case "auth/invalid-password":
          showSnackBar(context, "パスワードが短すぎます。最低6文字で指定してください。");
          break;
        default:
          handleAuthError(e, context);
          break;
      }
    }
  }
}
