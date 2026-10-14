import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_load_chat_history_usecase.dart';
import 'package:result_dart/result_dart.dart';

class LoadChatHistoryUsecase implements ILoadChatHistoryUsecase {
  final IChatRepository _repository;

  LoadChatHistoryUsecase(this._repository);

  @override
  Future<Result<ChatHistoryEntity>> call(String travelId) {
    return _repository.loadHistory(travelId);
  }
}
