import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:submon/components/submissions/submission_list_item.dart';
import 'package:submon/db/shared_prefs.dart';
import 'package:submon/events.dart';
import 'package:submon/isar_db/isar_digestive.dart';
import 'package:submon/isar_db/isar_submission.dart';
import 'package:submon/main.dart';
import 'package:submon/utils/ui.dart';
import 'package:submon/utils/utils.dart';

class SubmissionList extends StatefulWidget {
  const SubmissionList({Key? key, this.done = false}) : super(key: key);

  final bool done;

  @override
  SubmissionListState createState() => SubmissionListState();
}

class SubmissionListState extends State<SubmissionList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  List<Submission>? items;

  StreamSubscription? _stream1;
  StreamSubscription? _stream2;

  final AudioCache _audioCache = AudioCache();
  bool? _enableSE;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    SubmissionProvider().use((provider) async {
      if (!widget.done) {
        items = await provider.getUndoneSubmissions();
      } else {
        items = await provider.getDoneSubmissions();
      }

      setState(() {
        items?.asMap().forEach((index, element) async {
          _listKey.currentState?.insertItem(index, duration: const Duration());
        });
      });
    });

    _stream1 = eventBus.on<BottomNavDoubleClickEvent>().listen((event) {
      if (event.index == 0) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint);
      }
    });

    _stream2 = eventBus.on<SubmissionInserted>().listen((event) {
      SubmissionProvider().use((provider) async {
        var data = await provider.get(event.id);

        if (data != null) {
          setState(() {
            items!.add(data);
          });
          _listKey.currentState?.insertItem(items!.length - 1);
          await Future.delayed(const Duration(milliseconds: 300));
          _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint);
        }
      });
    });

    SharedPrefs.use((prefs) {
      _enableSE = prefs.isSEEnabled;
    });

    _audioCache.load("audio/decision28.mp3");
  }

  @override
  void dispose() {
    super.dispose();
    _stream1?.cancel();
    _stream2?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (items != null)
          AnimatedOpacity(
            opacity: items!.isNotEmpty ? 0 : 0.7,
            duration: const Duration(milliseconds: 200),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("???????????????????????????", style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        Scrollbar(
          child: AnimatedList(
            key: _listKey,
            controller: _scrollController,
            itemBuilder: (context, pos, anim) {
              return SizeTransition(
                sizeFactor: anim.drive(Tween(begin: 0.0, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOutQuint))),
                child: SubmissionListItem(items![pos],
                    key: ObjectKey(items![pos].id), onDelete: () {
                  delete(pos);
                }, onDone: () {
                  checkDone(pos);
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void checkDone(int index) {
    var item = items![index];
    setState(() {
      items!.removeAt(index);
      _listKey.currentState?.removeItem(
          index, (context, animation) => Container(),
          duration: const Duration(milliseconds: 1));
    });

    SubmissionProvider().use((provider) {
      return provider.writeTransaction(() async {
        await provider.invertDone(item);
      });
    });

    if (!widget.done && _enableSE == true) {
      _audioCache.play("audio/decision28.mp3");
    }

    showSnackBar(context, !widget.done ? "?????????????????????" : "????????????????????????",
        action: SnackBarAction(
          label: "????????????",
          textColor: Colors.pinkAccent,
          onPressed: () {
            try {
              setState(() {
                var actualIndex =
                    items!.length <= index ? items!.length : index;
                items!.insert(actualIndex, item);
                _listKey.currentState?.insertItem(actualIndex);
              });
            } catch (e, st) {
              recordErrorToCrashlytics(e, st);
            }
            SubmissionProvider().use((provider) {
              return provider.writeTransaction(() async {
                provider.invertDone(item);
              });
            });
          },
        ));
  }

  void delete(int index) async {
    var submission = items![index];

    SubmissionProvider().use((provider) async {
      SubmissionProvider.deleteFromGoogleTasks(submission.googleTasksTaskId);
      await provider.deleteItem(submission.id!);
    });

    late List<Digestive> digestivesToRestore;
    await DigestiveProvider().use((provider) async {
      digestivesToRestore =
          await provider.getDigestivesBySubmissionId(submission.id!);
    });

    try {
      setState(() {
        items!.removeAt(index);
        _listKey.currentState?.removeItem(
            index, (context, animation) => Container(),
            duration: const Duration(milliseconds: 1));
      });

      showSnackBar(globalContext!, "??????????????????",
          action: SnackBarAction(
            label: "????????????",
            textColor: Colors.pinkAccent,
            onPressed: () async {
              await SubmissionProvider().use((provider) async {
                await provider.writeTransaction(() async {
                  await provider.put(submission);
                });
              });

              DigestiveProvider().use((provider) async {
                provider.writeTransaction(() async {
                  for (var digestive in digestivesToRestore) {
                    await provider.put(digestive);
                  }
                });
              });

              setState(() {
                var actualIndex =
                    items!.length <= index ? items!.length : index;
                items!.insert(actualIndex, submission);
                _listKey.currentState?.insertItem(actualIndex);
              });
            },
          ));
    } catch (e, st) {
      recordErrorToCrashlytics(e, st);
      showSnackBar(context, "??????????????????????????????");
    }
  }
}
