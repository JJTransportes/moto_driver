import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:result_dart/result_dart.dart';

abstract class IRegisterRepository {
  Future<Result<void>> register(RegisterParams params);
}
