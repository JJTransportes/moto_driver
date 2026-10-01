# Edição de Perfil — Especificação de Estilo, Validação e Fluxo

> Referência para replicar no App Passageiro. Este documento descreve o comportamento
> implementado no App Motorista (`lib/modules/profile_configuration/`) para que os dois
> apps fiquem consistentes em estilo, validação, regex e regras de negócio.

## 1. Visão geral do fluxo

A tela de perfil tem dois modos:

- **View mode** (padrão ao abrir a tela): todos os campos (nome, e-mail, telefone)
  aparecem **desabilitados** (somente leitura, fundo cinza claro `Colors.grey.shade100`),
  com e-mail e telefone **mascarados**.
- **Edit mode** (após tocar em "Editar"): nome, e-mail, **confirmar e-mail** (campo que só
  existe nesse modo) e telefone ficam editáveis.

Não existe um botão "Salvar" fixo — o mesmo botão principal alterna de rótulo:

| Estado           | Botão(ões)                                         |
|------------------|-----------------------------------------------------|
| View mode        | um botão só, largura total: **"Editar"**            |
| Edit mode        | dois botões lado a lado: **"Cancelar"** (esquerda, `OutlinedButton`) + **"Salvar"** (direita, `ElevatedButton`) |

## 2. Máscaras em view mode

Aplicadas **apenas para exibição** — o valor real nunca é perdido; ao entrar em edição os
campos voltam a mostrar o valor completo.

### E-mail
Mostra só o primeiro caractere do usuário + tudo depois do `@` completo:

```
igor.almeida@gmail.com  →  i***@gmail.com
```

Regra: `email.substring(0,1) + '***' + email.substring(indexOf('@'))`.
Se não houver `@` válido, mostra o valor bruto sem mascarar (defesa contra dado malformado).

### Telefone
Mantém DDD e os **últimos 4 dígitos** visíveis; mascara o miolo com `*`, preservando a
formatação `(DD) ****-XXXX`:

```
(11) 91234-5678  →  (11) *****-5678   (celular, 9 dígitos locais)
(11) 1234-5678   →  (11) ****-5678    (fixo, 8 dígitos locais)
```

Implementação: pega os dígitos, separa DDD (2) do resto, aplica o mesmo split 5+4/4+4 do
formatador de digitação (ver seção 4), mas substitui o primeiro bloco por asteriscos do
mesmo tamanho e mantém o segundo bloco (últimos 4) como está.

Se o telefone estiver vazio (campo opcional, ver seção 3), não mostra nada.

## 3. Campos e regras de validação

| Campo             | Obrigatório | Regra                                                                 |
|-------------------|-------------|------------------------------------------------------------------------|
| Nome              | Sim         | Não pode ser vazio (trim)                                              |
| E-mail            | Sim         | Regex de formato (seção 5) — rejeita pontos duplos, ponto/hífen em início ou fim de label |
| Confirmar e-mail  | Sim (só em edit mode) | Deve bater exatamente com o campo E-mail (case-insensitive, trim) |
| Telefone          | **Opcional** | Se vazio, sem erro. Se preenchido, precisa ter 10 ou 11 dígitos (DDD + fixo/celular) |

### Confirmar e-mail — validação ao vivo
Mensagem vermelha "Os e-mails não coincidem" aparece **em tempo real**, enquanto o
usuário digita (listener nos dois controllers → `setState`), não só ao tentar salvar.
Fica em branco enquanto o campo de confirmação está vazio (não mostra erro prematuro).

### Botão "Salvar" — habilitação ao vivo
O botão **"Salvar" fica cinza/desabilitado** (`disabledBackgroundColor: Colors.grey.shade300`)
até que:
- Nome não vazio
- E-mail com formato válido
- Confirmar e-mail == e-mail
- Telefone vazio OU com formato válido

Isso é recalculado a cada tecla digitada (não só no submit) — o formulário expõe um
getter `isValid` e notifica o widget pai via callback `onChanged` a cada mudança de campo,
para o botão fora do formulário reagir.

