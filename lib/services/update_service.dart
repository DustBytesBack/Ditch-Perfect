import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {

  static const String repoOwner = "DustBytesBack";
  static const String repoName = "Ditch-Perfect";

  static Future<Map<String, dynamic>?> checkForUpdate() async {

    try {

      final url = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
      );

      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);

      final latestVersion = data["tag_name"];
      final apkUrl = data["assets"][0]["browser_download_url"];

      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = packageInfo.version;

      if (_isNewer(latestVersion, currentVersion)) {

        return {
          "version": latestVersion,
          "url": apkUrl,
        };
      }

      return null;

    } catch (e) {

      return null;

    }
  }

  static bool _isNewer(String latest, String current) {

    final latestParts = latest.replaceAll("v", "").split(".");
    final currentParts = current.split(".");

    for (int i = 0; i < latestParts.length; i++) {

      int l = int.parse(latestParts[i]);
      int c = int.parse(currentParts[i]);

      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }
}