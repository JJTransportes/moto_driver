import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

abstract class IRegistrationDatasource {
  Future<void> register(RegisterParams params);
}
