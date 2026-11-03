import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Detail fields the app has no data source for are reported honestly
  /// instead of being filled with invented values.
  static String _detail(
    AppSession? session,
    String? value, {
    required String guestFallback,
  }) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return session != null && !session.isGuest ? "Not set" : guestFallback;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSession?>(
      valueListenable: AuthService.session,
      builder: (context, session, _) {
        final isGuest = session?.isGuest ?? true;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Profile"),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 60,
                child: Icon(
                  Icons.person,
                  size: 70,
                  color: isGuest ? Colors.grey : null,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  session?.label ?? "Not signed in",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  session?.subtitle ?? "Sign in to sync your reports",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              if (isGuest) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.amber.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Demo mode. Nothing on this screen is saved to "
                            "an account.",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text("Name"),
                  subtitle: Text(
                    _detail(
                      session,
                      session?.displayName,
                      guestFallback: "Guest",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.email),
                  title: Text("Email"),
                  subtitle: Text(
                    _detail(
                      session,
                      session?.email,
                      guestFallback: "Not signed in",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.phone),
                  title: Text("Phone"),
                  subtitle: Text(
                    _detail(
                      session,
                      session?.phoneNumber,
                      guestFallback: "Not available in demo mode",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.location_city),
                  title: Text("City"),
                  subtitle: Text(
                    isGuest ? "Not available in demo mode" : "Not set",
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text("Reports Submitted"),
                  subtitle: const Text("Not tracked yet"),
                  trailing: const Chip(label: Text("-")),
                ),
              ),
              if (session != null) ...[
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await AuthService.signOut();
                      navigator.pushNamedAndRemoveUntil(
                        "/login",
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(
                      isGuest ? "Leave Demo Mode" : "Sign out",
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
