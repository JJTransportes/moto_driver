import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide ReadContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/driver_registration/domain/usecases/i_register_usecase.dart';
import 'package:moto_driver/modules/driver_registration/presentation/blocs/register_bloc.dart';
import 'package:moto_driver/modules/driver_registration/presentation/pages/registration_page.dart';

class MockRegisterUsecase extends Mock implements IRegisterUsecase {}

void main() {
  late MockRegisterUsecase mockUsecase;
  late RegisterBloc registerBloc;

  setUp(() {
    mockUsecase = MockRegisterUsecase();
    registerBloc = RegisterBloc(mockUsecase);
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
    testWidgets('renders all 9 form fields', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Nome completo'), findsOneWidget);
      expect(find.text('CPF'), findsOneWidget);
      expect(find.text('RG'), findsOneWidget);
      expect(find.text('Matrícula'), findsOneWidget);
      expect(find.text('Data de nascimento'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text('Departamento'), findsOneWidget);
      expect(find.text('CNH'), findsOneWidget);
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
