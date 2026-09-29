import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_error.dart';
import 'image_upload_utils.dart';

class UploadStoryPage extends StatefulWidget {
  final String? storyId;
  final String? title;
  final String? author;
  final String? genre;
  final String? description;
  final String? story;
  final String? coverUrl;
  final String? coverStoragePath;
  final String? status;

  const UploadStoryPage({
    super.key,
    this.storyId,
    this.title,
    this.author,
    this.genre,
    this.description,
    this.story,
    this.coverUrl,
    this.coverStoragePath,
    this.status,
  });

  @override
  State<UploadStoryPage> createState() => _UploadStoryPageState();
}

class _UploadStoryPageState extends State<UploadStoryPage> {
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final storyController = TextEditingController();
  final descriptionController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  Uint8List? coverImageBytes;
  String? coverContentType;

  bool isLoading = false;

  String selectedGenre = "Romance";

  String? currentCoverUrl;
  String? currentCoverStoragePath;

  final List<String> genres = [
    "Romance",
    "Horror",
    "Fantasy",
    "Mystery",
    "Adventure",
  ];

  @override
  void initState() {
    super.initState();
    titleController.text = widget.title ?? '';
    authorController.text = widget.author ?? '';
    storyController.text = widget.story ?? '';
    descriptionController.text = widget.description ?? '';
    selectedGenre = widget.genre ?? 'Romance';
    if (!genres.contains(selectedGenre)) {
      genres.add(selectedGenre);
    }
    currentCoverUrl = widget.coverUrl;
    currentCoverStoragePath = widget.coverStoragePath;
  }

  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    storyController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickCoverImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      final contentType = imageContentType(image);
      if (contentType == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPEG, PNG, or WebP image.')),
        );
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > maxImageUploadBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover images must be 10 MB or smaller.'),
          ),
        );
        return;
      }
      setState(() {
        coverImageBytes = bytes;
        coverContentType = contentType;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            firebaseErrorMessage(
              error,
              operation: 'Unable to select cover image',
            ),
          ),
        ),
      );
    }
  }

  Future<Map<String, String>?> uploadCoverImage({
    required User user,
    required String contentType,
  }) async {
    if (coverImageBytes == null) return null;

    final extension = imageFileExtension(contentType);
    final fileName =
        'covers/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = FirebaseStorage.instance.ref().child(fileName);

    await ref.putData(
      coverImageBytes!,
      SettableMetadata(contentType: contentType),
    );
    return {'url': await ref.getDownloadURL(), 'path': ref.fullPath};
  }

  Future<void> saveStory({required bool publish}) async {
    final title = titleController.text.trim();
    final author = authorController.text.trim();
    final description = descriptionController.text.trim();
    final story = storyController.text.trim();

    if (title.isEmpty || author.isEmpty || story.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all details")));
      return;
    }
    if (title.length > 150 ||
        author.length > 80 ||
        description.length > 2000 ||
        story.length > 180000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Title, author, description, or story exceeds the allowed length.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    Object? existingCreatedAt;
    String? uploadedCoverStoragePath;
    String? oldCoverStoragePath;
    var storySaved = false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null ||
          user.isAnonymous ||
          !user.providerData.any(
            (provider) => provider.providerId == 'password',
          )) {
        throw Exception('Please sign in with your email account first.');
      }

      if (widget.storyId != null && widget.storyId!.isNotEmpty) {
        final existingDoc = await FirebaseFirestore.instance
            .collection('stories')
            .doc(widget.storyId)
            .get();
        if (!existingDoc.exists) {
          throw Exception('This story no longer exists.');
        }
        final existingData = existingDoc.data()!;
        final ownerId = existingData['authorId']?.toString() ?? '';
        if (ownerId != user.uid) {
          throw Exception('You can only edit your own stories.');
        }
        existingCreatedAt = existingData['createdAt'];
        oldCoverStoragePath = existingData['coverStoragePath']?.toString();
      }

      String? imageUrl = currentCoverUrl;
      String? storagePath = currentCoverStoragePath;

      if (coverImageBytes != null) {
        final selectedContentType = coverContentType;
        if (selectedContentType == null) {
          throw Exception('Please select the cover image again.');
        }
        final uploadedCover = await uploadCoverImage(
          user: user,
          contentType: selectedContentType,
        );
        imageUrl = uploadedCover?['url'];
        storagePath = uploadedCover?['path'];
        uploadedCoverStoragePath = storagePath;
      }

      final storyData = {
        'title': title,
        'author': author,
        'authorId': user.uid,
        'genre': selectedGenre,
        'description': description,
        'story': story,
        'coverUrl': imageUrl ?? '',
        'coverStoragePath': storagePath ?? '',
        'status': publish ? 'published' : 'draft',
        'createdAt': existingCreatedAt is Timestamp
            ? existingCreatedAt
            : Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (widget.storyId != null && widget.storyId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(widget.storyId)
            .update(storyData);
      } else {
        await FirebaseFirestore.instance.collection('stories').add(storyData);
      }
      storySaved = true;
      uploadedCoverStoragePath = null;

      if (oldCoverStoragePath != null &&
          oldCoverStoragePath.isNotEmpty &&
          oldCoverStoragePath != storagePath &&
          oldCoverStoragePath.startsWith('covers/${user.uid}/')) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(oldCoverStoragePath)
              .delete();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Story saved, but the previous cover could not be removed.',
                ),
              ),
            );
          }
          debugPrint('Unable to remove replaced cover: $error');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish
                ? 'Story published successfully 🎉'
                : 'Draft saved successfully',
          ),
        ),
      );

      if (publish) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!storySaved && uploadedCoverStoragePath != null) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child(uploadedCoverStoragePath)
              .delete();
        } catch (cleanupError) {
          debugPrint('Unable to clean up uploaded cover: $cleanupError');
        }
      }
      if (!mounted) return;

      final message = e is FirebaseException
          ? firebaseErrorMessage(e, operation: 'Unable to save story')
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xff0D0D0D),
        elevation: 0,
        title: const Text(
          "Create Story",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: pickCoverImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: coverImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          coverImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        ),
                      )
                    : (currentCoverUrl?.isNotEmpty == true)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          currentCoverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          errorBuilder: (context, error, stackTrace) =>
                              _coverPlaceholder(),
                        ),
                      )
                    : _coverPlaceholder(),
              ),
            ),

            const SizedBox(height: 25),

            if (widget.storyId == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Anyone can publish. We’ll assign a secure author identity '
                  'so only you can edit or delete your story.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),

            inputField("Story Title", titleController),

            const SizedBox(height: 15),

            inputField("Author Name", authorController),

            const SizedBox(height: 20),

            const Text(
              "Choose Genre",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGenre,
                  dropdownColor: const Color(0xff222222),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: genres.map((genre) {
                    return DropdownMenuItem<String>(
                      value: genre,
                      child: Text(genre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedGenre = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Description",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: descriptionController,
              maxLines: 3,
              maxLength: 2000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Short description about the story...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Chapter 1",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: storyController,
              maxLines: 10,
              maxLength: 180000,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Write your story here...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => saveStory(publish: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Draft',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => saveStory(publish: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Publish Story',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, color: Colors.white, size: 55),
        SizedBox(height: 10),
        Text(
          "Add Book Cover",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  Widget inputField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLength: hint == 'Story Title' ? 150 : 80,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
