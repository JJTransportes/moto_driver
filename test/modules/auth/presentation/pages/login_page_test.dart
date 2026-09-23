import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/modules/auth/domain/entities/user_entity.dart';
import 'package:moto_driver/modules/auth/presentation/blocs/login_bloc.dart';
import 'package:moto_driver/modules/auth/presentation/pages/login_page.dart';
import 'package:moto_driver/widgets/app_button.dart';

void main() {
  late MockLoginBloc mockBloc;

  setUp(() {
    mockBloc = MockLoginBloc();
  });

  Widget buildWidget() => MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('Home')),
      '/recovery': (_) => const Scaffold(body: Text('Recovery')),
      '/terms': (_) => const Scaffold(body: Text('Terms')),
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

  // Regra de negócio: o botão "Entrar" fica desabilitado enquanto o
  // formulário não estiver completo (ver _isFormComplete em login_page.dart)
  // — por isso não dá pra "tocar no botão vazio" para revelar as mensagens
  // de campo obrigatório; o teste correto é verificar que o botão continua
  // desabilitado nesses cenários.
  testWidgets('Entrar button stays disabled with empty email', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Entrar button stays disabled with empty password', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'driver@moto.com',
    );
    await tester.pump();

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('adds LoginSubmitted event on form submit', (tester) async {
    when(() => mockBloc.state).thenReturn(const LoginInitial());

    await tester.pumpWidget(buildWidget());

    await tester.enterText(
      find.widgetWithText(TextField, 'Informe seu e-mail'),
      'driver@moto.com',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Informe sua senha'),
      'secret123',
    );
    await tester.pump();
    final entrarButton = find.text('Entrar');
    await tester.ensureVisible(entrarButton);
    await tester.tap(entrarButton);
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

  testWidgets('navigates to terms on success', (tester) async {
    // Simulate Bloc emitting LoginSuccess via the stream — BlocListener
    // reacts to stream emissions, not to the `.state` getter, so setting
    // `.state` and calling the mock's `.add()` (a no-op on a mock) never
    // triggers navigation. `whenListen` (bloc_test) stubs the stream
    // properly, matching the pattern MockBloc expects.
    // LoginPage navigates to /terms (not /home) on success — the terms
    // acceptance flow decides the final destination from there.
    const successUser = UserEntity(
      id: 'u1',
      token: 'tok',
      roles: ['Driver'],
    );
    whenListen(
      mockBloc,
      Stream.fromIterable([LoginSuccess(successUser)]),
      initialState: const LoginInitial(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Terms'), findsOneWidget);
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
