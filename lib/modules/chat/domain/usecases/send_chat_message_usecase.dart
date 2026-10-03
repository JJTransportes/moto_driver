import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_send_chat_message_usecase.dart';
import 'package:result_dart/result_dart.dart';

class SendChatMessageUsecase implements ISendChatMessageUsecase {
  final IChatRepository _repository;

  SendChatMessageUsecase(this._repository);

  @override
  Future<Result<ChatMessageEntity>> call(SendChatMessageParams params) {
    return _repository.sendMessage(params);
  }
}
