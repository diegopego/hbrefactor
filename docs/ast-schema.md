# Schema `ast-3` — o dump AST do compilador (spec)

Contrato entre o harbour patchado (branch `feature/compiler-ast-dump`,
arquivos `src/compiler/compast.c` + rastreamento de regras e de derivação
em `src/pp/ppcore.c`) e o hbrefactor. Um `.ast.json` por módulo compilado
com `-x`. O `ast-3` (fase B4d) = `ast-2` (fase B4) + o campo `from` (rastro
de derivação) nos tokens SINTETIZADOS; o `ast-2` = `ast-1`
(commit `2cca58e4b8`) + seções `ppRules`/`ppApplications`. Todo o resto é
idêntico byte a byte entre as versões.

**Como gerar** (a ferramenta faz isso via `AstDumps()`):
```
hbmk2 <alvos-do-projeto> -hbcmp -rebuild -q '-prgflag=-x<dir>/'
# → <dir>/<módulo>.ast.json por módulo. -rebuild: obrigatório com -inc.
# Direto: harbour f.prg -n -q2 -gh -o... -x<dir>/   (-x só salva quando há
# geração de saída: -gh/-gc; NÃO salva com -s)
```

**ARMADILHA de relink (custou um diagnóstico)**: o hbmk2 compila .prg com
o compilador EMBUTIDO (linka `libhbcplr`/`libhbpp`) — um hbmk2 velho emite
dumps do schema ANTIGO mesmo com o `bin/.../harbour` novo (visto na B4:
ast-1 sem `ppRules` via hbmk2, ast-2 pelo harbour direto; vale igual para
ast-2 sem `from` via hbmk2 enquanto o harbour emite ast-3). Conferência:
`strings $HB_BIN/hbmk2 | grep ast-`; cura: `rm $HB_BIN/hbmk2 && make`.

## Topo

```jsonc
{ "schema": "ast-3",           // versão emitida hoje (ast-1→ast-2→ast-3)
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
  colado em `UWMENU_PAINT`) não nasce com coluna própria — mas o token
  sintetizado carrega o campo `from` (ast-3, abaixo) apontando de QUAL
  marker cada faixa de bytes deriva. É a proveniência da COLAGEM e do
  STRINGIFY, não só do clone; fecha a lacuna que a B4 (`ppApplications`)
  só cobria pela posição do span casado.
- Tokens EOL não são emitidos. Linhas de diretiva (#...) não chegam ao
  parser (o pp as consome) — sem tokens.
- Tokens de `#include` aparecem com prov 'i' e line do ARQUIVO INCLUÍDO
  (col null) — filtrar por prov ao mapear para o módulo.

### Campo `from` — rastro de derivação do token sintetizado (ast-3)

Todo token que o pp SINTETIZA a partir de uma regra (colagem de keywords,
recheio de marker clonado, string de stringify) carrega `from`: um array
com um item por FAIXA DE BYTES derivada dentro do `text` deste token.
Registrado em `ppcore.c` no instante da síntese (mesmo padrão da posTbl da
B0: lógica no pp, ganchos de 1 linha gated por `fTrackPos`, tabela por
módulo limpa em `hb_pp_reset`, accessors em `hbpp.h`, emissão em
`compast.c`). Genérico por construção: vale para hbclass.ch e para qualquer
diretiva já existente ou inventada.

```jsonc
{ "line": 0, "col": null, "len": 12, "type": 21, "prov": "n",
  "text": "UWMenu_Paint",
  "from": [ { "app": 12, "marker": 2, "op": "paste", "at": 0, "len": 6 },
            { "app": 12, "marker": 1, "op": "paste", "at": 7, "len": 5 } ] }
```

- `app`: índice em `ppApplications[]` da aplicação de onde a faixa deriva
  (0-based, MESMA indexação que `ppApplications[].rule` usa contra
  `ppRules`). O `from` só referencia aplicações ANTERIORES (multi-passe:
  proveniência sempre para trás).
- `marker`: número do match marker (1-based) daquela aplicação de onde a
  faixa veio — o marker carrega a EXPRESSÃO inteira; `at`/`len` recortam só
  o nome.
- `op`: a operação de síntese —
  - `"clone"`: recheio de marker copiado no resultado (preserva posição);
  - `"paste"`: concatenação de keywords do resultado
    (`<Class>_<Method>` => `UWMENU_PAINT`);
  - `"stringify"`: marker despejado numa string (`<"Method">` => `"Paint"`).
- `at`/`len`: offset e comprimento EM BYTES da faixa dentro do `text` DESTE
  token. O separador LITERAL entre partes coladas (o `_` de `UWMENU_PAINT`,
  o `on_` de `on_Click`) é texto da própria regra e NÃO tem item `from`.
  Uma string de stringify puro tem um único item `op: "stringify"` com
  `at: 0`.

