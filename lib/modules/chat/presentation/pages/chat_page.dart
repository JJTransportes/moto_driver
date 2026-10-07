import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_bloc.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_event.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_state.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';

/// Conversa do chat temporário da viagem (spec pickup-chat-call). O [ChatBloc]
/// vem de um `BlocProvider` acima; [session] controla o selo de não lidas.
class ChatPage extends StatefulWidget {
  final String travelId;
  final String title;
  final ChatSession session;

  const ChatPage({
    super.key,
    required this.travelId,
    required this.title,
    required this.session,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _canSend = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.session.setChatOpen(true);
    _controller.addListener(() {
      final canSend = _controller.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
  }

  @override
  void dispose() {
    widget.session.setChatOpen(false);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    BlocProvider.of<ChatBloc>(context).add(ChatMessageSubmitted(text));
    _controller.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _onClosed() {
    if (_closing) return;
    _closing = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('O chat foi encerrado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Modular.to.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: context.moto.textPrimary, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: BlocConsumer<ChatBloc, ChatState>(
          listener: (context, state) {
            if (state is ChatClosed) {
              _onClosed();
            } else if (state is ChatReady) {
              _scrollToEnd();
              final notice = state.notice;
              if (notice != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(notice),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          builder: (context, state) => switch (state) {
            ChatInitial() || ChatLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ChatFailure(:final message) => _buildFailure(message),
            ChatClosed() => const SizedBox.shrink(),
            ChatReady() => _buildConversation(state),
          },
        ),
      ),
    );
  }

  Widget _buildFailure(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => BlocProvider.of<ChatBloc>(
                context,
              ).add(ChatStarted(widget.travelId)),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(ChatReady state) {
    return Column(
      children: [
        if (!state.connected)
          Container(
            key: const Key('chat_reconnecting_banner'),
            width: double.infinity,
            color: context.moto.danger.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Text(
              'Reconectando… o envio volta quando a conexão voltar.',
              style: TextStyle(color: context.moto.textPrimary, fontSize: 13),
            ),
          ),
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma mensagem ainda. Combine o ponto de encontro por aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.moto.textSecondary),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) => _Bubble(
                    item: state.items[index],
                    onRetry: () => BlocProvider.of<ChatBloc>(context).add(
                      ChatSendRetried(state.items[index].clientMessageId),
                    ),
                  ),
                ),
        ),
        _buildInput(state),
      ],
    );
  }

  Widget _buildInput(ChatReady state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input'),
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: kChatMaxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Digite uma mensagem',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: IconButton.filled(
              key: const Key('chat_send_button'),
              onPressed: _canSend && state.connected ? _send : null,
              icon: const Icon(Icons.send),
              tooltip: 'Enviar',
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatItem item;
  final VoidCallback onRetry;

  const _Bubble({required this.item, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failed = item.status == ChatItemStatus.failed;
    final bubbleColor = item.mine ? context.moto.accent : context.moto.bgRaised;
    final textColor = item.mine ? Colors.white : context.moto.textPrimary;

    return Align(
      alignment: item.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: item.mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: item.mine
                    ? null
                    : Border.all(color: context.moto.borderDefault),
              ),
              child: Text(item.text, style: TextStyle(color: textColor)),
            ),
            if (item.status == ChatItemStatus.sending)
              Text(
                'Enviando…',
                style: TextStyle(
                  fontSize: 11,
                  color: context.moto.textSecondary,
                ),
              ),
            if (failed)
              InkWell(
                key: const Key('chat_retry'),
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Não enviada. Toque para reenviar.',
                    style: TextStyle(fontSize: 12, color: context.moto.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
