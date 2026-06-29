import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/register_params.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final IRegisterUsecase _registerUsecase;

  RegisterBloc(this._registerUsecase) : super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterLoading());

    final result = await _registerUsecase.call(event.params);

    if (result.isSuccess()) {
      emit(const RegisterSuccess());
    } else {
      emit(RegisterFailure(result.exceptionOrNull()!.toString()));
    }
  }
}
