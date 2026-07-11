# Spec U — verbo de refatoração unificado (`rename <arq:linha:col> <novo>`)

Portão aberto pelo Diego (2026-07-11). Fatia 1 EXECUTADA na mesma sessão.
Escopo e critério do roadmap § U; decisões do portão registradas aqui.

## O problema (O NORTE na superfície da CLI)

A CLI expunha OITO comandos de rename (`rename-local`, `rename-param`,
`rename-static`, `rename-memvar`, `rename-function`, `rename-method`,
`rename-dsl`, `rename-pp-marker`). Para renomear, o usuário tinha de
**classificar o alvo de antemão** no sufixo do comando — é local ou static?
memvar ou param? método, função, palavra de DSL ou marcador de pp? Essa é
exatamente a taxonomia que **o compilador já fez** e que a ferramenta já
consome em `resolve-at`/`usages --at` (revisão Q5): dado um ponto, o FATO
diz o que o nome é. Repetir a taxonomia no sufixo é uma **réplica sintática
na superfície da CLI** — o mesmo anti-padrão que O NORTE proíbe no motor
(sem ajuste por-caso; a fonte da verdade é o compilador, não uma tabela de
tipos remontada à mão — aqui, na UX).

## A forma entregue

```
hbrefactor rename <projeto> <arq:linha:col> <novo> [--force] [--edit-rules] [--dry-run]
```

O KIND deixa de ser escolha do usuário e vira **consequência do fato sob o
cursor**. A posição (1-based, o mesmo `arq:linha:col` do `usages --at`;
arquivo pode conter `:`, linha/col são os dois últimos segmentos) resolve o
alvo; o dispatcher reconstrói a **argv EXATA** que o `rename-*` específico
espera e **DELEGA** para a mesma função que o `Main` chamaria — a saída sai
**byte-idêntica por construção** (reuso, zero reimplementação).

## Design (`src/hbrefactor.prg`)

Três peças novas + uma extensão aditiva:

1. **`ResolveAtQuery` ganha chaves `role`/`owner`** (aditivo). Em cada
   veredito do resolvedor de posição já existente, além de `name/kind/query`
   agora sai o **papel estrutural** do site: `method` (com `owner` quando a
   dona é única), `ppmarker`, `dsl`, `field`, `ident`. Os consumidores
   antigos (`resolve-at`, `usages --at`) leem só `name/kind/query` — as
   chaves novas são ignoradas. **Zero mudança de comportamento** (suíte
   inteira intacta).