Exemplos provados (fixtures fixmth/fixppm):
- hbclass: `UWMenu_Paint` (função gerada, type 21, prov 'n') traz
  `from = [ {paste, marker de UWMenu, at 0 len 6}, {paste, marker de Paint,
  at 7 len 5} ]`; a string `"Paint"` do registro traz
  `from = [ {stringify, marker de Paint, at 0 len 5} ]`.
- DSL de prefixo (`#xcommand HANDLER <n> => FUNCTION on_<n>`): `on_Click`
  traz `from = [ {paste, marker de Click, at 3 len 5} ]` — só a faixa do
  nome; `on_` é literal da regra, sem `from`.

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
- Os tokens CONSUMIDOS aqui também podem trazer `from` (ast-3, mesmo
  formato de `tokens[]`): quando o token consumido é RESULTADO de uma
  expansão anterior (multi-passe), a proveniência é copiada no INSTANTE da
  aplicação — o token morre com a substituição, então a cópia tem que ser
  feita ali. É o que dá o fecho de derivação transitivo (clone-de-composto)
  sem depender do token ainda estar vivo depois.
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
- **Modelo de NOME DE MARKER (B4d) — substitui as âncoras por forma da B4c**:
  nome de marker = o valor que o programador escreve e que preenche um match
  marker (`<x>`) de uma diretiva de pp, atravessando-a. Sobre o `from` (ast-3):
  - **Sementes** (`PpMarkerSeeds`): pares `(aplicação, marker)` alimentados
    pelo nome escrito; fecho transitivo numa passada (o `from` só referencia
    aplicações anteriores, então uma varredura para trás basta).
  - **Artefatos** (`PpMarkerArtifacts`/`PpMarkerRanges`): tokens cujo `from`
    alcança as sementes; a FAIXA (`at`/`len`) soletra o nome — recorte
    byte-exato, porque o marker carrega a expressão inteira e a faixa
    devolve só o nome. Resolução recursiva por clone-de-composto no
    multi-passe (usa o `from` copiado nos tokens consumidos de
    `ppApplications`).
  - **Donos** (`PpMarkerOwners`) por CO-DERIVAÇÃO: no hbclass são as classes;
    genérico = o OUTRO nome da co-derivação — `paste` que nomeia uma função
    torna esse outro nome dono; `stringify` contido numa função gerada por
    expansão torna o nome dela dono.
  - Send site editável = token type 21 cujo anterior é type 58
    (`SendLineHits`, inalterado). Atribuição a membro vira send `_NOME` —
    detector de VAR/DATA (rename recusa).
  - As âncoras por FORMA da B4c (`ClassRegs`/`StmtStrings`/`DeclHits`/
    `MethodLift`) foram REMOVIDAS do código: não há mais colagem `_`
    tentada nem comparação de STRING == nome de função.
- **Verificação quando o pcode muda de verdade** (rename-pp-marker/
  rename-method): o módulo da classe embute os nomes de mensagem em strings
  de registro — não há byte-idêntico. O mapa de símbolos/strings esperado
  é COMPUTADO do rastro (`PredictText`: substitui as faixas do nome de marker
  pelo nome novo em cada artefato), não mais declarado à mão. A saída do
  rename mostra `predicted: SIMBOLO -> NOVO` e `predicted string: ...`;
  `HrbSymbolsRenamed` confere cada símbolo/string prevista no dump
  pós-edição, os demais módulos seguem `HrbEquivalent` byte-idênticos e a
  execução idêntica fecha o contrato na suíte. Recusa por co-derivação
  (G5): símbolo previsto que já existe como função → recusa NOMEANDO o
  artefato; fonte que soletra manualmente um nome gerado que mudaria →
  recusa apontando o site órfão.
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
- **Lifting generalizado** (`PpMarkerLift` + `SeedRootRule`, substitui
  `MethodLift`): `usages <nome>` responde no VOCABULÁRIO DO FONTE usando a
  CABEÇA DA REGRA RAIZ que consumiu o nome — `method definition` no
  hbclass, `handler definition` numa DSL de handlers, `registro
  definition` etc. — sem nenhuma tabela por família. O nome GERADO
  (`UWMENU_PAINT`, `ON_CLICK`...) só aparece com `--show-expansion`. Vale
  para qualquer diretiva existente ou inventada; não há mais colagem
  `<A>_<B>` tentada. (`RuleHeadCollision` sobre `ppRules`, com abreviação
  dBase incluída, segue cobrindo a colisão de cabeça de regra.)
