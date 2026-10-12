# Auditoria Técnica — App Motorista (moto_driver)

**Subagente:** 02/4 — App Motorista (Flutter)
**Repositório:** `C:\JJ-Transportes\moto_driver`
**Branch:** `scalability-review`
**Data:** 2026-09-23
**Escopo:** Auditoria somente-leitura. Nenhum arquivo de código foi alterado.

---

## Áreas analisadas

| Área | Cobertura |
|---|---|
| Arquitetura/módulos (flutter_modular, Clean-ish por módulo) | Completa — `lib/app`, `lib/core`, `lib/modules/*`, `lib/screens`, `lib/blocs`, `lib/widgets` |
| Gerenciamento de estado (flutter_bloc + StatefulWidget/setState) | Completa — todos os blocs de `auth`, `profile_configuration`, `usage_terms`, `user_deletion`, `driver_registration`; telas com `setState`/`Timer` (`home_screen`, `active_travel_page`, `incoming_order_sheet`, `order_alert_page`) |
| Navegação/rotas | Completa — `app_module.dart` (todas as rotas) |
| Storage local (SQLite/sqflite) e secure storage | Completa — `core/local_db/*` (schema, repositórios), `core/auth/auth_storage.dart`, `core/auth/terms_storage.dart` |
| Comunicação com API (Dio: interceptors, erros, timeouts) | Completa — `core/http/dio_client.dart` e todos os datasources |
| Autenticação/token/refresh/expiração | Completa — `auth_storage`, `auth_repository`, `auth_datasource`, `bootstrap_bloc`, `order_refresh_page`, `sign_out_service` |
| Permissões (localização, notificação, câmera) | Completa — `AndroidManifest.xml`, `Info.plist`, `location_service.dart`, `bootstrap_bloc.dart` |
| Localização/GPS | Completa — `location_service.dart`, timers em `home_screen.dart` e `active_travel_page.dart` |
| Mapas (Google Maps, rotas, polylines) | Completa — `active_travel_page.dart`, `incoming_order_sheet.dart`, `directions_service.dart` |
| Push notifications (OneSignal) | Completa — `one_signal_notification_service.dart`, `notification_service.dart`, `inotification_service.dart` |
| Execução em background / ciclo de vida | Completa — manifestos Android/iOS, `WidgetsBindingObserver` em `app_widget.dart` e `home_screen.dart` |
| Fluxo completo de corrida (login → disponibilidade → localização → oferta → aceite/recusa → deslocamento → viagem → conclusão → histórico) | Rastreado ponta a ponta no código real |
| Cenários adversos (rede instável, app morto, GPS off, token expirado, corridas duplicadas, duplo toque, etc.) | Verificados no código, um a um |
| Android vs iOS | Comparados manifestos e capacidades de background |
| Escalabilidade (padrão de envio de localização, polling vs socket) | Analisada em detalhe (achado central do relatório) |
| Dependências (`pubspec.yaml`) | Revisadas por inspeção (sem acesso a base de CVE) |
| Testes existentes vs. lacunas | Levantamento completo de `test/**` comparado a `lib/**` |
| Especificações `.sdd/` (spec-vs-código) | `hotfix-auth-token-deadlock` e `reset-senha-duas-etapas` comparadas ao código atual, a pedido do coordenador |

---

## Confirmação: specs `.sdd/` vs. código real

A pedido do coordenador, as specs em `.sdd/specs/` e os dois documentos soltos foram comparados ao estado atual do código:

- **`hotfix-auth-token-deadlock`** (T1–T5): **totalmente implementada e verificada no código**. `AuthInterceptor` (dio_client.dart:11-30) tem try/catch com `handler.next()` garantido; `AuthStorage.saveToken`/`clear` (auth_storage.dart:19-38) são sequenciais; `SignOutService.signOut` (sign_out_service.dart:40-71) é tolerante a falha e sempre navega para `/login`; `UsageTermsBloc` (usage_terms_bloc.dart) distingue `UnauthorizedException` → `signOut()`, `ServerException` → mensagem própria, resto → mensagem de conexão, exatamente como especificado. T6 (smoke test manual) não pôde ser confirmado (não há evidência de execução no repo).
  - **Porém**: a própria spec já registrava como **fora de escopo** (D1) "`LogInterceptor` vazando senha em release — Crítico, mas independente" e (D11) "refresh automático de token em 401 no interceptor". Ambos **continuam não corrigidos** no código atual — ver F02 e F06 abaixo. A spec também registrava (D9) o mesmo padrão de 401 não tratado no aceite de corrida (`incoming_order_sheet.dart:323`) como pendente de spec própria — **ainda pendente**, ver F06.
- **`reset-senha-duas-etapas`** (Trilha A T1–T9, Trilha B T10–T15): **totalmente implementada e verificada no código**, incluindo a Trilha B (integração ao `registration_page.dart`, confirmada via grep — `IGetPasswordPolicyUsecase`, `isPasswordValid`, `PasswordPolicyChecklist` todos presentes). Contrato de `verify-code`/`confirm`/`password-policy` bate exatamente com `.sdd/contexto-frontend-reset-senha.md`. Nenhuma divergência encontrada.
- **`checklist-email-nao-cadastrado.md`**: implementado corretamente — `auth_datasource.dart` envia `expectedRole: 'Driver'` no `password-reset/request` e mapeia 404/429 conforme o checklist.

Essas duas specs, portanto, **não geram achados novos** — ficam registradas aqui como evidência de que o processo SDD foi seguido corretamente nesses dois casos, em contraste com os débitos técnicos (D1, D9, D11) que a própria equipe já havia identificado e permanecem em aberto.

---

## Investigação do bug relatado: "endereço do motorista não está retornando"

**Causa raiz identificada no app do motorista:** o modelo de perfil do app **não tem nenhum campo de endereço**.

- `ProfileEntity` (`lib/modules/profile_configuration/domain/entities/profile_entity.dart:1-31`) só tem `id, name, email, phone, photoUrl`.
- `ProfileModel.fromJson` (`lib/modules/profile_configuration/data/models/profile_model.dart:24-32`) só lê `id, name, email, phone, photoUrl` do JSON — qualquer campo `address`/`endereco` que o backend retorne em `GET /api/drivers/{userId}` é **silenciosamente descartado** (Dart não falha ao ignorar chaves não mapeadas).
- `ProfileForm` (`lib/modules/profile_configuration/presentation/widgets/profile_form.dart`) não renderiza nenhum campo de endereço — nem em modo leitura nem em edição.
- `RegisterParams` (`lib/modules/driver_registration/domain/usecases/register_params.dart:1-25`), usado no autocadastro, também não tem campo de endereço.
- Busca por `endereco|address|Endereco|Address` em todo `lib/` não retornou nenhuma ocorrência relacionada a endereço residencial/pessoal do motorista (só `departureAddress`/`destinationAddress`, que são endereços de embarque/destino da corrida — conceito totalmente diferente).