## 4. Máscara de telefone ao digitar (edit mode)

Formatador que já existia no app e deve ser reaproveitado (`PhoneInputFormatter` em
`core/utils/masks.dart`): formata como `(00) 0000-0000` (fixo, 10 dígitos) ou
`(00) 00000-0000` (celular, 11 dígitos), trocando o split de 4+4 para 5+4 assim que o 9º
dígito local é digitado.

## 5. Regex de e-mail (compartilhada com login/cadastro/recuperação de senha)

```
^[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*
@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?
(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$
```

Local part: um ou mais blocos separados por ponto, sem ponto duplo/início/fim.
Domínio: um ou mais labels separados por ponto, cada um sem começar/terminar com `-`.

Rejeita casos que uma regex ingênua (`^[^\s@]+@[^\s@]+\.[^\s@]+$`) deixaria passar:

| Entrada                        | Válido? |
|---------------------------------|---------|
| `igor.almeida@gmail.com`        | ✅ |
| `igor@sub.mail.empresa.com.br`  | ✅ |
| `igor.almeida@gmail...com`      | ❌ pontos duplos |
| `igor@.gmail.com`               | ❌ label começa com ponto |
| `igor@gmail.com.`                | ❌ termina com ponto |
| `.igor@gmail.com`               | ❌ local part começa com ponto |
| `igor..almeida@gmail.com`       | ❌ ponto duplo no local part |
| `igor@gmail-.com`                | ❌ label termina com hífen |
| `igor@-gmail.com`                | ❌ label começa com hífen |
| `igor@gmail`                     | ❌ sem TLD |

Função de referência: `validateEmailFormat` em `lib/core/utils/validators.dart`. Também
roda `validateSafeText` (bloqueia `<`, `>`, `javascript:`, padrões de SQL injection) por
cima da validação de formato — reaproveitar essa checagem também no passageiro.

Testes de regressão de referência: `test/core/utils/validators_test.dart`.

## 6. Fluxo de salvar (senha + logout forçado)

Regra de negócio confirmada com o backend — **não é intuitiva, seguir à risca**:

1. **Qualquer edição** (nome, e-mail e/ou telefone) → ao tocar em "Salvar", sempre abre um
   **modal de senha** pedindo a senha atual, **mesmo que só nome ou telefone tenham mudado**.
   O backend exige `password` em toda chamada de `PUT .../profile`, sem exceção.
2. O texto do modal muda conforme o caso:
   - Se o e-mail mudou: avisa que a sessão será encerrada após salvar.
   - Se só nome/telefone mudaram: só pede a senha, sem menção a logout.
3. Após confirmar a senha, dispara o update com `password` sempre preenchido no payload.
4. **Logout forçado só acontece se o e-mail mudou** (comparado com o e-mail carregado antes
   da edição, case-insensitive). Nome/telefone sozinhos → salva e continua logado.
5. O forçamento de logout deve:
   - Desconectar o SignalR (`SignalRService.disconnectAll()`)
   - Chamar o serviço de sign-out que limpa storage local e navega para `/login`

### Payload do PUT

```json
{
  "id": "<userId do usuário autenticado, NUNCA o id retornado pelo GET>",
  "name": "...",
  "email": "...",
  "phone": "...",
  "password": "<sempre presente>"
}
```

⚠️ **Armadilha real que já mordeu o motorista**: o `id` retornado pelo `GET /profile` (ou
endpoint equivalente) pode **não ser o mesmo** `userId`/`sub` do token JWT autenticado —
são registros com chaves internas diferentes no backend. Usar o `id` do perfil carregado
para montar a URL/`body` do `PUT` causa **403 "Você só pode editar o próprio perfil."**.
**Sempre usar o `userId` vindo do `AuthStorage` (o mesmo usado para autenticação), nunca o
`id` que voltou no GET do perfil.** Essa mesma armadilha já existia (e já estava corrigida)
no fluxo de upload de foto — replicar a mesma lógica em qualquer chamada autenticada por
userId.

### Mapeamento de erros do backend

