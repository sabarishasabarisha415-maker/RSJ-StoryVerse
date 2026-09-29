import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri.parse('mailto:sabarishasabarisha415@gmail.com?subject=RSJ%20StoryVerse%20Support');
    try {
      if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open email app.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Email:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchEmail(context),
              child: const Text(
                'sabarishasabarisha415@gmail.com',
                style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 24),
            const Text('App Version:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('1.0.0', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            const Text('FAQ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('How do I upload a story?\nHow do I update my profile?\nHow do I view favorites?', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 24),
            const Text('Report a Bug', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Please email us with the issue details and screenshots.', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 24),
            const Text('Contact Developer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchEmail(context),
              child: const Text(
                'sabarishasabarisha415@gmail.com',
                style: TextStyle(color: Colors.deepPurpleAccent, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
