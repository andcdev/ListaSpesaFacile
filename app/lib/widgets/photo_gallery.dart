import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Galleria a tutto schermo delle immagini di un prodotto: si scorre di lato, si ingrandisce con due dita.
/// [more] aggiunge altre immagini quando arrivano (es. quelle di Open Food Facts: ingredienti, tabella nutrizionale).
Future<void> showPhotoGallery(
  BuildContext context,
  List<ImageProvider> images, {
  String? caption,
  Future<List<ImageProvider>>? more,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PhotoGallery(images: images, caption: caption, more: more),
  ),
);

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.images, this.caption, this.more});

  final List<ImageProvider> images;
  final String? caption;
  final Future<List<ImageProvider>>? more;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final List<ImageProvider> _images = [...widget.images];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.more?.then((extra) {
      if (!mounted || extra.isEmpty) return;
      setState(() => _images.addAll(extra));
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.caption ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_images.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_page + 1} / ${_images.length}', style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: PageView.builder(
        itemCount: _images.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image(
              image: _images[i],
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, _, _) =>
                  Text(context.l10n.imageUnavailable, style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