| Status | Situação                                | Mensagem exibida |
|--------|------------------------------------------|-------------------|
| 400    | Corpo da resposta tem `error`/`message`/`detail`/`title` | Repassa a mensagem do backend (ex.: "Senha inválida.", "A senha é obrigatória...", "Email already exists.") |
| 400    | Sem mensagem no corpo                    | "Dados inválidos. Verifique as informações e tente novamente." |
| 401    | —                                         | "Sessão expirada. Faça login novamente." |
| 403    | userId da URL ≠ token                    | "Você só pode editar o próprio perfil." |
| 404    | —                                         | "Perfil não encontrado." |
| 413    | Upload de imagem grande demais            | "Arquivo muito grande. Envie uma imagem menor." |
| 415    | Formato de imagem não suportado           | "Formato de arquivo não suportado. Use JPEG ou PNG." |
| 5xx    | —                                         | "Erro interno do servidor. Tente novamente mais tarde." |

## 7. Gate por viagem em andamento

Enquanto o usuário tiver uma viagem ativa (status: aceita/aguardando início, a caminho, em
andamento), os botões **"Editar"**, **"Alterar foto"** e **"Excluir conta"** ficam
**desabilitados e visualmente cinza**. Só existe **uma** mensagem explicativa na tela,
abaixo dos campos do formulário — não duplicar a mensagem embaixo de cada botão.

⚠️ **Cuidado com botões que usam cor fixa (ex.: `OutlinedButton` vermelho de "Excluir
conta")**: `onPressed: null` já desabilita a interação, mas se a cor do texto/ícone/borda
estiver hardcoded (`color: Colors.red`) ela **não muda visualmente** quando desabilitado —
o botão parece continuar ativo mesmo não fazendo nada ao toque, o que confunde o usuário.
Sempre condicionar a cor ao estado: `color: hasActiveTravel ? Colors.grey.shade400 :
Colors.red` (e o mesmo para a borda). Botões que usam a paleta padrão do tema (sem cor
fixa) já escurecem sozinhos quando desabilitados e não precisam desse cuidado.

No motorista, isso reaproveita o cache local já existente
(`TravelLocalRepository.getActiveTravel()`), que já era usado só para o "Excluir conta" e
foi estendido para o botão "Editar" também. No passageiro, replicar a mesma ideia: uma
única fonte de verdade (local ou via bloc de estado de viagem) que os dois botões
consultam — não duplicar a lógica de "tem viagem ativa?" em dois lugares.

## 7.1. Excluir conta — mesmo padrão de modal de senha

A tela de "Excluir conta" segue o mesmo padrão visual do modal de confirmação de senha da
edição de perfil (seção 6): uma única tela de aviso (irreversibilidade dos dados) com botão
vermelho **"Continuar"**. Ao tocar, abre um **modal** (`showDialog`/`AlertDialog`) pedindo a
senha atual — não é mais uma segunda tela cheia. Confirmando a senha no modal, dispara a
exclusão direto; cancelando o modal, volta pra tela de aviso sem nenhuma chamada de rede.

## 8. Resumo de arquivos de referência (motorista)

- `lib/modules/profile_configuration/presentation/pages/profile_configuration_page.dart` —
  tela: toggle view/edit, botões, modal de senha, gate de viagem ativa, forced logout.
- `lib/modules/profile_configuration/presentation/widgets/profile_form.dart` — formulário:
  máscaras de exibição, validação ao vivo, `isValid`, `validate()`.
- `lib/modules/profile_configuration/presentation/blocs/profile_configuration_bloc.dart` —
  usa sempre o `userId` do `AuthStorage`, calcula `emailChanged` comparando com o e-mail
  carregado antes do update.
- `lib/modules/profile_configuration/data/datasources/profile_datasource.dart` — mapeamento
  de erros HTTP → exceptions tipadas, extração da mensagem real do backend.
- `lib/core/utils/validators.dart` — `validateEmailFormat`, `validatePhone`, `validateSafeText`.
- `lib/core/utils/masks.dart` — `PhoneInputFormatter`, `unmaskDigits`.
