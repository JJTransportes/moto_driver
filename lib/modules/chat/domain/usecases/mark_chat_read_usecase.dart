import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_mark_chat_read_usecase.dart';
import 'package:result_dart/result_dart.dart';

class MarkChatReadUsecase implements IMarkChatReadUsecase {
  final IChatRepository _repository;

  MarkChatReadUsecase(this._repository);

  @override
  Future<Result<void>> call(String travelId) {
    return _repository.markRead(travelId);
  }
}
