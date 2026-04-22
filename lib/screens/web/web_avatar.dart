import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const WebAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.size,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  String get _initial {
    final name = displayName.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? _fallback()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _fallback(),
              errorBuilder: (_, _, _) => _fallback(),
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        _initial,
        style: GoogleFonts.inter(
          fontSize: size * .38,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
