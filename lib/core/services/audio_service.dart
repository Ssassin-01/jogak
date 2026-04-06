import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();

  Future<void> playBgm() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      // 감성적인 잔잔한 피아노 곡 (Sample URL)
      // 실제 앱 시연을 위한 저작권 없는 샘플 주소입니다.
      await _bgmPlayer.play(UrlSource('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'));
      await _bgmPlayer.setVolume(0.3); // 배경음이므로 30% 정도로 낮춤
    } catch (e) {
      debugPrint('Error playing BGM: $e');
    }
  }

  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  void dispose() {
    _bgmPlayer.dispose();
  }
}
