# README — Pipeline de Build e Publicação (Moto Driver & Moto Passenger)

> Documento vivo. Se algo aqui ficar desatualizado, corrija — é melhor que a próxima pessoa confie neste arquivo do que precise redescobrir tudo do zero, como aconteceu da última vez.

Este documento existe porque a configuração de CI/CD dos apps (`moto_driver` e `moto_passenger`) foi reconstruída do zero em setembro/2026, depois de meses sem documentação e vários bugs silenciosos no pipeline (branch errada, testes que nunca rodavam, versionamento manual colidindo). A ideia é que **o próximo dev que mexer nisso não precise repetir esse trabalho de investigação**.

---

## Parte 1 — Explicação simples (pra quem não mexe com pipeline no dia a dia)

Pensa assim: existem "portas" (branches) que, quando alguém empurra código pra dentro delas, fazem o app ser automaticamente testado, compilado e publicado numa loja (Google Play / Apple App Store). Isso é feito por um serviço externo chamado **Codemagic**.

Pros apps Motô, temos hoje **2 portas ativas** (Android), por app:

| Porta (branch) | O que acontece quando algo entra nela |
|---|---|
| `android_staging` | Builda, testa e publica automaticamente na faixa **interna** do Google Play (ambiente de homologação, só pra testes) |
| `android_release` | Builda, testa e publica automaticamente na faixa **produção** do Google Play (é o que o usuário final baixa) |

Existe uma terceira porta (`android_pre_release`) que **está desativada de propósito** — não builda nada, é só um resquício de uma etapa intermediária que decidimos não usar por enquanto.

**Regra de ouro**: só a branch `dev` pode "entrar" nessas duas portas. Ninguém deve criar uma branch qualquer e mandar direto pra `android_staging`/`android_release` — isso é bloqueado automaticamente pelo GitHub agora (explico como, na parte técnica). E o caminho **nunca é de volta**: o que está em `android_staging`/`android_release` nunca deve ser trazido de volta pra `dev` — isso também está bloqueado.

Ou seja, o fluxo é sempre:

```
você trabalha na dev → abre PR pra android_staging → testa em homologação
                     → quando aprovado, abre PR pra android_release → vai pra produção
```

iOS (App Store) ainda não está nesse mesmo nível de proteção — está em processo de reconstrução, aguardando a migração da conta Apple Developer pra conta empresarial (ver seção "iOS — status" no final).

---

## Parte 2 — Explicação técnica

### 2.1 Estrutura de branches (Android)

```
dev  ──PR──▶  android_staging  ──PR──▶  android_release
 ▲                   │                        │
 └── nunca aceita PR de volta dessas duas ─────┘
```

- `dev`: fonte da verdade do código, onde features/hotfixes são integrados normalmente.
- `android_staging`: branch de pipeline pura — não é pra ter commits de feature direto nela, só recebe merge de `dev`.
- `android_release`: idem, só recebe merge de `dev`.
- `android_pre_release`: existe no repositório mas está **desativada** (`triggering.events: []` no `codemagic.yaml`). Não mexer nela sem decisão explícita de reativar.

### 2.2 O que cada `codemagic.yaml` faz (por branch)

Cada branch tem seu **próprio** `codemagic.yaml` na raiz do repositório (arquivos diferentes por branch, não é um arquivo único com múltiplos workflows visíveis ao mesmo tempo — o Codemagic lê o arquivo que está na branch que disparou o evento).

Passos padrão em `android_staging` e `android_release`, pros dois apps:

1. **Set up local.properties** — aponta o SDK do Flutter
2. **Get Flutter packages** — `flutter pub get`
3. **Config definitions** — gera o `.env` a partir das variáveis de ambiente do grupo do Codemagic (`API_BASE_URL`, `ONE_SIGNAL_ID`)
4. **Run tests** — `flutter test`. **Se os testes falharem, o build para aqui.** Isso é intencional — nenhum build deve ir pra frente com teste quebrado.
5. **Determine next build number** — chama `google-play get-latest-build-number` pra pegar o maior `versionCode` já publicado em qualquer track daquele app, e soma +1. Isso evita colisão de versão entre staging/pre_release/release (o Google Play exige `versionCode` sempre crescente, mesmo entre tracks diferentes do mesmo app).
6. **Build App Bundle** — `flutter build appbundle --release --build-number=$NEW_BUILD_NUMBER`
7. **Publishing** — envia o `.aab` pro Google Play, na track configurada (`internal` pra staging, `production` pra release), e manda e-mail de notificação.

