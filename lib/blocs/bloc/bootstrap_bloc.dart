import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'bootstrap_events.dart';
part 'bootstrap_states.dart';

class BootstrapBloc extends Bloc<BootstrapEvents, BootstrapStates> {
  BootstrapBloc() : super(BootstrapInitial()) {
    on<BootstrapEvents>((event, emit) {
      // TODO: implement event handler
    });
  }
}
