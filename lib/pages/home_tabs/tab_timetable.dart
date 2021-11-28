import 'package:flutter/material.dart';
import 'package:submon/components/timetable.dart';
import 'package:submon/local_db/shared_prefs.dart';

class TabTimetable extends StatefulWidget {
  const TabTimetable({key: Key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => TabTimetableState();
}

class TabTimetableState extends State<TabTimetable> {
  var loading = false;
  bool? timetableBanner1Flag;

  @override
  void initState() {
    super.initState();
    getPref();
  }

  void getPref() async {
    SharedPrefs.use((prefs) {
      setState(() {
        timetableBanner1Flag = prefs.timetableBanner1Flag;
      });
    });
  }

  var bannerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (timetableBanner1Flag == null) {
      return Container();
    } else {
      return Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                child: SizedBox(
                  // TODO: 時間割が1個でも設定されている条件追加
                  height: timetableBanner1Flag == false
                      ? (bannerKey.currentContext?.findRenderObject()
                              as RenderBox?)
                          ?.size
                          .height
                      : 0,
                  child: MaterialBanner(
                    key: bannerKey,
                    content: const Text("科目を長押しして提出物を作成することもできます"),
                    forceActionsBelow: true,
                    actions: [
                      TextButton(
                          child: const Text("閉じる"),
                          onPressed: () {
                            SharedPrefs.use((prefs) {
                              prefs.timetableBanner1Flag = true;
                              setState(() {
                                timetableBanner1Flag = true;
                              });
                            });
                          })
                    ],
                  ),
                ),
              ),
              const Timetable(),
            ],
          ),
        ],
      );
    }
  }

  void updateUI() {
    setState(() {});
  }
}
