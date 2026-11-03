import 'package:flutter_tts/flutter_tts.dart';

import 'app_settings.dart';

class VoiceAlertService {
  VoiceAlertService._();

  static final FlutterTts _tts = FlutterTts();

  static Future<void> speakHazard(String message) async {
    if (!AppSettings.voiceAlerts.value) return;
    try {
      await _tts.setVolume(AppSettings.voiceVolume.value);
      await _tts.speak(message);
    } catch (_) {
      // Spoken alerts are optional; a missing system speech engine must not
      // interrupt camera detection.
    }
  }
}