**Conclusão:** independente do que o painel web grava no backend, o app do motorista **nunca teria como exibir esse endereço hoje** — o contrato do lado do app simplesmente não modela esse dado. Isso não descarta também haver um problema do lado do backend (contrato de `GET/PUT /api/drivers/{id}` precisa ser confirmado com o subagente do backend), mas o app é, no mínimo, metade da causa e precisa de mudança de qualquer forma para o bug ser resolvido de ponta a ponta. Ver **F05**.

---

## Investigação da regra de negócio: veículo não pode ser desvinculado em viagem ativa

Busca por `veiculo|vehicle|Vehicle|Veiculo` em todo `lib/` **não retornou nenhuma ocorrência**. O app do motorista **não tem nenhuma tela, model ou fluxo de gestão de veículo** — nem visualização, nem vínculo/desvínculo. Essa gestão é, hoje, **exclusiva do painel web** (confirmado por ausência total no app, não por documentação). Não há, portanto, um front no app do motorista que precise (ou possa) respeitar essa regra — a responsabilidade de impedi-la é inteiramente do backend, e deve ser validada lá independentemente de qual cliente tentar a operação. Nenhum achado de código aplicável aqui; registrado como confirmação de escopo.

---

## Achados

### CRÍTICO

---

**ID:** F01
**Área:** Mapa / Fluxo de viagem / Localização
**Fluxo:** Viagem em andamento → finalizar viagem
**Arquivo:** `lib/screens/active_travel_page.dart:360-378` e `lib/core/network/signalr_service.dart:102-106`

**Evidência:**
```dart
// active_travel_page.dart
double? lat;
double? lng;
try {
  final locationService = Modular.get<LocationService>();
  final pos = await locationService.getCurrentPosition();
  if (pos.isGranted) {
    lat = pos.position!.latitude;
    lng = pos.position!.longitude;
  }
} catch (_) {
  // Location is optional — proceed without it
}

final signalR = Modular.get<SignalRService>();
await signalR.finishTravel(widget.travelId, latitude: lat, longitude: lng);
```
```dart
// signalr_service.dart
Future<void> finishTravel(String travelId, {double? latitude, double? longitude}) async {
  final conn = _connections['travel-management'];
  await conn?.invoke('FinishTravel', args: [travelId, latitude!, longitude!]);
}
```

**Problema:** O comentário diz "Location is optional — proceed without it", mas `finishTravel` faz `latitude!`/`longitude!` (null-check operator). Quando o hub está conectado (`_hubConnected == true`, o caminho mais comum), a lista de argumentos é avaliada antes do `conn?.invoke` decidir se chama ou não — se `lat`/`lng` forem `null`, o `!` lança `TypeError: Null check operator used on a null value`. A exceção é capturada pelo `catch (_)` externo de `_finishTravel()`, que só mostra "Erro ao finalizar viagem" — o motorista não recebe nenhuma pista do motivo real e o botão "Finalizar" continua falhando indefinidamente enquanto a localização não voltar.

**Como reproduzir:** Em uma viagem `InProgress` com o hub `travel-management` conectado, desativar o GPS do aparelho (ou negar a permissão de localização) e tocar em "Finalizar Viagem". `getCurrentPosition()` retorna `LocationStatus.serviceDisabled`/`denied` → `pos.isGranted == false` → `lat`/`lng` permanecem `null` → `finishTravel` lança exceção → snackbar genérico "Erro ao finalizar viagem", corrida trava em `InProgress`.

**Impacto:** Motorista fica **impossibilitado de finalizar a corrida** pela UI sempre que o GPS estiver indisponível no momento da finalização — cenário nada raro (motorista estaciona em garagem/prédio com sinal fraco, bateria em modo economia desativa GPS, permissão revogada acidentalmente). Sem fallback HTTP nesse caminho (o fallback só existe quando `!_hubConnected`, não quando o hub está conectado mas a localização falhou). Trava operacional real, gera corrida "presa" para suporte resolver manualmente.

**Criticidade:** Crítico

**Recomendação:** Tornar `latitude`/`longitude` genuinamente opcionais em `SignalRService.finishTravel`: só incluir os argumentos de posição no `invoke` quando ambos não forem nulos (dois overloads de invocação, ou enviar `null`/sentinel se o hub do backend aceitar), nunca usar `!` sobre valores potencialmente nulos vindos de uma fonte declarada opcional pelo próprio comentário do código.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste unitário de `SignalRService.finishTravel` com lat/lng nulos (verificar que não lança); teste de widget/bloc de `ActiveTravelPage._finishTravel` simulando `LocationService` retornando `denied`/`serviceDisabled` e confirmando que a viagem finaliza com sucesso sem posição.

---

**ID:** F02
**Área:** Segurança / Comunicação com API
**Fluxo:** Todos — login, perfil, viagem, disponibilidade
**Arquivo:** `lib/core/http/dio_client.dart:46-52`

**Evidência:**
```dart
dio.interceptors.add(AuthInterceptor(authStorage));
dio.interceptors.add(
  LogInterceptor(
    requestBody: true,
    responseBody: true,
    error: true,
  ),
);
```

**Problema:** `LogInterceptor` do Dio, por padrão, também loga `requestHeader: true` e `responseHeader: true` (não sobrescritos aqui) — ou seja, o header `Authorization: Bearer <token>` de **toda** requisição é impresso no console, junto com o corpo completo de request/response. Isso inclui a senha em texto plano no `POST /api/auth/sign-in` (`{'email':..., 'password':...}`), o `access_token`/`refresh_token` retornados no login, dados de perfil de passageiros (foto, nome, telefone), etc. Não há nenhum guard `kDebugMode`/`kReleaseMode` — roda **igual em build de release**. Esse comportamento é exatamente o débito **D1** já identificado pela própria equipe em `.sdd/specs/hotfix-auth-token-deadlock/requirements.md` ("Crítico, mas independente") em 2026-08-05 e **segue sem correção** até hoje.

**Como reproduzir:** Rodar o app em modo release conectado via `adb logcat` (Android) e fazer login — a senha digitada e o Bearer token aparecem em texto plano no log do dispositivo.

**Impacto:** Vazamento de credenciais (senha, tokens de sessão) e PII de motoristas/passageiros para qualquer processo/app com acesso a logs do dispositivo (ferramentas de terceiros, crash reporters mal configurados, ADB em dispositivo de terceiro/loja de reparo, etc). Em escala (milhares de motoristas), essa é uma superfície de exposição de credenciais sistemática, não um evento isolado.

**Criticidade:** Crítico

