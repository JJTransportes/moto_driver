import 'package:flutter/material.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/data/datasources/phone_dialer.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_get_passenger_phone_usecase.dart';

/// Ícone de ligação ao passageiro no card da viagem em `Accepted` (spec
/// pickup-chat-call, req 5.x). Só o motorista liga.
///
/// O telefone é buscado a cada toque e descartado em seguida — não é guardado
/// na tela nem registrado em log. Sem telefone cadastrado, abre um modal que
/// orienta a usar o chat; o discador nunca é aberto nesse caso. O ícone fica
/// sempre visível enquanto a viagem está em `Accepted`.
class CallPassengerButton extends StatefulWidget {
  final String travelId;
  final IGetPassengerPhoneUsecase getPassengerPhone;
  final IPhoneDialer dialer;

  /// Abre o chat (ação do modal de telefone ausente).
  final VoidCallback onOpenChat;

  const CallPassengerButton({
    super.key,
    required this.travelId,
    required this.getPassengerPhone,
    required this.dialer,
    required this.onOpenChat,
  });

  @override
  State<CallPassengerButton> createState() => _CallPassengerButtonState();
}

class _CallPassengerButtonState extends State<CallPassengerButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);

    final result = await widget.getPassengerPhone(widget.travelId);
    if (!mounted) return;
    setState(() => _busy = false);

    final error = result.exceptionOrNull();
    if (error != null) {
      _showSnack(_messageFor(error));
      return;
    }

    final phone = result.getOrNull()?.phone;
    if (phone == null || sanitizePhone(phone) == null) {
      await _showMissingPhoneDialog();
      return;
    }

    final opened = await widget.dialer.dial(phone);
    if (!opened && mounted) {
      _showSnack('Não foi possível abrir o discador.');
    }
  }

  String _messageFor(Exception error) {
    if (error is ConflictException ||
        error is ForbiddenException ||
        error is NotFoundException) {
      return 'A ligação não está mais disponível para esta viagem.';
    }
    return 'Não foi possível obter o telefone. Tente novamente.';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showMissingPhoneDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('missing_phone_dialog'),
        title: const Text('Passageiro sem telefone'),
        content: const Text(
          'O passageiro não tem telefone cadastrado. '
          'Entre em contato com ele pelo chat.',
        ),
        actions: [
          TextButton(
            key: const Key('missing_phone_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton(
            key: const Key('missing_phone_open_chat'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onOpenChat();
            },
            child: const Text('Abrir chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('call_passenger_button'),
      onPressed: _busy ? null : _onPressed,
      icon: const Icon(Icons.call),
      label: const Text('Ligar'),
    );
  }
}
