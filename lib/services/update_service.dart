import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String repoOwner = "DustBytesBack";
  static const String repoName = "Ditch-Perfect";

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    final url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/releases/latest",
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("GitHub API returned ${response.statusCode}");
    }

    final data = jsonDecode(response.body);

    final latestVersion = data["tag_name"] as String?;
    if (latestVersion == null) {
      throw Exception("No tag_name in response");
    }

    // Get download URL — fall back to the release HTML page if no assets.
    final assets = data["assets"] as List?;
    final String downloadUrl;
    if (assets != null && assets.isNotEmpty) {
      downloadUrl = assets[0]["browser_download_url"] as String;
    } else {
      downloadUrl =
          data["html_url"] as String? ??
          "https://github.com/$repoOwner/$repoName/releases/latest";
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_isNewer(latestVersion, currentVersion)) {
      return {
        "version": latestVersion,
        "url": downloadUrl,
        "notes": data["body"] as String?,
      };
    }

    return null;
  }

  static bool _isNewer(String latest, String current) {
    final latestParts = latest.replaceAll("v", "").split(".");
    final currentParts = current.split(".");

    final len = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (int i = 0; i < len; i++) {
      final l = i < latestParts.length ? int.tryParse(latestParts[i]) ?? 0 : 0;
      final c = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;

      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }

  /// Fetches the release notes (body) for a given version tag.
  /// Tries both "v{version}" and "{version}" tag formats.
  /// Returns the markdown body string, or null if not found.
  static Future<String?> fetchReleaseNotes(String version) async {
    // Try with "v" prefix first, then without.
    final tags = ["v$version", version];

    for (final tag in tags) {
      final url = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/releases/tags/$tag",
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final body = data["body"] as String?;
        if (body != null && body.trim().isNotEmpty) {
          return body;
        }
        // Release exists but no body — return the tag name at least.
        final name = data["name"] as String?;
        return name ?? "Updated to $version";
      }
    }

    return null;
  }

  /// Compares two version strings. Returns true if [a] is newer than [b].
  static bool isVersionNewer(String a, String b) => _isNewer(a, b);

  /// Fetches all releases from GitHub.
  static Future<List<Map<String, dynamic>>> fetchAllReleases() async {
    final url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/releases",
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("GitHub API returned ${response.statusCode}");
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((release) {
      return {
        "version": release["tag_name"] as String,
        "name": release["name"] as String?,
        "body": release["body"] as String?,
        "date": release["published_at"] as String?,
      };
    }).toList();
  }
}
