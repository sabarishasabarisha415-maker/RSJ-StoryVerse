import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_error.dart';

Future<void> openStoryReadingPage(
  BuildContext context, {
  required String storyId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final hasEmailAuthentication =
      user != null &&
      !user.isAnonymous &&
      user.providerData.any((provider) => provider.providerId == 'password');

  if (!context.mounted) return;
  if (!hasEmailAuthentication) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in to read this story.')),
    );
    return;
  }
  if (storyId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story not found.')),
    );
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StoryReadingPage(storyId: storyId),
    ),
  );
}

class StoryNotFoundException implements Exception {
  const StoryNotFoundException();
}

class StoryAuthenticationRequiredException implements Exception {
  const StoryAuthenticationRequiredException();
}

class StoryReadingPage extends StatefulWidget {
  final String storyId;

  const StoryReadingPage({super.key, required this.storyId});

  @override
  State<StoryReadingPage> createState() => _StoryReadingPageState();
}

class _StoryReadingPageState extends State<StoryReadingPage> {
  late Future<Map<String, dynamic>> _storyFuture;
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _storyData;
  bool _isFavorite = false;
  bool _isFavoriteLoading = true;
  bool _isLiking = false;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _storyFuture = _loadStory();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadStory() async {
    final user = FirebaseAuth.instance.currentUser;
    final hasEmailAuthentication =
        user != null &&
        !user.isAnonymous &&
        user.providerData.any((provider) => provider.providerId == 'password');
    if (!hasEmailAuthentication) {
      throw const StoryAuthenticationRequiredException();
    }

    final document = await FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyId)
        .get();
    if (!document.exists) {
      throw const StoryNotFoundException();
    }

