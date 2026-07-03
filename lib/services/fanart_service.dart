import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

class FanartService {
  static const _mbidCacheKey = 'fanart_mbid_cache';
  static const _urlCacheKey = 'fanart_url_cache';
  static const _negativeCachePrefix = 'missing:';

  static final FanartService _instance = FanartService._internal();
  factory FanartService() => _instance;
  FanartService._internal();

  final Dio _musicBrainz = Dio(
    BaseOptions(
      baseUrl: 'https://musicbrainz.org/ws/2',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'Musly/1.0 (https://github.com/lvshp/Musly)',
      },
    ),
  );

  final Dio _fanart = Dio(
    BaseOptions(
      baseUrl: 'https://webservice.fanart.tv/v3',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  final StorageService _storage = StorageService();
  SharedPreferences? _prefs;
  Map<String, String> _mbidCache = {};
  Map<String, String> _urlCache = {};
  bool _initialized = false;
  bool _enabled = false;
  String _apiKey = '';

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _mbidCache = _readStringMap(_mbidCacheKey);
    _urlCache = _readStringMap(_urlCacheKey);
    await reloadSettings();
    _initialized = true;
  }

  Future<void> reloadSettings() async {
    _enabled = await _storage.getFanartArtworkEnabled();
    _apiKey = await _storage.getFanartApiKey();
  }

  Future<String?> getArtistImageUrl(String? artistName) async {
    await initialize();
    if (!_canFetch || artistName == null || artistName.trim().isEmpty) {
      return null;
    }

    final normalizedArtist = _normalize(artistName);
    final cacheKey = 'artist:$normalizedArtist';
    final cached = _urlCache[_hashKey(cacheKey)];
    if (cached != null) {
      return cached.startsWith(_negativeCachePrefix) ? null : cached;
    }

    final artistMbid = await _resolveArtistMbid(normalizedArtist, artistName);
    if (artistMbid == null) {
      await _rememberMissingUrl(cacheKey);
      return null;
    }

    try {
      final response = await _fanart.get(
        '/music/$artistMbid',
        queryParameters: {'api_key': _apiKey},
      );
      final data = response.data as Map<String, dynamic>?;
      final url = _firstImageUrl(data, const [
        'artistthumb',
        'hdmusiclogo',
        'artistbackground',
        'musicbanner',
      ]);
      if (url != null) {
        await _rememberUrl(cacheKey, url);
        return url;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('[fanart.tv] Artist image lookup failed: $e');
      }
    } catch (e) {
      debugPrint('[fanart.tv] Artist image parse failed: $e');
    }

    await _rememberMissingUrl(cacheKey);
    return null;
  }

  Future<String?> getAlbumCoverUrl({
    required String? albumTitle,
    required String? artistName,
  }) async {
    await initialize();
    if (!_canFetch ||
        albumTitle == null ||
        albumTitle.trim().isEmpty ||
        artistName == null ||
        artistName.trim().isEmpty) {
      return null;
    }

    final normalizedAlbum = _normalize(albumTitle);
    final normalizedArtist = _normalize(artistName);
    final cacheKey = 'album:$normalizedArtist:$normalizedAlbum';
    final cached = _urlCache[_hashKey(cacheKey)];
    if (cached != null) {
      return cached.startsWith(_negativeCachePrefix) ? null : cached;
    }

    final releaseGroupMbid = await _resolveReleaseGroupMbid(
      normalizedAlbum: normalizedAlbum,
      normalizedArtist: normalizedArtist,
      albumTitle: albumTitle,
      artistName: artistName,
    );
    if (releaseGroupMbid == null) {
      await _rememberMissingUrl(cacheKey);
      return null;
    }

    try {
      final response = await _fanart.get(
        '/music/albums/$releaseGroupMbid',
        queryParameters: {'api_key': _apiKey},
      );
      final data = response.data as Map<String, dynamic>?;
      final albums = data?['albums'];
      if (albums is Map) {
        for (final value in albums.values) {
          if (value is Map) {
            final url = _firstImageUrl(
              Map<String, dynamic>.from(value),
              const ['albumcover', 'cdart'],
            );
            if (url != null) {
              await _rememberUrl(cacheKey, url);
              return url;
            }
          }
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('[fanart.tv] Album image lookup failed: $e');
      }
    } catch (e) {
      debugPrint('[fanart.tv] Album image parse failed: $e');
    }

    await _rememberMissingUrl(cacheKey);
    return null;
  }

  bool get _canFetch => _enabled && _apiKey.trim().isNotEmpty;

  Future<String?> _resolveArtistMbid(
    String normalizedArtist,
    String artistName,
  ) async {
    final cacheKey = 'artist:$normalizedArtist';
    final cached = _mbidCache[_hashKey(cacheKey)];
    if (cached != null) {
      return cached.startsWith(_negativeCachePrefix) ? null : cached;
    }

    try {
      final response = await _musicBrainz.get(
        '/artist',
        queryParameters: {
          'query': 'artist:"$artistName"',
          'fmt': 'json',
          'limit': '1',
        },
      );
      final artists = response.data?['artists'];
      if (artists is List && artists.isNotEmpty) {
        final id = artists.first['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _rememberMbid(cacheKey, id);
          return id;
        }
      }
    } catch (e) {
      debugPrint('[MusicBrainz] Artist lookup failed: $e');
    }

    await _rememberMissingMbid(cacheKey);
    return null;
  }

  Future<String?> _resolveReleaseGroupMbid({
    required String normalizedAlbum,
    required String normalizedArtist,
    required String albumTitle,
    required String artistName,
  }) async {
    final cacheKey = 'release-group:$normalizedArtist:$normalizedAlbum';
    final cached = _mbidCache[_hashKey(cacheKey)];
    if (cached != null) {
      return cached.startsWith(_negativeCachePrefix) ? null : cached;
    }

    try {
      final response = await _musicBrainz.get(
        '/release-group',
        queryParameters: {
          'query': 'releasegroup:"$albumTitle" AND artist:"$artistName"',
          'type': 'album',
          'fmt': 'json',
          'limit': '1',
        },
      );
      final groups = response.data?['release-groups'];
      if (groups is List && groups.isNotEmpty) {
        final id = groups.first['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _rememberMbid(cacheKey, id);
          return id;
        }
      }
    } catch (e) {
      debugPrint('[MusicBrainz] Release group lookup failed: $e');
    }

    await _rememberMissingMbid(cacheKey);
    return null;
  }

  String? _firstImageUrl(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final images = data[key];
      if (images is List && images.isNotEmpty) {
        for (final image in images) {
          if (image is Map) {
            final url = image['url']?.toString();
            if (url != null && url.isNotEmpty) return url;
          }
        }
      }
    }
    return null;
  }

  Map<String, String> _readStringMap(String key) {
    final jsonText = _prefs?.getString(key);
    if (jsonText == null || jsonText.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberMbid(String key, String value) async {
    _mbidCache[_hashKey(key)] = value;
    await _persist(_mbidCacheKey, _mbidCache);
  }

  Future<void> _rememberMissingMbid(String key) async {
    _mbidCache[_hashKey(key)] = '$_negativeCachePrefix${DateTime.now().day}';
    await _persist(_mbidCacheKey, _mbidCache);
  }

  Future<void> _rememberUrl(String key, String value) async {
    _urlCache[_hashKey(key)] = value;
    await _persist(_urlCacheKey, _urlCache);
  }

  Future<void> _rememberMissingUrl(String key) async {
    _urlCache[_hashKey(key)] = '$_negativeCachePrefix${DateTime.now().day}';
    await _persist(_urlCacheKey, _urlCache);
  }

  Future<void> _persist(String key, Map<String, String> map) async {
    await _prefs?.setString(key, jsonEncode(map));
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _hashKey(String key) {
    return sha1.convert(utf8.encode(key)).toString();
  }
}
