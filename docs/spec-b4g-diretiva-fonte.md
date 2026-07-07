# Spec B4g — a diretiva como fonte de primeira classe (schema ast-5)

**ORDEM DE SERVIÇO (2026-07-07)** — escrita ANTES do código (pedido do
Diego na sessão que investigou o veículo da generalidade). Volume de core
só depois do **portão**: probes P1-P5 + rascunho do schema apresentados ao
Diego. Ler antes: [ast-schema.md](ast-schema.md), [roadmap.md](roadmap.md),
CLAUDE.md dos dois repos.

## O problema (a fronteira exata dos casos 72-74)

O princípio da generalidade (Diego, 2026-07-07; regra durável no CLAUDE.md)
exige refatorar QUALQUER construto criado por diretiva de pp sem ajuste
por-caso. As fases B4-B4f fecharam as APLICAÇÕES das regras (palavra de
DSL, markers, rastro `from`, canal de tipos, dispatch) — mas a **REGRA POR
DENTRO** continua não-endereçável:

1. **Caso 74** (`fixsug/`): `rename-function Dobro` com
   `#command DOBRA <k> => <k> := Dobro( <k> )` recusa às CEGAS — o oráculo
   pega a divergência de símbolos no re-compile, mas a ferramenta não sabe
   ONDE na diretiva o nome vive. Recusa honesta, porém não-acionável: não
   nomeia o site, não pode oferecer a edição.
2. **`rename-dsl` só renomeia a CABEÇA.** Palavras secundárias do match
   (`ACTION`, `AT`, `TAMANHO`) e palavras de RESTRIÇÃO
   (`<m: RAPIDO, LENTO>`) não são fatos com posição.
3. **`usages`** não nomeia sites dentro de diretivas: identificador citado
   em corpo de regra é invisível (nem `possible`).
4. A cabeça editada pelo `rename-dsl` de hoje é **reancorada
   TEXTUALMENTE** no `#<kind>` (a linha registrada da regra é a última
   física da diretiva continuada) — funciona, mas é o último resquício de
   busca textual onde deveria haver posição-fato.

A lacuna é de EXPORTAÇÃO, não de conhecimento: o pp parseia a diretiva e
sabe o papel de cada token (literal, marker e seu tipo, grupo opcional,
restrição) — nada disso chega ao dump. `ppRules` hoje: `id, kind, file,
line, head, markers` (um CONTADOR).

## Como o pp funciona por dentro (estudo do .ppt + fonte, 2026-07-07)

Registro pedido pelo Diego: o `.ppt` (`-p+`) foi gerado e analisado com uma
DSL adversarial (probe `pptprobe/forja.ch`: multi-marker, keyword
secundária, cláusula opcional, marker de lista, restrição, wild,
stringify, multi-passe). Aprendizados que informam o desenho:

- **Pipeline numa MESMA linha**: `#define` aplica primeiro, depois
  `#[x]translate` (de dentro para fora), por último `#[x]command` sobre a
  statement já expandida — no probe, `FORJA oF TAMANHO DOBRO(
  LARGURA_PADRAO )` chega ao match do FORJA como `FORJA oF TAMANHO ( ( 42
  ) * 2 )`. Consequência (já provada na B4): recheio de marker pode ser
  token SINTETIZADO (col null) com rastro `from` copiado no instante.
- **O trace é SÓ TEXTO**: pares `arquivo(linha) >fonte<` /
  `#[x]kind >resultado<` (ppcore.c:5086-5100). Sem posições, sem
  atribuição de marker, sem identidade de regra (só a família via `mode`).
  `ppApplications` é estritamente mais rico; o `.ppt` segue como
  instrumento de validação cruzada 1:1 (S5/caso 42) — nada a importar
  dele para o schema.
- **`(concatenate)` é um segundo ponto de trace** fora do funil
  (`hb_pp_concatenateKeywords`, ppcore.c:5343-5392): a colagem de keywords
  adjacentes é transformação SEPARADA de patternReplace — e já é coberta
  pelo rastro `from` op 'p' (`hb_pp_drvMerge` no mesmo ponto, B4d). A
  regra-por-dentro NÃO toca esse caminho.
