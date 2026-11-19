import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.darkMode,
            builder: (context, isDark, _) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              subtitle: const Text('Saved on this device.'),
              value: isDark,
              onChanged: AppSettings.setDarkMode,
            ),
          ),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.voiceAlerts,
            builder: (context, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.record_voice_over),
              title: const Text('Spoken hazard alerts'),
              subtitle: const Text('Speak when a pothole is detected.'),
              value: enabled,
              onChanged: AppSettings.setVoiceAlerts,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: AppSettings.voiceVolume,
            builder: (context, volume, _) => ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Voice alert volume'),
              subtitle: Slider(
                value: volume,
                onChanged: AppSettings.setVoiceVolume,
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(volume * 100).round()}%',
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Blind spot distance'),
            subtitle: Text(
              'Not measured by this camera model. Use mirrors and direct '
              'observation; this app does not estimate collision risk.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Reports sync'),
            subtitle: Text(
              'Reports save offline. Cloud upload needs a configured Firebase '
              'project and a signed-in account.',
            ),
          ),
        ],
      ),
    );
  }
}
