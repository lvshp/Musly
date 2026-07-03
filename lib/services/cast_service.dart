import 'package:flutter/foundation.dart';

enum CastState { notConnected, connecting, connected, disconnecting }

class CastMediaState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? title;
  final String? artist;
  final String? imageUrl;
  final double volume;

  CastMediaState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.title,
    this.artist,
    this.imageUrl,
    this.volume = 1.0,
  });

  CastMediaState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? title,
    String? artist,
    String? imageUrl,
    double? volume,
  }) {
    return CastMediaState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      imageUrl: imageUrl ?? this.imageUrl,
      volume: volume ?? this.volume,
    );
  }
}

class CastService extends ChangeNotifier {
  CastState _state = CastState.notConnected;
  CastMediaState _mediaState = CastMediaState();
  String? _deviceName;

  CastState get state => _state;
  bool get isConnected => _state == CastState.connected;
  bool get isConnecting => _state == CastState.connecting;
  CastMediaState get mediaState => _mediaState;
  String? get deviceName => _deviceName;

  Future<bool> connectToDevice(Object device) async {
    debugPrint('CastService: Chromecast disabled on this build');
    return false;
  }

  Future<void> disconnect() async {
    _state = CastState.notConnected;
    _deviceName = null;
    _mediaState = CastMediaState();
    notifyListeners();
  }

  Future<bool> loadMedia({
    required String url,
    required String title,
    required String artist,
    required String imageUrl,
    String? albumName,
    int? trackNumber,
    Duration? duration,
    bool autoPlay = true,
  }) async {
    debugPrint('CastService: Cannot load media because Chromecast is disabled');
    return false;
  }

  Future<void> play() async {}

  Future<void> pause() async {}

  Future<void> stop() async {
    _mediaState = CastMediaState();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {}

  Future<void> setVolume(double volume) async {
    _mediaState = _mediaState.copyWith(volume: volume.clamp(0.0, 1.0));
    notifyListeners();
  }
}
