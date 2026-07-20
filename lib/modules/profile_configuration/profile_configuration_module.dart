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
import 'package:moto_driver/modules/user_deletion/data/datasources/i_user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/data/datasources/user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/data/repositories/user_deletion_repository.dart';
import 'package:moto_driver/modules/user_deletion/domain/repositories/i_user_deletion_repository.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/delete_account_usecase.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/i_delete_account_usecase.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_bloc.dart';

class ProfileConfigurationModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<IProfileDatasource>(ProfileDatasource.new);
    i.add<IUserDeletionDatasource>(UserDeletionDatasource.new);
    i.add<IProfileRepository>(ProfileRepository.new);
    i.add<IUserDeletionRepository>(UserDeletionRepository.new);
    i.add<IGetProfileUseCase>(GetProfileUseCase.new);
    i.add<IUpdateProfileUseCase>(UpdateProfileUseCase.new);
    i.add<IDeleteAccountUseCase>(DeleteAccountUseCase.new);
    i.add<IUploadProfileImageUseCase>(UploadProfileImageUseCase.new);
    i.addSingleton<ProfileConfigurationBloc>(ProfileConfigurationBloc.new);
    i.addSingleton<DeleteAccountBloc>(DeleteAccountBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: Modular.get<ProfileConfigurationBloc>(),
          ),
          BlocProvider.value(
            value: Modular.get<DeleteAccountBloc>(),
          ),
        ],
        child: ProfileConfigurationPage(
          userId: Modular.args.data['userId'] as String,
        ),
      ),
    );
  }
}
