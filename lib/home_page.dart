import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_error.dart';
import 'library_page.dart';
import 'profile_page.dart';
import 'setting_page.dart';
import 'story_reading_page.dart';
import 'upload_story_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final Set<String> _favoriteStoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFavoriteStoryIds();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadFavoriteStoryIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _favoriteStoryIds
          ..clear()
          ..addAll(
            snapshot.docs
                .map((doc) => doc.data()['storyId']?.toString() ?? '')
                .where((value) => value.isNotEmpty),
          );
      });
    } catch (error) {
      final message = firebaseErrorMessage(
        error,
        operation: 'Unable to load favorites',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _toggleFavorite({
    required String storyId,
    required String title,
    required String author,
    required String genre,
    required String story,
    required String coverUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to use favorites.')),
      );
      return;
    }

    final favoriteDocId = '${user.uid}_$storyId';
    final favoritesRef = FirebaseFirestore.instance
        .collection('favorites')
        .doc(favoriteDocId);

    try {
      if (_favoriteStoryIds.contains(storyId)) {
        await favoritesRef.delete();
      } else {
        await favoritesRef.set({
          'uid': user.uid,
          'storyId': storyId,
          'title': title,
          'author': author,
          'genre': genre,
          'story': story,
          'coverUrl': coverUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(error, operation: 'Saving favorite'),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      if (_favoriteStoryIds.contains(storyId)) {
        _favoriteStoryIds.remove(storyId);
      } else {
        _favoriteStoryIds.add(storyId);
      }
    });
  }

  Future<void> _focusSearch() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    _searchFocusNode.requestFocus();
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );

    if (!mounted) return;
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xff0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xff0D0D0D),
          elevation: 0,
          title: const Text(
            "RSJ StoryVerse",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: _focusSearch,
              icon: const Icon(Icons.search, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your next world awaits ✨",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.deepPurple,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: "Search stories...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "🔥 Trending Stories",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("stories")
                    .where('status', isEqualTo: 'published')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        firebaseErrorMessage(
                          snapshot.error!,
                          operation: 'Unable to load trending stories',
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final publishedStories =
                      snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  if (publishedStories.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "No trending stories yet.",
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ),
                    );
                  }

                  final filteredStories = publishedStories.where((doc) {
                    final data = doc.data();
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final author = (data['author'] ?? '')
                        .toString()
                        .toLowerCase();
                    final genre = (data['genre'] ?? '')
                        .toString()
                        .toLowerCase();
                    final query = _searchQuery;
                    return query.isEmpty ||
                        title.contains(query) ||
                        author.contains(query) ||
                        genre.contains(query);
                  }).toList();

                  if (filteredStories.isEmpty) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        key: const ValueKey('no-results'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.search_off,
                                color: Colors.white54,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "No stories found",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: ListView.builder(
                      key: ValueKey(_searchQuery),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredStories.length,
                      itemBuilder: (context, index) {
                        final story = filteredStories[index];
                        final data = story.data();
                        final title = data['title']?.toString() ?? '';
                        final author = data['author']?.toString() ?? '';
                        final genre = data['genre']?.toString() ?? '';
                        final storyText = data['story']?.toString() ?? '';
                        final coverUrl = data['coverUrl']?.toString() ?? '';
                        final isMatch =
                            _searchQuery.isNotEmpty &&
                            (title.toLowerCase().contains(_searchQuery) ||
                                author.toLowerCase().contains(_searchQuery) ||
                                genre.toLowerCase().contains(_searchQuery));

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          child: storyCard(
                            title,
                            author,
                            genre,
                            storyText,
                            coverUrl,
                            story.id,
                            _favoriteStoryIds.contains(story.id),
                            isHighlighted: isMatch,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.deepPurple,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadStoryPage()),
            );
          },
          icon: const Icon(Icons.upload, color: Colors.white),
          label: const Text("Upload", style: TextStyle(color: Colors.white)),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index == 0) {
              setState(() {
                currentIndex = index;
              });
              return;
            }

            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryPage()),
              );
              return;
            }

            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadStoryPage()),
              );
              return;
            }

            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              return;
            }
          },
          backgroundColor: const Color(0xff151515),
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: "Library"),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle),
              label: "Create",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget storyCard(
    String title,
    String author,
    String genre,
    String story,
    String coverUrl,
    String storyId,
    bool isFavorite, {
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: () => openStoryReadingPage(context, storyId: storyId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: isHighlighted
              ? Border.all(color: Colors.deepPurpleAccent, width: 2)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      width: 70,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.book, color: Colors.white),
                        );
                      },
                    )
                  : Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.book, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "✍️ $author",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 3),
                  Text(genre, style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavorite(
                storyId: storyId,
                title: title,
                author: author,
                genre: genre,
                story: story,
                coverUrl: coverUrl,
              ),
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.redAccent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