- **Cláusula opcional no resultado** só emite quando o marker casou
  (`[, <r> ]` sumiu no uso sem ROTULO); **restrição** casa alternativa
  literal (`<m: RAPIDO, LENTO>` + `MODO RAPIDO` → `"RAPIDO"`); **wild**
  engole até o fim da linha e vira string via stringify.
- Regras vivem em listas **LIFO** (`pState->pCommands`/`pTranslations`,
  ppcore.c:4205-4218); abreviação dBase ≥4 letras no match — ambos já
  consumidos pela ferramenta (`RuleHeadCollision`).

## Fatos verificados (2026-07-07, evidência arquivo:linha — não re-sondar)

| # | Fato | Fonte |
|---|------|-------|
| 1 | **A regra REUSA os objetos de token da linha da diretiva**: `directiveNew` faz SPLICE (não cópia) — `pMatch = pToken->pNext` / `pResult = pToken->pNext` cortados no `=>`. | ppcore.c:4042-4054 |
| 2 | **posTbl é hash por PONTEIRO com cheque de identidade** (valor ptr + len); entrada nunca é removida no free — `posFind` só devolve quando o token ainda carrega o valor registrado (ponteiro reciclado com outro conteúdo falha o cheque, por desenho). Tokens de regra vivem até `hb_pp_reset` → suas entradas são consultáveis enquanto ninguém trocar o VALUE do token. | ppcore.c:514-607 |
| 3 | **Conversão de marker preserva o objeto do token-nome**: `SETTYPE` muda só o type (identidade valor/len intacta) + `index` do marker; a SINTAXE (`<`, `>`, `#`, `[`, `]`, `:` da restrição) é liberada/reescrita no registro. Restrição/grupo opcional ficam em `pMTokens` do token-marker. | ppcore.c:4089-4150, 4180-4186 |
| 4 | **O gancho de registro JÁ EXISTE**: `hb_pp_trackRule` dispara com a regra montada — `'d'` (define, ppcore.c:3526), `'c'`/`'t'` (command/translate, ppcore.c:4220). É o lugar do snapshot. | ppcore.c:971-980, 3526, 4220 |
| 5 | **Papéis de token têm vocabulário pronto no pp**: match `HB_PP_MMARKER_REGULAR/LIST/RESTRICT/WILD/EXTEXP/NAME/OPTIONAL`; result `HB_PP_RMARKER_REGULAR/STRDUMP/STRSTD/STRSMART/BLOCK/LOGICAL/NUL/OPTIONAL/DYNVAL/REFERENCE`. Opcional é token-marker nos DOIS lados (grupo em `pMTokens`) — representação homogênea. | include/hbpp.h:125-142 |
| 6 | O trace `.ppt` sai do MESMO funil das aplicações (`hb_pp_patternReplace`) — ordem do `.ppt` == ordem de `ppApplications` (provado 1:1 na S5/caso 42). | ppcore.c:5086-5100; caso 42 |
| 7 | `#define` com corpo segue o MESMO formato de regra (pMatch/pResult; caso degenerado sem markers ou com pseudo-função `<x,y>`) — registro em `defineAdd` (fato 4, 'd'). | ppcore.c:3480-3526 |

## Probes ANTES do volume (executor; scratchpad; compilar tudo -w3 -es2)

