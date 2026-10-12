import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:result_dart/result_dart.dart';

abstract class IChatRepository {
  Future<Result<ChatMessageEntity>> sendMessage(SendChatMessageParams params);

  Future<Result<ChatHistoryEntity>> loadHistory(String travelId);

  Future<Result<void>> markRead(String travelId);

  /// Telefone do passageiro (nulo se não cadastrado). Nunca é guardado nem logado.
  Future<Result<PassengerContactEntity>> getPassengerContact(String travelId);
}
