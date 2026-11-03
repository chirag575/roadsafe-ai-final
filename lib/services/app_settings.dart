import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> voiceAlerts = ValueNotifier<bool>(false);
  static final ValueNotifier<double> voiceVolume = ValueNotifier<double>(0.8);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    darkMode.value = preferences.getBool('dark_mode') ?? false;
    voiceAlerts.value = preferences.getBool('voice_alerts') ?? false;
    voiceVolume.value = preferences.getDouble('voice_volume') ?? 0.8;
  }

  static bool get isDarkMode => darkMode.value;

  static Future<void> setDarkMode(bool enabled) async {
    darkMode.value = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('dark_mode', enabled);
  }

  static Future<void> setVoiceAlerts(bool enabled) async {
    voiceAlerts.value = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('voice_alerts', enabled);
  }

  static Future<void> setVoiceVolume(double volume) async {
    voiceVolume.value = volume;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('voice_volume', volume);
  }
}
