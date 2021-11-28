import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  SharedPreferences? pref;

  SharedPrefs(this.pref);

  bool get analyticsEnabled => pref!.getBool("ANALYTICS_ENABLED") ?? true;

  set analyticsEnabled(bool value) => pref!.setBool("ANALYTICS_ENABLED", value);

  bool get enableSE => pref!.getBool("ENABLE_SE") ?? true;

  set enableSE(bool value) => pref!.setBool("ENABLE_SE", value);

  bool get timetableBanner1Flag =>
      pref!.getBool("TIMETABLE_BANNER_1_FLAG") ?? false;

  set timetableBanner1Flag(bool value) =>
      pref!.setBool("TIMETABLE_BANNER_1_FLAG", value);

  String? get linkSignInEmail => pref!.getString("LINK_SIGN_IN_EMAIL");

  set linkSignInEmail(String? value) =>
      pref!.setString("LINK_SIGN_IN_EMAIL", value!);

  int? get timetableHour => pref!.getInt("TIMETABLE_HOUR") ?? 6;

  set timetableHour(int? value) => pref!.setInt("TIMETABLE_HOUR", value!);

  static use(dynamic Function(SharedPrefs prefs) callback) {
    SharedPreferences.getInstance().then((pref) {
      var prefs = SharedPrefs(pref);
      callback(prefs);
    });
  }
}
