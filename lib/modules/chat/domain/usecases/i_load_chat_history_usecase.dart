import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:result_dart/result_dart.dart';

abstract class ILoadChatHistoryUsecase {
  Future<Result<ChatHistoryEntity>> call(String travelId);
}
