import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_driver/modules/chat/data/datasources/chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_realtime_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/phone_dialer.dart';
import 'package:moto_driver/modules/chat/data/repositories/chat_repository.dart';
import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/usecases/get_passenger_phone_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_get_passenger_phone_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_load_chat_history_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_mark_chat_read_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/i_send_chat_message_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/load_chat_history_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/send_chat_message_usecase.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_bloc.dart';
import 'package:moto_driver/modules/chat/presentation/blocs/chat_event.dart';
import 'package:moto_driver/modules/chat/presentation/pages/chat_page.dart';
import 'package:moto_driver/modules/chat/presentation/session/chat_session.dart';
import 'package:moto_driver/core/common_module.dart';

/// Chat temporário da viagem (spec pickup-chat-call). Os binds ficam disponíveis
/// para quem importa este módulo (o acompanhamento da viagem usa o [ChatSession]).
class ChatModule extends Module {
  @override
  List<Module> get imports => [CommonModule()];

  @override
  void binds(Injector i) {
    i.add<IChatDatasource>(ChatDatasource.new);
    i.add<IChatRealtimeDatasource>(ChatRealtimeDatasource.new);
    i.add<IChatRepository>(ChatRepository.new);
    i.add<ISendChatMessageUsecase>(SendChatMessageUsecase.new);
    i.add<ILoadChatHistoryUsecase>(LoadChatHistoryUsecase.new);
    i.add<IMarkChatReadUsecase>(MarkChatReadUsecase.new);
    i.add<IGetPassengerPhoneUsecase>(GetPassengerPhoneUsecase.new);
    i.add<IPhoneDialer>(PhoneDialer.new);
    // Uma sessão para o app: o selo do card e a tela de conversa compartilham.
    i.addSingleton<ChatSession>(ChatSession.new);
    // Estado novo a cada conversa.
    i.add<ChatBloc>(ChatBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) {
        final args = Modular.args.data as Map;
        final travelId = args['travelId'] as String;
        final title = args['title'] as String? ?? 'Chat';
        return BlocProvider<ChatBloc>(
          create: (_) => Modular.get<ChatBloc>()..add(ChatStarted(travelId)),
          child: ChatPage(
            travelId: travelId,
            title: title,
            session: Modular.get<ChatSession>(),
          ),
        );
      },
    );
  }
}