**Recomendação:** Remover `LogInterceptor` de builds de release (`if (kDebugMode) dio.interceptors.add(...)`) ou, no mínimo, desabilitar `requestHeader`/`responseHeader`/`requestBody`/`responseBody` fora de debug e mascarar campos sensíveis (`password`, `token`) antes de logar, mesmo em debug.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste que verifica que `DioClient.create` não adiciona `LogInterceptor` (ou adiciona uma versão sem corpo/headers) quando `kReleaseMode` é `true`.

---

**ID:** F03
**Área:** Localização/GPS / Background / Android vs iOS
**Fluxo:** Viagem em andamento → atualização de localização
**Arquivo:** `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist:58-61`, `lib/screens/active_travel_page.dart:244-264`, `lib/screens/home_screen.dart:658-679`

**Evidência (Android manifest — sem `ACCESS_BACKGROUND_LOCATION`, sem `<service>` de foreground):**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
**Evidência (iOS — pede permissão "Always" mas não declara o background mode correspondente):**
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Este aplicativo utiliza sua localização com o app em segundo plano...</string>
...
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```
(nota-se a ausência de `<string>location</string>` no array `UIBackgroundModes`)

**Problema:** Todo o envio de localização do app (tanto em disponibilidade — `home_screen.dart:658-679` — quanto durante viagem — `active_travel_page.dart:244-264`) é feito via `Timer.periodic` dentro de `State` de widgets Flutter. Esses timers **só executam com o app em primeiro plano**. Nem o Android nem o iOS estão configurados para manter esse trabalho vivo em segundo plano:
- iOS pede a string de permissão "Always" (implica intenção de rastrear em background) mas **não declara `location` em `UIBackgroundModes`** — sem isso, o iOS suspende o app poucos segundos após ele ir para background e nenhum timer roda.
- Android não declara `ACCESS_BACKGROUND_LOCATION` nem usa um `Foreground Service` (obrigatório desde Android 10+/12+ para rastreamento contínuo) — o SO mata o trabalho em background rapidamente (Doze mode, App Standby, e ainda mais agressivo em fabricantes como Xiaomi/Samsung com otimização de bateria própria).

**Como reproduzir:** Iniciar uma viagem (`InProgress`), minimizar o app ou bloquear a tela do celular por mais de ~30s-1min. Voltar ao app: nenhuma atualização de localização foi enviada nesse intervalo (nem para o hub SignalR nem via HTTP), e a última posição vista pelo painel/passageiro é a de antes de minimizar.

**Impacto:** Este é o cenário mais comum na prática — motorista com o celular no suporte, tela apagada, ou trocando de app para navegação externa (ex.: usa o botão "Navegar até o destino" que abre o Google Maps externamente, saindo do app). O rastreamento em tempo real para o passageiro/painel **para completamente** exatamente quando o app menos está em primeiro plano — que é a maior parte do tempo de uma corrida real. Isso compromete a funcionalidade central de um app de transporte (rastreamento ao vivo) e a confiança do passageiro/operação no sistema.

**Criticidade:** Crítico

**Recomendação:** Implementar rastreamento de localização em background de verdade: Android com `Foreground Service` de tipo `location` (permissão `FOREGROUND_SERVICE_LOCATION` + `ACCESS_BACKGROUND_LOCATION`, notificação persistente "Compartilhando localização") e iOS com `UIBackgroundModes: [location]` + `CLLocationManager` em modo "significant location changes" ou "always" com `allowsBackgroundLocationUpdates = true`. Na prática isso normalmente exige um plugin dedicado (ex. `flutter_background_geolocation`, `background_locator_2`, ou implementação nativa) em vez de `Timer.periodic` associado ao ciclo de vida do widget. Esforço arquitetural relevante — tratar como item de roadmap, não hotfix.

**Complexidade:** Grande (G)

**Testes necessários:** Teste manual em dispositivo físico Android e iOS: iniciar viagem, bloquear a tela por 5+ minutos, confirmar no backend/painel que posições continuam chegando. Teste de regressão de bateria (consumo em 1h de trip em background). Testes automatizados são limitados aqui (dependem de plugin nativo), mas o novo serviço de localização deve ter testes unitários para a lógica de throttle/retry que o envolve.

---

**ID:** F04
**Área:** Escalabilidade / Localização / Backend load
**Fluxo:** Disponível (idle) → viagem em andamento
**Arquivo:** `lib/screens/home_screen.dart:227-248, 250-269, 658-679` e `lib/screens/active_travel_page.dart:244-264`

**Evidência:**
```dart
// home_screen.dart — dispara ao entrar na Home e nunca é cancelado
// enquanto a Home continuar montada (ela NÃO é removida da pilha quando
// /active-travel é empurrada por cima via pushNamed)
_activeTravelPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkActiveTravelHttp());   // HTTP GET
_driverPositionTimer  = Timer.periodic(const Duration(seconds: 10), (_) => _updateDriverPosition());     // HTTP POST /api/positions/drivers/$_userId
// ...dentro de _connectHubs, chamado no connect inicial:
_startLocationReporting(signalR); // Timer.periodic 30s → signalR.reportLocation (SignalR)
```
```dart
// active_travel_page.dart — SOMA-SE aos timers acima quando a viagem está InProgress
_locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  ...
  await signalR.updateLocation(widget.travelId, result.position!.latitude, result.position!.longitude); // SignalR
});
```

**Problema:** `Modular.to.pushNamed('/active-travel', ...)` empilha `ActiveTravelPage` **sobre** `HomeScreen` — `HomeScreen` nunca é disposta enquanto a viagem está ativa (a navegação de volta usa `Modular.to.pop()`/`navigate('/home')`, mas enquanto a página de viagem está aberta a Home continua viva por baixo). Isso significa que, durante uma viagem `InProgress`, **quatro canais de reporte/poll rodam em paralelo, todos ligados ao mesmo motorista**:
1. HTTP `POST /api/positions/drivers/{userId}` a cada 10s (Home)
2. SignalR `ReportLocation` a cada 30s (Home)
3. HTTP `GET /api/travels/active` a cada 15s (Home, "rede de segurança")
4. SignalR `UpdateLocation` a cada 10s (ActiveTravelPage)

Os canais 1, 2 e 4 são, na prática, **redundantes entre si** — todos existem só para informar a posição atual do motorista, por três mecanismos e frequências diferentes simultaneamente, para o mesmo motorista, ao mesmo tempo.

**Como reproduzir:** Abrir o DevTools/log de rede (ou instrumentar `Dio`/`SignalRService`) durante uma viagem `InProgress` e contar as chamadas de rede por minuto atribuíveis a um único motorista — chega a ~6 requisições HTTP + 6 mensagens SignalR de localização só nesse 1 minuto, fora o poll de 15s.

**Impacto:** Em escala, isso multiplica diretamente a carga no backend. Com N motoristas simultaneamente em corrida, o tráfego de localização/poll não é N × (1 canal), é N × (até 4 canais concorrentes com frequências diferentes). Para milhares de motoristas simultâneos (o cenário que esta auditoria existe para endereçar), isso é a diferença entre um backend dimensionado corretamente e um sobrecarregado por tráfego que não agrega valor nenhum além do primeiro canal. Também é desperdício de bateria/dados do motorista.

**Criticidade:** Crítico

**Recomendação:** (1) Escolher **um único transporte e uma única frequência** para reporte de localização — dado que o app já usa SignalR (WebSocket) para tudo mais, eliminar o `POST /api/positions/drivers` HTTP redundante e manter só o SignalR. (2) Ao empilhar `/active-travel`, pausar explicitamente os timers de "modo idle" da Home (`_driverPositionTimer`, `_locationTimer` de report) e retomá-los só quando a Home voltar ao topo da pilha — ou, melhor, mover toda a responsabilidade de localização para um serviço singleton único (não duplicado por tela) que sabe se há viagem ativa e ajusta frequência/canal de acordo. (3) Avaliar throttle por distância (`distanceFilter` do Geolocator) além de tempo, para não reenviar quando o motorista está parado.

**Complexidade:** Média (M) para consolidar os canais existentes; Grande (G) se combinado com F03 (rearquitetura para background).

**Testes necessários:** Teste de integração/instrumentação contando requisições de rede por minuto durante uma sessão simulada Home→ActiveTravel→Home; teste garantindo que timers de Home são cancelados/pausados quando ActiveTravelPage está no topo da pilha.

---

**ID:** F05
**Área:** Perfil do motorista / Contrato com backend
**Fluxo:** Edição de perfil (via painel web) → exibição no app do motorista
**Arquivo:** `lib/modules/profile_configuration/domain/entities/profile_entity.dart:1-31`, `lib/modules/profile_configuration/data/models/profile_model.dart:24-32`, `lib/modules/profile_configuration/presentation/widgets/profile_form.dart`

**Evidência:**
```dart
// profile_entity.dart
class ProfileEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  // sem campo de endereço
}
// profile_model.dart
factory ProfileModel.fromJson(Map<String, dynamic> json) {
  return ProfileModel(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    photoUrl: json['photoUrl'] as String?,
    // 'address'/'endereco' nunca é lido, mesmo que venha no payload
  );
}
```

**Problema:** ver seção "Investigação do bug relatado" acima. O app do motorista não modela, não busca (explicitamente) e não exibe endereço nenhum no perfil do motorista — o campo simplesmente não existe no `ProfileEntity`/`ProfileModel`/`ProfileForm`. Isso é consistente com o sintoma relatado pelo usuário ("endereço do motorista não está retornando").

**Como reproduzir:** Editar o endereço de um motorista pelo painel web, abrir `/profile-configuration` no app do motorista logado com essa conta — não há nenhum campo de endereço exibido, em nenhum estado (visualização ou edição).

**Impacto:** Funcionalidade ausente do ponto de vista do motorista — qualquer dado de endereço mantido pelo backend/painel é invisível para quem deveria ser o dono do dado. Se o objetivo do produto é que o motorista veja (ou edite) seu próprio endereço no app, esse é 100% do gap do lado do app.

**Criticidade:** Crítico (dado ser o bug explicitamente reportado pelo usuário como não investigado)

**Recomendação:** Confirmar com o time de backend o shape exato do campo de endereço em `GET /api/drivers/{id}` (nome do campo, se é string única ou objeto estruturado rua/número/cidade/etc — mesmo padrão que o subagente do backend deve confirmar). Depois: adicionar o campo a `ProfileEntity`/`ProfileModel.fromJson`, exibir em `ProfileForm` (mesmo que somente-leitura, se a edição for exclusiva do painel web).

**Complexidade:** Média (M) — depende de alinhamento de contrato com o backend antes de codar.

**Testes necessários:** Teste de `ProfileModel.fromJson` cobrindo o novo campo (presente, ausente, nulo); teste de widget de `ProfileForm` renderizando o endereço em modo leitura.

---

**ID:** F06
**Área:** Autenticação/token / Fluxo de corrida
**Fluxo:** Qualquer chamada HTTP autenticada durante uma viagem, exceto as que passam por push (`OrderRefreshPage`) ou por `UsageTermsBloc`
**Arquivo:** `lib/core/http/dio_client.dart:6-30` (não trata 401), `lib/screens/active_travel_page.dart:112-177, 316-425` (chamadas sem tratamento de 401), `lib/modules/driver_home/presentation/widgets/incoming_order_sheet.dart:367-370`

**Evidência:**
```dart
// incoming_order_sheet.dart — já documentado como débito D9 na spec hotfix-auth-token-deadlock
case 401:
  message = 'Sessão expirada. Faça login novamente.';
  break;
