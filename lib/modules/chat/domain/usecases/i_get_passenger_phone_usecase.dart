import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:result_dart/result_dart.dart';

abstract class IGetPassengerPhoneUsecase {
  /// Contato do passageiro da viagem em `Accepted` (telefone nulo se não cadastrado).
  Future<Result<PassengerContactEntity>> call(String travelId);
}
