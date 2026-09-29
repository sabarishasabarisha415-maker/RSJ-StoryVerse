import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final StreamSubscription<User?> _authSubscription;
  User? _user;
  Object? _authError;
  bool _authLoaded = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen(
      _onAuthStateChanged,
      onError: _onAuthError,
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  bool _hasEmailAuthentication(User? user) {
    return user != null &&
        !user.isAnonymous &&
        user.providerData.any((provider) => provider.providerId == 'password');
  }

  void _onAuthStateChanged(User? user) {
    final wasLoaded = _authLoaded;
    final previousUid = _user?.uid;
    final previousEmailAuthentication = _hasEmailAuthentication(_user);
    final nextEmailAuthentication = _hasEmailAuthentication(user);

    if (mounted) {
      setState(() {
        _user = user;
        _authError = null;
        _authLoaded = true;
      });
    }

    if (wasLoaded &&
        (previousUid != user?.uid ||
            previousEmailAuthentication != nextEmailAuthentication)) {
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _onAuthError(Object error) {
    debugPrint('Unable to monitor Firebase Authentication state: $error');
    if (!mounted) return;
    setState(() {
      _user = null;
      _authError = error;
      _authLoaded = true;
    });
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.menu_book_rounded, color: Colors.deepPurple, size: 100),
              SizedBox(height: 24),
              Text(
                'Checking your account...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.deepPurple),
            ],
          ),
        ),
      );
    }

    if (!_hasEmailAuthentication(_user)) {
      return LoginPage(
        key: const ValueKey('email-sign-in-required'),
        authError: _authError,
      );
    }

    return const HomePage(key: ValueKey('authenticated-storyverse'));
  }
}
