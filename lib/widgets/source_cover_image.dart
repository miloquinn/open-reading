import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../book_sources/services/source_cover_cache.dart';

class SourceCoverImage extends StatefulWidget {
  const SourceCoverImage({
    super.key,
    required this.url,
    required this.fallback,
    this.cache,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.alignment = Alignment.center,
  });

  final Uri url;
  final Widget fallback;
  final SourceCoverCache? cache;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final AlignmentGeometry alignment;

  @override
  State<SourceCoverImage> createState() => _SourceCoverImageState();
}

class _SourceCoverImageState extends State<SourceCoverImage> {
  late Future<Uint8List> _bytes;
  int _decodeRetryCount = 0;
  bool _decodeRetryScheduled = false;

  SourceCoverCache get _cache => widget.cache ?? SourceCoverCache.instance;

  @override
  void initState() {
    super.initState();
    _bytes = _cache.load(widget.url);
  }

  @override
  void didUpdateWidget(covariant SourceCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cache != widget.cache) {
      _decodeRetryCount = 0;
      _decodeRetryScheduled = false;
      _bytes = _cache.load(widget.url);
    }
  }

  void _retryAfterDecodeFailure() {
    if (_decodeRetryCount > 0 || _decodeRetryScheduled) return;
    _decodeRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _decodeRetryCount++;
      try {
        await _cache.evict(widget.url);
        if (!mounted) return;
        setState(() {
          _decodeRetryScheduled = false;
          _bytes = _cache.load(widget.url);
        });
      } catch (_) {
        _decodeRetryScheduled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return widget.fallback;
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            _retryAfterDecodeFailure();
            return widget.fallback;
          },
        );
      },
    );
  }
}