2. **`ResolveRenameAt(hAst, hAsts, nLine, nCol0)`** classifica a posição em
   um dos oito alvos. **PRINCÍPIO (endurecido nas DUAS rodadas de revisão,
   ver §Revisão): o que decide entre "nome que a diretiva vira código" e
   "símbolo ligado" é o FATO DO CORE `generates` (ast-12: o marker faz
   paste/stringify), não o binding cego nem o papel de pp.** Um símbolo
   LIGADO que flui para um comando (`? x`) continua sendo esse símbolo; um
   nome que GERA (o marker que a DSL pasteia num símbolo, stringifica numa
   string) é o marker, mesmo que a expansão fabrique um LOCAL homônimo.
   Ordem:
   - **(1) fato de posição não-ambíguo**: `method` → `rename-method`
     (`owner:msg` quando a dona é fato, ou msg cru num send); `field` (com
     alias) → recusa (RDD); **`dsl` (palavra de regra) → `rename-dsl`**
     (a cabeça/keyword da diretiva NUNCA é símbolo ligado — mata o roubo
     por local homônimo, Codex #4);
   - **(2) marker que GERA** (`role ppmarker` E `generates` do ast-12) →
     `rename-pp-marker`. **Vence QUALQUER binding homônimo**, inclusive o
     `LOCAL <n>` que `REGISTRO <n> => …LOCAL <n>` fabrica na linha da
     diretiva (o mirror que a rodada 2 pegou);
   - **(3) CHAMADA** nesta posição (`IsCallAt`: token seguido de `(` no
     stream, por COLUNA — sem depender de `calls[].line`, cobre statement
     continuado, Codex #3) → `rename-function`. Markers que geram já saíram
     em (2), então `(` aqui é chamada de fato (`Dobra( Dobra )` — a chamada
     é a função, o argumento é o local);
   - **(4) símbolo DECLARADO na função dona** (`FuncAtLine`): `local`+param
     → `rename-param`; `local` → `rename-local`; `static` → `rename-static`
     (`--func`); `memvar`/`private`/`public` (decl ou occ) → `rename-memvar`;
     `field` → recusa. **Pega o local dentro de `? x`** (pass-through
     clone), e o param de método (clone, em função de nome gerado) — que um
     flag "declaração gerada" quebraria;
   - **(5) STATIC file-wide**;
   - **(6) função do projeto** (`IsProjectFunction`; `--file` quando a função
     é STATIC deste módulo — desambigua statics homônimas, Codex #1) →
     `rename-function`; nada disso → **recusa nomeando a exceção**.

3. **`Rename(aArgs)`** — parse da posição, uma compilação para resolver, o
   `ResolveRenameAt`, e o despacho: monta `aDel` (a argv do `rename-*`) com
   o command-name em `aDel[1]`, repassa `--force`/`--edit-rules`/`--dry-run`
   quando o alvo os aceita, e chama `RenameLocal`/`RenameStatic`/… A saída é
   a do delegado — o `rename` não imprime NADA a mais (só `Refuse` na falha
   de resolução).

## Mapa posição → comando (os oito alvos)

| Fato sob o cursor | role/escopo | Comando delegado |
|---|---|---|
| LOCAL (decl/uso) | `ident` → decl `local` !param | `rename-local <arq> <FUNC> <old>` |
| parâmetro | `ident` → decl `local` param | `rename-param <arq> <FUNC> <old>` |
| STATIC de função | `ident` → decl `static` (em função) | `rename-static <arq> <old> --func <FUNC>` |
| STATIC file-wide | `ident` → decl `static` (em `fileDecl`) | `rename-static <arq> <old>` |
| memvar (PRIVATE/PUBLIC/dinâmico) | `ident` → `memvar`/`private`/`public` | `rename-memvar <old>` |
| função (def/chamada) | `ident` → `IsProjectFunction` | `rename-function <old>` |
| método (send / impl / decl) | `method` (owner opcional) | `rename-method <owner:msg | msg>` |
| marker de diretiva (valor) | `ppmarker` | `rename-pp-marker <old>` |
| palavra de regra de pp | `dsl` | `rename-dsl <old>` |

## Decisões do portão (Diego, 2026-07-11)

- **D-U1 — Comandos antigos: DESCONTINUAR + REMOVER (não manter como
  aliases).** Esta fatia entrega o `rename` e marca os oito `rename-*` como
  **descontinuados** no `--help` (mantidos funcionais nesta fatia porque
  são o MOTOR da delegação E o ORÁCULO do teste byte-idêntico); a remoção da
  superfície pública dos oito, a migração do harness e o ADR-002 ficam para
  a fatia SEGUINTE (o oráculo do byte-idêntico precisa dos dois lados vivos
  agora — congelar a saída esperada como golden vem com a remoção).
- **D-U2 — Todos os oito alvos de uma vez.** Fatia 1 cobre local/param/
  static/memvar/function/method/dsl/pp-marker, cada um com prova
  byte-idêntica (caso 107).
- **D-U3 — Ambiguidade/sem fato = recusa nomeando a exceção** (idioma do
  degrade honesto), NUNCA adivinha. A CLI continua não-interativa; a
  extensão herda a recusa (a mensagem do CLI explica). Já estava no roadmap;
  confirmado.
- **D-U4 — O nome da função dona é o CANÔNICO do compilador** (uppercase). O
  verbo não recebe casing do usuário (o alvo é a POSIÇÃO); logo a
  função-dona que ele deriva é o fato do dump (`hFunc["name"]`, uppercased).
  O oráculo byte-idêntico de local/param usa o nome canônico (MAIN/DUPLA) —
  não é cherry-pick, é a definição: o `rename` delega com o nome que o fato
  dá.

## Revisão externa (Codex gpt-5.5 + Claude) — DUAS rodadas comparadas

Achado externo é HIPÓTESE até verificação no fonte; cada um foi reproduzido
por FATO antes de agir.

### Rodada 1 (sobre a 1ª implementação role-first)
- **A** — sombra chamada/local + `? nTotal` rotulado `ppmarker`. **B** —
  FIELD escorrega p/ rename-function. **C** — `Val("5x")=5` frouxo. **D** —
  recusa pré-delegação diverge (DOCUMENTADO, não consertado). **E** — STATIC
  após statement (REFUTADO: `E0004`). Placar: 1 comum (A), Codex +2 (C,D),
  Claude +1 (B), 1 refutado (E). Levou ao redesenho **binding-first**.

### Rodada 2 (sobre o binding-first) — destravou o fato do core
O binding-first cego tinha o MIRROR: `REGISTRO Salva` — um marker que GERA
`reg_Salva` mas cuja expansão também fabrica um `LOCAL Salva` na linha da
diretiva — saía `rename-local` de 1 site (perdendo os artefatos). Codex
achou o mesmo cluster (#2 marker×local homônimo; #4 dsl-word×local; #3
chamada continuada; #1 duas statics sem `--file`). **A síntese com a
intuição do Diego** ("a AST devia ter info pré-pp pra rastrear o trecho
importante") levou ao FATO CERTO: o pp já classifica cada derivação em
`'c'lone` / `'p'aste` / `'s'tringify` (ppcore.c) — **paste/stringify GERA
artefato, clone é pass-through**. Não é "declaração gerada" (isso quebraria
param de método, que mora em função de nome gerado mas é do usuário): é
**por-MARKER**.

**Decisão do Diego: expor o fato como CANAL do core** (não recomputar no
consumidor). `ast-12`: `hb_compAstMarkerGenerates` (reverse-scan do `from`,
puro no dump) carimba `"generates": true` no recheio de marker que pasteia/
stringifica. **Este achado — a operação de derivação do pp como FATO de
resolução — pode ser arquitetural e tem registro honesto próprio (escopo,
limites, perguntas boas e ruins) em
[adr-003-derivacao-pp-como-fato.md](adr-003-derivacao-pp-como-fato.md).** O `ResolveRenameAt` lê o fato e decide marker×binding (§2). O
`SymCalledAt` linha-estrito morreu (Codex #3 → `IsCallAt` por coluna); o
`--file` do static entrou (Codex #1). Zero impacto no pcode (lexdiff 0
divergências reais); commit do core sob autorização por-commit do Diego;
rebuild harbour + hbmk2 (compast.c → libhbcplr).

## Critério de pronto (executável) — FECHADO

Caso 107 (29 checks): em CADA um dos oito alvos, `rename <pos> <novo>
--dry-run` sai **byte-idêntico** ao `rename-*` específico (`diff -q`);
resolução da DONA de método por fato; **aplicação REAL** (edita + recompila
+ verifica byte a byte); e as guardas das DUAS revisões — **`? nTotal` →
rename-local** (clone, não pp-marker), **MIRROR** (`REGISTRO Salva` gera →
rename-pp-marker, não o LOCAL homônimo), **CLONE** (param `nX` de PARAMFN →
rename-param), **MÉTODO** (param em função de nome gerado → rename-param),
**sombra** (chamada → função, local → local; **continuada** inclusa),
**FIELD** → recusa, **duas STATIC homônimas** → `--file` desambigua,
**malformada/vazia** → recusa. Suíte **797/0** byte-idêntica paralelo;
**lexdiff 0 divergências reais** (o canal ast-12 é byte-idêntico no pcode).

## Limites honestos desta fatia

- **Byte-idêntico vale quando a resolução TEM SUCESSO** (achado D). O
  `rename` compila para resolver a posição antes de delegar; se o projeto
  não compila, ele recusa "não compila" onde um `rename-*` específico
  recusaria por outra razão (ex.: nome novo inválido). Recusa × recusa,
  mensagem diferente — nunca edição divergente.
- **`extract`/`reorder`/`inline-local` NÃO colapsam num verbo por-posição**:
  uma posição não especifica um range de extração nem uma permutação de
  parâmetros — esses verbos precisam de mais que o ponto. Ficam como estão;
  o roadmap § U previa "mesmo tratamento SE o fato os cobrir" — o fato não
  cobre com só a posição.
- **Renomear CLASSE está fora**: nenhum dos oito verbos renomeia o nome de
  uma classe; o cursor num `CREATE CLASS Foo` recai no motor de método/
  marker (a classe é a dona, não o alvo) ou recusa. Fica registrado como
  limite; um `rename-class` seria fase própria.
- **Custo: dupla compilação.** O `rename` compila uma vez para resolver a
  posição e o delegado compila de novo. Correto (a saída não depende da
  contagem), mais lento. Otimizável passando os dumps já carregados ao
  delegado — adiado (arriscaria drift na saída; não vale nesta fatia).
- **Acoplamento `role`↔`ResolveAtQuery`**: o `ResolveRenameAt` depende das
  chaves `role`/`owner` que o `ResolveAtQuery` emite. É acoplamento contido
  (mesmo arquivo, mesmo autor) e guardado pelo caso 107 — mudar um veredito
  de papel sem atualizar o outro lado quebra um check.

## Fatia 2 (próxima, sob o mesmo portão D-U1)

Remover a superfície pública dos oito `rename-*` (o `Main`/`Usage` deixam de
aceitá-los; as funções `Rename*` sobrevivem como delegados internos);
migrar o harness (as ~40 invocações `rename-*` viram `rename <pos>` ou
golden congelado); ADR-002 registrando a remoção; CHANGELOG do corte.