### 2.3 Variáveis de ambiente (Codemagic → Environment variables)

Cada app tem grupos de variáveis separados por ambiente:

| Grupo | Usado por |
|---|---|
| `moto_staging` (driver) / `moto_passenger_staging` (passageiro) | workflow `android_staging` |
| `release` | workflow `android_release` |
| `pre_release` | workflow `android_pre_release` (desativado) |

Variáveis principais em cada grupo: `API_BASE_URL`, `ONE_SIGNAL_ID`, `BUNDLE_ID`/`MOTO_PASSENGER_BUNDLE_ID`, `IOS_MAPS_API_KEY`, `ISSUER_ID`, `APP_STORE_APPLE_ID` (iOS), `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS` (Android — credencial de serviço da Google Play Console, permite publicação automática).

**Nunca commitar essas credenciais no `codemagic.yaml` ou no código** — elas vivem só no painel do Codemagic (Settings → Environment variables).

### 2.4 Bundle IDs / Application IDs

| App | Android | iOS |
|---|---|---|
| Motorista | `br.com.rockservicos.moto_driver` | `br.com.rockservicos.motoDriverApp` |
| Passageiro | `br.com.rockservicos.moto_passenger` | `br.com.rockservicos.motoPassengerApp` |

Os IDs de iOS têm sufixo `App` porque os IDs originais (`motoDriver`, `motoPassenger`, sem sufixo) ficaram presos numa conta Apple Developer antiga e inacessível para transferência — foi necessário registrar novos IDs. Ver seção "iOS — status" pra contexto completo.

### 2.5 Proteção de branch (GitHub)

Configurado em **Settings → Branches** de cada repositório (`moto_driver` e `moto_passenger`), pras branches `dev`, `android_staging` e `android_release`:

- **Require a pull request before merging** — ninguém dá push direto, tudo passa por PR
- **Require status checks to pass before merging** — força os checks abaixo
- **Do not allow bypassing the above settings** — nem admin pula a regra sem querer

### 2.6 GitHub Actions — os dois "guardas" automáticos

Vivem em `.github/workflows/` (adicionados à `dev`, e propagam pras outras branches conforme forem sendo mergeadas normalmente a partir da `dev`):

**`enforce-dev-source.yml`** — roda em todo PR que mira `android_staging` ou `android_release`. Falha se a branch de origem do PR não for literalmente `dev`.

```yaml
on:
  pull_request:
    branches: [android_staging, android_release]
jobs:
  check-source-branch:
    steps:
      - run: |
          if [ "${{ github.head_ref }}" != "dev" ]; then
            exit 1
          fi
```

**`block-pipeline-branch-merge.yml`** — roda em todo PR que mira `dev`. Compara os commits novos do PR com o histórico de `android_staging`/`android_release`; se encontrar sobreposição, significa que alguém trouxe conteúdo dessas branches de volta pra `dev` (ex: rodou `git merge android_staging` sem querer), e o PR falha.

```yaml
on:
  pull_request:
    branches: [dev]
jobs:
  check-no-pipeline-merge:
    steps:
      - run: |
          # compara commits novos do PR com o histórico de android_staging/android_release
          # falha se houver sobreposição
```

Os nomes dos checks que aparecem no GitHub (pra marcar como obrigatório nas branch protection rules) são `check-source-branch` e `check-no-pipeline-merge` — os nomes dos jobs, não dos arquivos.

### 2.7 Como adicionar/alterar algo no pipeline com segurança

1. Nunca edite `codemagic.yaml` direto em `android_staging`/`android_release` via branch solta — sempre `dev` → PR → merge.
2. Se a mudança for específica de pipeline (não é feature de app), ainda assim prefira fazer via PR normal a partir de uma branch de trabalho mergeada em `dev` primeiro — mantém o histórico da `dev` como fonte única da verdade.
3. Depois de qualquer mudança no `codemagic.yaml`, teste rodando `flutter test` localmente antes de abrir o PR — o pipeline já vai rodar de novo, mas economiza um ciclo de build se algo quebrar.
4. **Nunca dispare um build manual no Codemagic ("Start new build") sem checar duas vezes qual branch está selecionada.** Foi exatamente isso que causou o incidente da seção 2.8 — build manual apontado pra uma branch de trabalho antiga em vez de `android_release`.

