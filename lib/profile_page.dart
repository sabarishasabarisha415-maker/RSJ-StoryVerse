import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'about_page.dart';
import 'author_dashboard.dart';
import 'downloads_page.dart';
import 'edit_profile_page.dart';
import 'favorites_page.dart';
import 'firebase_error.dart';
import 'help_support_page.dart';
import 'image_upload_utils.dart';

import 'my_stories_page.dart';
import 'reading_history_page.dart';
import 'setting_page.dart';
import 'upload_story_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  String displayName = 'RSJ User';
  String email = 'No Email';
  String bio = 'Welcome to RSJ StoryVerse';
  String profileImageUrl = '';
  String joinDate = 'Welcome to RSJ StoryVerse';
  int storiesPublished = 0;
  int storiesRead = 0;
  int favorites = 0;
  bool isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _listenToFavoriteCount();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  void _listenToFavoriteCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _favoritesSubscription?.cancel();
    _favoritesSubscription = _firestore
        .collection('favorites')
        .where('uid', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            favorites = snapshot.docs.length;
          });
        }, onError: (Object error) {
          firebaseErrorMessage(error, operation: 'Loading favorite count');
        });
  }

  Future<void> _loadProfileData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      displayName = currentUser.displayName?.trim().isNotEmpty == true
          ? currentUser.displayName!
          : 'RSJ User';
      email = currentUser.email?.trim().isNotEmpty == true ? currentUser.email! : 'No Email';
    });

    try {
      final userRef = _firestore.collection('users').doc(currentUser.uid);
      var profileDoc = await userRef.get();

      if (!profileDoc.exists) {
        await userRef.set({
          'displayName': currentUser.displayName?.trim().isNotEmpty == true
              ? currentUser.displayName!
              : 'RSJ User',
          'email': currentUser.email?.trim().isNotEmpty == true
              ? currentUser.email!
              : 'No Email',
          'bio': 'Welcome to RSJ StoryVerse',
          'joinDate': FieldValue.serverTimestamp(),
        });
        profileDoc = await userRef.get();
      }

      final data = profileDoc.data() ?? {};
      if (!mounted) return;
      setState(() {
        displayName =
            (data['displayName'] ?? currentUser.displayName ?? 'RSJ User')
                .toString();
        bio = (data['bio'] ?? 'Welcome to RSJ StoryVerse').toString();
        profileImageUrl =
            (data['profileImageUrl'] ?? currentUser.photoURL ?? '').toString();
        joinDate = data['joinDate'] is Timestamp
            ? (data['joinDate'] as Timestamp).toDate().toString()
            : 'Welcome to RSJ StoryVerse';
      });

      final storiesSnapshot = await _firestore
          .collection('stories')
          .where('authorId', isEqualTo: currentUser.uid)
          .get();
      final historySnapshot = await userRef.collection('reading_history').get();
      final favoriteSnapshot = await _firestore
          .collection('favorites')
          .where('uid', isEqualTo: currentUser.uid)
          .get();
      final publishedStoriesCount = storiesSnapshot.docs.where((doc) {
        final status =
            (doc.data()['status'] ?? 'published').toString().toLowerCase();
        return status == 'published';
      }).length;

      if (!mounted) return;
      setState(() {
        storiesPublished = publishedStoriesCount;
        storiesRead = historySnapshot.docs.length;
        favorites = favoriteSnapshot.docs.length;
      });
    } catch (error) {
      final message = firebaseErrorMessage(
        error,
        operation: 'Unable to load profile data',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to update your profile picture.')),
        );
        return;
      }

      final contentType = imageContentType(pickedFile);
      if (contentType == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPEG, PNG, or WebP image.')),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      final imageBytes = await pickedFile.readAsBytes();
      if (imageBytes.length > maxImageUploadBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile images must be 10 MB or smaller.')),
        );
        return;
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${currentUser.uid}.jpg');
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await ref.getDownloadURL();

      await currentUser.updatePhotoURL(url);
      await _firestore.collection('users').doc(currentUser.uid).set({
        'profileImageUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        profileImageUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(e, operation: 'Unable to upload profile picture'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  Future<void> _openContinueWriting() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    final snapshot = await _firestore
        .collection('stories')
        .where('authorId', isEqualTo: currentUser.uid)
        .get();

    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aTime = a.data()['updatedAt'] ?? a.data()['createdAt'];
        final bTime = b.data()['updatedAt'] ?? b.data()['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

    final story = docs.isNotEmpty ? docs.first : null;
    final data = story?.data();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadStoryPage(
          storyId: story?.id,
          title: data?['title']?.toString(),
          author: data?['author']?.toString(),
          genre: data?['genre']?.toString(),
          description: data?['description']?.toString(),
          story: data?['story']?.toString(),
          coverUrl: data?['coverUrl']?.toString(),
          coverStoragePath: data?['coverStoragePath']?.toString(),
          status: data?['status']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.deepPurple,
                    backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                    child: profileImageUrl.isEmpty
                        ? const Icon(Icons.person, size: 44, color: Colors.white)
                        : null,
                  ),
                  if (isLoading)
                    const Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    const Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.deepPurple),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(email, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Stories Published', storiesPublished.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('Stories Read', storiesRead.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('Favorites', favorites.toString()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Author Tools',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildAuthorToolItem('✍️ Write New Story', Icons.edit_note, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadStoryPage()));
                }),
                _buildAuthorToolItem('📚 My Stories', Icons.menu_book, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStoriesPage()));
                }),
                _buildAuthorToolItem('📝 Draft Stories', Icons.drafts_outlined, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStoriesPage(statusFilter: 'draft')));
                }),
                _buildAuthorToolItem('📖 Continue Writing', Icons.auto_stories, _openContinueWriting),
                _buildAuthorToolItem('📊 Dashboard / Analytics', Icons.bar_chart, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorDashboardPage()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildMenuItem('Edit Profile', Icons.edit, () async {
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
              await _loadProfileData();
            }
          }),
          _buildMenuItem('Favorites', Icons.favorite, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
          }),
          _buildMenuItem('Reading History', Icons.history, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingHistoryPage()));
          }),
          _buildMenuItem('Downloads', Icons.download, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage()));
          }),
          _buildMenuItem('Settings', Icons.settings, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          _buildMenuItem('Help & Support', Icons.help_outline, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()));
          }),
          _buildMenuItem('About RSJ StoryVerse', Icons.info_outline, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
          }),
          _buildMenuItem('Logout', Icons.logout, _logout),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAuthorToolItem(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(icon, color: Colors.deepPurpleAccent),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white54,
            size: 16,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(icon, color: Colors.deepPurple),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white54,
            size: 16,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
