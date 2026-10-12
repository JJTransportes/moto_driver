import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_get_passenger_phone_usecase.dart';
import 'package:result_dart/result_dart.dart';

class GetPassengerPhoneUsecase implements IGetPassengerPhoneUsecase {
  final IChatRepository _repository;

  GetPassengerPhoneUsecase(this._repository);

  @override
  Future<Result<PassengerContactEntity>> call(String travelId) {
    return _repository.getPassengerContact(travelId);
  }
}
