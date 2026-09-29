import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'firebase_error.dart';
import 'story_reading_page.dart';
import 'story_utils.dart';
import 'upload_story_page.dart';

class MyStoriesPage extends StatefulWidget {
  final String? statusFilter;

  const MyStoriesPage({super.key, this.statusFilter});

  @override
  State<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends State<MyStoriesPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          widget.statusFilter == 'draft' ? 'Draft Stories' : 'My Stories',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Please sign in',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('stories')
                  .where('authorId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        firebaseErrorMessage(
                          snapshot.error!,
                          operation: 'Unable to load your stories',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }

                final docs =
                    (snapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .where((doc) {
                          if (widget.statusFilter == null ||
                              widget.statusFilter!.isEmpty) {
                            return true;
                          }
                          return normalizeStoryStatus(doc.data()['status']) ==
                              widget.statusFilter;
                        })
                        .toList()
                      ..sort((a, b) {
                        final aTime =
                            a.data()['updatedAt'] ?? a.data()['createdAt'];
                        final bTime =
                            b.data()['updatedAt'] ?? b.data()['createdAt'];
                        if (aTime is Timestamp && bTime is Timestamp) {
                          return bTime.compareTo(aTime);
                        }
                        return 0;
                      });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.statusFilter == 'draft'
                            ? "You don't have any draft stories yet."
                            : emptyAuthorStoriesMessage(),
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildStoryCard(context, docs[index]);
                  },
                );
              },
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
    final description = data['description']?.toString() ?? '';
    final storyText = data['story']?.toString() ?? '';
    final storyId = storyDoc.id;
    final authorName = data['author']?.toString() ?? '';
    final coverStoragePath = data['coverStoragePath']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: coverUrl.isNotEmpty
                ? Image.network(
                    coverUrl,
                    width: 82,
                    height: 110,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  genre,
                  style: const TextStyle(color: Colors.deepPurpleAccent),
                ),
                const SizedBox(height: 6),
                Text(
                  displayStoryStatus(status),
                  style: TextStyle(
                    color: storyStatusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _actionButton(
                      icon: Icons.edit_note,
                      label: 'Continue Writing',
                      onPressed: () => _openEditor(
                        context,
                        storyId: storyId,
                        title: title,
                        author: authorName,
                        genre: genre,
                        description: description,
                        story: storyText,
                        coverUrl: coverUrl,
                        coverStoragePath: coverStoragePath,
                        status: status,
                      ),
                    ),
                    _actionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      onPressed: () => _openEditor(
                        context,
                        storyId: storyId,
                        title: title,
                        author: authorName,
                        genre: genre,
                        description: description,
                        story: storyText,
                        coverUrl: coverUrl,
                        coverStoragePath: coverStoragePath,
                        status: status,
                      ),
                    ),
                    _actionButton(
                      icon: Icons.visibility,
                      label: 'Preview',
                      onPressed: () =>
                          openStoryReadingPage(context, storyId: storyId),
                    ),
                    _actionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onPressed: () => _confirmDelete(context, storyDoc),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 82,
      height: 110,
      color: Colors.deepPurple.withValues(alpha: 0.3),
      child: const Icon(Icons.menu_book, color: Colors.white, size: 38),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required String storyId,
    required String title,
    required String author,
    required String genre,
    required String description,
    required String story,
    required String coverUrl,
    required String coverStoragePath,
    required String status,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue editing.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadStoryPage(
          storyId: storyId,
          title: title,
          author: author,
          genre: genre,
          description: description,
          story: story,
          coverUrl: coverUrl,
          coverStoragePath: coverStoragePath,
          status: status,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> storyDoc,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final authorId = storyDoc.data()['authorId']?.toString() ?? '';

    if (currentUser == null || currentUser.uid != authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own stories.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Delete story?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will remove the story and its cover image.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePath = storyDoc.data()['coverStoragePath']?.toString() ?? '';
      final coverUrl = storyDoc.data()['coverUrl']?.toString() ?? '';

      if (storagePath.isNotEmpty) {
        await FirebaseStorage.instance.ref().child(storagePath).delete();
      } else if (coverUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(coverUrl).delete();
      }

      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyDoc.id)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story deleted successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to delete story'),
          ),
        ),
      );
    }
  }
}
