import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../design/colors.dart';

/// Reusable cached network image widget with consistent loading/error handling.
/// Caches images to disk for fast subsequent loads.
class CachedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Color backgroundColor;

  const CachedImage(
    this.url, {
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor = const Color(0xFF111111),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => Container(
        color: backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => _brokenImage(),
      imageBuilder: (context, imageProvider) {
        if (borderRadius == null) {
          return Image(image: imageProvider, fit: fit);
        }
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image(image: imageProvider, fit: fit),
        );
      },
    );
  }

  Widget _brokenImage() => Container(
    color: backgroundColor,
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
    ),
  );
}

/// Avatar widget with caching - shows initials if no URL.
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;
  final Color backgroundColor;

  const CachedAvatar({
    required this.imageUrl,
    required this.displayName,
    this.radius = 16,
    this.backgroundColor = const Color(0xFF2A2A2A),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImageProvider(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
