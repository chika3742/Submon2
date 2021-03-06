import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:submon/isar_db/isar_digestive.dart';
import 'package:submon/isar_db/isar_submission.dart';
import 'package:submon/method_channel/main.dart';
import 'package:submon/utils/ui.dart';

import '../utils/ad_unit_ids.dart';

const addMinutes = 20;
const breakMinutes = 10;
const breakCoolingMinutes = 10;

class FocusTimerPage extends StatefulWidget {
  FocusTimerPage({Key? key, required Map<String, dynamic> arguments})
      : digestive = arguments["digestive"],
        super(key: key);

  final Digestive digestive;

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage>
    with WidgetsBindingObserver {
  String _submissionName = "";
  final AudioCache _audioCache = AudioCache();
  bool? _dndAccessGranted = Platform.isAndroid ? false : null;

  bool _isEnableDnd = true;
  bool _timerFinished = false;
  bool _displayTimer = true;
  bool _started = false;
  bool _takingBreak = false;
  Duration _remainingTime = Duration.zero;
  Duration _breakRemainingTime = Duration.zero;
  Duration _lastTookBreak = Duration.zero;
  Timer? _timer;
  Timer? _breakTimer;
  Timer? _blinkTimer;
  AudioPlayer? _alarmPlayer;
  InterstitialAd? ad;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    _remainingTime = Duration(minutes: widget.digestive.minute);

    if (widget.digestive.submissionId != null) {
      SubmissionProvider().use((provider) async {
        _submissionName =
            (await provider.get(widget.digestive.submissionId!))!.title;
        setState(() {});
      });
    }

    _audioCache.load("audio/alarm.mp3");

    if (!kIsWeb && Platform.isAndroid) {
      MainMethodPlugin.enterFullscreen();
    }

    _checkDndAccessGranted();

    InterstitialAd.load(
      adUnitId: AdUnits.focusTimerInterstitial!,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            this.ad = ad;
          },
          onAdFailedToLoad: (e) {}),
    );

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _stopBreakTimer();
    _stopBlinkTimer(inDispose: true);
    _alarmPlayer?.stop();
    MainMethodPlugin.disableWakeLock();
    if (!kIsWeb && Platform.isAndroid) {
      MainMethodPlugin.exitFullscreen();
    }
    if (Platform.isAndroid) {
      FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALL);
    }
    ad?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDndAccessGranted();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('??????????????????'),
        backgroundColor: Theme.of(context).backgroundColor,
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_started) {
            await showSimpleDialog(context, "??????", "?????????????????????????????????????????????",
                showCancel: true, onOKPressed: () {
              Navigator.pop(context, false);
            });
            return false;
          }
          return true;
        },
        child: Stack(
          children: [
            // ???????????????
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_submissionName.isNotEmpty)
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: "?????????: "),
                      TextSpan(
                          text: _submissionName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ])),
                  const SizedBox(height: 8),
                  if (widget.digestive.content.isNotEmpty)
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: "??????????????????: "),
                      TextSpan(
                          text: widget.digestive.content,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ])),
                  const SizedBox(height: 16),
                  const Text('???????????????????????????????????????????????????????????????????????????????????????'),
                ],
              ),
            ),

            // ???????????????
            SizedBox.expand(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_takingBreak)
                      Text(
                          _breakRemainingTime.inSeconds > 0
                              ? '?????????...'
                              : '????????????????????????',
                          style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: _displayTimer ? 1 : 0,
                      child: Text(
                        !_takingBreak
                            ? _getTimerString(_remainingTime)
                            : _getTimerString(_breakRemainingTime),
                        style: TextStyle(
                          fontFamily: "B612 Mono",
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _takingBreak ? Colors.blue.shade500 : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 96),
                    AnimatedCrossFade(
                      crossFadeState: !_started
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeOutQuint,
                      firstCurve: Curves.easeOutQuint,
                      secondCurve: Curves.easeOutQuint,
                      firstChild: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 300,
                              height: 50,
                              child: ElevatedButton(
                                child: const Text('????????????'),
                                onPressed: () async {
                                  setState(() {
                                    _started = true;
                                  });
                                  _startTimer();
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_dndAccessGranted != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isEnableDnd,
                                    onChanged: _dndAccessGranted == true
                                        ? (value) {
                                            setState(() {
                                              _isEnableDnd = !_isEnableDnd;
                                            });
                                          }
                                        : null,
                                ),
                                Flexible(
                                  child: GestureDetector(
                                    onTap: _dndAccessGranted == true
                                        ? () {
                                            setState(() {
                                              _isEnableDnd = !_isEnableDnd;
                                            });
                                          }
                                        : null,
                                    child: Opacity(
                                      opacity:
                                          _dndAccessGranted == true ? 1 : 0.7,
                                      child: const Text('????????????????????????????????????'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_dndAccessGranted == false)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Column(
                                  children: [
                                    Text(
                                        '???????????????????????????????????????????????????????????????????????????????????????????????????Submon???????????????????????????????????????????????????????????????',
                                        style: Theme.of(context)
                                            .textTheme
                                            .caption),
                                    OutlinedButton(
                                      child: const Text('???????????????'),
                                      onPressed: () {
                                        FlutterDnd.gotoPolicySettings();
                                      },
                                    )
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      secondChild: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 300,
                              height: 50,
                              child: OutlinedButton(
                                child:
                                    const Text('????????????????????? (+ $addMinutes min)'),
                                onPressed: _remainingTime.inMinutes < 10 &&
                                        !_takingBreak
                                    ? () {
                                        setState(() {
                                          _remainingTime += const Duration(
                                              minutes: addMinutes);
                                          if (_lastTookBreak.inSeconds != 0) {
                                            _lastTookBreak += const Duration(
                                                minutes: addMinutes);
                                          }
                                        });
                                        if (_timerFinished) {
                                          _startTimer();
                                        }
                                        showSnackBar(
                                            context, "$addMinutes?????????????????????");
                                      }
                                    : null,
                              ),
                            ),
                            if (_remainingTime.inMinutes >= 10)
                              Text('??????10???????????????????????????????????????',
                                  style: Theme.of(context).textTheme.caption),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 300,
                              height: 50,
                              child: OutlinedButton(
                                child: const Text('?????? ($breakMinutes min)'),
                                onPressed: !_takingBreak &&
                                        _takingBreakAvailable() &&
                                        !_timerFinished
                                    ? () {
                                        _breakRemainingTime = const Duration(
                                            minutes: breakMinutes);
                                        _startBreakTimer();
                                        setState(() {
                                          _lastTookBreak = _remainingTime;
                                          _takingBreak = true;
                                        });
                                      }
                                    : null,
                              ),
                            ),
                            if (!_takingBreak && !_takingBreakAvailable())
                              Text(
                                  '???????????????????????????$breakCoolingMinutes??????????????????????????????????????????',
                                  style: Theme.of(context).textTheme.caption),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 300,
                              height: 50,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: _takingBreak
                                      ? MaterialStateProperty.all(
                                          Colors.blue.shade200)
                                      : null,
                                ),
                                child: Text(!_takingBreak ? '???????????????' : "??????????????????"),
                                onPressed: () async {
                                  if (!_takingBreak) {
                                    ad?.show();
                                    showSnackBar(context, "Digestive????????????????????????");
                                    Navigator.pop(context, true);
                                  } else {
                                    _startTimer();
                                    setState(() {
                                      _takingBreak = false;
                                    });
                                  }
                                  _stopBlinkTimer();
                                  _alarmPlayer?.stop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _takingBreakAvailable() {
    var elapsedTime = _lastTookBreak - _remainingTime;
    return elapsedTime.inMinutes > breakCoolingMinutes ||
        elapsedTime.isNegative;
  }

  void _enableDnd() {
    if (_isEnableDnd && _dndAccessGranted == true) {
      FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_NONE);
    }
  }

  void _disableDnd() {
    if (_isEnableDnd && _dndAccessGranted == true) {
      FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALL);
    }
  }

  void _startTimer() {
    MainMethodPlugin.enableWakeLock();
    _enableDnd();
    _stopBreakTimer();
    _stopBlinkTimer();
    setState(() {
      _timerFinished = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        setState(() {
          _remainingTime -= const Duration(seconds: 1);
        });
      }
      if (_remainingTime.inSeconds == 0) {
        _stopTimer();
        _disableDnd();
        _startBlinkTimer();
        _alarmPlayer = await _audioCache.play("audio/alarm.mp3");
        setState(() {
          _timerFinished = true;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _startBreakTimer() {
    _stopTimer();
    _disableDnd();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        setState(() {
          _breakRemainingTime -= const Duration(seconds: 1);
        });
      }
      if (_breakRemainingTime.inSeconds == 0) {
        _stopBreakTimer();
        _startBlinkTimer();
        _alarmPlayer = await _audioCache.loop("audio/alarm.mp3");
      }
    });
  }

  void _stopBreakTimer() {
    _breakTimer?.cancel();
  }

  void _startBlinkTimer() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _displayTimer = !_displayTimer;
        });
      }
    });
  }

  void _stopBlinkTimer({bool inDispose = false}) {
    _blinkTimer?.cancel();
    if (mounted && !inDispose) {
      setState(() {
        _displayTimer = true;
      });
    }
  }

  String _getTimerString(Duration timer) {
    if (timer.inHours > 0) {
      return "${timer.inHours} ${(timer.inMinutes % 60).toString().padLeft(2, "0")} ${(timer.inSeconds % 60).toString().padLeft(2, "0")}";
    } else if (timer.inMinutes > 0) {
      return "${timer.inMinutes} ${(timer.inSeconds % 60).toString().padLeft(2, "0")}";
    } else {
      return "${timer.inSeconds}";
    }
  }

  void _checkDndAccessGranted() {
    if (Platform.isAndroid) {
      FlutterDnd.isNotificationPolicyAccessGranted.then((value) {
        setState(() {
          _dndAccessGranted = value;
        });
      });
    }
  }
}
