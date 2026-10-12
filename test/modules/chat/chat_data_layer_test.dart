// Camada de dados do chat (spec pickup-chat-call): datasource (Dio → exceções
// tipadas), repositório (exceção → Failure, JSON → entidade), casos de uso.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moto_driver/core/errors/exceptions.dart';
import 'package:moto_driver/modules/chat/data/datasources/chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/datasources/i_chat_datasource.dart';
import 'package:moto_driver/modules/chat/data/repositories/chat_repository.dart';
import 'package:moto_driver/modules/chat/data/repositories/i_chat_repository.dart';
import 'package:moto_driver/modules/chat/domain/client_message_id.dart';
import 'package:moto_driver/modules/chat/domain/entities/chat_entities.dart';
import 'package:moto_driver/modules/chat/domain/usecases/load_chat_history_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/mark_chat_read_usecase.dart';
import 'package:moto_driver/modules/chat/domain/usecases/send_chat_message_usecase.dart';
import 'package:result_dart/result_dart.dart';

class MockDio extends Mock implements Dio {}

class MockChatDatasource extends Mock implements IChatDatasource {}

class MockChatRepository extends Mock implements IChatRepository {}

DioException _dioError(int status, {Object? body}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
      type: DioExceptionType.badResponse,
    );

const _params = SendChatMessageParams(
  travelId: 'travel-1',
  text: 'oi',
  clientMessageId: 'client-1',
);

