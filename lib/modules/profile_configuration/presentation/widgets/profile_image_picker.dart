import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImagePicker {
  final ImagePicker _picker = ImagePicker();

  /// Shows a bottom sheet with options: Gallery and Camera.
  /// Returns the cropped file path, or null if cancelled.
  Future<String?> pickAndCropImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile == null) return null;

    return pickedFile.path;
  }
}
