import 'package:flutter/material.dart';

class ProfileImageDisplay extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const ProfileImageDisplay({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 17,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return CircleAvatar(
      backgroundColor: const Color(0xFF4685C0),
      radius: radius,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius > 25 ? 24 : 16,
        ),
      ),
    );
  }
}