void main() {
  group('ChatDatasource', () {
    late MockDio dio;
    late ChatDatasource datasource;

    setUp(() {
      dio = MockDio();
      datasource = ChatDatasource(dio);
    });

    test('sendMessage faz POST com texto e clientMessageId', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
          data: {'messageId': 'm1'},
        ),
      );

      final json = await datasource.sendMessage('travel-1', 'oi', 'client-1');

      expect(json['messageId'], 'm1');
      verify(
        () => dio.post(
          '/api/travels/travel-1/chat/messages',
          data: {'text': 'oi', 'clientMessageId': 'client-1'},
        ),
      ).called(1);
    });

    test('getHistory faz GET do histórico', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'messages': [], 'unreadCount': 0},
        ),
      );

      final json = await datasource.getHistory('travel-1');

      expect(json['unreadCount'], 0);
      verify(() => dio.get('/api/travels/travel-1/chat/messages')).called(1);
    });

    test('markRead faz POST de leitura', () async {
      when(() => dio.post(any())).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 204),
      );

      await datasource.markRead('travel-1');

      verify(() => dio.post('/api/travels/travel-1/chat/read')).called(1);
    });

    final cases = <int, Matcher>{
      400: isA<ValidationException>(),
      403: isA<ForbiddenException>(),
      404: isA<NotFoundException>(),
      409: isA<ConflictException>(),
      429: isA<RateLimitedException>(),
      503: isA<ServerException>(),
      401: isA<UnauthorizedException>(),
    };

    cases.forEach((status, matcher) {
      test('HTTP $status vira a exceção tipada correspondente', () async {
        when(() => dio.post(any(), data: any(named: 'data')))
            .thenThrow(_dioError(status));

        await expectLater(
          () => datasource.sendMessage('travel-1', 'oi', 'client-1'),
          throwsA(matcher),
        );
      });
    });

    test('repassa a mensagem em português do backend', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        _dioError(429, body: {'error': 'Você está enviando mensagens rápido demais.'}),
      );

      await expectLater(
        () => datasource.sendMessage('travel-1', 'oi', 'client-1'),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.message,
            'message',
            'Você está enviando mensagens rápido demais.',
          ),
        ),
      );
    });

    test('erro de conexão vira NetworkException', () async {
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => datasource.getHistory('travel-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('ChatRepository', () {
    late MockChatDatasource datasource;
    late ChatRepository repository;

    setUp(() {
      datasource = MockChatDatasource();
      repository = ChatRepository(datasource);
    });

    test('sendMessage converte o JSON em entidade', () async {
      when(() => datasource.sendMessage(any(), any(), any())).thenAnswer(
        (_) async => {
          'messageId': 'm1',
          'travelId': 'travel-1',
          'senderRole': 'Driver',
          'text': 'oi',
          'sentAt': '2026-10-02T15:00:00Z',
          'mine': true,
        },
      );

      final result = await repository.sendMessage(_params);

      final message = result.getOrNull()!;
      expect(message.id, 'm1');
      expect(message.text, 'oi');
      expect(message.mine, isTrue);
    });

    test('sendMessage devolve Failure quando o datasource lança', () async {
      when(() => datasource.sendMessage(any(), any(), any()))
          .thenThrow(const ConflictException('chat indisponível'));

      final result = await repository.sendMessage(_params);

      expect(result.isError(), isTrue);
      expect(result.exceptionOrNull(), isA<ConflictException>());
    });

    test('loadHistory converte mensagens e contagem de não lidas', () async {
      when(() => datasource.getHistory(any())).thenAnswer(
        (_) async => {
          'unreadCount': 2,
          'messages': [
            {'messageId': 'm1', 'travelId': 't', 'senderRole': 'Driver', 'text': 'a', 'sentAt': '2026-10-02T15:00:00Z', 'mine': false},
            {'messageId': 'm2', 'travelId': 't', 'senderRole': 'Passenger', 'text': 'b', 'sentAt': '2026-10-02T15:01:00Z', 'mine': true},
          ],
        },
      );

      final history = (await repository.loadHistory('t')).getOrNull()!;

      expect(history.unreadCount, 2);
      expect(history.messages.map((m) => m.text), ['a', 'b']);
      expect(history.messages.map((m) => m.mine), [false, true]);
    });

    test('loadHistory devolve Failure quando o datasource lança', () async {
      when(() => datasource.getHistory(any())).thenThrow(const NetworkException());

      expect((await repository.loadHistory('t')).isError(), isTrue);
    });

    test('markRead devolve Success e Failure', () async {
      when(() => datasource.markRead('ok')).thenAnswer((_) async {});
      when(() => datasource.markRead('ruim')).thenThrow(const ServerException());

      expect((await repository.markRead('ok')).isSuccess(), isTrue);
      expect((await repository.markRead('ruim')).isError(), isTrue);
    });

    test('chatMessageFromJson do evento em tempo real assume mine = false', () {
      final m = chatMessageFromJson({
        'travelId': 't',
        'messageId': 'm1',
        'senderRole': 'Driver',
        'text': 'oi',
        'sentAt': '2026-10-02T15:00:00Z',
      });

      expect(m.mine, isFalse);
    });
  });

  group('Casos de uso delegam ao repositório', () {
    late MockChatRepository repository;

    setUp(() {
      repository = MockChatRepository();
      registerFallbackValue(_params);
    });

    test('SendChatMessageUsecase', () async {
      final message = ChatMessageEntity(
        id: 'm', travelId: 't', senderRole: 'Driver', text: 'x',
        sentAt: DateTime.utc(2026), mine: true,
      );
      when(() => repository.sendMessage(any())).thenAnswer((_) async => Success(message));

      final result = await SendChatMessageUsecase(repository)(_params);

      expect(result.getOrNull(), message);
      verify(() => repository.sendMessage(_params)).called(1);
    });

    test('LoadChatHistoryUsecase', () async {
      const history = ChatHistoryEntity(messages: [], unreadCount: 3);
      when(() => repository.loadHistory('t')).thenAnswer((_) async => const Success(history));

      final result = await LoadChatHistoryUsecase(repository)('t');

      expect(result.getOrNull()!.unreadCount, 3);
    });

    test('MarkChatReadUsecase', () async {
      when(() => repository.markRead('t')).thenAnswer((_) async => const Success(unit));

      final result = await MarkChatReadUsecase(repository)('t');

      expect(result.isSuccess(), isTrue);
      verify(() => repository.markRead('t')).called(1);
    });
  });

  group('generateClientMessageId', () {
    test('gera UUID v4 válido e diferente a cada chamada', () {
      final a = generateClientMessageId();
      final b = generateClientMessageId();

      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(a, matches(uuid));
      expect(b, matches(uuid));
      expect(a, isNot(b));
    });
  });
}
