import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_error.dart';
import 'story_reading_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Favorites', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in', style: TextStyle(color: Colors.white70)))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('favorites')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        firebaseErrorMessage(
                          snapshot.error!,
                          operation: 'Unable to load favorites',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No favorites yet', style: TextStyle(color: Colors.white70)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final favorite = snapshot.data!.docs[index];
                    final data = favorite.data();
                    final storyId = data['storyId']?.toString() ?? '';
                    final title = data['title']?.toString() ?? 'Untitled';
                    final author = data['author']?.toString() ?? '';
                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        onTap: storyId.isEmpty
                            ? null
                            : () => openStoryReadingPage(
                                  context,
                                  storyId: storyId,
                                ),
                        title: Text(
                          title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          author,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove from favorites',
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeFavorite(context, favorite),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _removeFavorite(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> favorite,
  ) async {
    try {
      await favorite.reference.delete();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to remove favorite'),
          ),
        ),
      );
    }
  }
}
