import 'package:flutter/material.dart';

String normalizeStoryStatus(dynamic value) {
  final status = value?.toString().trim().toLowerCase();
  if (status == 'draft') {
    return 'draft';
  }
  return 'published';
}

bool isPublishedStory(dynamic value) => normalizeStoryStatus(value) == 'published';
bool isDraftStory(dynamic value) => normalizeStoryStatus(value) == 'draft';

String displayStoryStatus(dynamic value) => isDraftStory(value) ? 'Draft' : 'Published';

Color storyStatusColor(dynamic value) {
  return isDraftStory(value) ? Colors.orangeAccent : Colors.greenAccent;
}

String emptyAuthorStoriesMessage() {
  return "You haven't published any stories yet.";
}