    final data = document.data()!;
    if (mounted) {
      setState(() {
        _storyData = data;
      });
    }
    unawaited(_loadFavoriteState(user));
    unawaited(_saveToReadingHistory(user, data));
    return data;
  }

  Future<void> _loadFavoriteState(User? user) async {
    if (user == null) return;
    try {
      final favorite = await FirebaseFirestore.instance
          .collection('favorites')
          .doc('${user.uid}_${widget.storyId}')
          .get();
      if (!mounted) return;
      setState(() {
        _isFavorite = favorite.exists;
        _isFavoriteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFavoriteLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(
              error,
              operation: 'Unable to load favorite status',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    final data = _storyData;
    if (user == null || data == null || _isFavoriteLoading) return;

    setState(() {
      _isFavoriteLoading = true;
    });

    final favoriteRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc('${user.uid}_${widget.storyId}');
    try {
      if (_isFavorite) {
        await favoriteRef.delete();
      } else {
        await favoriteRef.set({
          'uid': user.uid,
          'storyId': widget.storyId,
          'title': data['title']?.toString() ?? '',
          'author': data['author']?.toString() ?? '',
          'genre': data['genre']?.toString() ?? '',
          'story': data['story']?.toString() ?? '',
          'coverUrl': data['coverUrl']?.toString() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      setState(() {
        _isFavorite = !_isFavorite;
        _isFavoriteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFavoriteLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to update favorite'),
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike(bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || _isLiking) return;

    setState(() => _isLiking = true);
    final likeRef = FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyId)
        .collection('likes')
        .doc(user.uid);
    try {
      if (isLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              firebaseErrorMessage(error, operation: 'Unable to update like'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _commentController.text.trim();
    if (user == null || user.isAnonymous || text.isEmpty || _isSubmittingComment) {
      return;
    }

    setState(() => _isSubmittingComment = true);
    final displayName = user.displayName?.trim();
    final author = displayName != null && displayName.isNotEmpty
        ? displayName
        : user.email?.split('@').first ?? 'Reader';
    try {
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(widget.storyId)
          .collection('comments')
          .add({
            'uid': user.uid,
            'author': author,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _commentController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              firebaseErrorMessage(
                error,
                operation: 'Unable to post comment',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _editComment(
    DocumentReference<Map<String, dynamic>> commentRef,
    String existingText,
  ) async {
    final controller = TextEditingController(text: existingText);
    final editedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(hintText: 'Write a comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (editedText == null || editedText.isEmpty) return;
    try {
      await commentRef.update({
        'text': editedText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to edit comment'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteComment(
    DocumentReference<Map<String, dynamic>> commentRef,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This comment will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await commentRef.delete();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to delete comment'),
          ),
        ),
      );
    }
  }

  Future<void> _saveToReadingHistory(
    User? user,
    Map<String, dynamic> data,
  ) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reading_history')
          .doc(widget.storyId)
          .set(
            {
              'storyId': widget.storyId,
              'title': data['title']?.toString() ?? '',
              'author': data['author']?.toString() ?? '',
              'genre': data['genre']?.toString() ?? '',
              'coverUrl': data['coverUrl']?.toString() ?? '',
              'authorId': data['authorId']?.toString() ?? '',
              'lastReadChapter': 'Chapter 1',
              'lastReadTime': FieldValue.serverTimestamp(),
              'progress': 0,
            },
            SetOptions(merge: true),
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Unable to save reading history'),
          ),
        ),
      );
    }
  }

  void _retryLoading() {
    setState(() {
      _storyData = null;
      _isFavorite = false;
      _isFavoriteLoading = true;
      _storyFuture = _loadStory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xff0D0D0D),
        elevation: 0,
        title: const Text(
          'Reading',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isFavoriteLoading ? null : _toggleFavorite,
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite, color: Colors.redAccent),
            isSelected: _isFavorite,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }
          if (snapshot.hasError) {
            final isNotFound = snapshot.error is StoryNotFoundException;
            final requiresAuthentication =
                snapshot.error is StoryAuthenticationRequiredException;
            final message = isNotFound
                ? 'Story not found.'
                : requiresAuthentication
                ? 'Please sign in to read this story.'
                : firebaseErrorMessage(
                    snapshot.error!,
                    operation: 'Unable to load this story',
                  );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!isNotFound && !requiresAuthentication) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _retryLoading,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return _buildStory(data);
        },
      ),
    );
  }

  Widget _buildStory(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final author = data['author']?.toString() ?? '';
    final genre = data['genre']?.toString() ?? '';
    final content = data['story']?.toString() ?? '';
    final coverUrl = data['coverUrl']?.toString() ?? '';

    return SingleChildScrollView(
      key: ValueKey(widget.storyId),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 260,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.menu_book, size: 80, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.menu_book, size: 80, color: Colors.white),
            ),
          ),
          const SizedBox(height: 25),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'By $author',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            genre,
            style: const TextStyle(
              color: Colors.deepPurple,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildLikes(),
          const SizedBox(height: 30),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 36),
          _buildComments(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLikes() {
    final user = FirebaseAuth.instance.currentUser;
    final likes = FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyId)
        .collection('likes');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: likes.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Unable to load story likes: ${snapshot.error}');
          return const Text(
            'Likes are temporarily unavailable.',
            style: TextStyle(color: Colors.white54),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final documents = snapshot.data!.docs;
        final isLiked =
            user != null && documents.any((document) => document.id == user.uid);
        return Row(
          children: [
            IconButton(
              onPressed: _isLiking ? null : () => _toggleLike(isLiked),
              icon: Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                color: isLiked ? Colors.deepPurpleAccent : Colors.white70,
              ),
              tooltip: isLiked ? 'Unlike story' : 'Like story',
            ),
            Text(
              '${documents.length} ${documents.length == 1 ? 'like' : 'likes'}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComments() {
    final comments = FirebaseFirestore.instance
        .collection('stories')
        .doc(widget.storyId)
        .collection('comments')
        .orderBy('createdAt', descending: true);
    final currentUser = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Write a comment',
                  counterText: '',
                  filled: true,
                  fillColor: Color(0xFF1D1D1D),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              icon: _isSubmittingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: 'Post comment',
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: comments.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Unable to load story comments: ${snapshot.error}');
              return const Text(
                'Comments are temporarily unavailable.',
                style: TextStyle(color: Colors.white54),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final documents = snapshot.data?.docs ?? [];
            if (documents.isEmpty) {
              return const Text(
                'No comments yet.',
                style: TextStyle(color: Colors.white54),
              );
            }

            return Column(
              children: documents.map((document) {
                final data = document.data();
                final isOwnComment = data['uid'] == currentUser?.uid;
                final text = data['text']?.toString() ?? '';
                final author = data['author']?.toString() ?? 'Reader';
                return Card(
                  color: const Color(0xFF1D1D1D),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                author,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isOwnComment) ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Edit comment',
                                onPressed: () =>
                                    _editComment(document.reference, text),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Delete comment',
                                onPressed: () =>
                                    _deleteComment(document.reference),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