| # | Pergunta | Método | Fallback se falhar |
|---|----------|--------|--------------------|
| P1 | Tokens LITERAIS de `pMatch`/`pResult` retêm entrada viva na posTbl no fim do parse? (risco: uppercase/`tokenSetValue` no caminho de registro mataria a identidade) | patch experimental: no `hb_pp_trackRule`, caminhar as listas e imprimir `posFind` de cada token; conferir byte-exato contra o `.ch` do probe forja | **snapshot no registro** (desenho abaixo) — que é o desenho preferido de qualquer forma; P1 só decide se o snapshot pode ler da posTbl ou precisa de outra fonte |
| P2 | O token-marker sobrevivente é o do NOME (`<nome>` → token `nome`)? Sua posição aponta o nome no `.ch`? | mesmo patch de P1 sobre os markers | exportar marker sem posição do nome (papel+índice bastam para os comandos previstos; posição do nome é nice-to-have) |
| P3 | Diretiva CONTINUADA por `;`: cada token com sua linha física real? (mata a reancoragem textual do rename-dsl) | probe com diretiva de 3 linhas físicas | manter a reancoragem atual SÓ para a cabeça (documentada como resquício) |
| P4 | Grupo opcional do MATCH (`[...]`): confirmar `MMARKER_OPTIONAL` com grupo em `pMTokens` e literais internos com posição (ler `hb_pp_matchPatternNew` — ainda não lido) | leitura + probe | representar opcional como span achatado sem recursão |
| P5 | Regra definida DENTRO de expansão de outra regra (cstruct-style, caso 73): tokens da diretiva sintetizada — posições honestas (col null/prov da origem)? | probe com `#xcommand` que gera `#define` na expansão | nada a consertar: col null JÁ É o relato honesto; só documentar no ast-schema |

## Desenho — core (schema ast-5)

`ppRules[]` ganha `match[]` e `result[]`, um item por token, **achatado**
(grupo opcional = tokens `role: "opt-open"`/`"opt-close"` reconstruíveis
por pilha — o padrão de `blocks[]`; sem árvore no schema):

```jsonc
"match": [
  { "text": "FORJA",  "type": 21, "role": "literal",
    "line": 5, "col": 9, "len": 5, "prov": "i" },
  { "text": "nome",   "role": "marker", "marker": 1, "mkind": "regular" },
  { "text": "TAMANHO","role": "literal", ... },
  { "role": "opt-open" },                       // [ ROTULO <r> ]
  { "text": "ROTULO", "role": "literal", ... },
  { "text": "r", "role": "marker", "marker": 3, "mkind": "regular" },
  { "role": "opt-close" },
  { "text": "RAPIDO", "role": "restrict", "marker": 2, ... } ],  // <m: RAPIDO, LENTO>
"result": [
  { "text": "nome", "role": "marker", "marker": 1, "mkind": "regular" },
  { "text": ":=",   "type": ..., "role": "literal", ... },
  { "text": "ForjaNova", "role": "literal", "line": 6, "col": 15, ... },
  { "text": "nome", "role": "marker", "marker": 1, "mkind": "strdump" } ]
```

- `mkind` usa o vocabulário do pp (fato 5): match
  `regular|list|restrict|wild|extexp|name`; result
  `regular|strdump|strstd|strsmart|block|logical|nul|dynval|reference`.
  `marker` = índice 1-based (o MESMO que `ppApplications[].tokens[].marker`
  — as duas seções se ligam por ele).
- Posições `line/col/len/prov` pelas MESMAS regras de `tokens[]` (col
  byte-exata ou null; prov 's'/'i'/'n'). Regra builtin: `match`/`result`
  presentes com posições null (`file: null` já existe).
- **Snapshot no instante do registro** (padrão B4d "cópia no instante"):
  `hb_pp_trackRuleAdd` (ppcore.c:942) caminha `pMatch`/`pResult` e grava
  texto+papel+posição na tabela lateral da regra — imune a qualquer
  mutação posterior do token. Gancho NOVO: zero (o `trackRule` já dispara
  nos três pontos, fato 4). Lógica nova toda no pp-side, gated
  `fTrackPos`; tabela limpa em `hb_pp_reset`; accessors em `hbpp.h`;
  emissão em `compast.c`. Schema → **ast-5**.
- **Zero impacto sem `-x`**: prova padrão — varredura src/ com/sem `-x`
  `.hrb` byte-idênticos em **-w0 E -w3**; binário sem `-x` idêntico;
  relink duplo `harbour` E `hbmk2` conferido
  (`strings $HB_BIN/hbmk2 | grep ast-5`).
- Leitor `ReadAst` aceita ast-4|ast-5; comandos que exigem regra-por-dentro
  recusam dump antigo (padrão `FromReady`).

## Desenho — ferramenta

Tudo construto-agnóstico: os papéis vêm do parse que o PP faz da regra —
régua do caso 64 (nenhuma palavra de DSL em `src/hbrefactor.prg`).

