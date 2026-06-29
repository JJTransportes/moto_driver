import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/common_module.dart';
import 'package:moto_driver/modules/driver_registration/data/datasources/i_registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/data/datasources/registration_datasource.dart';
import 'package:moto_driver/modules/driver_registration/data/repositories/register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/repositories/i_register_repository.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_driver/modules/driver_registration/presentation/pages/registration_confirmation_page.dart';
import 'package:moto_driver/modules/driver_registration/presentation/pages/registration_page.dart';

class DriverRegistrationModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<IRegistrationDatasource>(RegistrationDatasource.new);
    i.add<IRegisterRepository>(RegisterRepository.new);
    i.add<IRegisterUsecase>(RegisterUsecase.new);
    i.addSingleton<RegisterBloc>(RegisterBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<RegisterBloc>(),
        child: const RegistrationPage(),
      ),
    );
    r.child(
      '/confirmation',
      child: (_) => const ConfirmationPage(),
    );
  }
}
