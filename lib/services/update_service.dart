import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;

  const ReleaseAsset({required this.name, required this.browserDownloadUrl});

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String,
        browserDownloadUrl: json['browser_download_url'] as String,
      );
}

class ReleaseInfo {
  final String version;
  final String tagName;
  final String htmlUrl;

  final String body;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    return ReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tagName: tag,
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>?)
              ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UpdateService {
  static const String repositoryUrl = 'https://github.com/lvshp/Musly';

  static const String _apiUrl =
      'https://api.github.com/repos/lvshp/Musly/releases/latest';

  static const MethodChannel _installerChannel =
      MethodChannel('com.devid.musly/update_installer');

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );

  static Future<String> getCurrentVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final match =
          RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(pubspec);
      final rawVersion = match?.group(1);
      if (rawVersion == null || rawVersion.isEmpty) return '0.0.0';
      return rawVersion.split('+').first;
    } catch (e) {
      debugPrint('UpdateService: failed to read app version - $e');
      return '0.0.0';
    }
  }

  static Future<ReleaseInfo?> checkForUpdate({String? currentVersion}) async {
    try {
      final version = currentVersion ?? await getCurrentVersion();
      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final data = response.data;
      if (data == null) return null;

      final release = ReleaseInfo.fromJson(data);
      if (_isNewer(release.version, version)) {
        return release;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: check failed – $e');
      return null;
    }
  }

  static ReleaseAsset? findAndroidApkAsset(ReleaseInfo release) {
    final apkAssets = release.assets
        .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
        .toList();
    if (apkAssets.isEmpty) return null;

    for (final asset in apkAssets) {
      final name = asset.name.toLowerCase();
      if (name.contains('release') || name.contains('android')) {
        return asset;
      }
    }
    return apkAssets.first;
  }

  static Future<File> downloadAndroidApk(
    ReleaseInfo release, {
    required void Function(int received, int total) onProgress,
  }) async {
    final asset = findAndroidApkAsset(release);
    if (asset == null) {
      throw StateError('No Android APK asset found for ${release.tagName}');
    }

    final directory = await getTemporaryDirectory();
    final fileName = asset.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final file = File(p.join(directory.path, fileName));

    await _dio.download(
      asset.browserDownloadUrl,
      file.path,
      deleteOnError: true,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        responseType: ResponseType.bytes,
      ),
    );

    return file;
  }

  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    return await _installerChannel.invokeMethod<bool>(
          'canRequestPackageInstalls',
        ) ??
        false;
  }

  static Future<void> openUnknownSourcesSettings() async {
    if (!Platform.isAndroid) return;
    await _installerChannel.invokeMethod<void>('openUnknownSourcesSettings');
  }

  static Future<void> installAndroidApk(File apk) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK install is only supported on Android');
    }
    await _installerChannel.invokeMethod<void>('installApk', {
      'path': apk.path,
    });
  }

  static bool _isNewer(String remote, String current) {
    try {
      List<int> parse(String v) =>
          v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final r = parse(remote);
      final c = parse(current);
      final len = r.length > c.length ? r.length : c.length;
      while (r.length < len) {
        r.add(0);
      }
      while (c.length < len) {
        c.add(0);
      }

      for (int i = 0; i < len; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`{1,3}(.*?)`{1,3}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^---+$', multiLine: true), '─────────────')
        .trim();
  }
}
