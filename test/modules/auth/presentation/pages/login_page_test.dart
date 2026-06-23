import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/pages/login_page.dart';

void main() {
  late MockLoginBloc mockBloc;

  setUp(() {
    mockBloc = MockLoginBloc();
  });

  Widget buildWidget() => MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('Home')),
      '/recovery': (_) => const Scaffold(body: Text('Recovery')),
    },
    home: BlocProvider<LoginBloc>.value(
      value: mockBloc,
      child: const LoginPage(),
    ),
  );

  testWidgets('shows app title', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('App Motorista'), findsOneWidget);
  });

  testWidgets('shows email and password fields', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
  });

  testWidgets('shows Entrar button', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('shows Esqueci minha senha link', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });

  testWidgets('validates empty email', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('E-mail obrigatório'), findsOneWidget);
  });

  testWidgets('validates empty password', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'driver@moto.com',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Senha obrigatória'), findsOneWidget);
  });

  testWidgets('adds LoginSubmitted event on form submit', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'driver@moto.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Informe sua senha'),
      'secret123',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    verify(
      () => mockBloc.add(
        LoginSubmitted(email: 'driver@moto.com', password: 'secret123'),
      ),
    ).called(1);
  });

  testWidgets('shows loading indicator while loading', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginLoading());

    await tester.pumpWidget(buildWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error message on failure', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginFailure('E-mail ou senha inválidos'));

    await tester.pumpWidget(buildWidget());

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('navigates to home on success', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    // Simulate Bloc emitting LoginSuccess
    const successUser = UserEntity(
      id: 'u1',
      token: 'tok',
      roles: ['Driver'],
    );
    when(() => mockBloc.state).thenReturn(LoginSuccess(successUser));
    mockBloc.add(LoginSubmitted(email: '', password: ''));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('navigates to recovery screen on forgot password tap', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recovery'), findsOneWidget);
  });
}

class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}
