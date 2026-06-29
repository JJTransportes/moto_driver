import 'package:result_dart/result_dart.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

abstract class IRegisterUsecase {
  Future<Result<void>> call(RegisterParams params);
}
