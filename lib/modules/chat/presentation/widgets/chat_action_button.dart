import 'package:flutter/material.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';

/// Ação "Chat" do card da viagem. O selo de não lidas fica no cabeçalho.
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
          onPressed: () {
            session.setChatOpen(true);
            onPressed();
          },
          icon: Badge(
            key: const Key('chat-button-unread-badge'),
            isLabelVisible: unread > 0,
            backgroundColor: Theme.of(context).colorScheme.error,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(
              Icons.chat_bubble_outline,
              color: unread > 0 ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          label: Text(label),
        );
      },
    );
  }
}
