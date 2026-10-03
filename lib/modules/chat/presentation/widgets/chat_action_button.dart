import 'package:flutter/material.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';

/// Ação "Chat" do card da viagem, com selo de mensagens não lidas.
class ChatActionButton extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onPressed;
  final String label;

  const ChatActionButton({
    super.key,
    required this.session,
    required this.onPressed,
    this.label = 'Chat',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: session.unread,
      builder: (context, unread, _) {
        return OutlinedButton.icon(
          key: const Key('chat_action_button'),
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          label: Text(unread > 0 ? '$label ($unread)' : label),
        );
      },
    );
  }
}
