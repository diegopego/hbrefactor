# Schema `ast-4` — o dump AST do compilador (spec)

Contrato entre o harbour patchado (branch `feature/compiler-ast-dump`,
arquivos `src/compiler/compast.c` + rastreamento de regras e de derivação
em `src/pp/ppcore.c`) e o hbrefactor. Um `.ast.json` por módulo compilado
com `-x`. O `ast-4` (fase B4f) = `ast-3` + o CANAL DE TIPOS DA LINGUAGEM
(seção `declared` + `declarations[]` parse-time tipadas — ver a seção
própria); o `ast-3` (fase B4d) = `ast-2` (fase B4) + o campo `from`
(rastro de derivação) nos tokens SINTETIZADOS; o `ast-2` = `ast-1`
(commit `2cca58e4b8`) + seções `ppRules`/`ppApplications`. Fora as adições,
tudo é idêntico byte a byte entre as versões — exceto `declarations[]`,
cuja fonte MUDOU no ast-4 (ver lá).

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
{ "schema": "ast-4",           // versão emitida hoje (ast-1→...→ast-4)
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
  "declarations": [   // ast-4: capturadas no PARSE (ver nota abaixo)
    { "sym": "NTOTAL", "scope": "local"|"static"|"field"|"memvar"|
                        "private"|"public",
      "declLine": 7, "param": false,
      "type": "S",             // só quando declarado (AS <tipo>): caractere
                               // do compilador - N C D L B A O S; minúscula
                               // = ARRAY do tipo ('s' = AS CLASS ARRAY)
      "class": "CAIXA" } ],    // só em AS CLASS: o NOME COMO ESCRITO
                               // (sobrevive à classe não registrada)
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

## Canal de tipos da linguagem (ast-4, fase B4f)

A GRAMÁTICA do compilador aceita declarações de tipo opcionais — `AS
<tipo>`/`AS CLASS <nome>` em TODA declaração de variável (lexer
complex.c:110 `{"AS"}`, tabela complex.c:205-224; produções
harbour.y:341-368) e o subsistema `DECLARE` (funções globais com assinatura
e retorno; classes; métodos — `DECLARE`/`DECLARE_CLASS`≡`_HB_CLASS`/
`DECLARE_MEMBER`≡`_HB_MEMBER`, complex.c:114/158/159, harbour.y:1226-1330).
Harbour continua NÃO tipado em runtime: esses fatos eram write-only
(warnings -w3, zero efeito em pcode) e o ast-4 os TRANSPORTA 1:1 — sem
nenhuma convenção de biblioteca no core.

### `declarations[]` mudou de fonte no ast-4

Até o ast-3 a lista era escrita no FIM do módulo a partir das listas vivas
do compilador — PÓS-otimizador de pcode, que APAGA locais ("Selfifying" +
"Delete unused", hbopt.c): o `Self` de método e locais nunca usadas não
apareciam. No ast-4 a captura é no PARSE (gancho em `hb_compVariableAdd`):

- o `Self` de todo método aparece, com `"type": "S"` e `"class"` (o
  hbclass expande `local Self AS CLASS <C>` — hbclass.ch:263-265);
- locais deletadas pelo otimizador aparecem;
- `PUBLIC` ganha escopo próprio; PRIVATEs aparecem em qualquer -w (antes
  só com -w3);
- o campo `used` MORREU (era do pós-otimizador; derive de `occurrences[]`);
- `"class"` carrega o nome COMO ESCRITO, mesmo quando a classe não está
  registrada no módulo (o compilador degradaria `cType` p/ 'O' e perderia
  o nome — hbmain.c:463-478).

### Seção `declared` (nível de módulo) — as tabelas DECLARE

```jsonc
"declared": {
  "classes": [                    // DECLARE CLASS / _HB_CLASS (hbclass)
    { "name": "CAIXA", "methods": [
        { "name": "NEW", "type": "S", "class": "CAIXA",   // ctor declara
          "params": [ { "type": "N", "byref": false, "optional": false } ] },
        { "name": "SOMA", "params": [ ... ] } ] } ],      // sem AS: sem type
  "functions": [                  // DECLARE f(...) AS ... + auto-declaração
    { "name": "CAIXA", "type": "S", "class": "CAIXA", "params": [] } ] }
```

Fatos que alimentam a tabela, todos da linguagem:

- `_HB_CLASS <Classe> [<Func>]` (o CREATE CLASS do hbclass emite) registra
  a classe E auto-declara a FUNÇÃO-CLASSE devolvendo `AS CLASS <Classe>`
  (hbmain.c hb_compClassAdd);
- `_HB_MEMBER <M>(...) [AS ...]` declara o método; `METHOD <M> ...
  CONSTRUCTOR` faz o hbclass emitir `AS CLASS _CLASS_NAME_` no retorno
  (hbclass.ch:283) — a cadeia `Classe():New()` é TODA declarada;
- `DECLARE F( x AS ... ) AS ...` escrito à mão funciona igual.

As tabelas são POR MÓDULO (o consumidor agrega o projeto). O subsistema
era gated por `-w3` (hb_compClassFind/Add etc.); com `-x` os gates abrem
(`iWarnings < 3 && ! fAst`) mantendo TODOS os warnings gated por nível na
emissão — zero impacto sem `-x` provado por `.hrb` byte-idênticos em -w0 E
-w3. Tipos de parâmetro podem carregar offsets BYREF(+60)/OPTIONAL(+90) do
subsistema; a decodificação no writer é best-effort (faixas se sobrepõem)
— consumidores atuais só usam RETORNOS.

### TypeOf — propagação na ferramenta (regra FECHADA)

A ferramenta classifica o receptor de send propagando SÓ tipos declarados
sobre `statements[]`: `VARIABLE` (classe declarada; senão binding único =
exatamente 1 write + 0 refs + um só ASSIGN de topo → tipo do RHS),
`FUNCALL` (retorno declarado), `SEND` (retorno declarado do método na
classe do obj), literais de valor, `LIST` (último item), `SELF`. Sem
ordem, sem caminhos, sem fixpoint; fora da regra → desconhecido
(`possible`). Sombras de codeblock: uso de local externa dentro de bloco
resolve como `detached` (classifica); `local`+`block` é PARÂMETRO do bloco
(não classifica — o CBVAR não guarda classe). Estender a regra = novo
portão.

### Resolução de dispatch (B4f-2, ferramenta — spec-b4f2-dispatch.md)

Sobre o tipo do receptor, o `usages Classe:Método` DECIDE o dispatch com a
regra da LINGUAGEM (classes.c, provada em runtime pelos probes da spec):
método PRÓPRIO vence herdado; em conflito entre pais vence o PRIMEIRO da
cláusula `FROM`, em PROFUNDIDADE (o 1º pai leva junto tudo que herdou —
flattening do `__clsNew`). Os FATOS vêm dos canais genéricos: pais na
ordem TEXTUAL do FROM com flag dentro/fora do projeto (markers das
aplicações declarantes — o interleaving importa: pai de FORA antes de um
hit torna a resolução indecidível; hit do projeto antes do pai de fora é
decidível); mensagens próprias = união do registro por stringify e do
canal `declared`. Camadas resultantes:

- `confirmed send (receiver class X dispatches to C:M)` — dispatch
  resolvido na implementação consultada (herança alcançada, transitiva);
- `excluded send (dispatches to Y:M)` — receptor de classe EXATA (cadeia
  declarada): a resolução é absoluta, o send alcança OUTRA implementação;
- `excluded send within the project's class graph (dispatches to Y:M)` —
  receptor DECLARADO (promessa: pode carregar descendente em runtime): a
  exclusão vale no MUNDO FECHADO do grafo do projeto, sem descendente que
  sequestre o dispatch — o rótulo carrega a ressalva;
- `possible send (descendant D of X may dispatch to C:M)` — descendente no
  projeto que sequestraria o dispatch impede a exclusão (nomeado);
- indecidível (pai fora do projeto antes de um hit, classe desconhecida,
  classes criadas/alteradas em runtime) — camadas B4f de sempre, nunca
  excluded.

Escopo (HIDDEN/PROTECTED) NÃO muda a resolução, só o acesso (probe);
ACCESS/ASSIGN entram na mesma tabela de mensagens com a mesma regra
(ASSIGN = mensagem `_NOME`). Todo `excluded` fica fora das `Location[]`
do `--json`.

Sites de DECLARAÇÃO e IMPLEMENTAÇÃO na forma `Classe:Método` (fatia dos
homônimos de declaração, caso 70; generalizada na B4f-3, caso 72). A dona
de cada site escrito vem de DUAS fontes de fato, ambas genéricas:

1. **canal declared no stream**: `_HB_CLASS <nome>` muda a classe corrente
   (semântica SEQUENCIAL do compilador — harbour.y, não convenção) e
   `_HB_MEMBER <nome>` declara nela; o nome chega POSICIONADO no site
   escrito. Cobre hbclass, DSL espelho e DSL declarativa pura pelo MESMO
   canal da linguagem;
2. **registro por string** contido (por índice) na função GERADA — posse
   por containment (os fatos da PpMarkerOwners, site a site). Cobre builds
   do hbclass sem declarações e DSLs que só registram.

A implementação separada é o composto `DONA_MÉTODO` (co-derivação). O
veredito consome a resolução da própria CONSULTADA:

- dona == consultada → `declaration (class X)` (nas `Location[]`);
- `ResolveDispatch( consultada ) == dona` → `... (class X, dispatch
  target of C:M)` — herança: o site é o alvo que o dispatch alcança;
- resolução da consultada decidível em OUTRA dona provada no grafo
  (classe com a mensagem própria — fato 5) → `excluded ...
  (declares/implements Y:M)`, fora das `Location[]`;
- indecidível (fato 9) ou dona fora do grafo → `possible`, nunca excluded.

A string de registro respondida por esse passe NÃO repete na camada
genérica de strings (ela É o artefato da declaração); strings escritas
pelo usuário (call-by-name) continuam `possible reference in string`.

Fatos da linguagem consumidos por essas camadas (aprendidos nos probes
da B4f-3 — evidência: dumps de fixhom/fixcst e probe vprobe executado):

- **Escrita `o:x := v` envia a mensagem `_X`** (fato 11): em `sends[]` o
  sym é `_X`, mas a ÁRVORE guarda `ASSIGN → SEND` do nome BASE (`X`) —
  o casamento aceita as duas formas e o walk do receptor cai para o nome
  base quando o sym começa com `_`.
- **VAR registra o PAR leitura/escrita em runtime** (`__objHasMsg` devolve
  .T. para `NT` E `_NT` — probe vprobe), mas stringify/declared carregam
  só o nome base — a resolução da forma de escrita tenta `_X` (ASSIGN
  explícito registra `_NOME`) e cai para `X` (par de dados).
- **`_HB_MEMBER { a, b }`**: a forma de LISTA do canal declared (é como o
  VAR do hbclass declara); os nomes vêm POSICIONADOS dentro do grupo.
- **Strings de registro nem sempre têm posição**: a do hbclass é
  posicionada no nome escrito; a de stringify de DSL própria (`<(x)>`)
  nasce `line 0` — por isso a fonte 1 (canal no stream) existe.
- **INIT PROCEDURE ganha sufixo `$`** no nome da função no dump
  (`__INIT_PONTO$`) — afeta casamentos por nome de função gerada.
- **Classes de RUNTIME** (ex.: xhb cstruct — `hb_CStructure`/`__clsNew`,
  regras de pp definidas de dentro de expansões): nada estático cruza; o
  relato é `possible` em tudo, sites escritos listados (caso 73).

### Contrato de extensão (para autores de comandos de pp)

**Qualquer comando novo fica semanticamente refatorável DECLARANDO pelo
canal da linguagem na expansão** — `_HB_CLASS`, `_HB_MEMBER ... AS CLASS`,
`LOCAL ... AS CLASS`, `DECLARE` — exatamente como o hbclass.ch, que é
apenas o PRIMEIRO CLIENTE do canal. Sem declaração, o relato é honesto
(`possible`): o fato não existe em compilação. **Nunca é preciso alterar
harbour nem hbrefactor para um comando novo** (provado no caso 64 com um
DSL inventado que a ferramenta e o core não mencionam). O contrato cobre
também HOMÔNIMOS (B4f-3, caso 72): donos de DSL homônimos entre si e
contra classes do hbclass são resolvidos — declaração, implementação e
sends — pelos mesmos fatos genéricos, com os rótulos no VOCABULÁRIO da
própria DSL (a cabeça da regra raiz: `cog declaration`, `dote
declaration`, `forge definition`...). E cobre comandos que EMBRULHAM
classes existentes (`#command mybrowse <a> <b> => ...Grade():New(...)`)
sem declarar nada de novo: os fatos de classificação fluem da árvore
EXPANDIDA — instância criada e send contido na expansão resolvem
homônimos igualmente, relatados no site ESCRITO do comando (caso 72,
fatia 2). Classe embrulhada de FORA do projeto fica `possible` honesto.

### Caveats honestos (moldam os rótulos do usages)

- Tipo declarado é PROMESSA do programador — não verificado em runtime;
  polimorfismo pode despachar para override em subclasse.
- `excluded` por valor (ex.: `a := {}`) exclui dispatch em classe de
  INSTÂNCIA; classes ESCALARES associadas em runtime (ex.: xhb) são
  invisíveis à compilação — o rótulo nomeia o fato, não impossibilidade
  absoluta.
- Classe conhecida ≠ consultada só exclui quando a resolução de dispatch
  DECIDE (B4f-2); indecidível fica `possible` com a classe nomeada. A
  exclusão de receptor DECLARADO é de mundo fechado (rótulo com a
  ressalva); a de instância EXATA herda a natureza de promessa do retorno
  declarado da cadeia (um ctor que devolvesse OUTRA classe quebraria a
  própria declaração).
- Classe referida por `DECLARE`/`AS CLASS` mas não registrada NO MÓDULO:
  em `declarations[]` o nome sobrevive; nas tabelas `declared` o retorno
  degrada para 'O' (comportamento do subsistema) — declare a classe no
  módulo (idioma da linguagem) para a cadeia funcionar.
- Dona SÓ do canal declared (DSL declarativa pura, sem função geradora —
  B4f-3): entra no grafo com a interface declarada como PROMESSA FECHADA
  do autor e pais vazios (o canal não carrega superclasse — fato 4). É a
  mesma natureza de promessa de todo tipo declarado; um registro em
  runtime fora da declaração (`__clsModify` etc.) é a fronteira já
  nomeada.

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
- **extract-to-method (B4e P2a)**: range num corpo de MÉTODO extrai para um
  NOVO `METHOD` da MESMA classe — o alvo é decidido pelo **CONTÊINER**, não
  pelo range (dogfooding do Diego no hbhttpd: range sem `::` dentro de
  método virava função e surpreendia; método funciona sempre). Contêiner é
  método = nome composto pelo rastro CUJA PRIMEIRA PARTE nomeia uma função
  de CLASSE do projeto (`ClassFuncMap` — composto de DSL sem classe segue
  no caminho de função). O corpo move VERBATIM (`::`/sends/`Super`
  continuam válidos: mesma classe ⇒ mesmo binding, provado por execução).
  Fatos consumidos:
  - `Self` é local comum SEM declaration no dump do método (só occurrences;
    a atribuição sintética do preâmbulo do hbclass gera um write na LINHA do
    `METHOD` — fora de qualquer range válido). `::` = dois tokens `:`
    type 58 sem coluna, NENHUM token SELF no stream — uso de Self detecta-se
    pelas occurrences, nunca por token. Write/ref de SELF no range = recusa
    (o Self da função nova é OUTRA local; `Self := x` e `@Self` compilam).
  - identidade classe+mensagem: `GenNameParts`/`MethodImplOf` (rastro
    `from`); símbolo gerado previsto: `PredictText` sobre o token composto
    (faixa do método → nome novo; nenhum separador `_` assumido).
  - âncora do protótipo (`MethodProtoAnchor`): aplicações com a identidade
    INTEIRA (como `SigParamHits`) cujos tokens posicionados ficam ANTES da
    implementação — a última linha física é onde o protótipo novo entra
    (mesma seção de visibilidade do método de origem; PROTECTED interno
    funciona — scope só é checado em runtime). Classe declarada em include:
    tokens `prov 'i'` sem coluna ⇒ recusa limpa.
  - membros registrados (`ClassMembersOf`): strings de STRINGIFY contidas
    POR ÍNDICE (nascem com line 0) na função da classe (`FuncStmtSpans`) —
    colisão do nome novo recusa; cadeia de ancestrais no projeto
    (`ClassDeclApps`/`ClassParentsOf`): pais = markers posicionados NA LINHA
    da declaração da classe nas apps declarantes (o fecho de derivação
    arrasta apps de protótipo, cujos markers têm outras linhas; a palavra
    `FROM` cai sob o MESMO marker do pai e é filtrada por não chegar ao
    stream — `StreamHasIdent`). Pai fora do projeto = fato inexistente em
    compilação ⇒ AVISO nomeando-o, nunca palpite.
  - mensagem já ENVIADA em qualquer módulo (`sends`, incluindo o setter
    `_X`) = recusa: o método novo sombrearia dispatch existente.
  - assinatura: protótipo ≡ implementação, params na grafia dos tokens
    (o hbclass casa a assinatura INTEIRA — P1a/W0001); método gerado exige
    `RETURN` com valor (`RETURN NIL`; vazio = W0005, fatal sob -es2).
  - verificação (`HrbMethodExtractCheck`): funções +1 (a gerada prevista),
    símbolos novos ⊆ { símbolo gerado, símbolo da MENSAGEM (o send `::Nome`
    o cria) }, e a string do nome (grafia escrita) presente no pcode da
    FUNÇÃO DA CLASSE (fato de registro — sem ele o send falharia só em
    runtime); demais módulos byte-idênticos + rollback. Range que usa Self
    FORA de método (função com `LOCAL Self`, INLINE) = recusa limpa.
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
versionou de ast-2 para ast-3. O canal de tipos da linguagem
(`declarations[]` parse-time tipadas + seção `declared`) entregue no
**ast-4** (fase B4f, 2026-07-06), consumido pelas camadas
confirmed/excluded do usages (TypeOf). O leitor da ferramenta (`ReadAst`)
aceita `ast-2`/`ast-3`/`ast-4`; comandos que EXIGEM o rastro usam
`FromReady` (ast-3+) e a classificação de receptor exige projeto inteiro
em ast-4 (`Ast4Ready`/`DeclTables`) — em dump antigo degrada para a camada
`possible`, sem recusar. Próximo a avaliar: span original de string no
posTrack (mataria `StrDelimsOk`). Ao mudar, versionar `"schema"` e
atualizar este documento NO MESMO commit.
