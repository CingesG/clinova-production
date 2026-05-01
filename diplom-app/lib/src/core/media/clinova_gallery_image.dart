import 'package:image_picker/image_picker.dart';

/// Gallery pick with identical behavior on mobile, web, and desktop (profile + chat).
Future<XFile?> pickClinovaGalleryJpeg() async {
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1200,
  );
}
