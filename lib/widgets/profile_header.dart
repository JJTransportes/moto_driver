import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/widgets/profile_image_display.dart';

class ProfileHeader extends StatelessWidget {
  final String fullName;
  final String? photoUrl;
  final String userId;
  final VoidCallback? onSignOut;
  final VoidCallback? onSettingsTap;

  const ProfileHeader({
    super.key,
    required this.fullName,
    this.photoUrl,
    required this.userId,
    this.onSignOut,
    this.onSettingsTap,
  });

  static const _weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String _todayLabel() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileImageDisplay(
          photoUrl: photoUrl,
          name: fullName,
          radius: 20,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_todayLabel(), style: Theme.of(context).textTheme.bodySmall),
            Text(
              'Olá, ${fullName.split(' ').first}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.moto.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'settings') {
              if (onSettingsTap != null) {
                onSettingsTap!();
              } else {
                Modular.to.pushNamed('/profile-configuration', arguments: {'userId': userId});
              }
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
