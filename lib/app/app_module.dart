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
import 'package:moto_driver/modules/driver_home/presentation/pages/order_alert_page.dart';
import 'package:moto_driver/modules/driver_home/presentation/pages/order_refresh_page.dart';
import 'package:moto_driver/modules/profile_configuration/profile_configuration_module.dart';
import 'package:moto_driver/modules/user_deletion/user_deletion_module.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_bloc.dart';
import 'package:moto_driver/modules/usage_terms/presentation/pages/terms_page.dart';
import 'package:moto_driver/screens/active_travel_page.dart';
import 'package:moto_driver/screens/bootstrap_screen.dart';
import 'package:moto_driver/screens/home_screen.dart';
import 'package:moto_driver/screens/splash_screen.dart';
import 'package:moto_driver/screens/travel_history_page.dart';

class AppModule extends Module {
  @override
  List<Module> get imports => [
    CommonModule(),
  ];

  @override
  void binds(i) {
    i.add<ILoginUsecase>(LoginUsecase.new);
    i.addSingleton<LoginBloc>(LoginBloc.new);
    i.addSingleton<UsageTermsBloc>(UsageTermsBloc.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (_) => const SplashScreen());
    r.child('/bootstrap', child: (_) => const BootstrapScreen());
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
    r.child(
      '/order-refresh',
      child: (_) => OrderRefreshPage(
        orderId: Modular.args.data['orderId'] as String?,
      ),
    );
    r.child(
      '/order-alert',
      child: (_) => OrderAlertPage(
        orderId: Modular.args.data['orderId'] as String?,
      ),
    );
    r.child(
      '/active-travel',
      child: (_) {
        final args = Modular.args.data as Map<String, dynamic>;
        return ActiveTravelPage(travelId: args['travelId'] as String);
      },
    );
    r.child(
      '/terms',
      child: (_) => BlocProvider.value(
        value: Modular.get<UsageTermsBloc>(),
        child: const TermsPage(),
      ),
    );
    r.child('/travel-history', child: (_) => const DriverTravelHistoryPage());
    r.module('/driver-register', module: DriverRegistrationModule());
    r.module('/profile-configuration', module: ProfileConfigurationModule());
    r.module('/delete-account', module: UserDeletionModule());
  }
}
