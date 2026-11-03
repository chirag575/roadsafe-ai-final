import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 50),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RoadSafe "),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, "/profile");
            },
            icon: const Icon(Icons.person),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            ValueListenableBuilder<AppSession?>(
              valueListenable: AuthService.session,
              builder: (context, session, _) {
                return UserAccountsDrawerHeader(
                  accountName: Text(session?.label ?? "RoadSafe AI"),
                  accountEmail: Text(
                    session?.subtitle ?? "Not signed in",
                  ),
                  currentAccountPicture: const CircleAvatar(
                    child: Icon(Icons.person, size: 40),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text("Maps"),
              onTap: () {
                Navigator.pushNamed(context, "/map");
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pushNamed(context, "/settings");
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text("About"),
              onTap: () {
                Navigator.pushNamed(context, "/about");
              },
            ),
            const Divider(),
            ValueListenableBuilder<AppSession?>(
              valueListenable: AuthService.session,
              builder: (context, session, _) {
                if (session == null) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Sign out"),
                  subtitle: Text(
                    session.isGuest
                        ? "Leave demo mode"
                        : "Sign out of ${session.label}",
                  ),
                  onTap: () async {
                    // Captured before the await: popping the drawer
                    // deactivates this BuildContext.
                    final navigator = Navigator.of(context);
                    Navigator.pop(context);
                    await AuthService.signOut();
                    navigator.pushNamedAndRemoveUntil(
                      "/login",
                      (route) => false,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.white, size: 55),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      Text(
                        "Road Safety Detection",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  buildCard(
                    context,
                    "Pothole Detection",
                    Icons.camera_alt,
                    Colors.blue,
                    "/camera",
                  ),

                  buildCard(
                    context,
                    "Blind Spot",
                    Icons.warning,
                    Colors.orange,
                    "/blindspot",
                  ),

                  // Pothole Detection opens the shared camera screen, which
                  // also reports vehicle detection in its status cards.
                  buildCard(
                    context,
                    "Maps",
                    Icons.map,
                    Colors.green,
                    "/map",
                  ),

                  buildCard(
                    context,
                    "Reports",
                    Icons.history,
                    Colors.deepPurple,
                    "/reports",
                  ),

                  buildCard(
                    context,
                    "Settings",
                    Icons.settings,
                    Colors.grey,
                    "/settings",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, "/camera");
        },
        label: const Text("Start"),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}
