import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';

class ProfileImageDisplay extends StatefulWidget {
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
  State<ProfileImageDisplay> createState() => _ProfileImageDisplayState();
}

class _ProfileImageDisplayState extends State<ProfileImageDisplay> {
  Map<String, String>? _authHeaders;

  @override
  void initState() {
    super.initState();
    _loadAuthHeaders();
  }

  Future<void> _loadAuthHeaders() async {
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token != null && mounted) {
      setState(() {
        _authHeaders = {'Authorization': 'Bearer $token'};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only use NetworkImage when auth headers are loaded.
    // Show fallback (initials) while token is being fetched to avoid
    // an unauthorized request (401) on /api/files/{fileId}.
    if (widget.photoUrl != null &&
        widget.photoUrl!.isNotEmpty &&
        _authHeaders != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage:
            NetworkImage(widget.photoUrl!, headers: _authHeaders),
        onBackgroundImageError: (_, __) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return CircleAvatar(
      backgroundColor: const Color(0xFF4685C0),
      radius: widget.radius,
      child: Text(
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: widget.radius > 25 ? 24 : 16,
        ),
      ),
    );
  }
}
