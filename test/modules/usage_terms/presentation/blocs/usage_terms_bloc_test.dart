import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/auth/terms_storage.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/usage_terms/data/datasources/usage_terms_datasource.dart';
import 'package:moto_driver/modules/usage_terms/domain/entities/usage_term_entity.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_bloc.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_event.dart';
import 'package:moto_driver/modules/usage_terms/presentation/blocs/usage_terms_state.dart';

class MockUsageTermsDatasource extends Mock implements UsageTermsDatasource {}

class MockTermsStorage extends Mock implements TermsStorage {}

class MockSignOutService extends Mock implements SignOutService {}

void main() {
  late MockUsageTermsDatasource datasource;
  late MockTermsStorage termsStorage;
  late MockSignOutService signOutService;

  UsageTermsBloc build() =>
      UsageTermsBloc(datasource, termsStorage, signOutService);

  setUp(() {
    datasource = MockUsageTermsDatasource();
    termsStorage = MockTermsStorage();
    signOutService = MockSignOutService();
    when(() => signOutService.signOut()).thenAnswer((_) async {});
  });

  const naoPrecisaAceitar = AcceptanceStatusEntity(
    activeUsageTermId: 'term_1',
    accepted: true,
  );

  group('CheckStatus', () {
    blocTest<UsageTermsBloc, UsageTermsState>(
      'emite Accepted quando não há termo pendente',
      build: () {
        when(() => datasource.getAcceptanceStatus())
            .thenAnswer((_) async => naoPrecisaAceitar);
        return build();
      },
      act: (bloc) => bloc.add(const CheckStatus()),
      expect: () => [isA<UsageTermsChecking>(), isA<UsageTermsAccepted>()],
    );

    // R3: antes, um 401 virava "Verifique sua conexão" com retry infinito.
    blocTest<UsageTermsBloc, UsageTermsState>(
      'em 401, encerra a sessão em vez de emitir erro com retry',
      build: () {
        when(() => datasource.getAcceptanceStatus())
            .thenThrow(const UnauthorizedException());
        return build();
      },
      act: (bloc) => bloc.add(const CheckStatus()),
      expect: () => [isA<UsageTermsChecking>()],
      verify: (_) => verify(() => signOutService.signOut()).called(1),
    );

    blocTest<UsageTermsBloc, UsageTermsState>(
      'em erro de servidor, emite mensagem própria e permite retry',
      build: () {
        when(() => datasource.getAcceptanceStatus())
            .thenThrow(const ServerException());
        return build();
      },
      act: (bloc) => bloc.add(const CheckStatus()),
      expect: () => [
        isA<UsageTermsChecking>(),
        isA<UsageTermsError>()
            .having((e) => e.message, 'message', contains('servidor'))
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ],
      verify: (_) => verifyNever(() => signOutService.signOut()),
    );

    blocTest<UsageTermsBloc, UsageTermsState>(
      'em erro de rede, mantém a mensagem de conexão',
      build: () {
        when(() => datasource.getAcceptanceStatus())
            .thenThrow(const NetworkException());
        return build();
      },
      act: (bloc) => bloc.add(const CheckStatus()),
      expect: () => [
        isA<UsageTermsChecking>(),
        isA<UsageTermsError>()
            .having((e) => e.message, 'message', contains('conexão'))
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ],
      verify: (_) => verifyNever(() => signOutService.signOut()),
    );
  });

  group('LoadTerms', () {
    blocTest<UsageTermsBloc, UsageTermsState>(
      'em 401, encerra a sessão',
      build: () {
        when(() => datasource.getActiveTerms())
            .thenThrow(const UnauthorizedException());
        return build();
      },
      act: (bloc) => bloc.add(const LoadTerms()),
      expect: () => [isA<UsageTermsLoading>()],
      verify: (_) => verify(() => signOutService.signOut()).called(1),
    );
  });

  group('AcceptTerms', () {
    const terms = UsageTermEntity(
      usageTermId: 'term_1',
      title: 'Termos',
      subTerms: [],
    );

    blocTest<UsageTermsBloc, UsageTermsState>(
      'em 401, encerra a sessão',
      build: () {
        when(() => datasource.acceptTerms())
            .thenThrow(const UnauthorizedException());
        return build();
      },
      seed: () => const UsageTermsLoaded(terms: terms),
      act: (bloc) => bloc.add(const AcceptTerms()),
      expect: () => [isA<UsageTermsSubmitting>()],
      verify: (_) => verify(() => signOutService.signOut()).called(1),
    );
  });
}
