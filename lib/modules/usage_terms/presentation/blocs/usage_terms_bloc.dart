import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/modules/usage_terms/data/datasources/usage_terms_datasource.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_event.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_state.dart';

class UsageTermsBloc extends Bloc<UsageTermsEvent, UsageTermsState> {
  final UsageTermsDatasource _datasource;
  final TermsStorage _storage;

  UsageTermsBloc(this._datasource, this._storage) : super(const UsageTermsInitial()) {
    on<CheckStatus>(_onCheckStatus);
    on<LoadTerms>(_onLoadTerms);
    on<AcceptTerms>(_onAcceptTerms);
    on<DeclineTerms>(_onDeclineTerms);
  }

  Future<void> _onCheckStatus(
    CheckStatus event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsChecking());
    try {
      final status = await _datasource.getAcceptanceStatus();
      if (status.mustAccept) {
        add(const LoadTerms());
      } else {
        emit(const UsageTermsAccepted());
      }
    } catch (_) {
      emit(const UsageTermsError(
        message: 'Erro ao verificar termos. Verifique sua conexão.',
        isRetryable: true,
      ));
    }
  }

  Future<void> _onLoadTerms(
    LoadTerms event,
    Emitter<UsageTermsState> emit,
  ) async {
    emit(const UsageTermsLoading());
    try {
      final terms = await _datasource.getActiveTerms();
      emit(UsageTermsLoaded(terms: terms));
    } catch (_) {
      emit(const UsageTermsError(
        message: 'Erro ao carregar termos. Tente novamente.',
        isRetryable: true,
      ));
    }
  }

  Future<void> _onAcceptTerms(
    AcceptTerms event,
    Emitter<UsageTermsState> emit,
  ) async {
    final current = state;
    if (current is! UsageTermsLoaded && current is! UsageTermsSubmitting) {
      return;
    }

    final terms = current is UsageTermsLoaded
        ? current.terms
        : (current as UsageTermsSubmitting).terms;

    emit(UsageTermsSubmitting(terms: terms));

    try {
      final response = await _datasource.acceptTerms();
      await _storage.saveAcceptedTermId(response.usageTermId);
      emit(const UsageTermsAccepted());
    } catch (_) {
      emit(const UsageTermsError(
        message: 'Erro ao aceitar termos. Tente novamente.',
        isRetryable: true,
      ));
    }
  }

  void _onDeclineTerms(
    DeclineTerms event,
    Emitter<UsageTermsState> emit,
  ) {
    add(const LoadTerms());
  }
}