### 2.8 Incidente registrado: produção publicada com código desatualizado (22-23/09/2026)

**O que aconteceu**: a sprint de correções de segurança e funcionalidades (trabalhada na branch `hotfix-login`, ~09/09 a 18/09) foi mergeada em `main` e `android_staging`, mas **nunca chegou a `android_release` nem a `dev`**. Ninguém notou porque não havia processo de verificação. Enquanto isso:

- O bug de trigger invertido (`include: false`, ver "Perguntas frequentes") fez o Codemagic disparar automaticamente um build de **produção** a partir de uma branch de trabalho velha (`fix-android-release-pipeline` / commit anterior à sprint), publicando código desatualizado — **sem a sprint de segurança** — direto na Google Play (build 45 do passageiro).
- Um build manual também foi disparado depois apontando pra branch errada (mesmo tipo de engano), reforçando o mesmo problema.

**Como foi detectado**: verificação simples com `git merge-base --is-ancestor <commit-da-sprint> origin/android_release` — se o resultado for "não é ancestral", a branch de produção não tem aquele commit. Vale rodar esse teste sempre que houver dúvida sobre se uma branch está atualizada:

```bash
git merge-base --is-ancestor <hash-do-commit> origin/<branch> && echo "presente" || echo "AUSENTE"
```

Como reforço, também dá pra verificar diretamente se um arquivo específico introduzido pela mudança existe na branch (`git show origin/<branch>:<caminho/do/arquivo>`), já que squash-merges no GitHub podem quebrar a checagem de ancestralidade mesmo com o conteúdo presente.

**Correção aplicada**: merge de reconciliação `android_staging → android_release` (que por sua vez já continha `hotfix-login` + as correções de pipeline), preservando manualmente `pubspec.yaml` (versão `2.0.0`, não a `1.0.0` de staging) e `codemagic.yaml` (config de publicação de produção, não a de staging) — esses dois arquivos sempre entram em conflito nesse tipo de merge porque staging e release têm valores intencionalmente diferentes.

**Lição pro futuro**: sempre que `hotfix-*`/features forem mergeados fora do fluxo `dev` normal (direto em `main`, por urgência), é preciso **também** trazer esse conteúdo pra `dev` (e daí pra `android_staging`/`android_release`) manualmente — senão a `dev` fica desatualizada silenciosamente e a proteção de branch (seção 2.5/2.6) não detecta isso, porque ela só verifica a *origem* do PR, não se o *conteúdo* está completo.

---

## iOS — status (setembro/2026)

O pipeline de iOS ainda **não** está no mesmo nível de maturidade/proteção do Android. Motivo: a conta Apple Developer usada para publicar os apps estava cadastrada como Pessoa Física, e precisou passar por um processo de migração pra conta empresarial (Organização) junto à Apple, que envolveu:

- Documentação da empresa (CNPJ, Contrato Social, identidade do responsável legal — enviada, Enrollment ID `DKTT8PQV38`, em análise pela Apple)
- Bloqueio temporário do portal de Certificates, Identifiers & Profiles durante a migração (App Store Connect em si continua acessível)
- Descoberta de que os Bundle IDs originais (`motoDriver`, `motoPassenger`, sem sufixo) estavam presos numa conta antiga (`coronell@...`) inacessível para transferência (Apple só permite transferir apps já aprovados pelo menos uma vez em review — os antigos foram rejeitados, nunca aprovados), exigindo registro de IDs novos (`motoDriverApp`, `motoPassengerApp`)

### Concluído (não depende da aprovação da Apple)

- [x] Apps criados no App Store Connect (Motô Driver e Motô Passageiro), com os novos Bundle IDs
- [x] Ícone 1024×1024 já embutido no projeto Xcode dos dois apps (`Assets.xcassets/AppIcon.appiconset`) — não precisa de upload manual, a Apple extrai do build automaticamente assim que um for enviado
- [x] Screenshots de iPhone enviados nos dois apps
- [x] Textos completos (nome, subtítulo, descrição, palavras-chave, texto promocional, copyright) nos dois apps
- [x] Categoria e direitos de conteúdo configurados
- [x] Privacidade do app (declaração de coleta de dados) preenchida nos dois — ver tabela abaixo
- [x] Classificação etária preenchida (resultado: +4, sem conteúdo sensível)
- [x] Preço (grátis) e disponibilidade (Brasil apenas, Mac/Vision Pro desativados) configurados
- [x] Conta de teste para a equipe de revisão da Apple configurada nos dois apps (contas de produção, já aprovadas — ver abaixo)

