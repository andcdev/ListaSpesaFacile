import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';

enum PhotoChoice { gallery, camera, remove }

/// Chiede da dove prendere la foto: galleria, fotocamera o (se [canRemove]) rimuovere quella attuale.
Future<PhotoChoice?> askPhotoSource(BuildContext context, {bool canRemove = false, String? title}) {
  return showModalBottomSheet<PhotoChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(title)),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.l10n.pickFromGallery),
            onTap: () => Navigator.pop(context, PhotoChoice.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.l10n.takePhoto),
            onTap: () => Navigator.pop(context, PhotoChoice.camera),
          ),
          if (canRemove)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.removePhoto),
              onTap: () => Navigator.pop(context, PhotoChoice.remove),
            ),
        ],
      ),
    ),
  );
}

/// Percorso della foto scelta (ridotta a 1600 px, JPEG 85%), null se l'utente annulla.
Future<String?> pickPhoto(PhotoChoice source) async {
  final photo = await ImagePicker().pickImage(
    source: source == PhotoChoice.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  return photo?.path;
}

/// Foto a tutto schermo (tocca una miniatura per aprirla), con didascalia facoltativa.
void showPhoto(BuildContext context, ImageProvider image, {String? caption}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InteractiveViewer(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) =>
                    Padding(padding: const EdgeInsets.all(32), child: Text(context.l10n.imageUnavailable)),
              ),
            ),
          ),
          if (caption != null) ListTile(title: Text(caption)),
        ],
      ),
    ),
  );
}