// ...apenas mostra a mensagem no card; NÃO chama SignOutService nem navega para /login
```
```dart
// active_travel_page.dart — _loadTravel/_startTravel/_finishTravel/_cancelTravel
} catch (e) {
  if (!mounted) return;
  setState(() { _isLoading = false; _error = e.toString(); });
}
```

**Problema:** O único ponto onde o app reage a um 401 desconectando a sessão é `UsageTermsBloc` (via `SignOutService`) e o fluxo de push (`OrderRefreshPage`, que sempre faz refresh proativo antes de abrir a oferta). Não existe nenhum `Interceptor` de Dio que intercepte 401 globalmente, tente `refreshToken` e reenvie a requisição original — isso já era um débito reconhecido (D11, "mudança de arquitetura de sessão, não hotfix") e continua ausente. Como consequência, em qualquer tela do fluxo de corrida (`ActiveTravelPage`, aceitar/recusar oferta via `IncomingOrderSheet`, `HomeScreen`), se o access token expirar enquanto o app está em uso contínuo (sem passar por um evento de push que force refresh), toda chamada HTTP subsequente falha com 401 e o motorista só vê mensagens genéricas ("Erro ao finalizar viagem", "Sessão expirada. Faça login novamente." sem ação) — nunca é efetivamente deslogado/redirecionado para logar de novo.

**Como reproduzir:** Fazer login, aguardar o access token expirar (sem receber nenhuma push nesse meio-tempo — o app não teria motivo pra chamar refresh), e tentar iniciar/finalizar/cancelar uma viagem ou aceitar uma oferta pelo modal SignalR (não pela tela de push) — a operação falha com um erro genérico, sem redirecionamento para login.

**Impacto:** Motorista fica "preso" numa sessão morta no meio de uma corrida real, sem instrução clara de como recuperar (a mensagem existe em alguns lugares mas não aciona a ação). Precisa descobrir sozinho que precisa fechar o app e reabrir (o que dispara `BootstrapBloc._checkAuthEventHandler`, que faz refresh de novo).

**Criticidade:** Crítico

**Recomendação:** Implementar um `QueuedInterceptor` de Dio que, ao receber 401 (exceto nos próprios endpoints de auth), tenta `refreshToken` uma vez, atualiza o storage e reenvia a requisição original; se o refresh também falhar, chama `SignOutService.signOut()`. Isso resolve o problema uma única vez para todas as telas, em vez de precisar de tratamento ad-hoc em cada datasource/bloc.

**Complexidade:** Média (M)

**Testes necessários:** Teste de `DioClient`/interceptor simulando 401 → refresh bem-sucedido → replay da requisição original com o novo token; 401 → refresh falha → `SignOutService.signOut()` chamado.

---

### ALTO

---

**ID:** F07
**Área:** Comunicação em tempo real (SignalR) / Fluxo de corrida
**Fluxo:** Viagem aceita → entrar em `/active-travel` → voltar para Home
**Arquivo:** `lib/core/network/signalr_service.dart:29-52`, `lib/screens/active_travel_page.dart:226-242, 427-434`, `lib/screens/home_screen.dart:658-679`

**Evidência:**
```dart
// signalr_service.dart — connect() SEMPRE para e remove a conexão existente
// com o mesmo nome antes de criar uma nova, mesmo se já havia uma conexão
// saudável (ex.: a da Home).
Future<void> connect(String hubName, String hubUrl, String accessToken) async {
  await _connections[hubName]?.stop();
  _connections.remove(hubName);
  ...
}
```

**Problema:** Quando `ActiveTravelPage._connectManagementHub()` chama `signalR.connect('travel-management', ...)`, ele **para e recria** a conexão `travel-management` — a mesma que a `HomeScreen` já estava usando para `onTravelStarted`/`onTravelCompleted`/`onTravelCancelled` e para `reportLocation` (F04). Depois, ao sair da viagem, `ActiveTravelPage.dispose()`/`_goHome()` chama `signalR.disconnect('travel-management')`, **desconectando totalmente** esse hub. A `HomeScreen`, que continua montada por baixo, mantém seu `_locationTimer` (30s, `reportLocation`) rodando — mas agora `_connections['travel-management']` é `null`, então `conn?.invoke(...)` vira um no-op silencioso. Nada volta a conectar esse hub automaticamente até o próximo evento de lifecycle (`resumed`) ou até o `onClosed` dele disparar (o que não acontece, pois ele foi desconectado deliberadamente, não caiu).

**Como reproduzir:** Abrir o app, ficar disponível na Home (SignalR conectado), aceitar uma corrida, completar a viagem e voltar para a Home. A partir desse ponto, o reporte de localização "idle" da Home (canal 2 de F04) fica mudo — sem erro visível — até o app ser minimizado/restaurado ou a conexão cair por outro motivo.

**Impacto:** Painel/dashboard perde visibilidade da posição do motorista assim que ele volta a ficar disponível após completar uma corrida, até um evento de lifecycle acidental reconectar. Em uma frota com alta rotatividade de corridas, isso significa "buracos" recorrentes na cobertura de rastreamento de motoristas disponíveis.

**Criticidade:** Alto

**Recomendação:** Depois que `ActiveTravelPage` desconectar `travel-management`, a `HomeScreen` precisa detectar isso (ex.: expor um `Stream`/callback de desconexão explícita do `SignalRService`, não só o `onclose` interno) e reconectar. Alternativa mais robusta: não usar hubs nomeados compartilhados entre telas — ter um único ponto (serviço) responsável pelo ciclo de vida da conexão `travel-management`, que as telas apenas consultam/assinam, sem chamar `connect`/`disconnect` diretamente.

**Complexidade:** Média (M)

**Testes necessários:** Teste de `SignalRService` garantindo que, após `disconnect('travel-management')`, uma chamada a `reportLocation`/`updateLocation` não lança e é reportada como "não enviada" (hoje falha silenciosamente); teste de integração cobrindo o ciclo Home → ActiveTravel → Home confirmando que o hub volta a ficar `Connected`.

---

**ID:** F08
**Área:** Localização/GPS
**Fluxo:** Motorista disponível (idle) — reporte periódico de posição
**Arquivo:** `lib/screens/home_screen.dart:250-269`

**Evidência:**
```dart
Future<void> _updateDriverPosition() async {
  try {
    final dio = Modular.get<Dio>();
    final localtionService = Modular.get<LocationService>();
    final position = await localtionService.getCurrentPosition();

    final response = await dio.post(
      '/api/positions/drivers/$_userId',
      data: {
        "latitude": position.position?.latitude,
        "longitude": position.position?.longitude,
      },
    );
    ...
```

**Problema:** Quando a localização não está disponível (permissão negada, GPS desligado), `LocationService.getCurrentPosition()` retorna `LocationResult(position: null, status: ...)`. O código não checa `isGranted` antes de montar o corpo da requisição — `position.position?.latitude` vira `null`, e o `POST` é enviado assim mesmo, com `{"latitude": null, "longitude": null}`, a cada 10 segundos.

**Como reproduzir:** Negar a permissão de localização (ou desligar o GPS) com o motorista disponível na Home; observar (via proxy/log de rede) que `POST /api/positions/drivers/{userId}` continua sendo chamado a cada 10s com `latitude`/`longitude` nulos.

**Impacto:** Tráfego inútil (payload nulo não tem valor para o backend, mas ainda consome uma requisição HTTP completa a cada 10s por motorista nessa condição) e risco de o backend gravar/propagar posições nulas para consumidores downstream (painel, cálculo de distância para despacho) se não validar isso do lado dele.

**Criticidade:** Alto

**Recomendação:** Checar `position.isGranted` antes de montar/enviar a requisição; se não concedido, pular o ciclo (igual ao padrão já usado em `_startLocationReporting`, que faz esse check corretamente).

**Complexidade:** Pequena (P)

**Testes necessários:** Teste unitário/widget de `_updateDriverPosition` (ou extraído para uma função testável) garantindo que nenhuma requisição é enviada quando `LocationService` retorna `isGranted == false`.

---

**ID:** F09
**Área:** UX / Localização / Cenários adversos
**Fluxo:** Viagem em andamento — perda de GPS
**Arquivo:** `lib/screens/active_travel_page.dart:244-264`, `lib/screens/home_screen.dart:658-679`

**Evidência:**
```dart
_locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  if (!_hubConnected) return;
  try {
    final locationService = Modular.get<LocationService>();
    final result = await locationService.getCurrentPosition();
    if (!result.isGranted) return; // <- sai em silêncio
    ...
  } catch (_) {
    // Best-effort — location send failure should not break anything
  }
});
```

**Problema:** Se o GPS for desativado ou a permissão for revogada **durante** uma viagem em andamento, o app simplesmente para de enviar posições, sem nenhum aviso visual ao motorista (nenhum banner, nenhum ícone de alerta — o indicador "Compartilhando localização" em `active_travel_page.dart:750-760` só reflete `_hubConnected`, não o status real do GPS).

**Como reproduzir:** Iniciar uma viagem, desativar o GPS do aparelho no meio do trajeto. O app continua parecendo normal ("Compartilhando localização" permanece visível), mas nenhuma posição nova é enviada.

**Impacto:** Passageiro/painel perdem rastreamento em tempo real sem que ninguém (nem o motorista) seja avisado. Motorista não tem como saber que precisa reativar o GPS.

**Criticidade:** Alto

**Recomendação:** Rastrear o resultado de `getCurrentPosition()` no state da tela; quando `isGranted == false` por N ciclos consecutivos, exibir um banner "Localização indisponível — ative o GPS para continuar compartilhando sua posição" com atalho para `LocationService.openLocationSettings()`.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste de widget verificando que o banner aparece após falhas consecutivas de `LocationService` e desaparece quando a localização volta.

---

**ID:** F10
**Área:** Testes / Qualidade
**Fluxo:** Todo o fluxo de corrida em tempo real
**Arquivo:** `test/**` (ausência) vs. `lib/screens/home_screen.dart`, `lib/screens/active_travel_page.dart`, `lib/core/network/signalr_service.dart`, `lib/core/location/location_service.dart`

**Evidência:** Listagem completa de `test/**/*.dart` (29 arquivos) não contém nenhum arquivo correspondente a `home_screen`, `active_travel_page`, `signalr_service`, `location_service`, `sign_out_service`, `directions_service`, `travel_history_page`, `profile_configuration_bloc`/`page`, ou `availability_sheet`. Cobertura boa existe para: `auth` (datasource/repository/usecases/blocs/página de login), `driver_registration`, `usage_terms`, `notifications` (OneSignal + serviço), `driver_availability` (entity/datasource), `driver_home` (entity, `order_refresh_page`, `order_alert_page`, `incoming_order_sheet`), utilitários (`masks`, `validators`), `dio_client`, `auth_storage`.

**Problema:** A cobertura de teste está invertida em relação ao risco: os módulos com testes são majoritariamente CRUD/autenticação (importantes, mas relativamente simples e já bem estruturados em Clean Architecture com Result/Failure). O código com **maior complexidade ciclomática, mais estado mutável (`Timer`, `StreamSubscription`, múltiplos hubs SignalR), mais pontos de falha assíncrona e diretamente responsável pela consistência da corrida em produção** (`home_screen.dart`, 681 linhas de `StatefulWidget` com 8 `StreamSubscription` + 4 `Timer`; `active_travel_page.dart`, 822 linhas com lógica de navegação/hub/GPS) **não tem nenhum teste automatizado**. Os achados F01, F04, F07, F08, F09 deste relatório são exatamente do tipo que um teste de widget/bloc bem desenhado nesses arquivos teria capturado antes de chegar em produção.

**Impacto:** Qualquer alteração futura nesses arquivos (o coração do produto) não tem rede de segurança automatizada — regressões só são detectadas em produção ou por QA manual.

**Criticidade:** Alto

**Recomendação:** Priorizar testes de widget/bloc para `ActiveTravelPage` (mockando `Dio`, `SignalRService`, `LocationService` via `Modular.replaceInstance` ou injeção equivalente) cobrindo: finalizar sem GPS (F01), timer de localização respeitando permissão negada, comportamento ao receber `TravelCancelled`/`TravelCompleted` via stream. Extrair a lógica de `home_screen.dart` (hoje 100% acoplada ao widget) para uma classe controladora testável isoladamente reduziria o custo de testar esse arquivo.

**Complexidade:** Grande (G) — cobertura completa; Média (M) por achado pontual (ex.: só o teste de F01).

**Testes necessários:** Ver recomendações acima; no mínimo, um teste de regressão por achado Crítico/Alto listado neste relatório que hoje não tem teste (F01, F04, F07, F08, F09).

---

**ID:** F11
**Área:** UX / Performance / Startup
**Fluxo:** Login → bootstrap → home
**Arquivo:** `lib/screens/splash_screen.dart:6-23`, `lib/blocs/bloc/bootstrap_bloc.dart:97-107`

**Evidência:**
```dart
// splash_screen.dart
const SplashScreen({super.key, this.delay = const Duration(seconds: 2)});
...
Future.delayed(widget.delay, () => Modular.to.navigate('/bootstrap'));
```
```dart
// bootstrap_bloc.dart
Future<void> _initializeNotificationService(Emitter<BootstrapStates> emit) async {
  emit(NotificationServiceConfigurationState());
  try {
    final appId = AppConfig.getOneSignalAppId();
    await _notificationService.initialize(appId);
    await Future.delayed(const Duration(seconds: 8)); // <- incondicional, sempre 8s
  } on Exception catch (e) { ... }
}
```

**Problema:** Todo cold start do app soma, no mínimo, **~10 segundos de espera artificial** (2s fixos na splash + 8s fixos após inicializar o OneSignal) antes do motorista sequer chegar em `/terms`/`/home`, independentemente de o dispositivo/rede serem rápidos. O `Future.delayed(seconds: 8)` não está condicionado a nada (não é um timeout de um `Completer` que resolve mais cedo se o callback do OneSignal já chegou) — é uma espera cega sempre igual.

**Impacto:** Para um app cujo caso de uso principal é "motorista quer ficar disponível o mais rápido possível para começar a receber corridas", 10s de splash/bootstrap fixos em todo cold start é atrito direto na métrica de negócio mais sensível ao tempo do produto.

**Criticidade:** Alto

**Recomendação:** Substituir a espera fixa de 8s por um `Completer` que resolve assim que o observer do OneSignal (`OneSignal.User.addObserver`) retornar o `playerId` pela primeira vez, com um timeout máximo (ex.: 8s) só como fallback de segurança — não como comportamento padrão. Reavaliar também a necessidade dos 2s fixos da splash (hoje parecem existir só por estética de marca).

**Complexidade:** Pequena (P)

**Testes necessários:** Teste de `BootstrapBloc` garantindo que `_initializeNotificationService` completa assim que o observer dispara, sem esperar o timeout completo quando isso acontece antes.

---

**ID:** F12
**Área:** Segurança / Build Android
**Fluxo:** N/A (infraestrutura de build)
**Arquivo:** `android/app/build.gradle.kts:40-53`

**Evidência:**
```kotlin
android:usesCleartextTraffic="true"
```
(`AndroidManifest.xml:13`)
```kotlin
signingConfigs {
  create("release") {
    if (System.getenv()["CI"].toBoolean()) { ... }
    else {
      storeFile = file(keystoreProperties.getProperty("storeFile")) // debug_local.jks
      storePassword = keystoreProperties.getProperty("storePassword") // "debug123"
      ...
```

**Problema:** Dois pontos combinados: (1) `usesCleartextTraffic="true"` permite tráfego HTTP não criptografado para **qualquer** domínio no app inteiro (não escopado por `network_security_config.xml` a domínios específicos de desenvolvimento); (2) fora de CI, um build "release" local usa o keystore `android/debug_local.jks` com senha trivial `debug123`, **commitado no repositório** (não está no `.gitignore`).

**Impacto:** (1) Se por engano ou fallback o app se conectar a um endpoint HTTP em produção, o tráfego (incluindo o token vazado em F02) trafega em texto plano, sujeito a interceptação em redes não confiáveis (Wi-Fi público, etc). (2) Qualquer pessoa com acesso ao repositório pode assinar um APK "release" com credenciais idênticas às usadas por desenvolvedores localmente — não afeta a distribuição oficial (que usa segredos de CI), mas é uma prática de higiene de segurança ruim que pode confundir/ser reaproveitada incorretamente.

**Criticidade:** Alto

**Recomendação:** Restringir `usesCleartextTraffic` via `network_security_config.xml` só para hosts de desenvolvimento local (`10.0.2.2`, etc.), nunca `true` global. Mover `debug_local.jks`/`key.properties` para fora do controle de versão (adicionar ao `.gitignore`) ou, no mínimo, documentar claramente que esse keystore nunca deve assinar um artefato distribuído.

**Complexidade:** Pequena (P)

**Testes necessários:** N/A (configuração) — validar manualmente que builds release feitos localmente continuam funcionando com o keystore movido para fora do VCS (ex.: variável de ambiente/arquivo local não versionado).

---

### MÉDIO

---

**ID:** F13
**Área:** Push notification / Duplicação de eventos
**Fluxo:** Recebimento de corrida com app em foreground
**Arquivo:** `lib/core/notifications/one_signal_notification_service.dart:92-98`

**Evidência:**
```dart
@override
Future<void> handleForegroundNotification() async {
  OneSignal.Notifications.addClickListener((event) async {
    log(jsonEncode(event.notification.body));
    await handleNotificationClick(event.notification.additionalData);
  });
}
```

**Problema:** Só existe um listener de **clique** na notificação. Não há `OneSignal.Notifications.addForegroundWillDisplayListener` para controlar (suprimir ou customizar) a exibição do banner OS quando o app já está em primeiro plano. O mecanismo `NotificationService.setSheetVisible`/`orderAlertOpen` usado pelo app (comentários "RF05: suprimir foreground dup") só evita duplicação **dentro do app** (SignalR vs. clique) — ele não impede o **banner nativo do SO** de aparecer simultaneamente com o `IncomingOrderSheet` já aberto via SignalR, já que nada no código intercepta a exibição da notificação do OneSignal em si.

**Como reproduzir:** Com o app em foreground e uma nova oferta chegando simultaneamente por SignalR (abrindo o `IncomingOrderSheet`) e por push, observar se o banner de notificação do sistema aparece por cima do sheet já exibido.

**Impacto:** Possível duplicação de alerta para o motorista (banner do SO + sheet in-app) para a mesma corrida — confuso, especialmente considerando que o motorista está em movimento e precisa de mínima distração (requisito de UX citado no escopo desta auditoria).

**Criticidade:** Médio

**Recomendação:** Implementar `addForegroundWillDisplayListener`, chamando `event.preventDefault()`/equivalente da versão do SDK quando `NotificationService.orderAlertOpen` ou o sheet já estiver visível, deixando o app cuidar 100% da exibição nesse caso.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste unitário de `OneSignalNotificationService` (mockando o SDK) garantindo que o listener de foreground chama `preventDefault` quando `NotificationService.orderAlertOpen == true`.

---

**ID:** F14
**Área:** UX / Performance / Listas
**Fluxo:** Histórico de viagens
**Arquivo:** `lib/screens/travel_history_page.dart:23-37`

**Evidência:**
```dart
final response = await dio.get('/api/travels/driver?pageSize=50');
setState(() {
  _travels = (response.data['items'] as List).cast<Map<String, dynamic>>();
  ...
```

**Problema:** Busca só a primeira página (`pageSize=50`), sem nenhum mecanismo de paginação/scroll infinito — não há como o motorista ver viagens além das 50 mais recentes.

**Impacto:** Motoristas com mais de 50 viagens no histórico simplesmente não conseguem visualizar corridas mais antigas pelo app. Não é crítico para a operação da corrida em si, mas é uma lacuna funcional perceptível.

**Criticidade:** Médio

**Recomendação:** Implementar paginação real (scroll infinito com `ListView.builder` + carregamento incremental usando os parâmetros de paginação que o backend já parece suportar, dado que a resposta tem `items`).

**Complexidade:** Média (M)

**Testes necessários:** Teste de widget simulando scroll até o fim da lista e verificando que uma nova página é solicitada.

---

**ID:** F15
**Área:** Dependências / Dead code
**Fluxo:** N/A
**Arquivo:** `lib/core/maps/directions_service.dart:1-42`, `lib/core/common_module.dart:36`

**Evidência:**
```dart
final apiKey = const String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
```
Busca por `getDirections(` em `lib/` retorna **apenas a própria definição** — nenhum call site.

**Problema:** `DirectionsService.getDirections` nunca é chamado em nenhum lugar do app (todas as rotas/polylines de fato exibidas vêm pré-computadas do backend, via `encodedPolyline`/`routeJson` nos payloads de oferta/viagem). Além de ser código morto registrado como singleton no DI (`i.addSingleton<DirectionsService>`), depende de uma variável `--dart-define=MAPS_API_KEY` que não aparece configurada em nenhum script de build do repositório — se fosse chamado, falharia silenciosamente (`catch (_) { return null; }`) por chave vazia.

**Impacto:** Baixo risco funcional (não é chamado), mas é manutenção morta, uma dependência de rede (chamada direta à API do Google Maps, fora do backend próprio) que nunca é exercida e pode confundir desenvolvedores futuros pensando que é o mecanismo real de cálculo de rota.

**Criticidade:** Médio (por ser sinal de possível confusão arquitetural, não por risco de produção)

**Recomendação:** Remover `DirectionsService` (mantendo só `DirectionsResult.decode`/`decodePolyline`, que são genuinamente usados) ou, se houver plano de uso futuro (fallback client-side quando o backend não fornece rota), documentar isso explicitamente e configurar `MAPS_API_KEY` no pipeline de build.

**Complexidade:** Pequena (P)

**Testes necessários:** N/A (remoção) — se mantido, adicionar teste cobrindo o parse da resposta do Google Directions.

---

**ID:** F16
**Área:** UX / Robustez / Duplo toque
**Fluxo:** Aceitar/recusar oferta de corrida
**Arquivo:** `lib/modules/driver_home/presentation/widgets/incoming_order_sheet.dart:279-436`

**Evidência:**
```dart
Future<void> _accept(BuildContext context, String id) async {
  _rejectTimer?.cancel();
  setState(() {
    _status = _AcceptStatus.accepting;
    _errorMessage = null;
  });
  // sem "if (_status != _AcceptStatus.idle) return;" antes do setState
  ...
```

**Problema:** Diferente de `AvailabilitySheetBody._confirm` (que tem `if (_submitting) return;` como primeira linha — padrão correto), `_accept`/`_deny` de `IncomingOrderSheet` não têm um guard de reentrância explícito no topo da função. Na prática, os botões somem da árvore assim que `isLoading` fica `true` (linha 103 do `build`), o que cobre a maioria dos casos — mas depende inteiramente do rebuild acontecer antes de um segundo toque ser processado, sem a garantia explícita que um early-return traria.

**Impacto:** Risco baixo-a-moderado de disparo duplo de `accept`/`deny` em condições de dispositivo lento ou dois toques quase simultâneos (ex.: toque acidental com a palma da mão, comum em cenário de uso "em movimento" citado no escopo desta auditoria) antes do primeiro frame de rebuild.

**Criticidade:** Médio

**Recomendação:** Adicionar guard explícito no início de `_accept`/`_deny`/`_autoReject`: `if (_status != _AcceptStatus.idle) return;` antes de qualquer `setState`, replicando o padrão já usado em `AvailabilitySheetBody`.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste de widget disparando dois toques sequenciais rápidos em "Aceitar" e verificando que só uma chamada `dio.post(.../accept)` foi feita.

---

### BAIXO

---

**ID:** F17
**Área:** Performance / Ciclo de vida
**Fluxo:** App em primeiro/segundo plano
**Arquivo:** `lib/app/app_widget.dart:30-39`

**Evidência:**
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  bool isActive = switch (state) {
    AppLifecycleState.resumed => true,
    _ => false,
  };
  Future.delayed(const Duration(seconds: 2), () async {
    await _updateDriverPosition(isActive); // named _updateDeviceStatus no arquivo real
  });
}
```

**Problema:** Cada mudança de lifecycle agenda um `Future.delayed` de 2s não vinculado ao ciclo de vida do `State` (não é cancelado em `dispose()`); se o `State` for descartado antes dos 2s (ex.: hot-restart em dev, ou teoricamente uma sequência rápida de mudanças de estado), a chamada a `Modular.get<...>()` dentro do callback pode rodar após o widget não existir mais.

**Impacto:** Baixo — cenário de borda, sem efeito colateral visível grave hoje (o método já trata `DioException` internamente), mas é um padrão frágil (timer solto, sem `mounted`/cancelamento).

**Criticidade:** Baixo

**Recomendação:** Guardar a referência do `Future.delayed`/usar um `Timer` cancelável em `dispose()`, ou checar `mounted` (via um `StatefulWidget` proxy, já que `_AppWidgetState` tem `mounted`) antes de agir.

**Complexidade:** Pequena (P)

**Testes necessários:** Não prioritário; se endereçado, teste garantindo que nenhuma chamada ocorre após `dispose()`.

---

**ID:** F18
**Área:** Storage local / Migração de schema
**Fluxo:** Atualização de versão do app com schema SQLite novo
**Arquivo:** `lib/core/local_db/schema.dart:75-93`

**Evidência:**
```dart
static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) { ... }
  await db.update('metadata', {'value': newVersion.toString()}, ...);
}
```

**Problema:** O padrão de migração (`if (oldVersion < N)` por versão) está correto para hoje, mas é o único ponto de manutenção do schema — não há teste automatizado cobrindo migração de v1→v2 (verificação de que colunas novas realmente existem pós-upgrade), nem documentação/convenção clara para quando a v3 for necessária.

**Impacto:** Baixo hoje (schema simples, 2 versões). Risco cresce conforme o schema evolui sem rede de segurança de teste.

**Criticidade:** Baixo

**Recomendação:** Adicionar teste de migração (abrir DB em v1, popular dados, rodar `onUpgrade`, validar colunas/dados). Documentar convenção no próprio arquivo para novas versões.

**Complexidade:** Pequena (P)

**Testes necessários:** Teste de `Schema.onUpgrade` cobrindo v1→v2 com verificação de colunas resultantes via `PRAGMA table_info`.

---

## Limitações

- **Não foi possível executar `flutter analyze`/`flutter test`/`flutter build`** neste ambiente: o agente está isolado em um worktree de um repositório diferente (`moto_backend/Moto`), sem acesso a shell/Bash dentro de `C:\JJ-Transportes\moto_driver` (apenas ferramentas de leitura de arquivo/busca funcionaram nesse caminho). Toda a análise de testes é **por inspeção estática** do código-fonte dos arquivos em `test/**` comparados a `lib/**`, não por execução real da suíte. A afirmação do contexto prévio de que "31 falhas foram corrigidas" **não pôde ser confirmada por execução**; o que foi possível confirmar é que os arquivos de teste referentes à spec `hotfix-auth-token-deadlock` (`dio_client_test.dart`, `auth_storage_test.dart`, `usage_terms_bloc_test.dart`) existem e o código de produção correspondente está consistente com o que esses testes deveriam cobrir.
- **Sem acesso ao código do backend** (fora do escopo deste subagente) — achados que dependem do contrato do backend (F05, endereço do motorista; F06, comportamento real de expiração de token) foram documentados com a evidência do lado do app, mas precisam de confirmação cruzada com o subagente responsável pelo backend para fechar a causa raiz de ponta a ponta.
- **Sem acesso a dispositivo físico ou emulador** — os achados sobre background/lifecycle (F03), GPS (F09) e startup (F11) foram derivados de leitura de código e configuração (manifests, plists, timers), não de observação empírica em dispositivo. A recomendação de teste manual em device físico permanece válida e necessária antes de qualquer correção ser dada como resolvida.
- **Sem acesso a uma base de CVE/auditoria de dependências online** — a revisão de `pubspec.yaml` foi por inspeção de versões declaradas, não uma varredura de vulnerabilidades conhecidas contra bases externas.
- **`.env` e segredos de build não foram lidos** (não necessário para os achados deste relatório, e por prudência de segurança).
- Nenhuma tela de gestão de veículo existe no app — a regra de negócio "sem desvínculo em viagem ativa" foi confirmada como **não aplicável** a este cliente (não há UI/lógica correspondente), não como "aplicável e não tratada".