**Contas de teste usadas na revisão** (produção, `is_active = true`, já aprovadas via painel admin):
- Motorista: `junior.motorista@moto.com`
- Passageiro: `junior.passageiro@moto.com`

**Declaração de privacidade aplicada nos dois apps** (Nome, E-mail, Localização precisa, Foto de perfil, IDs, Interações com o produto, Outros dados = CPF/RG/CNH/matrícula/placa — todos "Não" para rastreamento; "vinculado à identidade" varia por campo, ver histórico de conversa/commits se precisar do detalhe exato por campo).

### Pendente (bloqueado até a Apple aprovar a migração)

- [ ] Aprovação da Apple sobre o Enrollment `DKTT8PQV38`
- [ ] Gerar certificado + perfil de provisionamento na conta nova
- [ ] Gerar/atualizar API Key de integração do Codemagic com a conta Apple nova
- [ ] Anexar um build assinado em cada app no App Store Connect (hoje aparecem com ícone genérico — só resolve com o primeiro build real)
- [ ] Validar build de homologação (`ios_staging`) ponta a ponta nos dois apps
- [ ] Validar/testar `ios_release` e `ios_pre_release` (nunca foram validados)
- [ ] Reativar gatilho de push nos workflows iOS (`events: []` hoje desligado de propósito)
- [ ] Replicar neste repositório o mesmo pacote de proteção que já existe no Android (branch protection, Actions de `enforce-dev-source`/`block-pipeline-branch-merge`, trigger correto no `codemagic.yaml`)
- [ ] Enviar os apps pra revisão da Apple assim que houver build

---

## Perguntas frequentes

**"Empurrei uma branch nova a partir de `android_staging`, por que builda sozinho?"**
Antes de setembro/2026 isso acontecia por um bug de configuração (`include: false` invertido nos `branch_patterns`). Foi corrigido — hoje só builda em push real na própria `android_staging`/`android_release`. Se ainda estiver acontecendo, o `codemagic.yaml` da branch em questão regrediu, precisa investigar.

**"Meu PR pra `android_staging` foi recusado dizendo que a origem precisa ser `dev`, mas eu preciso mandar uma correção urgente direto"**
Não force isso. Merge primeiro pra `dev`, depois abra o PR de `dev` pra `android_staging`. A regra existe justamente pra evitar que pipeline e código de produto divirjam.

**"Os testes falharam no build e ele não publicou, e agora?"**
Comportamento esperado — corrija o teste (ou o código) e tente de novo. Não comente/desative o passo `Run tests` como atalho; se isso acontecer sem registro, pipelines já ficaram sem teste rodando por semanas sem ninguém perceber.

**"Como funciona o número de versão (`versionCode`)?"**
É automático — não edite manualmente no `pubspec.yaml` esperando que isso defina a versão publicada. O `codemagic.yaml` consulta o Google Play e usa sempre o maior número já visto +1, então builds em qualquer track nunca colidem.

**"Preciso rodar um build manual no Codemagic ('Start new build'), como faço com segurança?"**
Builds manuais **ignoram completamente** `events` e `branch_patterns` do `codemagic.yaml` — a proteção de trigger automático não vale pra eles. Antes de clicar em "Start new build": (1) confira a branch selecionada no dropdown é exatamente a que você quer (`android_release`, não uma branch de trabalho antiga), (2) confirme que essa branch tem o código atualizado (`git log origin/<branch> -3` ou o teste de ancestralidade da seção 2.8), (3) só então rode. Foi um build manual na branch errada que causou o incidente da seção 2.8.

**"Como sei se uma branch está com o código mais atual, sem confiar só no nome dela?"**
Não confie no nome — confirme pelo conteúdo. Rode `git diff origin/<branch-A> origin/<branch-B> --stat`; se a única diferença for `pubspec.yaml` e `codemagic.yaml`, as branches estão sincronizadas em termos de código de app (é o padrão esperado entre `android_staging` e `android_release`). Se aparecerem arquivos de `lib/` na lista, alguma das duas está desatualizada.