1. **`usages <nome>`, seção nova**: identificador citado DENTRO de regra —
   `in rule result (#command DOBRA, forja.ch:6, col 15)` /
   `in rule match (keyword)` / `in rule restriction`. Fecha o último
   esconderijo de um nome.
2. **`rename-function` (e família)**: nome presente em `result[]` de regra
   do projeto → a recusa do caso 74 passa a NOMEAR diretiva+posição
   (acionável); com **`--edit-rules`** (opt-in), edita o token na diretiva
   junto com os sites normais e re-verifica com o oráculo de sempre (mapa
   de símbolos + rollback). Regra builtin (`file: null`) → relato, nunca
   edição.
3. **`rename-dsl` estendido**: palavra SECUNDÁRIA do match e palavra de
   RESTRIÇÃO viram renomeáveis — mesma verificação padrão-ouro
   (`.ppo` E `.hrb` de todos os módulos byte-idênticos + rollback +
   ida-e-volta A→B→A). Colisões: mesma política da cabeça
   (`RuleHeadCollision`, abreviação dBase nos dois sentidos, captura por
   identificador existente).
4. **Cabeça por posição-fato**: a reancoragem textual do `rename-dsl`
   morre (P3) — a posição da cabeça vem de `match[0]`.
5. **Extensão VSCode** (regra da casa: capacidade nova chega à extensão na
   MESMA fase): saída nova do `usages` já flui pelo canal textual; se
   `--edit-rules` nascer, o `cmdRenameFunction` ganha o mesmo padrão
   confirm-then-force dos demais.

## Casos adversariais (fixtures novas ou estendidas)

- `forja.ch` do probe promovido a fixture (multi-marker, opcional, lista,
  restrição, wild, stringify) — `match[]`/`result[]` conferidos **campo a
  campo contra o `.ch`** (byte-exato nas posições).
- **Caso 74 upgrade**: recusa nomeando o site; `--edit-rules` com
  round-trip A→B→A byte-exato + execução idêntica.
- Palavra secundária renomeada (`TAMANHO`→`MEDIDA`) e palavra de restrição
  (`RAPIDO`→`VELOZ`, editando restrição + usos) — `.ppo`/`.hrb`
  byte-idênticos.
- Diretiva continuada por `;` (posições por linha física; edição de cabeça
  e de literal interno).
- Regra definida dentro de expansão (caso 73/cstruct): relato honesto
  (posições null), nunca edição.
- Homônimo por papel: função `X` no projeto + literal `X` em regra
  não-relacionada + marker de nome `X` — sites distinguidos por papel, sem
  vazamento entre mundos.
- `#define` com corpo: nome de função no valor (`#define CALC Dobro(2)`),
  hoje invisível — mesmo tratamento de `result[]`.
- Regra builtin usada no módulo: `match[]`/`result[]` sem posição; comandos
  de edição recusam nomeando o motivo.

## Critério de pronto (mecânico)

1. ast-5 com zero impacto provado (padrão B4f: `.hrb` -w0 E -w3
   byte-idênticos com/sem `-x` na varredura de src/; relink duplo
   conferido).
2. `match[]`/`result[]` byte-exatos contra os `.ch` das fixtures
   (incl. continuada e opcional aninhado no match).
3. Caso 74 upgrade verde (recusa acionável + `--edit-rules` round-trip
   byte-exato + execução idêntica).
4. Renames de secundária e restrição verdes com `.ppo`/`.hrb`
   byte-idênticos em todos os módulos.
5. `usages` nomeando sites em regra nas fixtures; régua do caso 64
   assertada (nenhuma palavra das DSLs de fixture na ferramenta/core).
6. Suíte inteira verde; `make lexdiff` sem divergência nova.
7. ast-schema.md + roadmap.md atualizados no MESMO commit do
   comportamento (regra da casa); extensão coberta (item 5 do desenho).

## Portão

Executar P1-P5 e apresentar ao Diego: resultados dos probes + schema
draft ajustado + qualquer surpresa (vira fato numerado aqui). Só então o
volume de core. Autorizações de commit continuam por-commit, como sempre.
