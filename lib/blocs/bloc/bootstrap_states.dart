part of 'bootstrap_bloc.dart';

sealed class BootstrapStates {}

final class BootstrapInitial extends BootstrapStates {}

final class LoadingConfigurationsState extends BootstrapStates {}

final class AuthCheckLoadingState extends BootstrapStates {}

final class LocalPersistenceConfigurationState extends BootstrapStates {}

final class LocalPersistenceFailureState extends BootstrapStates {
  final String message;

  LocalPersistenceFailureState({required this.message});
}

final class LocationPermissionRequestState extends BootstrapStates {}

final class LocationPermissionRequestFailureState extends BootstrapStates {
  final String message;

  LocationPermissionRequestFailureState({required this.message});
}

final class NotificationServiceConfigurationState extends BootstrapStates {}

final class NotificationServiceFailureState extends BootstrapStates {
  final String message;

  NotificationServiceFailureState({required this.message});
}

final class NotificationsPermissionRequestState extends BootstrapStates {}

final class ConfigurationSuccessState extends BootstrapStates {}

final class TermsNavigationState extends BootstrapStates {}

final class LoginNavigationState extends BootstrapStates {}
