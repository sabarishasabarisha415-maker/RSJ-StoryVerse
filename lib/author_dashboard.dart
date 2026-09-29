import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_error.dart';
import 'story_reading_page.dart';
import 'story_utils.dart';
import 'upload_story_page.dart';

class AuthorDashboardPage extends StatelessWidget {
  const AuthorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xff0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'Dashboard / Analytics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Text(
            'Please sign in to manage your stories.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Dashboard / Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadStats(user.uid),
        builder: (context, statsSnapshot) {
          if (statsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          }

          if (statsSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  firebaseErrorMessage(
                    statsSnapshot.error!,
                    operation: 'Unable to load dashboard data',
                  ),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final counts = statsSnapshot.data ?? {
            'published': 0,
            'draft': 0,
            'reads': 0,
            'favorites': 0,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '📊 Author Overview',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statCard('Published Stories', counts['published'].toString())),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Draft Stories', counts['draft'].toString())),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statCard('Stories Read', counts['reads'].toString())),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Favorites Saved', counts['favorites'].toString())),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadStoryPage()),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('✍️ Write New Story'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '📚 Your Stories',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('stories')
                    .where('authorId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, storySnapshot) {
                  if (storySnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                  }
                  if (storySnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        firebaseErrorMessage(
                          storySnapshot.error!,
                          operation: 'Unable to load your stories',
                        ),
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final myStories = (storySnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .toList()
                        ..sort((a, b) {
                          final aTime = a.data()['updatedAt'] ?? a.data()['createdAt'];
                          final bTime = b.data()['updatedAt'] ?? b.data()['createdAt'];
                          if (aTime is Timestamp && bTime is Timestamp) {
                            return bTime.compareTo(aTime);
                          }
                          return 0;
                        });

                  if (myStories.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No stories yet. Start writing your first story.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    children: myStories.map((storyDoc) => _buildStoryCard(context, storyDoc)).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> storyDoc,
  ) {
    final data = storyDoc.data();
    final title = data['title']?.toString() ?? 'Untitled';
    final genre = data['genre']?.toString() ?? 'General';
    final status = normalizeStoryStatus(data['status']);
    final coverUrl = data['coverUrl']?.toString() ?? '';
    final storyText = data['story']?.toString() ?? '';
    final storyId = storyDoc.id;
    final authorId = data['authorId']?.toString() ?? '';
    final authorName = data['author']?.toString() ?? '';

    return Card(
      color: const Color(0xff1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      width: 70,
                      height: 95,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _placeholder();
                      },
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(genre, style: const TextStyle(color: Colors.deepPurpleAccent)),
                  const SizedBox(height: 6),
                  Text(
                    displayStoryStatus(status),
                    style: TextStyle(color: storyStatusColor(status), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () {
                          if (FirebaseAuth.instance.currentUser?.uid == authorId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UploadStoryPage(
                                  storyId: storyId,
                                  title: title,
                                  author: authorName,
                                  genre: genre,
                                  description: data['description']?.toString() ?? '',
                                  story: storyText,
                                  coverUrl: coverUrl,
                                  coverStoragePath: data['coverStoragePath']?.toString(),
                                  status: status,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _actionButton(
                        icon: Icons.visibility,
                        label: 'Preview',
                        onPressed: () => openStoryReadingPage(
                          context,
                          storyId: storyId,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff2A2A2A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 70,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.menu_book, color: Colors.white70),
    );
  }

  Future<Map<String, int>> _loadStats(String uid) async {
    final storiesSnapshot = await FirebaseFirestore.instance
        .collection('stories')
        .where('authorId', isEqualTo: uid)
        .get();

    final publishedCount = storiesSnapshot.docs.where((doc) {
      return normalizeStoryStatus(doc.data()['status']) == 'published';
    }).length;

    final draftCount = storiesSnapshot.docs.length - publishedCount;

    final readsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reading_history')
        .get();
    final favoritesSnapshot = await FirebaseFirestore.instance
        .collection('favorites')
        .where('uid', isEqualTo: uid)
        .get();

    return {
      'published': publishedCount,
      'draft': draftCount,
      'reads': readsSnapshot.docs.length,
      'favorites': favoritesSnapshot.docs.length,
    };
  }
}
