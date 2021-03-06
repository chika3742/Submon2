import 'dart:io';

import 'package:url_launcher/url_launcher_string.dart';

import 'method_channel/main.dart';

class Browser {
  static void openTermsOfUse() {
    MainMethodPlugin.openWebPage(
        "利用規約", "https://www.chikach.net/nonav/submon-terms/");
  }

  static void openPrivacyPolicy() {
    MainMethodPlugin.openWebPage(
        "プライバシーポリシー", "https://www.chikach.net/nonav/submon-privacy-2/");
  }

  static void openChangelog() {
    MainMethodPlugin.openWebPage(
        "更新履歴・開発進捗", "https://www.chikach.net/submon-changelog/");
  }

  static void openHelp() {
    MainMethodPlugin.openWebPage("ヘルプ", "https://www.chikach.net/submon-help/");
  }

  static void openAnnouncements() {
    MainMethodPlugin.openWebPage(
        "お知らせ", "https://www.chikach.net/category/submon-info/");
  }

  static void openStoreListing() {
    if (Platform.isAndroid) {
      launchUrlString(
          "https://play.google.com/store/apps/details?id=net.chikach.submon",
          mode: LaunchMode.externalApplication);
    } else if (Platform.isIOS || Platform.isMacOS) {
      launchUrlString("https://apps.apple.com/jp/app/youtube/id1625033197",
          mode: LaunchMode.externalApplication);
    }
  }
}
