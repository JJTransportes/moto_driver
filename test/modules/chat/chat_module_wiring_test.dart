// Fiação do ChatModule (spec pickup-chat-call): o selo de não lidas do card e a
// tela de conversa precisam compartilhar a MESMA ChatSession — senão abrir a
// conversa não zeraria o selo do card.
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moto_driver/modules/chat/chat_module.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_bloc.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';

/// Importa o ChatModule (como o NewTravelModule) e também o expõe como rota
/// (como o AppModule): as duas formas de uso convivem no app.
class _RootModule extends Module {
  @override
  List<Module> get imports => [ChatModule()];

  @override
  void routes(RouteManager r) {
    r.module('/chat', module: ChatModule());
  }
}

void main() {
  setUp(() => Modular.init(_RootModule()));

  tearDown(() {
    try {
      Modular.destroy();
    } catch (_) {}
  });

  test('ChatSession é um singleton compartilhado', () {
    expect(identical(Modular.get<ChatSession>(), Modular.get<ChatSession>()), isTrue);
  });

  test('ChatBloc é novo a cada resolução (estado zerado por conversa)', () {
    final a = Modular.get<ChatBloc>();
    final b = Modular.get<ChatBloc>();

    expect(identical(a, b), isFalse);
    a.close();
    b.close();
  });

  test('o datasource de tempo real é resolvido', () {
    expect(Modular.get<IChatRealtimeDatasource>(), isA<IChatRealtimeDatasource>());
  });
}
