import 'package:moto_driver/modules/usage_terms/domain/entities/usage_term_entity.dart';

abstract class UsageTermsState {
  const UsageTermsState();
}

class UsageTermsInitial extends UsageTermsState {
  const UsageTermsInitial();
}

class UsageTermsChecking extends UsageTermsState {
  const UsageTermsChecking();
}

class UsageTermsAccepted extends UsageTermsState {
  const UsageTermsAccepted();
}

class UsageTermsLoading extends UsageTermsState {
  const UsageTermsLoading();
}

class UsageTermsLoaded extends UsageTermsState {
  final UsageTermEntity terms;

  const UsageTermsLoaded({required this.terms});
}

class UsageTermsSubmitting extends UsageTermsState {
  final UsageTermEntity terms;

  const UsageTermsSubmitting({required this.terms});
}

class UsageTermsError extends UsageTermsState {
  final String message;
  final bool isRetryable;

  const UsageTermsError({
    required this.message,
    this.isRetryable = true,
  });
}
