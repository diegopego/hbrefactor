# Schema `ast-2` — o dump AST do compilador (spec)

Contrato entre o harbour patchado (branch `feature/compiler-ast-dump`,
arquivos `src/compiler/compast.c` + rastreamento de regras em
`src/pp/ppcore.c`) e o hbrefactor. Um `.ast.json` por módulo compilado
com `-x`. O `ast-2` (fase B4) = `ast-1` (commit `2cca58e4b8`) + seções
`ppRules`/`ppApplications`; todo o resto é idêntico byte a byte.

**Como gerar** (a ferramenta faz isso via `AstDumps()`):
```
hbmk2 <alvos-do-projeto> -hbcmp -rebuild -q '-prgflag=-x<dir>/'
# → <dir>/<módulo>.ast.json por módulo. -rebuild: obrigatório com -inc.
# Direto: harbour f.prg -n -q2 -gh -o... -x<dir>/   (-x só salva quando há
# geração de saída: -gh/-gc; NÃO salva com -s)
```

**ARMADILHA de relink (custou um diagnóstico)**: o hbmk2 compila .prg com
o compilador EMBUTIDO (linka `libhbcplr`/`libhbpp`) — um hbmk2 velho emite
dumps do schema ANTIGO mesmo com o `bin/.../harbour` novo (visto: ast-1
sem `ppRules` via hbmk2, ast-2 pelo harbour direto). Conferência:
`strings $HB_BIN/hbmk2 | grep ast-`; cura: `rm $HB_BIN/hbmk2 && make`.

## Topo

```jsonc
{ "schema": "ast-1",
  "generator": "Harbour 3.2.0dev (...)",
  "module": "core.prg",          // nome capturado no PARSE (não o -o)
  "hasCDump": false,             // módulo tem #pragma BEGINDUMP
  "tokens": [...], "functions": [...] }
```

## `tokens[]` — o stream que o compilador consumiu

Um item por token entregue ao parser (yylex), na ordem de consumo. O ÍNDICE
no array é a identidade referenciada por `statements[].expr.tok` e
`blocks[].tok`.

```jsonc
{ "line": 42,      // linha FÍSICA no arquivo indicado por prov
  "col": 8,        // coluna 0-based em BYTES na linha física; null = sem
                   // posição no fonte (sintetizado por regra de pp, veio de
                   // include, separador). REGRA DE OURO: col não-null é
                   // byte-exato — fonte[line][col..col+len) == text para
                   // identificadores (para strings, text é o valor
                   // NORMALIZADO; o span original inclui delimitadores)
  "len": 6,
  "type": 21,      // HB_PP_TOKEN_TYPE: 21=identificador/keyword, 41=string,
                   // 42=número, 30=';' separador, 58=SEND ':', 59=ALIAS '->',
                   // 50/51='(' ')' ... (include/hbpp.h)
  "prov": "s",     // 's' = fonte principal COM posição; 'i' = include;
                   // 'n' = sintetizado (texto de regra, sem coluna)
  "text": "nTotal" }
```

Garantias e limites (provados na fixture de tortura e no lexdiff):
- Identificador que atravessa regra de pp via **match marker** mantém
  linha/coluna do fonte original (inclusive stringify `#<x>`).
- TAB conta como 1 byte (coluna byte-exata, não visual).
- Statement continuado por `;`: cada token carrega sua linha física real.
- Operadores de 1 caractere costumam vir com col=null (call sites literais
  no tokenizer do pp) — não conte com coluna de pontuação. Isso inclui
  `( ) [ ] { } , := |`: **fechamentos e vírgulas nunca têm coluna**.
- STRING (type 41): `col` aponta o **conteúdo** (o delimitador de abertura
  está em col-1) e `len` é o comprimento do valor NORMALIZADO. O span
  original só é reconstruível para string trivial (delimitador + conteúdo
  byte-idêntico + fechamento casando: `".."`, `'..'`, `[..]`); string com
  escape (`e"..."`) não confere byte a byte — valide e recuse (padrão
  `StrDelimsOk`/`TokStartCol`/`TokEndCol` no fonte da ferramenta).
