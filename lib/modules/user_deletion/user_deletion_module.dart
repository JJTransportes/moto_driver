import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/common_module.dart';
import 'package:moto_driver/modules/user_deletion/data/datasources/i_user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/data/datasources/user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/data/repositories/user_deletion_repository.dart';
import 'package:moto_driver/modules/user_deletion/domain/repositories/i_user_deletion_repository.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/delete_account_usecase.dart';
import 'package:moto_driver/modules/user_deletion/domain/usecases/i_delete_account_usecase.dart';
import 'package:moto_driver/modules/user_deletion/presentation/blocs/delete_account_bloc.dart';
import 'package:moto_driver/modules/user_deletion/presentation/pages/delete_account_page.dart';

class UserDeletionModule extends Module {
  @override
  List<Module> get imports => [CommonModule()];

  @override
  void binds(i) {
    i.add<IUserDeletionDatasource>(UserDeletionDatasource.new);
    i.add<IUserDeletionRepository>(UserDeletionRepository.new);
    i.add<IDeleteAccountUseCase>(DeleteAccountUseCase.new);
    i.addSingleton<DeleteAccountBloc>(DeleteAccountBloc.new);
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (_) => BlocProvider.value(
        value: Modular.get<DeleteAccountBloc>(),
        child: DeleteAccountPage(),
      ),
    );
  }
}
