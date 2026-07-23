import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_image_display.dart';

class ProfileHeader extends StatelessWidget {
  final String fullName;
  final String? photoUrl;
  final String userId;
  final VoidCallback? onSignOut;

  const ProfileHeader({
    super.key,
    required this.fullName,
    this.photoUrl,
    required this.userId,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileImageDisplay(
          photoUrl: photoUrl,
          name: fullName,
          radius: 17,
        ),
        const SizedBox(width: 12),
        Text(
          'Olá, ${fullName.split(' ').first}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4E4E4E),
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'settings') {
              Modular.to.pushNamed('/profile-configuration', arguments: {'userId': userId});
            }
            if (value == 'signout') onSignOut?.call();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'settings',
              child: Text('Configurações'),
            ),
            PopupMenuItem(
              value: 'signout',
              child: Text('Sair'),
            ),
          ],
        ),
      ],
    );
  }
}
