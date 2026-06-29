import 'package:moto_driver/modules/driver_registration/domain/repositories/i_register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:result_dart/result_dart.dart';

class RegisterUsecase implements IRegisterUsecase {
  final IRegisterRepository _repository;

  RegisterUsecase(this._repository);

  @override
  Future<Result<void>> call(RegisterParams params) {
    return _repository.register(params);
  }
}
