import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('About RSJ StoryVerse', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RSJ StoryVerse', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Version: 1.0.0', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('Developer: RSJ Studio', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text(
              'RSJ StoryVerse is a modern storytelling app where readers can discover, upload, and enjoy stories from talented creators.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
