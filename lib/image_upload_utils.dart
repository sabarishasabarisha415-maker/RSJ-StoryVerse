import 'package:image_picker/image_picker.dart';

const maxImageUploadBytes = 10 * 1024 * 1024;

String? imageContentType(XFile file) {
  const supportedTypes = {'image/jpeg', 'image/png', 'image/webp'};
  final mimeType = file.mimeType?.split(';').first.trim().toLowerCase();
  if (mimeType != null && supportedTypes.contains(mimeType)) {
    return mimeType;
  }

  final extension = file.name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => null,
  };
}

String imageFileExtension(String contentType) {
  return switch (contentType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => throw ArgumentError.value(contentType, 'contentType'),
  };
}
