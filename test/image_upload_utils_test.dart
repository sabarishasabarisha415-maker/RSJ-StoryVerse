import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/image_upload_utils.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('image content type uses supported picker MIME types', () {
    final image = XFile('cover.jpeg', mimeType: 'image/png');

    expect(imageContentType(image), 'image/png');
  });

  test('image content type falls back to supported file extensions', () {
    expect(imageContentType(XFile('cover.JPEG')), 'image/jpeg');
    expect(imageContentType(XFile('cover.webp')), 'image/webp');
  });

  test('unsupported image content types are rejected', () {
    expect(
      imageContentType(XFile('cover.svg', mimeType: 'image/svg+xml')),
      isNull,
    );
  });
}
