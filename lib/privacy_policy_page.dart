import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Text(
            'Your privacy matters to us. We use Firebase Authentication to manage your account and securely store your story data. We only use your information to provide app functionality such as sign-in, profile updates, and story sharing. We do not sell your personal information. By using RSJ StoryVerse, you agree to the safe handling of your account and content data.',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ),
      ),
    );
  }
}
