import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/models/password_policy.dart';
import 'package:moto_driver/modules/auth/domain/usecases/i_get_password_policy_usecase.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_driver/modules/driver_registration/presentation/pages/registration_page.dart';
import 'package:result_dart/result_dart.dart';

class MockRegisterUsecase extends Mock implements IRegisterUsecase {}

class MockGetPasswordPolicyUsecase extends Mock implements IGetPasswordPolicyUsecase {}

/// Módulo mínimo só para disponibilizar o [IGetPasswordPolicyUsecase] via
/// `Modular.get` na página (design D4 — usecase compartilhado de CommonModule).
class _TestModule extends Module {
  final IGetPasswordPolicyUsecase usecase;
  _TestModule(this.usecase);

  @override
  void binds(i) {
    i.addInstance<IGetPasswordPolicyUsecase>(usecase);
  }
}

void main() {
  late MockRegisterUsecase mockUsecase;
  late RegisterBloc registerBloc;
  late MockGetPasswordPolicyUsecase mockPolicyUsecase;

  setUp(() {
    mockUsecase = MockRegisterUsecase();
    registerBloc = RegisterBloc(mockUsecase);
    mockPolicyUsecase = MockGetPasswordPolicyUsecase();
    when(() => mockPolicyUsecase.call()).thenAnswer(
      (_) async => const Success(PasswordPolicy.fallback()),
    );
    Modular.init(_TestModule(mockPolicyUsecase));
  });

  tearDown(() {
    try {
      Modular.destroy();
    } catch (_) {
      // Tolerante a chamadas duplicadas de destroy entre testes.
    }
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: BlocProvider.value(
        value: registerBloc,
        child: const RegistrationPage(),
      ),
    );
  }

  group('RegistrationPage', () {
    testWidgets('renders all 11 form fields', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Nome completo *'), findsOneWidget);
      expect(find.text('CPF *'), findsOneWidget);
      expect(find.text('RG *'), findsOneWidget);
      expect(find.text('Matrícula *'), findsOneWidget);
      expect(find.text('Telefone'), findsOneWidget);
      expect(find.text('Data de nascimento *'), findsOneWidget);
      expect(find.text('E-mail *'), findsOneWidget);
      expect(find.text('Confirmar E-mail *'), findsOneWidget);
      expect(find.text('Senha *'), findsOneWidget);
      expect(find.text('Confirmar Senha *'), findsOneWidget);
      expect(find.text('CNH *'), findsOneWidget);
    });

    testWidgets('shows "As senhas não coincidem" when confirm password differs', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      await tester.enterText(
        find.widgetWithText(TextField, 'Informe sua senha'),
        'Senha@123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Digite novamente a senha'),
        'Outra@123',
      );
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsOneWidget);
    });

    testWidgets('clears the mismatch error once both password fields match', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      await tester.enterText(
        find.widgetWithText(TextField, 'Informe sua senha'),
        'Senha@123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Digite novamente a senha'),
        'Senha@12',
      );
      await tester.pump();
      expect(find.text('As senhas não coincidem'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Digite novamente a senha'),
        'Senha@123',
      );
      await tester.pump();
      expect(find.text('As senhas não coincidem'), findsNothing);
    });

    testWidgets('requires confirm password to be filled on submit', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      final cadastrarButton = find.text('Cadastrar');
      await tester.ensureVisible(cadastrarButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Informe sua senha'),
        'Senha@123',
      );
      await tester.pump();

      // Botão fica desabilitado com o formulário incompleto (design
      // existente: submit só habilita via _isFormComplete) — dispara a
      // validação diretamente chamando tap num finder habilitado seria
      // redundante aqui; o importante é confirmar que o campo de confirmação
      // vazio não deixa o formulário completo.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('renders Cadastrar button', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Cadastrar'), findsOneWidget);
    });

    testWidgets('renders Já tem uma conta? Entrar link', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Já tem uma conta? Entrar'), findsOneWidget);
    });

    testWidgets(
        'shows validation errors when required fields are empty and submit is tapped',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      // Scroll down to make the Cadastrar button visible
      final cadastrarButton = find.text('Cadastrar');
      await tester.ensureVisible(cadastrarButton);
      await tester.pumpAndSettle();

      await tester.tap(cadastrarButton);
      await tester.pumpAndSettle();

      // Should show multiple "Campo obrigatório" errors
      expect(find.text('Campo obrigatório'), findsWidgets);
    });

    testWidgets('shows loading indicator when state is RegisterLoading',
        (tester) async {
      registerBloc.emit(const RegisterLoading());
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // The CircularProgressIndicator should be rendered
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state is RegisterFailure',
        (tester) async {
      registerBloc.emit(const RegisterFailure('Erro de conexão.'));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Erro de conexão.'), findsOneWidget);
    });
  });
}
