import 'package:result_dart/result_dart.dart';

abstract class IMarkChatReadUsecase {
  Future<Result<void>> call(String travelId);
}
