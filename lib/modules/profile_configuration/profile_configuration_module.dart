import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/common_module.dart';
import 'package:moto_driver/modules/profile_configuration/data/datasources/i_profile_datasource.dart';
import 'package:moto_driver/modules/profile_configuration/data/datasources/profile_datasource.dart';
import 'package:moto_driver/modules/profile_configuration/data/repositories/profile_repository.dart';
import 'package:moto_driver/modules/profile_configuration/domain/repositories/i_profile_repository.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/get_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_get_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_update_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/i_upload_profile_image_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/update_profile_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/domain/usecases/upload_profile_image_usecase.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/blocs/profile_configuration_bloc.dart';
import 'package:moto_driver/modules/profile_configuration/presentation/pages/profile_configuration_page.dart';

class ProfileConfigurationModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<IProfileDatasource>(ProfileDatasource.new);
    i.add<IProfileRepository>(ProfileRepository.new);
    i.add<IGetProfileUseCase>(GetProfileUseCase.new);
    i.add<IUpdateProfileUseCase>(UpdateProfileUseCase.new);
    i.add<IUploadProfileImageUseCase>(UploadProfileImageUseCase.new);
    i.addSingleton<ProfileConfigurationBloc>(ProfileConfigurationBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<ProfileConfigurationBloc>(),
        child: ProfileConfigurationPage(
          userId: Modular.args.data['userId'] as String,
        ),
      ),
    );
  }
}