- Nome consumido pela regra SEM marker (ex.: `METHOD Paint() CLASS UWMenu`
  colado em `UWMENU_PAINT`) NÃO aparece com posição — é a lacuna que a fase
  B4 (`ppApplications`) cobre.
- Tokens EOL não são emitidos. Linhas de diretiva (#...) não chegam ao
  parser (o pp as consome) — sem tokens.
- Tokens de `#include` aparecem com prov 'i' e line do ARQUIVO INCLUÍDO
  (col null) — filtrar por prov ao mapear para o módulo.

## `ppRules[]` + `ppApplications[]` — as regras de pp e cada aplicação (ast-2)

A lacuna que estas seções fecham: as PALAVRAS de uma DSL de pp
(`REPEAT`, `MENUITEM`, `ACTION`, `METHOD`...) são consumidas pelo
preprocessador e nunca chegam ao yylex — não existem em `tokens[]`.
O rastreamento fica em `ppcore.c` (mesmo padrão da posTbl da B0: lógica
no pp, ganchos de 1 linha gated por `fTrackPos`): registro no funil
único de aplicação (`hb_pp_patternReplace`) e nos pontos de registro de
`#define`/`#[x]translate`/`#[x]command`.

```jsonc
"ppRules": [
  { "id": 2,               // índice estável no módulo; referenciado por
                           // ppApplications[].rule
    "kind": "command",     // define|translate|xtranslate|command|xcommand
    "file": "menu.ch",     // arquivo da DIRETIVA; null = regra builtin
                           // (std rules compiladas, -D, dyn defines)
    "line": 3,             // linha da diretiva (0 quando builtin)
    "head": "MENUITEM",    // palavra-cabeça; null se a regra começa com
                           // match marker
    "markers": 4 } ],      // nº de match markers da regra

"ppApplications": [        // UMA entrada por aplicação, na ORDEM em que o
                           // pp as fez (multi-passe visível: aplicação
                           // sobre resultado de outra regra aparece depois)
  { "rule": 2, "line": 8,  // linha de input corrente na aplicação
    "tokens": [            // os tokens CONSUMIDOS (o span casado no fonte)
      { "line": 8, "col": 3, "len": 8, "type": 21, "prov": "s",
        "marker": 0,       // 0 = palavra/literal DA PRÓPRIA REGRA;
                           // N = recheio do match marker N (1-based)
        "text": "MENUITEM" } ] } ]
```

Garantias e limites (provados no smoke test da B4):
- **Palavra de DSL** = token com `marker == 0`: em aplicação no módulo
  principal vem com linha/coluna byte-exatas (`prov 's'`) — é a posição
  que `usages-dsl`/`rename-dsl` editam. Regras builtin aplicadas
  aparecem com `file: null` (registro lazy na 1ª aplicação).
- Recheio de marker (`marker == N`) segue as MESMAS regras de posição de
  `tokens[]`: identificador que atravessou por marker mantém posição;
  token vindo de expansão anterior (multi-passe) vem com `col null` e
  linha/prov apontando a ORIGEM (ex.: valor de `#define` aponta a linha
  do `.ch`, `prov 'i'`).
- `#[x]translate` opera SUBSTITUINDO no meio da statement (aplicações em
  qualquer posição); `#[x]command` só casa statement inteira e **o uso
  tem que estar numa linha só** (continuação exige `;`) — famílias
  distintas, testar ambas (nota do Diego, 2026-07-05).
- Aplicações dentro de includes vêm com tokens `prov 'i'` — filtrar
  como em `tokens[]`.
- Diretiva processada em linha lógica: `line` da regra/aplicação segue a
  convenção do pp (linha de input corrente). Para diretiva CONTINUADA por
  `;`, isso é a ÚLTIMA linha física — quem for editar a diretiva precisa
  reancorar no início físico (a linha `#<kind>` mais próxima, para trás;
  o pp aceita o nome da diretiva abreviado em >= 4 letras, ex. `#xtrans`).
  O mesmo vale para `ppApplications[].line` de USO continuado por `;`
  (aponta a última linha física do uso) — mas cada token consumido carrega
  a SUA linha/coluna físicas reais, então a edição por token não sofre.
- **Validação cruzada disponível**: `harbour -p+` gera `.ppt` com uma
  linha por aplicação — sai do MESMO funil (`hb_pp_patternReplace`);
  `ppApplications` deve casar 1:1 com o `.ppt` do módulo.
- **Armadilha std.ch em fixtures**: `#command ENDIF <*x*> => endif`
  (std.ch:71) tem wild marker que ENGOLE `; ENDDO` que venha atrás na
  expansão — `UNTIL <c> => IF <c> ; EXIT ; ENDIF ; ENDDO` perde o ENDDO
  (comportamento PRÉ-EXISTENTE do Harbour, provado em binário pristino).
  Forma que funciona: `IF <c> ; EXIT ; END ; END`.

## `functions[]` — um item por FUNCTION/PROCEDURE (+ pseudo-função fileDecl)

A primeira entrada com `"fileDecl": true` é o container do nível de módulo
(STATICs file-wide, código solto). Métodos de classe aparecem com o nome da
função de implementação gerada pelo hbclass.ch (`<CLASSE>_<MÉTODO>`).

```jsonc
{ "name": "MAIN", "kind": "procedure"|"function", "static": false,
  "fileDecl": false, "line": 5, "usesMacro": false,   // & macro no pcode
  "declarations": [   // variáveis declaradas, com escopo RESOLVIDO
    { "sym": "NTOTAL", "scope": "local"|"static"|"field"|"memvar"|"private",
      "declLine": 7, "used": 1, "param": false } ],
  "occurrences": [    // cada referência de variável (parse-time)
    { "sym": "NTOTAL", "scope": "local"|"detached"|"static"|"memvar"|
                        "field"|"memvar_implicit",
      "line": 12,     // ATENÇÃO: statement continuado → ÚLTIMA linha física
      "access": "read"|"write"|"ref"|"use",
      "block": false, // true = dentro de corpo de codeblock
      "filewide": true /* só quando static file-wide */ } ],
  "calls":  [ { "sym": "DUPLA", "line": 10, "block": false } ],
  "sends":  [ { "sym": "EVAL",  "line": 10, "block": false } ],
  "blocks": [   // eventos de estrutura de controle, do próprio parser
    { "kind": "if"|"while"|"for"|"case"|"switch"|"sequence",
      "event": "open"|"close", "line": 24, "tok": 118 } ],
  "statements": [   // árvore de expressão PRÉ-reduce de cada statement/push
    { "kind": "stmt"|"push", "line": 12, "block": false,
      "expr": { "et": "ASSIGN",          // nome do HB_ET_*/HB_EO_*
                "line": 12, "tok": 7,    // tok = índice em tokens[] no
                                         // NASCIMENTO do nó (aproximado ±1
                                         // por lookahead; use span da
                                         // subárvore p/ delimitar)
                "left":  { "et": "VARIABLE", "val": "NTOTAL", ... },
                "right": { "et": "NUMERIC",  "val": 0, ... } } } ] }
```

Filhos por `et`: operadores → `left`/`right` (unário: sem right);
`FUNCALL` → `fun`+`parms`; `SEND` → `msg`/`msgmacro`+`obj`+`parms`;
`ARRAYAT` → `base`+`index`; `ARRAY/HASH/LIST/ARGLIST/IIF` → `items[]`;
`CODEBLOCK` → `cbflags`+`body[]`; `ALIASVAR/ALIASEXPR` → `alias`+`var`+
`expr`; `SETGET` → `var`+`expr`; `MACRO` → `val`+`expr`; `RTVAR` → `val`.
Folhas com `val`: VARIABLE, FUNNAME, STRING (+ NUMERIC/LOGICAL/DATE).

Semânticas importantes:
- `stmt` = statement-expressão completo; `push` = expressão empurrada em
  contexto de valor (condição de IF/WHILE, valor de RETURN, limites de FOR).
- Sombra léxica JÁ DECIDIDA: em cada occurrence o `scope` é o que o
  compilador resolveu ali (parâmetro de codeblock homônimo = `local`+
  `block:true`; captura de local externa = `detached`).
- PRIVATE/PUBLIC com init aparecem em occurrences como `memvar` `write`
  (hook RTVar) + call `__MVPRIVATE`/`__MVPUBLIC`.

## Receitas de consumo (as que a ferramenta usa)

- **Coluna de um símbolo numa linha**: tokens com `type==21`, `prov=='s'`,
  `col!=null`, `Upper(text)==alvo` naquela linha.
- **Excluir contexto `:msg` / `alias->campo`**: pular token cujo ANTERIOR NO
  STREAM tem type 58 ou 59 (nível compilador — não use texto).
- **rename de LOCAL**: coletar por SPAN DA FUNÇÃO (da line da função até a
  line da próxima), não por linhas de occurrence (continuação `;` aponta a
  última linha física). Recusar antes: parâmetro de codeblock homônimo
  (occurrence `local`+`block` do velho OU do novo nome).
- **Continuação em call sites** (rename-function): resolver linha→tokens
  pelos SPANS DE ÍNDICE das statements dessa linha (min/max de `tok` na
  subárvore) + complemento por linha física (`LineTokens()` no fonte novo).
- **ARMADILHA do `tok` (birthTok)**: os índices nascem ATRASADOS pelo
  lookahead do bison (ex.: `NUMERIC 10` com tok apontando a vírgula seguinte;
  `FUNNAME` nasce ainda mais tarde). Servem para DELIMITAR statements
  (min/max de subárvore com folga), NÃO para recortar sub-expressões. Para
  argumentos de chamada: balancear o STREAM por TIPO de token a partir do
  padrão nome+`(` (ver `CallSitesArgs()` no fonte) — multi-linha de graça.
- **Recorte de argumento por span** (`BuildArgSpan()`): o argumento é uma
  FAIXA DE ÍNDICES do stream; o miolo é copiado entre o primeiro e o último
  token POSICIONADOS, strings são estendidas aos delimitadores (validação
  byte-exata) e os tokens de borda SEM posição (`)` `]` `}` `{` `|`...) são
  casados um a um contra o fonte pulando espaço/`;` — qualquer
  não-conferência (comentário no meio, escape) recusa. Sem isso,
  `Foo( Len( "a,b)c" ), 2 )` seria cortado no meio da string.
- **Edição de linha de declaração** (`DeclCutRange()`): decisão POR
  VARIÁVEL — o vão entre o nome e os vizinhos posicionados deve ser só
  espaço + UMA vírgula (a esquerda do primeiro nome: só espaço até o
  LOCAL; atrás do último: nada). `LOCAL nI, cI, cRet := ""` libera nI e cI
  mesmo com o inicializador de cRet na mesma linha.
- **Estrutura de controle**: `blocks[]` pareado por pilha (open/close da
  mesma kind) dá os pares { kind, linhaAbre, linhaFecha } — recusas de
  extração por estrutura cruzando borda saem daí, sem varrer texto.
- **Strings candidatas a call-by-name**: tokens `type==41` com `line>0` e
  texto identificador — nunca editar; relato + `--force`.
- **Stringify NÃO tem linha**: o token de string gerado por `<"v">` nasce
  sintetizado com `line 0`/`prov 'n'` (o clone de marker preserva posição
  do IDENTIFICADOR, não da string gerada). Guarda de recusa por nome-em-
  string deve varrer **sem** filtro de linha quando a verificação do
  comando não é byte-idêntica (lição do inline-local; rename sobrevive
  porque o `.hrb` byte-exato pega a string mudada).
- **Criadores de memvar (B4b)**: `PRIVATE x` gera declaration
  `scope 'private'` (declLine exata); `PUBLIC x` NÃO gera declaration —
  o fato é o call `__MVPUBLIC` na linha + occurrence memvar write/use na
  mesma linha (assimetria do compilador). Criação via macro
  (`PRIVATE &nome`): call `__MV*` SEM occurrence casada na linha = nome
  invisível ao compilador (furo). Occurrence memvar com `filewide: true`
  = referência resolvida pela declaração MEMVAR de nível de módulo.
- **Alcance dinâmico (B4b)**: fecho transitivo dos callees a partir do
  criador (`ReachFrom`), resolução de chamada STATIC-vence-no-módulo,
  senão pública de qualquer módulo, senão core (`CoreFunction` = seguro)
  ou FURO (função externa). Furos adicionais por função visitada:
  `usesMacro`, `sends` não-vazio, token string com nome de função do
  projeto no span (chamada dinâmica). Política do rename-memvar:
  1 criador + usos ⊆ alcance + zero furos no alcance; macro FORA do
  alcance nunca roda com o PRIVATE vivo → aviso + `--force`.
- **M-> é memvar**: token do nome após `->` (type 59) cujo token anterior
  ao alias é `M` = uso da própria memvar (editável); qualquer outro
  `alias->` e `:msg` (type 58) ficam de fora (`MvLineHits`).
- **Pureza p/ duplicar expressão** (`ExprPure()`): allowlist sobre os `et`
  da árvore — folhas NIL/NUMERIC/DATE/TIMESTAMP/STRING/LOGICAL/VARIABLE e
  combinadores IIF/LIST/OR/AND/NOT/EQUAL/EQ/NE/IN/LT/GT/LE/GE/PLUS/MINUS/
  MULT/DIV/MOD/POWER/NEGATE; o resto recusa (tabela completa de nomes em
  `s_szExprNames`, compast.c).
- **Init de LOCAL**: `LOCAL x := expr` gera statement `ASSIGN` (left =
  VARIABLE x, line = declLine) E occurrence `write` na declLine; um init
  por #define expande para tokens SEM posição — recorte do texto falha por
  construção (conservador).
- **Palavra de DSL** (`usages`/`DslHits`): definição = `ppRules` com
  `Upper(head) == alvo` (dedupe entre módulos por arquivo+linha+kind — o
  mesmo .ch registra a regra em cada módulo que o inclui); usos = tokens
  de `ppApplications` com `marker == 0` e o texto — cobre a cabeça E as
  palavras secundárias (ACTION, AT, SAY...), builtin incluso. Genérico
  por construção: só cabeça/kind/atribuição de marker, nada por família.
- **rename-dsl**: edita (a) os tokens `marker 0` posicionados das
  aplicações da regra e (b) a palavra no lado do MATCH da diretiva (antes
  do `=>`; reancorada no início físico — ver convenção de `line` acima;
  `#define` = só a 1ª ocorrência). Recusas fato-based: builtin
  (`file null`), diretiva fora do projeto, cabeça nova já regra/abreviação
  dBase (4 letras, famílias sem `x`), nome novo já identificador no stream
  (captura), aplicação sem posição (multi-passe/include), uso abreviado.
  Verificação padrão-ouro: rename consistente não muda a expansão →
  `.ppo` e `.hrb -gh -l` de TODOS os módulos byte-idênticos, senão
  rollback. O `.ppo`/`.ppt` gravam SEMPRE ao lado do fonte (independe de
  `-o`/cwd) — preservar um `.ppo` pré-existente do usuário.
- **Lifting método/classe** (`MethodLift`): função gerada por DSL casa com
  a aplicação NA MESMA LINHA cujos recheios de marker (identificadores
  posicionados) concatenam `A_B == nome da função` — devolve classe,
  método e a posição REAL do nome no fonte. Vale para qualquer DSL que
  cole `<A>_<B>` (hbclass.ch é o caso canônico); preferir o par cujo
  token está na linha da função (a aplicação DECLARED repete o nome com a
  posição da declaração). A convenção textual de sufixo da era smoke test
  morreu junto com `DefineCollision`/`PpHeadIn` (hoje `RuleHeadCollision`
  sobre `ppRules`, com abreviação dBase incluída).

## Evolução

O schema é livre para evoluir (liberação de 2026-07-05: sem compromisso de
compatibilidade com a era occ). `ppRules` + `ppApplications` entregues no
ast-2 (fase B4, consumidos por usages/rename-dsl/lifting). Próximo a
avaliar: `sends` de `__clsAddMsg` (rename-method, backlog); span original
de string no posTrack (mataria `StrDelimsOk`). Ao mudar, versionar
`"schema"` e atualizar este documento NO MESMO commit.
