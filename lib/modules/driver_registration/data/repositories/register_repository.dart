import 'package:moto_driver/modules/driver_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/domain/repositories/i_register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';
import 'package:result_dart/result_dart.dart';

class RegisterRepository implements IRegisterRepository {
  final IRegistrationDatasource _datasource;

  RegisterRepository(this._datasource);

  @override
  Future<Result<void>> register(RegisterParams params) async {
    try {
      await _datasource.register(params);
      return const Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
