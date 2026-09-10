import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedProductImage extends StatelessWidget {
  static const int defaultCacheSize = 360;

  static CachedNetworkImageProvider provider(
    String url, {
    int cacheSize = defaultCacheSize,
  }) {
    return CachedNetworkImageProvider(
      url.trim(),
      maxWidth: cacheSize,
      maxHeight: cacheSize,
    );
  }

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedProductImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth = defaultCacheSize,
    this.cacheHeight = defaultCacheSize,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final image = url.trim();
    if (image.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    final targetWidth = cacheWidth ?? defaultCacheSize;
    final targetHeight = cacheHeight ?? defaultCacheSize;

    return CachedNetworkImage(
      imageUrl: image,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      fit: fit,
      memCacheWidth: targetWidth,
      memCacheHeight: targetHeight,
      maxWidthDiskCache: targetWidth,
      maxHeightDiskCache: targetHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: placeholder == null
          ? null
          : (context, url) => placeholder!,
      errorWidget: (context, url, error) =>
          errorWidget ??
          placeholder ??
          const Icon(Icons.image_not_supported_outlined),
    );
  }
}
