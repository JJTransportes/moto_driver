part of 'bootstrap_bloc.dart';

sealed class BootstrapEvents {}

class ConfigureApplicationEvent extends BootstrapEvents {}

class CheckAuthEvent extends BootstrapEvents {}
