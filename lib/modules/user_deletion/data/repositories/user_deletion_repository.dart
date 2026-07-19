import 'package:moto_driver/modules/user_deletion/data/datasources/i_user_deletion_datasource.dart';
import 'package:moto_driver/modules/user_deletion/domain/repositories/i_user_deletion_repository.dart';
import 'package:result_dart/result_dart.dart';

class UserDeletionRepository implements IUserDeletionRepository {
  final IUserDeletionDatasource _datasource;

  UserDeletionRepository(this._datasource);

  @override
  Future<Result<void>> deleteAccount(String password) async {
    try {
      await _datasource.deleteAccount(password);
      return const Success(unit);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
