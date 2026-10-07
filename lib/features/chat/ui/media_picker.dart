import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/app_failure.dart';
import '../domain/message.dart';

const _tooBig = AppFailure('That file is too big (50 MB max).');

/// Images we render inline; anything else is sent as a file card.
const _inlineImageTypes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
};

/// The camera is only offered on phones/tablets.
bool get cameraAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Picks a photo (gallery or camera), downscaled to 2048px. Null if cancelled.
Future<OutgoingAttachment?> pickPhoto({bool camera = false}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 85,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (bytes.length > OutgoingAttachment.maxBytes) throw _tooBig;
  final type =
      lookupMimeType(x.name, headerBytes: bytes) ?? x.mimeType ?? 'image/jpeg';
  if (!_inlineImageTypes.contains(type)) {
    return _asFile(bytes, x.name, type);
  }
  final size = await imageSize(bytes);
  return OutgoingAttachment(
    bytes: bytes,
    name: x.name,
    kind: AttachmentKind.image,
    contentType: type,
    width: size?.$1,
    height: size?.$2,
  );
}

/// Picks any file. Common image types are sent as photos. Null if cancelled.
Future<OutgoingAttachment?> pickAnyFile() async {
  final f = await FilePicker.pickFile();
  if (f == null) return null;
  final known = f.lengthSync();
  if (known != null && known > OutgoingAttachment.maxBytes) throw _tooBig;
  final bytes = await f.readAsBytes();
  if (bytes.length > OutgoingAttachment.maxBytes) throw _tooBig;
  final type =
      lookupMimeType(f.name, headerBytes: bytes) ?? 'application/octet-stream';
  if (_inlineImageTypes.contains(type)) {
    final size = await imageSize(bytes);
    return OutgoingAttachment(
      bytes: bytes,
      name: f.name,
      kind: AttachmentKind.image,
      contentType: type,
      width: size?.$1,
      height: size?.$2,
    );
  }
  return _asFile(bytes, f.name, type);
}

OutgoingAttachment _asFile(Uint8List bytes, String name, String type) =>
    OutgoingAttachment(
      bytes: bytes,
      name: name,
      kind: AttachmentKind.file,
      contentType: type,
    );

/// Pixel size of encoded image bytes, or null if they can't be decoded.
Future<(int, int)?> imageSize(Uint8List bytes) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

/// Picks a square-ish profile photo, downscaled to 512px. Null if cancelled.
Future<({Uint8List bytes, String extension})?> pickAvatar() async {
  final x = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final type = lookupMimeType(x.name, headerBytes: bytes) ?? 'image/jpeg';
  if (type != 'image/jpeg' && type != 'image/png') {
    throw const AppFailure('Pick a JPEG or PNG photo.');
  }
  return (bytes: bytes, extension: type == 'image/png' ? 'png' : 'jpg');
}
