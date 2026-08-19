import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/blocs/bloc/bootstrap_bloc.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late final BootstrapBloc _bloc;

  @override
  void initState() {
    super.initState();

    _bloc = context.read<BootstrapBloc>();
    _bloc.add(ConfigureApplicationEvent());
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

          if (state is ConfigurationSuccessState) {
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
                Icon(
                  Icons.settings,
                  size: MediaQuery.sizeOf(context).height * 0.072,
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
