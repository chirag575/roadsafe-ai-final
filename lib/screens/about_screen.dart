import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Icon(
              Icons.verified_user,
              size: 100,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'RoadSafe AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'RoadSafe AI is a road safety application built with '
              'Flutter, Firebase, GPS and Google Maps. It reads live '
              'camera, location and accelerometer data, and is designed '
              'to run an on-device object-detection model for potholes '
              'and blind-spot vehicles.',
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 15),

            // The bundled .tflite files are placeholders, so detection is
            // not active in this build. Saying so here is the whole point
            // of an About screen.
            Card(
              color: Colors.amber.shade50,
              child: const ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Colors.amber,
                ),
                title: Text('Detection model not bundled'),
                subtitle: Text(
                  'The models/ folder contains placeholder files, so live '
                  'detection is disabled in this build.',
                ),
              ),
            ),

            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.code,
                  color: Colors.blue,
                ),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.people,
                  color: Colors.blue,
                ),
                title: const Text('Developed By'),
                subtitle: const Text('RoadSafe AI Team'),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.security,
                  color: Colors.blue,
                ),
                title: const Text('Purpose'),
                subtitle: const Text(
                  'Improving road safety using AI technology',
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'RoadSafe AI',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Road safety application using AI.',
                  );
                },
                icon: const Icon(Icons.info),
                label: const Text('Learn More'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
