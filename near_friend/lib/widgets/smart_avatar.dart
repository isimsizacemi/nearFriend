import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SmartAvatar extends StatelessWidget {
  final String? photoURL;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const SmartAvatar({
    super.key,
    required this.photoURL,
    this.size = 50,
    this.fallbackIcon = CupertinoIcons.person_fill,
    this.fallbackColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: _buildImageWidget(),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (photoURL == null || photoURL!.isEmpty) {
      return _buildFallbackIcon();
    }

    if (photoURL!.startsWith('assets/')) {
      return Image.asset(
        photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Asset image error: $error for path: $photoURL');
          return _buildFallbackIcon();
        },
      );
    }

    if (photoURL!.startsWith('http://') || photoURL!.startsWith('https://')) {
      return Image.network(
        photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Network image error: $error for URL: $photoURL');
          return _buildFallbackIcon();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    if (photoURL!.contains('firebase') || photoURL!.contains('googleapis')) {
      return Image.network(
        photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Firebase image error: $error for URL: $photoURL');
          return _buildFallbackIcon();
        },
      );
    }

    print('⚠️ Unknown photo URL format: $photoURL');
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Icon(
      fallbackIcon,
      color: Colors.white,
      size: size * 0.6,
    );
  }
}
