import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'constants.dart';
import 'photo_files.dart';

/// A photo as picked: downscaled, in memory, not yet stored anywhere.
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
}

/// The camera and the gallery. The picker does the downscale itself
/// ([kPhotoMaxDimension], JPEG [kPhotoJpegQuality]), so no image package ships.
class PhotoPicker {
  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// One photo from the camera, or null when cancelled.
  Future<PickedPhoto?> takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: kPhotoMaxDimension,
      maxHeight: kPhotoMaxDimension,
      imageQuality: kPhotoJpegQuality,
    );
    return file == null ? null : _read(file);
  }

  /// Several pages from the gallery; empty when cancelled.
  Future<List<PickedPhoto>> pickPages() async {
    final files = await _picker.pickMultiImage(
      maxWidth: kPhotoMaxDimension,
      maxHeight: kPhotoMaxDimension,
      imageQuality: kPhotoJpegQuality,
      limit: kMaxPagePhotos,
    );
    return [for (final f in files.take(kMaxPagePhotos)) await _read(f)];
  }

  Future<PickedPhoto> _read(XFile file) async {
    final name = file.name.isEmpty ? file.path : file.name;
    final dot = name.lastIndexOf('.');
    return PickedPhoto(
      bytes: await file.readAsBytes(),
      mimeType: photoMimeType(name),
      extension: dot < 0 ? '.jpg' : name.substring(dot).toLowerCase(),
    );
  }
}
