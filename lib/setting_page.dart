import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'about_page.dart';
import 'edit_profile_page.dart';
import 'main.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = true;
  String displayName = 'RSJ User';
  String email = 'No Email';
  String bio = 'Welcome to RSJ StoryVerse';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    setState(() {
      displayName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'RSJ User';
      email = user?.email?.trim().isNotEmpty == true
          ? user!.email!
          : 'No Email';
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      darkModeEnabled = prefs.getBool('dark_mode') ?? true;
      themeNotifier.value = darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _saveNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (!mounted) return;
    setState(() {
      notificationsEnabled = value;
    });
  }

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    if (!mounted) return;
    setState(() {
      darkModeEnabled = value;
    });
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to sign out now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeEnabled;
    final backgroundColor = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Profile',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: TextStyle(color: secondaryTextColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildTile(
            title: 'Edit Profile',
            subtitle: 'Update your display name',
            icon: Icons.edit,
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: secondaryTextColor,
              size: 16,
            ),
            onTap: () async {
              final refreshed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(
                    currentName: displayName,
                    currentBio: bio,
                  ),
                ),
              );
              if (refreshed == true && mounted) {
                await _loadUserData();
              }
            },
          ),
          _buildTile(
            title: 'Notifications',
            subtitle: 'Receive updates and reminders',
            icon: Icons.notifications,
            trailing: Switch(
              value: notificationsEnabled,
              activeThumbColor: Colors.deepPurple,
              onChanged: (value) async {
                await _saveNotifications(value);
              },
            ),
          ),
          _buildTile(
            title: 'Dark Mode',
            subtitle: 'Use the dark theme',
            icon: Icons.dark_mode,
            trailing: Switch(
              value: darkModeEnabled,
              activeThumbColor: Colors.deepPurple,
              onChanged: (value) async {
                await _saveTheme(value);
              },
            ),
          ),
          _buildTile(
            title: 'About RSJ StoryVerse',
            subtitle: 'Discover, read and share stories',
            icon: Icons.info_outline,
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: secondaryTextColor,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
          _buildTile(
            title: 'Privacy Policy',
            subtitle: 'Read how your data is handled',
            icon: Icons.privacy_tip_outlined,
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: secondaryTextColor,
              size: 16,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(icon, color: Colors.deepPurple),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}
