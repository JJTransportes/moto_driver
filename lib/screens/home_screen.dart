import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_driver/core/auth/auth_storage.dart';
import 'package:moto_driver/core/auth/sign_out_service.dart';
import 'package:moto_driver/core/config/app_config.dart';
import 'package:moto_driver/core/local_db/repositories/travel_local_repository.dart';
import 'package:moto_driver/core/network/signalr_service.dart';
import 'package:moto_driver/core/notifications/notification_service.dart';
import 'package:moto_driver/design_system/design_system.dart';
import 'package:moto_driver/modules/driver_availability/data/datasources/availability_datasource.dart';
import 'package:moto_driver/modules/driver_availability/domain/entities/driver_availability_entity.dart';
import 'package:moto_driver/modules/driver_availability/presentation/widgets/availability_sheet.dart';
import 'package:moto_driver/modules/driver_home/presentation/widgets/incoming_order_sheet.dart';
import 'package:moto_driver/widgets/profile_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderCancelledSub;
  StreamSubscription? _reconnectingSub;
  StreamSubscription? _reconnectedSub;
  StreamSubscription? _closedSub;
  StreamSubscription? _travelCancelledSub;
  StreamSubscription? _travelStartedSub;
  StreamSubscription? _travelCompletedSub;
  bool _isReconnecting = false;
  bool _reconnectLoopActive = false;
  bool _signalRListenersRegistered = false;
  bool _checkingActiveTravel = false;
  String? _currentTravelStatus;
  String? _currentTravelId;
  String? _currentPassengerName;
  Timer? _locationTimer;
  Timer? _activeTravelPollTimer;
  Position? _lastReportedPosition;
  DateTime? _lastLocationReportAt;
  bool _locationReportInFlight = false;
  bool _isAppActive = true;
  String? _userId;
  String? _userPhotoUrl;
  String? _userName;

  final Set<String> _deniedOrderIds = {};

  // ── Disponibilidade (modo de atendimento) ──
  DriverAvailabilityEntity? _availability;
  Timer? _availabilityTimer;
  bool _isTogglingAvailability = false;

  static const _locationReportInterval = Duration(seconds: 30);
  static const _locationHeartbeatInterval = Duration(minutes: 5);
  static const _minimumDisplacementMeters = 20.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isReconnecting)
                Container(
                  color: context.moto.warning,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.moto.textOnAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reconectando...',
                        style: TextStyle(color: context.moto.textOnAccent),
                      ),
                    ],
                  ),
                ),
              ProfileHeader(
                fullName: _userName ?? 'Motorista',
                photoUrl: _userPhotoUrl,
                userId: _userId ?? '',
                onSignOut: _handleSignOut,
                onSettingsTap: () async {
                  await Modular.to.pushNamed(
                    '/profile-configuration',
                    arguments: {'userId': _userId},
                  );
                  _loadUserId();
                },
              ),
              const SizedBox(height: MotoSpace.s5),
              _buildAvailabilityCard(),
              const SizedBox(height: MotoSpace.s4),
              if (_currentTravelId != null)
                _buildActiveTravelCard()
              else
                MotoGlass(
                  painted: true,
                  padding: const EdgeInsets.all(MotoSpace.s5),
                  child: Center(
                    child: Text(
                      'Aguardando novas viagens...',
                      style: TextStyle(
                        color: context.moto.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: MotoSpace.s4),
              MotoGlass(
                painted: true,
                child: InkWell(
                  borderRadius: MotoRadius.brLg,
                  onTap: () => Modular.to.pushNamed('/travel-history'),
                  child: Padding(
                    padding: const EdgeInsets.all(MotoSpace.s4),
                    child: Row(
                      children: [
                        const MotoTile(icon: Icons.history),
                        const SizedBox(width: MotoSpace.s3),
                        Expanded(
                          child: Text(
                            'Histórico de viagens',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.moto.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    final isActive = _availability?.isActive ?? false;

    return MotoSapphire(
      // Builder: precisamos do BuildContext DE DENTRO do MotoSapphire (que
      // troca o Theme ambiente para a paleta safira/escura) — usar o
      // `context` do método externo pegava o Theme.of() de fora (claro),
      // deixando o texto escuro em cima do card azul-marinho.
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MotoStatusBadge(
                  label: isActive ? 'Recebendo corridas' : 'Modo indisponível',
                  tone: isActive ? MotoTone.success : MotoTone.neutral,
                  live: isActive,
                ),
                const Spacer(),
                Switch(
                  value: isActive,
                  onChanged: _isTogglingAvailability
                      ? null
                      : _onAvailabilityToggled,
                ),
              ],
            ),
            const SizedBox(height: MotoSpace.s4),
            Text(
              isActive ? 'Você está\nonline' : 'Você está\noffline',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTravelCard() {
    final isInProgress = _currentTravelStatus == 'InProgress';
    final tripStatus = isInProgress
        ? TripStatus.emAndamento
        : TripStatus.aceita;

    return GestureDetector(
      onTap: _openActiveTravel,
      child: MotoGlass(
        painted: true,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MotoTile(
                  icon: Icons.directions_car,
                  accent: true,
                  size: 40,
                ),
                const SizedBox(width: MotoSpace.s3),
                Expanded(
                  child: Text(
                    'Viagem ativa',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                MotoStatusBadge.trip(tripStatus),
              ],
            ),
            const SizedBox(height: MotoSpace.s4),
            if (_currentPassengerName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: MotoSpace.s2),
                child: Row(
                  children: [
                    Icon(Icons.person, color: context.moto.accent, size: 20),
                    const SizedBox(width: MotoSpace.s2),
                    Text(
                      _currentPassengerName!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: MotoSpace.s3),
            MotoButton(
              label: 'Abrir viagem',
              large: false,
              onPressed: _openActiveTravel,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _availabilityTimer?.cancel();
    _activeTravelPollTimer?.cancel();
    _newOrderSub?.cancel();
    _orderCancelledSub?.cancel();
    _travelCancelledSub?.cancel();
    _travelStartedSub?.cancel();
    _travelCompletedSub?.cancel();
    _reconnectingSub?.cancel();
    _reconnectedSub?.cancel();
    _closedSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserId();
    _checkActiveTravelHttp();
    _connectSignalR();

    _checkAvailability();

    // Rede de segurança: re-consulta o estado canônico periodicamente,
    // cobrindo eventos SignalR perdidos (não há replay para o motorista).
    _startActiveTravelPolling();

    // F04 (auditoria de escalabilidade): existia um terceiro canal aqui,
    // `POST /api/positions/drivers/{userId}` via HTTP a cada 10s, rodando em
    // paralelo ao `reportLocation` via SignalR abaixo — redundante (mesma
    // informação, dois transportes, ao mesmo tempo, para o mesmo motorista).
    // Removido; o SignalR já é o transporte usado para tudo mais no app.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;

    if (!_isAppActive) {
      // SignalR permanece conectado para não alterar recebimento de ofertas.
      // Apenas leituras periódicas de GPS/HTTP e o repaint do contador param.
      _locationTimer?.cancel();
      _activeTravelPollTimer?.cancel();
      _availabilityTimer?.cancel();
      return;
    }

    // Ao voltar de background, re-consulta a viagem ativa para refletir
    // mudanças de status ocorridas enquanto o app não estava visível.
    _checkActiveTravelHttp();
    _checkAvailability();
    _startActiveTravelPolling();
    _reconnectSignalRIfNeeded();
  }

  void _startActiveTravelPolling() {
    _activeTravelPollTimer?.cancel();
    if (!_isAppActive) return;
    _activeTravelPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkActiveTravelHttp(),
    );
  }

  /// O SO pode ter suspendido a conexão de rede com o app em background sem
  /// avisar; o retry automático do SignalR pode já ter desistido (backoff
  /// esgotado) nesse meio-tempo. Em vez de esperar o próximo ciclo de retry
  /// (ou nenhum, se já desistiu), força uma reconexão na hora que o app volta
  /// ao primeiro plano.
  Future<void> _reconnectSignalRIfNeeded() async {
    final signalR = Modular.get<SignalRService>();
    if (signalR.isConnected('travel-orders') &&
        signalR.isConnected('travel-management')) {
      return;
    }
    await _connectSignalR();
  }

  Future<void> _loadUserId() async {
    final authStorage = Modular.get<AuthStorage>();
    final userId = await authStorage.getUserId();
    setState(() => _userId = userId);
    if (userId != null) {
      await _loadUserName(userId);
    }
  }

  Future<void> _loadUserName(String userId) async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get(
        '${AppConfig.getBaseUrl()}/api/drivers/me',
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        final name = response.data['name'] as String?;
        var photoUrl = response.data['photoUrl'] as String?;
        if (photoUrl != null &&
            photoUrl.isNotEmpty &&
            !photoUrl.startsWith('http://') &&
            !photoUrl.startsWith('https://')) {
          photoUrl = '${AppConfig.getBaseUrl()}$photoUrl';
        }
        setState(() {
          if (name != null && name.isNotEmpty) _userName = name;
          _userPhotoUrl = photoUrl;
        });
      }
    } catch (_) {
      // Silently fallback — name stays null, ProfileHeader handles gracefully
    }
  }

  Future<void> _checkActiveTravelHttp() async {
    if (_checkingActiveTravel) return;
    _checkingActiveTravel = true;
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get(
        '${AppConfig.getBaseUrl()}/api/travels/active',
      );
      if (!mounted) return;

      // Contrato do endpoint GET /api/travels/active:
      // 200 com objeto {travelId, status, passengerName, ...} = viagem ativa;
      // 204 No Content = sem viagem ativa.
      // Viagens só nascem em Accepted/InProgress (o enum Pending é vestigial),
      // então a existência da resposta já garante o estado — sem filtro de status.
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['travelId'] != null) {
          setState(() {
            _currentTravelId = data['travelId'] as String;
            _currentTravelStatus = data['status'] as String?;
            _currentPassengerName = data['passengerName'] as String?;
          });
          return;
        }
      }
      // 204 (ou resposta sem travelId) = sem viagem ativa — limpa estado
      setState(() {
        _currentTravelId = null;
        _currentTravelStatus = null;
        _currentPassengerName = null;
      });
    } catch (_) {
      // Falha de rede/erro de servidor — fallback silencioso para cache local
      await _loadActiveTravelFromLocal();
    } finally {
      _checkingActiveTravel = false;
    }
  }

  Future<void> _loadActiveTravelFromLocal() async {
    final travelRepo = Modular.get<TravelLocalRepository>();
    final active = await travelRepo.getActiveTravel();
    if (active != null && mounted) {
      setState(() {
        _currentTravelId = active.travelId;
        _currentTravelStatus = active.status;
        _currentPassengerName = active.passengerName;
      });
    }
  }

  /// Abre a página da viagem ativa e, ao voltar, re-consulta o estado canônico
  /// para que mudanças de status feitas na página reflitam na home na hora.
  Future<void> _openActiveTravel() async {
    await Modular.to.pushNamed(
      '/active-travel',
      arguments: {'travelId': _currentTravelId},
    );
    if (mounted) _checkActiveTravelHttp();
  }

  Future<void> _connectSignalR() async {
    final signalR = Modular.get<SignalRService>();
    final authStorage = Modular.get<AuthStorage>();
    final token = await authStorage.getToken();
    if (token == null) return;

    if (_signalRListenersRegistered) {
      await _connectHubs(signalR, token);
      return;
    }
    _signalRListenersRegistered = true;

    _newOrderSub = signalR.onNewOrder.listen((data) async {
      print(
        '[DIAG] NewOrder event received: $data, orderAlertOpen=${NotificationService.orderAlertOpen}, sheetVisible=${NotificationService.sheetVisible}, currentTravelId=$_currentTravelId',
      );
      if (NotificationService.orderAlertOpen) return;
      // Reenvio do mesmo evento NewOrder (reconexão do hub, retry do
      // backend) enquanto o sheet do pedido atual ainda está na tela —
      // sem essa checagem, abria um segundo sheet por cima do primeiro.
      if (NotificationService.sheetVisible) return;
      if (_currentTravelId != null) return;

      // `_currentTravelId` só é atualizado por fluxos que passam pela home —
      // um aceite via notificação push (OrderAlertPage → /active-travel)
      // nunca toca essa variável, então sob nenhuma hipótese basta confiar
      // só nela: confere a fonte persistida antes de exibir qualquer oferta.
      final travelRepo = Modular.get<TravelLocalRepository>();
      final active = await travelRepo.getActiveTravel();
      print('[DIAG] NewOrder: active local travel=$active, mounted=$mounted');
      if (active != null || !mounted) return;

      final orderId = data['orderId'] as String?;
      if (orderId == null) return;

      // If this order was already denied, ignore the re-send
      if (_deniedOrderIds.contains(orderId)) return;

      // A new (non-denied) order signals a fresh dispatch round — clear old denials
      if (_deniedOrderIds.isNotEmpty) {
        _deniedOrderIds.clear();
      }

      IncomingOrderSheet.show(
        context,
        data,
        onDenied: () {
          _deniedOrderIds.add(orderId);
          NotificationService.setSheetVisible(false);
        },
      );

      // RF05: Marcar sheet como visível para suprimir foreground dup
      NotificationService.setSheetVisible(true);
    });

    // Listen for travel cancellations
    _travelCancelledSub = signalR.onTravelCancelled.listen((data) {
      if (!mounted) return;
      final travelId = data['travelId'] as String?;
      if (travelId != null && travelId == _currentTravelId) {
        setState(() {
          _currentTravelId = null;
          _currentTravelStatus = null;
          _currentPassengerName = null;
        });
        Modular.get<TravelLocalRepository>().clearTravels();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viagem cancelada'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _checkActiveTravelHttp();
      }
    });

    // Accepted → InProgress: o card passa a "Em andamento" imediatamente e o
    // estado canônico é re-consultado (payload só traz travelId/startedAt).
    // Se a home ainda não conhece a viagem (aceite via /order-alert), adota.
    _travelStartedSub = signalR.onTravelStarted.listen((data) {
      if (!mounted) return;
      final travelId = data['travelId'] as String?;
      if (travelId == null) return;
      if (travelId == _currentTravelId || _currentTravelId == null) {
        setState(() {
          _currentTravelId = travelId;
          _currentTravelStatus = 'InProgress';
        });
        _checkActiveTravelHttp();
      }
    });

    // InProgress → Completed: encerra a viagem ativa na home (limpa card,
    // cache local e informa o motorista).
    _travelCompletedSub = signalR.onTravelCompleted.listen((data) {
      if (!mounted) return;
      final travelId = data['travelId'] as String?;
      if (travelId != null && travelId == _currentTravelId) {
        setState(() {
          _currentTravelId = null;
          _currentTravelStatus = null;
          _currentPassengerName = null;
        });
        Modular.get<TravelLocalRepository>().clearTravels();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viagem concluída'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _checkActiveTravelHttp();
      }
    });

    _reconnectingSub = signalR.onReconnecting.listen((_) {
      setState(() => _isReconnecting = true);
    });

    _reconnectedSub = signalR.onReconnected.listen((_) {
      setState(() => _isReconnecting = false);
      // Sem replay de eventos para o motorista: ao reconectar, re-consulta
      // o estado canônico para refletir transições perdidas.
      _checkActiveTravelHttp();
    });

    // Dispara quando o backoff automático se esgota e a conexão cai de vez
    // (não é mais um "onReconnecting" — o client desistiu). Sem este
    // listener a badge "Reconectando" ficava travada indefinidamente, já
    // que nada tirava _isReconnecting de true nesse caso.
    _closedSub = signalR.onClosed.listen((_) {
      if (!mounted) return;
      setState(() => _isReconnecting = true);
      _reconnectSignalRWithRetry();
    });

    _orderCancelledSub = signalR.onOrderCancelled.listen((data) {
      if (!mounted) return;
      // Página de pedido aberta: quem trata o cancelamento é a própria página
      // (RF10) — o popUntil abaixo arrancaria a /order-alert da pilha.
      if (NotificationService.orderAlertOpen) return;
      // Dismiss any open bottom sheet and notify the driver
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido cancelado pelo passageiro.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    // ── Now connect to hubs (listeners are already registered) ──
    await _connectHubs(signalR, token);
  }

  /// Reconecta após um onClosed, com retry em loop até dar certo.
  ///
  /// `connect()` pode falhar (ex.: handshake do protocolo SignalR cancelado
  /// por uma race entre stop()/start(), hiccup de rede) — sem tratamento,
  /// essa exceção subia sem catch pelo listener do stream ("Unhandled
  /// Exception") e nenhuma nova tentativa era agendada, travando a badge
  /// "Reconectando" pra sempre. Também garante que _isReconnecting volte a
  /// false no sucesso: onReconnected só dispara para o auto-reconnect
  /// interno do client, não para esse reconnect manual pós-close.
  Future<void> _reconnectSignalRWithRetry() async {
    if (_reconnectLoopActive) return;
    _reconnectLoopActive = true;
    try {
      const retryDelay = Duration(seconds: 3);
      while (mounted) {
        try {
          await _connectSignalR();
          if (mounted) setState(() => _isReconnecting = false);
          return;
        } catch (e) {
          developer.log(
            'Falha ao reconectar SignalR, tentando novamente',
            error: e,
          );
          await Future.delayed(retryDelay);
        }
      }
    } finally {
      _reconnectLoopActive = false;
    }
  }

  /// Conecta (ou reconecta) apenas os hubs, sem re-registrar os listeners —
  /// esses são inscritos uma única vez nos streams persistentes do
  /// [SignalRService]. Usado tanto no primeiro connect quanto na reconexão
  /// forçada (resume do app / onClosed).
  Future<void> _connectHubs(SignalRService signalR, String token) async {
    await signalR.connect(
      'travel-orders',
      '${AppConfig.getBaseUrl()}/hubs/travel-orders',
      token,
    );

    try {
      await signalR.connect(
        'travel-management',
        '${AppConfig.getBaseUrl()}/hubs/travel-management',
        token,
      );
    } catch (_) {
      // Non-critical — cancels won't arrive in real-time without this hub
    }

    _startLocationReporting(signalR);
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    _stopAvailabilityTimer();
    await Modular.get<SignalRService>().disconnectAll();
    await Modular.get<TravelLocalRepository>().clearTravels();
    await Modular.get<SignOutService>().signOut();
  }

  // ── Disponibilidade (modo de atendimento) ──

  /// Verifica o status de disponibilidade ao entrar no app.
  /// Fire-and-forget — não bloqueia SignalR nem viagem ativa.
  Future<void> _checkAvailability() async {
    try {
      final datasource = Modular.get<AvailabilityDatasource>();
      final availability = await datasource.getAvailability();
      if (!mounted) return;

      setState(() => _availability = availability);

      if (availability.isActive) {
        _startAvailabilityTimer();
      } else if (!AvailabilitySheet.isOpen) {
        final result = await AvailabilitySheet.show(
          context,
          datasource: datasource,
        );
        if (!mounted || result == null) return; // cancelou — permanece inactive
        setState(() => _availability = result);
        _startAvailabilityTimer();
      }
    } catch (e) {
      // RF06: falha silenciosa — re-tenta na próxima entrada do app
      developer.log('[AVAILABILITY] GET failed: $e', name: 'availability');
    }
  }

  void _startAvailabilityTimer() {
    _stopAvailabilityTimer();
    final availability = _availability;
    if (availability == null || !availability.isActive) return;

    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {}); // recalcula a contagem regressiva
      if (availability.isExpired) {
        _stopAvailabilityTimer(); // indicador passa a exibir ramo inativo
      }
    });
  }

  void _stopAvailabilityTimer() {
    _availabilityTimer?.cancel();
    _availabilityTimer = null;
  }

  Future<void> _onAvailabilityToggled(bool value) async {
    final datasource = Modular.get<AvailabilityDatasource>();
    setState(() => _isTogglingAvailability = true);

    try {
      if (value) {
        // Ativar passa pelo sheet de confirmação (RF02/03/04) — mesma janela
        // de 4h já usada em outros pontos de entrada, não pula essa etapa.
        final result = await AvailabilitySheet.show(
          context,
          datasource: datasource,
        );
        if (!mounted || result == null) return; // cancelou no sheet
        setState(() => _availability = result);
        _startAvailabilityTimer();
      } else {
        final result = await datasource.deactivate();
        if (!mounted) return;
        setState(() => _availability = result);
        _stopAvailabilityTimer();
      }
    } catch (e) {
      developer.log('[AVAILABILITY] toggle failed: $e', name: 'availability');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar sua disponibilidade.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  void _startLocationReporting(SignalRService signalR) {
    _locationTimer?.cancel();
    if (!_isAppActive) return;

    _reportIdleLocation(signalR, force: true);
    _locationTimer = Timer.periodic(
      _locationReportInterval,
      (_) => _reportIdleLocation(signalR),
    );
  }

  Future<void> _reportIdleLocation(
    SignalRService signalR, {
    bool force = false,
  }) async {
    if (!_isAppActive ||
        _currentTravelStatus == 'InProgress' ||
        _locationReportInFlight) {
      return;
    }
    _locationReportInFlight = true;
    try {
      // F04: enquanto a viagem está InProgress, o ActiveTravelPage já
      // reporta a posição via SignalR a cada 10s (canal mais frequente e
      // mais relevante nesse momento) — pausar este canal da Home evita
      // dois canais de localização simultâneos, ao mesmo tempo, para o
      // mesmo motorista. Retoma sozinho no próximo tick assim que a
      // viagem deixar de ser InProgress (_currentTravelStatus muda em
      // várias listeners de SignalR/HTTP já existentes acima).
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!_isAppActive || _currentTravelStatus == 'InProgress') return;

      final previous = _lastReportedPosition;
      final lastReportAt = _lastLocationReportAt;
      final heartbeatDue =
          lastReportAt == null ||
          DateTime.now().difference(lastReportAt) >= _locationHeartbeatInterval;
      final movedEnough =
          previous == null ||
          Geolocator.distanceBetween(
                previous.latitude,
                previous.longitude,
                position.latitude,
                position.longitude,
              ) >=
              _minimumDisplacementMeters;

      if (!force && !heartbeatDue && !movedEnough) return;

      await signalR.reportLocation(position.latitude, position.longitude);
      _lastReportedPosition = position;
      _lastLocationReportAt = DateTime.now();
    } catch (_) {
      // Silently skip on error
    } finally {
      _locationReportInFlight = false;
    }
  }
}
