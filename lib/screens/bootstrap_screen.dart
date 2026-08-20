import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/blocs/bloc/bootstrap_bloc.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> with SingleTickerProviderStateMixin {
  late final BootstrapBloc _bloc;
  late final AnimationController _gearController;

  @override
  void initState() {
    super.initState();

    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bloc = context.read<BootstrapBloc>();
    _bloc.add(ConfigureApplicationEvent());
  }

  @override
  void dispose() {
    _gearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener(
        bloc: _bloc,
        listener: (context, state) {
          if (state is ConfigurationSuccessState) {
            _bloc.add(CheckAuthEvent());
          }

          if (state is TermsNavigationState) {
            Modular.to.navigate('/terms');
          }

          if (state is LoginNavigationState) {
            Modular.to.navigate('/login');
          }
        },
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height,
          width: MediaQuery.sizeOf(context).width,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _gearController,
                  child: Icon(
                    Icons.settings,
                    size: MediaQuery.sizeOf(context).height * 0.072,
                  ),
                ),
                Text(
                  'Olá! Estamos preparando o app.\nPor favor aguarde',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