- **Assinatura de param de método (B4e P1a)** (`SigParamHits` +
  `GenNameParts`): renomear o param de um método precisa mover a DECLARAÇÃO
  fora do corpo — o protótipo no `CREATE CLASS` e a linha `METHOD ... CLASS`.
  Em `tokens[]` a posição dessas duas assinaturas COLAPSA para a do protótipo
  (clone multi-passe → mesma linha/col), então o span da função (que usa
  `tokens[]`) só alcança os usos do CORPO. Os sites da assinatura só têm
  posição byte-exata em `ppApplications` (markers posicionados, `prov 's'`,
  `marker >= 1`). Coleta: os apptokens cujo texto é o param, em aplicações que
  carregam TODA a IDENTIDADE do nome gerado — as partes de colagem do composto
  `<Classe>_<Metodo>` que `GenNameParts` extrai do `from` (`{ CLASSE, METODO }`)
  — presentes como markers posicionados na MESMA aplicação. Isso escopa ao
  método certo sem colher param homônimo de outro método/classe (fato provado:
  nenhuma aplicação de expansão mistura dois métodos). Dedup por posição-fonte
  (`AddHit`): a assinatura reaparece em várias aplicações. O hbclass casa
  protótipo↔implementação pela assinatura INTEIRA (nomes de param inclusos), então
  os três sites TÊM que mover juntos, senão `W0001 declaration mismatch`; nome de
  param não entra no pcode, então a verificação byte-idêntica dos `.hrb` vale.
- **reorder-params ciente de método (B4e P1b)** (`SendSitesArgs` + `ArgSpansAt`
  + `PpMarkerOwners`): reordenar os params de um método reordena (a) a
  ASSINATURA — protótipo + `METHOD ... CLASS`, pelos mesmos sites de
  `ppApplications` da P1a (`SigParamHits`), o corpo intacto; e (b) os
  ARGUMENTOS nos call sites de SEND. O recorte de argumentos (balancear o
  stream por tipo a partir de nome+`(`, quebrar em vírgulas de nível 1,
  materializar por `BuildArgSpan`) foi extraído de `CallSitesArgs` para
  `ArgSpansAt` e reusado por `SendSitesArgs`, que ancora no token da MENSAGEM
  (type 21 posicionado, anterior `:` type 58, seguido de `(`). Send é despacho
  DINÂMICO: os sends não carregam classe, então só é seguro reordenar quando a
  mensagem pertence a UMA classe do projeto — `PpMarkerOwners` (donos por
  co-derivação) sobre o nome do método; > 1 classe ⇒ recusa NOMEANDO as classes
  (mesma política do rename-method). O pcode muda de verdade (ordem de push);
  a verificação é `HrbSymbolsEqual` (símbolos/funções intactos) + rollback, não
  byte-idêntico.
- **call-graph ciente de método (B4e P2b)**: um índice de MENSAGENS de método é
  montado do rastro — cada função gerada `<Classe>_<Metodo>` decompõe por
  `GenNameParts`, a última parte é a mensagem. `call-graph <método>`
  (bare/`Classe:Método`) resolve para o símbolo gerado e imprime a definição;
  os `sends` da mensagem viram arestas DINÂMICAS (`~>`, distintas das estáticas
  `->` de `calls`) com alvo `[dynamic: NOME_GERADO]`. Send é despacho dinâmico:
  não há aresta estática para inventar; mensagem homônima em N classes lista os
  N alvos (ambiguidade visível). Só sends cuja mensagem É método do projeto
  entram (filtra `:New`, acesso a VAR/DATA etc.).
- **find-dynamic-calls: ruído do `&` da expansão (B4e P3)** (`HasUserMacro`): a
  função gerada para o `CREATE CLASS` traz `usesMacro: true` por causa do `&`
  INTERNO do hbclass.ch, sem token `&` posicionado no fonte do usuário → falso
  positivo. Um macro REAL é token **type 22** posicionado (`prov 's'`, ex.:
  `&cVar.`); a flag só é reportada quando existe um desses no span de linhas da
  função. Strings que nomeiam função do projeto seguem relatadas (stringify da
  expansão tem `line 0`, já excluído por `line > 0`).

## Evolução

O schema é livre para evoluir (liberação de 2026-07-05: sem compromisso de
compatibilidade com a era occ). `ppRules` + `ppApplications` entregues no
ast-2 (fase B4, consumidos por usages/rename-dsl/lifting). O campo `from`
(rastro de derivação nos tokens sintetizados) entregue no **ast-3**
(fase B4d, 2026-07-06), consumido pelo modelo de nome de marker — usages
(lifting generalizado), rename-pp-marker e rename-method (açúcar). O schema
versionou de ast-2 para ast-3. O leitor da ferramenta (`ReadAst`) aceita
`ast-2` OU `ast-3`; comandos que EXIGEM o rastro (rename-method /
rename-pp-marker) recusam dump antigo pedindo recompilar `harbour` E `hbmk2`
do branch (`FromReady` = schema == `ast-3`). Próximo a avaliar: span
original de string no posTrack (mataria `StrDelimsOk`). Ao mudar,
versionar `"schema"` e atualizar este documento NO MESMO commit.
