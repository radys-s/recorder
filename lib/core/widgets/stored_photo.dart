import 'dart:io';

import 'package:flutter/material.dart';

import '../paths.dart';

/// A photo from app storage, by its stored (relative) path. A missing file
/// shows a quiet placeholder rather than an error: the photo is an extra.
class StoredPhoto extends StatefulWidget {
  const StoredPhoto({
    super.key,
    required this.storedPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String storedPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends State<StoredPhoto> {
  late Future<String> _path = resolveStoredPath(widget.storedPath);

  @override
  void didUpdateWidget(StoredPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedPath != widget.storedPath) {
      _path = resolveStoredPath(widget.storedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
    );

    return FutureBuilder<String>(
      future: _path,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) return placeholder;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Image.file(
          File(path),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          // Decode near display size: a 1600 px photo per bubble adds up.
          cacheWidth: widget.width == null ? null : (widget.width! * dpr).round(),
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}

/// The photo full screen, zoomable.
Future<void> showStoredPhoto(BuildContext context, String storedPath) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: StoredPhoto(storedPath: storedPath, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}
