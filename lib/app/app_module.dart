import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/core/common_module.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_login_usecase.dart';
import 'package:moto_driver/modules/auth/domain/usecases/login_usecase.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/pages/login_page.dart';
import 'package:moto_driver/modules/auth/presentation/pages/password_recovery_page.dart';
import 'package:moto_driver/modules/auth/presentation/pages/password_reset_page.dart';
import 'package:moto_driver/modules/driver_registration/driver_registration_module.dart';
import 'package:moto_driver/screens/active_travel_page.dart';
import 'package:moto_driver/screens/home_screen.dart';
import 'package:moto_driver/screens/splash_screen.dart';
import 'package:moto_driver/screens/travel_history_page.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [CommonModule()];
  @override
  void binds(i) {
    i.add<ILoginUsecase>(LoginUsecase.new);
    i.addSingleton<LoginBloc>(LoginBloc.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (_) => const SplashScreen());
    r.child(
      '/login',
      child: (_) => BlocProvider.value(
        value: Modular.get<LoginBloc>(),
        child: const LoginPage(),
      ),
    );
    r.child('/recovery', child: (_) => const PasswordRecoveryPage());
    r.child('/reset-password', child: (_) => const PasswordResetPage());
    r.child('/home', child: (_) => const HomeScreen());
    r.child('/active-travel', child: (_) {
      final args = Modular.args.data as Map<String, dynamic>;
      return ActiveTravelPage(travelId: args['travelId'] as String);
    });
    r.child('/travel-history', child: (_) => const DriverTravelHistoryPage());
    r.module('/driver-register', module: DriverRegistrationModule());
  }
}
