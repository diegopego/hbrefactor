# Schema `ast-16` — o dump AST do compilador (spec)

Contrato entre o harbour patchado (branch `feature/compiler-ast-dump`,
arquivos `src/compiler/compast.c` + rastreamento de regras e de derivação
em `src/pp/ppcore.c`) e o hbrefactor. Um `.ast.json` por módulo compilado
com `-x`.

> **O bump é PARTE do canal, não um detalhe administrativo (cicatriz da P10,
> 2026-07-13).** O `ast-16` entrou no core **sem versionar o `HB_AST_SCHEMA`** —
> o dump entregava os campos novos declarando-se `ast-15`, e este documento
> ainda dizia `ast-14` no título. O `NEWS.md` e a landing page do core mandam o
> consumidor *"conferir o campo `schema`"*, então isso não era desleixo de doc:
> era o **contrato mentindo**. Pior, ao consertar o número a ferramenta
> **recusou o projeto inteiro** — o `ReadAst` tinha uma **lista enumerada** de
> versões aceitas (`{ "ast-2", …, "ast-15" }`) e ela morre em silêncio a cada
> bump. Um esquecimento escondia o outro.
>
> **E o conserto certo era mais radical do que eu tinha feito (Diego, 2026-07-13):**
> *"estamos fazendo a AST sob demanda, então mexer no core é parte do trabalho e é
> normal — não existe esta busca de compatibilidade; estamos INVENTANDO a ferramenta"*.
> Eu tinha trocado a lista por um **piso** (`ast-2` para cima) — ainda maquinaria de
> compatibilidade, **com o quê?**. O dump é gerado **na hora**, a cada comando, pelo
> `harbour` do `HB_BIN`: **não existe "dump antigo"** — existe **toolchain fora de
> passo**, e isso se **BERRA**. Hoje: **o schema é EXATO** (`AstSchema()`, um só lugar
> na ferramenta), e divergiu → recusa alta nomeando as duas versões. As **cinco funções
> e 23 sítios** de degradação por versão foram **removidos** — e nada na suíte dependia
> deles. *Ao entregar um canal: versionar o `"schema"` no core, atualizar este documento
> e o `AstSchema()` — **no mesmo commit**. O **caso 122** fica vermelho se você esquecer.*

O **`ast-16` (fase P-AUDIT / P11) = `ast-15` + TEMPO DE VIDA E FAMÍLIA DA REGRA**
(o prefixo de modo em `kind` — `""` dBase / `x` exato / `y` exato e
case-sensitive —, o `un` de diretiva que REMOVE, o `undoes` e o `removed`);
detalhado na seção `ppRules[]`. O **`ast-15` (P-AUDIT) = `ast-14` + `ruletok`**
(QUAL literal da regra o token casou), detalhado em `ppApplications[]`.

O **`ast-14` (fase P / P5) = `ast-13` + TODO MARKER DE MATCH É NUMERADO.**
Antes, o pp só dava índice a um marker de match que o RESULT referenciasse
(`usPCount`); um marker casado e **não usado no resultado** ficava com índice
0 — e, pior, o casamento dele era **DESCARTADO** (`hb_pp_patternMatch` só
chama `hb_pp_patternAddResult` quando `pMatch->index` está setado). Efeito no
rastro: o recheio desse marker chegava ao `ppApplications[].tokens[]` com
`marker: 0`, **indistinguível de uma palavra literal da regra** — o comentário
do `hb_pp_trackApply` afirmava exatamente isso ("everything not covered by a
marker result is a literal word of the rule itself") e estava ERRADO. Um
consumidor só podia separar os dois ADIVINHANDO pelo texto, e a adivinhação tem
furo demonstrável: conteúdo do usuário igual a uma keyword da regra
(`ANOTA ANOTA`, com `#xcommand ANOTA <*x*>`) classifica errado.
**O conserto foi no CORE, onde o fato tinha de nascer** (ppcore.c,
`hb_pp_directiveNew`, **gated por `fTrackPos`** — build default do Harbour
byte-a-byte intocado): todo marker de match ganha índice, o casamento passa a
ser registrado, e o rastreador exporta a ligação REAL. Consequências para o
consumidor:
- **`marker: 0` agora significa UMA coisa só**: palavra literal da própria
  regra (cabeça, keyword secundária, alternativa de restrição).
- **`marker: N >= 1` é recheio de marker POR FATO** — inclusive de markers que
  o resultado nunca usa (`<*x*>` wild descartado, `<x: A, B>` restrito que não
  vaza). Combinado com o `mkind` do `match[]` e com os mkinds do `result[]`, o
  consumidor decide sem heurística: o marker EMITE o valor? é RESTRITO? senão,
  o que o usuário escreveu ali é **consumido e descartado** pela diretiva.
- A expansão NÃO muda (o result nunca referencia esses markers): `lexdiff` 0
  divergências reais.

O `ast-13` (fase P) = `ast-12` + a **GENEALOGIA DE REGRA**:
(a) `"from"` (mesmo formato do ast-3) nos tokens de `match[]`/`result[]`
de uma regra **GERADA pela expansão de outra regra** — a linha de diretiva
dela foi SINTETIZADA, então seus tokens carregam de qual aplicação/marker
cada faixa de bytes deriva, ligando a regra à aplicação que a CRIOU
(capturado no registro, `hb_pp_ruleTokWalk`/`hb_pp_drvFind`; accessors
`hb_pp_trackRuleTokenFrom*`); ausente em regra escrita direto no
fonte/include; (b) a **derivação sobrevive ao CLONE**
(`hb_pp_tokenClone` copia as entradas de derivação junto com a posição —
a cópia carrega o mesmo texto, logo as mesmas faixas derivam da mesma
origem): o literal de resultado de uma regra gerada mantém a origem
através das APLICAÇÕES dela (a string stringificada na expansão de uma
regra que outra regra criou vira artefato rastreável). Consumidores:
resolução do `rename` (`genrule` — o nome que VIRA regra é do marker,
mesmo sem `generates`, porque a derivação de uma diretiva gerada entra no
REGISTRO da regra e não no stream), coleta de sementes com gate de
pertencimento (caso 108) e o fecho de artefatos/predições. O
`ast-12` (fase U / revisão) = `ast-11` + `"generates": true` no
recheio de match marker do `ppApplications[].tokens[]` cujo nome ESCRITO
alimenta um paste/stringify (GERA artefato) — reverse-scan do `from` (op
`p`/`s`), puro no dump; separa "nome que a diretiva vira código" de "símbolo
ligado que só flui para um comando" (ver a seção `ppApplications`). O
`ast-11` (completude M-B) = `ast-10` + `"params"` no nó
`CODEBLOCK` — a lista dos parâmetros do bloco COMO DECLARADOS, presa ao
PRÓPRIO nó (`[{"sym","type","class"}]`; `type`/`class` só quando há
anotação, inclusive a `'S'`+classe do canal `_HB_INLINESELF`). Deixa o
consumidor tipar o receptor de um send pelo bloco EXATO em que ele está,
sem casar por linha — dois blocos na MESMA linha de fonte (o getter e o
`"_"`setter de um `VAR ... IS`) deixam de ser ambíguos; o `ast-10`
(RE.6/F6.1) = `ast-9` + o canal de parentesco DECLARADO no stream
(`_HB_SUPER`, o gate do fato de exclusão de send); o `ast-9` (B9 fatia 3) = `ast-8` + `"nameLine"`/`"nameCol"` em
`declarations[]` (posição do token ESCRITO do nome — a âncora do
materializador; ausente quando o nome não tem token de fonte, ex.: param
gerado por diretiva); o `ast-8` (RE.5) = `ast-7` + `"chk"` (fato de
cobertura do `-kt`); o `ast-7` (fase B9) = `ast-6` + `"kt"` no cabeçalho (o módulo
foi compilado com `-kt`? — anotação vira INVARIANTE imposta) + `"dim"`
em `declarations[]` (a forma dimensionada `LOCAL a[n]` carrega um 'A'
INTERNO do compilador, não anotação escrita — ver a seção B9); o
`ast-6` (fase B7) = `ast-5` + `"ret": true` no statement
`push` que carrega o valor de RETURN (ver `statements[]`); o `ast-5`
(fase B4g) = `ast-4` + A REGRA POR DENTRO
(`match[]`/`result[]` em `ppRules[]` — ver lá); o `ast-4` (fase B4f) =
`ast-3` + o CANAL DE TIPOS DA LINGUAGEM (seção `declared` +
`declarations[]` parse-time tipadas — ver a seção própria); o `ast-3`
(fase B4d) = `ast-2` (fase B4) + o campo `from` (rastro de derivação) nos
tokens SINTETIZADOS; o `ast-2` = `ast-1` (commit `2cca58e4b8`) + seções
`ppRules`/`ppApplications`. Fora as adições, tudo é idêntico byte a byte
entre as versões — exceto `declarations[]`, cuja fonte MUDOU no ast-4
(ver lá).

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
{ "schema": "ast-13",          // versão emitida hoje (ast-1→...→ast-13)
  "generator": "Harbour 3.2.0dev (...)",
  "module": "core.prg",          // nome capturado no PARSE (não o -o)
  "hasCDump": false,             // módulo tem #pragma BEGINDUMP
  "kt": false,                   // ast-7: compilado com -kt? (anotações
                                 // impostas em runtime - camada guaranteed)
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
    "kind": "command",     // ast-16: a FAMÍLIA como o pp a vê. Prefixo de MODO
                           // de comparação + (opcional) "un" de REMOÇÃO:
                           //   define     undef        -> a CONSTANTE e seu fim
                           //   command    translate    -> dBase: casa ABREVIADO
                           //   xcommand   xtranslate   -> exato
                           //   ycommand   ytranslate   -> exato E case-sensitive
                           //   uncommand  untranslate  -> REMOVE a regra
                           //   xuncommand xuntranslate  (idem, por família)
                           //   yuncommand yuntranslate
                           // ATÉ o ast-16 o modo era um BOOLEANO ("é x?") e a
                           // família y saía rotulada como "command" - ou seja, o
                           // dump dizia "casa abreviado" sobre uma regra EXATA.
    "file": "menu.ch",     // arquivo da DIRETIVA; null = regra builtin
                           // (std rules compiladas, -D, dyn defines)
    "line": 3,             // linha da diretiva (0 quando builtin); para
                           // diretiva CONTINUADA por ';' é a ÚLTIMA linha
                           // física - a âncora real é match[0] (ast-5)
    "head": "MENUITEM",    // palavra-cabeça; null se a regra começa com
                           // match marker
    "markers": 4,          // nº de match markers da regra
    "match": [ ... ],      // ast-5: a regra POR DENTRO (abaixo)
    "result": [ ... ] } ],

// ------------------------------------------------------------------------
// ast-16: a regra tem TEMPO DE VIDA. Ela vale do `#[x|y]command` até o
// `#[x|y]uncommand` correspondente - depois disso a palavra volta a ser código
// cru. O pp SABIA disso (ele executa a remoção) e o dump DESCARTAVA: a diretiva
// de remoção não deixava rastro nenhum.
//
// A diretiva de REMOÇÃO entra em ppRules como um registro próprio (com o seu
// `match`/`result` POSICIONADOS, como qualquer regra - logo é editável por
// posição, sem procurar `#xuncommand` por TEXTO):
// ------------------------------------------------------------------------
  { "id": 3,
    "kind": "xuncommand",  // é uma REMOÇÃO (ver o vocabulário de kind acima)
    "file": "un.prg",
    "line": 9,
    "head": "PINTA",
    "undoes": 0,           // id da regra que ela REMOVEU -- vínculo por FATO.
                           // null = não removeu NADA: um #un... ÓRFÃO, que é
                           // código morto silencioso (e é exatamente o que um
                           // rename desatento PRODUZ, ver abaixo)
    "markers": 1,
    "match": [ ... ], "result": [ ... ] },

// ...e a regra removida ganha, do outro lado do vínculo:
  { "id": 0, "kind": "xcommand", "head": "PINTA",
    "removed": true,       // um #un... tirou esta regra da mesa
    ... }

// POR QUE ISSO É CORRETUDE, não enfeite: sem o fato, o `rename` da cabeça
// trocava só o `#xcommand` e deixava o `#xuncommand` ÓRFÃO - ele passava a
// desligar uma regra que não existe mais, e a regra VAZAVA para além do ponto
// de desligamento, mudando a semântica de código que ninguém tocou. E era
// SILENCIOSO: a rede `.ppo`/`.hrb` não vê diferença quando nada DEPOIS do
// desligamento usa a palavra. Prova executável: caso 117 (fixture `fixun`).
// Com o fato, o conserto não custou UMA LINHA de lógica nova na ferramenta: a
// remoção é só mais uma regra com aquela cabeça, e a maquinaria de rename por
// posição que já existia passou a editá-la sozinha.

"ppApplications": [        // UMA entrada por aplicação, na ORDEM em que o
                           // pp as fez (multi-passe visível: aplicação
                           // sobre resultado de outra regra aparece depois)
  { "rule": 2, "line": 8,  // linha de input corrente na aplicação
    "tokens": [            // os tokens CONSUMIDOS (o span casado no fonte)
      { "line": 8, "col": 3, "len": 8, "type": 21, "prov": "s",
        "marker": 0,       // 0 = palavra/literal DA PRÓPRIA REGRA;
                           // N = recheio do match marker N (1-based)
        "ruletok": 2,      // ast-15: QUAL literal da regra este token casou -
                           // índice no `match[]` DA REGRA. SÓ em `marker: 0`
                           // (palavra literal); ausente para recheio de marker.
                           // O pp pareia cada token-fonte com o token do padrão
                           // enquanto casa, e DESCARTAVA o par do literal
                           // (hb_pp_patternMatch só registrava quando o padrão
                           // tinha índice de marker). Sem ele o consumidor só
                           // podia ADIVINHAR o literal pelo TEXTO - e a
                           // adivinhação QUEBRA na abreviação dBase: família sem
                           // `x` casa keyword abreviada em >= 4 letras
                           // (ppcore.c:2533), então uma keyword SECUNDÁRIA que
                           // seja prefixo de 4+ letras da CABEÇA, escrita por
                           // extenso, é indistinguível de uma cabeça abreviada.
                           // Furo real: o rename da cabeça dava RECUSA FALSA
                           // (caso 115). Gated por fTrackPos; lexdiff 0.
        "generates": true, // ast-12: SÓ em recheio de marker (N>=1) cujo NOME
                           // ESCRITO alimenta um 'p'aste ou 's'tringify -
                           // GERA artefato (um símbolo colado dele, uma string
                           // despejada dele) que perde a ligação com o nome.
                           // AUSENTE = não gera ('c'lone/pass-through: o valor
                           // atravessa como está, ex.: arg de `? x`, param de
                           // método). Reverse-scan do `from` (op p/s) dos
                           // tokens[], puro no dump. É o fato que separa "nome
                           // que a diretiva vira código" (renomear = pp-marker,
                           // carrega os derivados) de "símbolo LIGADO que
                           // apenas flui para dentro de um comando" (renomear =
                           // o local/param que ele é). Sem ele, um `REGISTRO
                           // <n> => ...LOCAL <n>` faria o marker `<n>` colidir
                           // com o LOCAL homônimo que a própria expansão cria.
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
- **`generates` e o marker que GERA E passa adiante (veredito P2, caso 109)**:
  um mesmo marker pode GERAR (paste/stringify, `generates: true`) E ao mesmo
  tempo passar o nome ADIANTE por clone (uma referência), em multiplicidade
  ILIMITADA (o pp não põe teto no nº de usos no destino). O consumidor resolve
  pelo `generates` (vence → `rename-pp-marker`), e a segurança NÃO depende de
  distinguir paste de stringify nem de modelar a multiplicidade: é ESTRUTURAL —
  a rede de verificação (recompilação `-es2` + símbolos/identidade do `.hrb`)
  confere o ARTEFATO COMPILADO FINAL. Todo caso é rollback honesto (referência
  quebrada / delta não-previsto) OU re-derivação verificada; nunca corrupção
  silenciosa. Fundamentação: [spec-p § P2](spec-p-pp-refatoracao.md),
  [adr-004](adr-004-grafo-transformacao-pp.md).

### `match[]`/`result[]` — a regra POR DENTRO (ast-5, fase B4g)

Um item por token do padrão da regra, com o PAPEL que o próprio pp
atribuiu ao parsear a diretiva (snapshot no instante do REGISTRO —
`hb_pp_trackRuleAdd` —, imune a mutação posterior dos tokens). Fecha a
lacuna dos casos 72-74: a regra deixou de ser opaca (era só cabeça +
contagem de markers). Fundamentação e probes: spec-b4g (fatos 1-13) +
ADR-001.

```jsonc
"match": [
  { "role": "literal", "type": 21, "line": 12, "col": 10, "len": 5,
    "prov": "i", "text": "FORJA" },                 // palavra da regra
  { "role": "marker", "marker": 1, "mkind": "regular",
    "line": 12, "col": 17, "len": 3, "prov": "i", "text": "oIt" },
  { "role": "opt-open" },                           // grupo [ ... ]
  { "role": "literal", "type": 21, ..., "text": "ROTULO" },
  { "role": "marker", "marker": 4, "mkind": "regular", ..., "text": "cRot" },
  { "role": "opt-close" },
  { "role": "marker", "marker": 3, "mkind": "restrict", ..., "text": "modo" },
  { "role": "restrict", "marker": 3, "type": 21, ..., "text": "RAPIDO" } ],
"result": [
  { "role": "marker", "marker": 1, "mkind": "regular", ..., "text": "oIt" },
  { "role": "literal", "type": 21, ..., "text": "ForjaNova" },
  { "role": "marker", "marker": 3, "mkind": "strstd", ..., "text": "modo" } ]
```

- **`role`**: `literal` (palavra/pontuação da regra, com `type` cru do
  pp), `marker` (o token sobrevivente é o do NOME do marker, com
  `marker` 1-based — o MESMO índice de `ppApplications[].tokens[].marker`
  — e `mkind`), `restrict` (alternativa de restrição, com `marker` do
  dono; vírgulas do grupo incluídas, col null), `opt-open`/`opt-close`
  (grupo opcional achatado, reconstruível por pilha; o match pode
  ANINHAR — o result não).
- **`mkind`** (vocabulário do pp, hbpp.h). **Fase P4/P5 exauriu os 15**: cada um
  foi exercitado em fixture e recebeu veredito (consumo provado OU recusa
  documentada). **Desde o ast-14, TODO marker de match é numerado** — a nota
  antiga ("marker casado mas não usado no result fica com `marker: 0`") está
  MORTA: era o próprio defeito que o ast-14 consertou.

  **MATCH (6)** — sintaxe (parser: `hb_pp_matchMarkerNew`, ppcore.c) e consumo:

  | mkind | sintaxe | veredito |
  |---|---|---|
  | `regular` | `<x>` | consumido (recheio comum) |
  | `list` | `<x,...>` | consumido; os itens chegam **individualmente posicionados** nos tokens consumidos |
  | `restrict` | `<x: A, B>` | consumido; as ALTERNATIVAS vêm como itens `role: "restrict"` com o `marker` do dono → o rename **VALIDA contra elas** e recusa antes de recompilar (P5) |
  | `wild` | `<*x*>` | consumido; se o result não usa o marker, o recheio é **descartado** — a ferramenta o relata, nunca o edita |
  | `extexp` | `<(x)>` | consumido (expressão estendida) |
  | `name` | `<!x!>` | consumido (só casa identificador) |

  **RESULT (9)** — sintaxe (parser: `hb_pp_resultMarkerNew`) e consumo:

  | mkind | sintaxe | veredito |
  |---|---|---|
  | `regular` | `<x>` | emite o valor → recheio é símbolo ligado |
  | `strstd` | `<"x">` | stringify sempre → gera artefato (`generates`) |
  | `strsmart` | `<(x)>` | smart-quote: bareword vira string, expressão passa crua |
  | `block` | `<{x}>` | embrulha o valor num codeblock; o valor É emitido |
  | `logical` | `<.x.>` | emite `.T.`/`.F.` — **o VALOR não é emitido**: o recheio é consumido e DESCARTADO (relato honesto, nunca edição) |
  | `nul` | `<-x->` | não emite nada — recheio DESCARTADO (idem) |
  | `reference` | `<@>` | **guarda anti-recursão**: token significativo para o pp e INVISÍVEL ao compilador, que carrega o padrão de match da regra e impede uma regra circular de re-casar a própria saída (ChangeLog do core 2010-08-19; uso real: `hbfoxpro.ch:63`). Sem nome e sem posição (`text: "~"`, `col: null`) → nada a renomear; a ferramenta o **preserva por construção** (edita regra por posição de byte, e o guarda não tem posição). |
  | `strdump` | `#<x>` (e `%s`) | o **NOME ESCRITO** virado string (`ppcore.c:4262`, ramo `fDump`; o `%s` do stream é o outro caminho para o mesmo mkind, `ppcore.c:3215`). Alimenta o `generates` do ast-12 (`ppcore.c:5414` registra o `'s'`). **CORREÇÃO 2026-07-13**: até aqui esta linha dizia "RECUSA DOCUMENTADA — não existe em regra", e era FALSO: 31 regras do ecossistema o emitem, **6 delas no `std.ch`** (`MENU TO`, `SET COLOR TO`, `RELEASE ALL LIKE`, `RUN`, `JOIN`) — ver [pp-corpus/strdump.md](pp-corpus/strdump.md). |
  | `dynval` | — | **RECUSA DOCUMENTADA**: não é escrivível pelo usuário — é o canal INTERNO do pp para os `#define` dinâmicos (`__FILE__`, `__LINE__`, `__DATE__`…; ppcore.c:5209/7190). Nenhum `#xcommand` pode produzi-lo. |
- **Posições**: `line`/`col`/`len`/`prov` como em `tokens[]`, com UMA
  diferença deliberada: **col é emitida também para token de include**
  (`prov 'i'`) — a posTbl guarda coluna de qualquer arquivo (fato 8 da
  spec-b4g) e as regras vivem em `.ch`; o byte-exato contra o arquivo da
  regra é o contrato (provado campo a campo no caso 82). Pontuação e
  operador curto: linha real, col null. `<@>` no result: pos null (o pp
  troca o value). Regra builtin: tudo null.
- **Ordem = a ARMAZENADA pela regra** (a que o pp usa para casar), NÃO a
  do fonte: grupos opcionais consecutivos onde o PRIMEIRO não tem keyword
  são reordenados no registro (`hb_pp_matchPatternNew` mantém o grupo com
  keyword primeiro — decisão do Diego no portão, ADR-001: o dump
  transporta o fato 1:1). A ordem do fonte é recuperável pelas posições;
  fixture executável: regra TEMPERA do caso 82.
- **Regra nascida de EXPANSÃO** (cstruct/caso 73; fato 13): as posições
  são REAIS e rastreáveis — a cabeça aponta o texto DENTRO do result da
  diretiva-mãe, recheio de marker aponta o site de uso; o rule record
  (`file`/`line`) fica no site da APLICAÇÃO. A posição pode viver em
  OUTRO arquivo que o da regra (a posTbl não guarda nome de arquivo) — o
  guard de edição byte-exato contra o arquivo da regra decide (não
  confere → recusa honesta), e o oráculo pós-edição cobre o resto.
- **`from` em token de regra GERADA (ast-13, genealogia)**: quando a
  regra foi CRIADA pela expansão de outra regra (a diretiva dela é
  sintetizada — hbclass gerando os `#xcommand METHOD ... <nome> CLASS
  <classe> ...` por método; qualquer DSL `#xcommand DEF <n> => #xcommand
  USA <n> => ...`), os tokens de `match[]`/`result[]` que derivam de
  markers carregam `"from"` no MESMO formato do ast-3
  (`{app, marker, op, at, len}`) — a ligação da regra à aplicação que a
  criou. Capturado no snapshot do registro (a tabela de derivação ainda
  tem entrada viva para cada token da diretiva). Ausente em regra escrita
  à mão. É o fato que separa "nome que VIRA regra" (renomear = pp-marker,
  mesmo com `generates` ausente — a derivação de uma diretiva gerada
  entra no REGISTRO, não no stream, e o reverse-scan do ast-12 não a vê)
  de homônimo coincidente; fixtures `fixgen` (caso 108), prova real:
  regras `METHOD` por-método do hbclass apontando a app da declaração.
- **Derivação sobrevive ao clone (ast-13)**: `hb_pp_tokenClone` copia as
  entradas de derivação junto com a posição — o literal de RESULT de uma
  regra gerada mantém a origem quando a regra é APLICADA (a string
  `"Ponto"` na expansão de `USA Ponto` traz `from` op `stringify`
  apontando a app do `DEFREGRA`). Antes do ast-13 esses tokens nasciam
  órfãos; agora o fecho de artefatos/predições os alcança. Recheio de
  marker clonado logo em seguida ganha o registro próprio via
  `hb_pp_drvAdd1` (substitui a cópia) — comportamento inalterado.

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
      "dim": true,             // ast-7: SÓ na forma dimensionada (a[n]);
                               // o "type" 'A' que a acompanha é marca
                               // interna do compilador, NÃO promessa
      "nameLine": 7,           // ast-9: posição do token ESCRITO do nome
      "nameCol": 9,            // (linha física + col 0-based em bytes, como
                               // tokens[]) - a ÂNCORA do materializador.
                               // AUSENTE quando o nome não tem token de
                               // fonte (param gerado por diretiva, Self de
                               // INLINE, ~1 de SETGET). Em statement
                               // CONTINUADO nameLine é a linha ESCRITA
                               // (declLine de param de bloco = linha da
                               // MATERIALIZAÇÃO, a última física do bloco)
      "type": "S",             // só quando declarado (AS <tipo>): caractere
                               // do compilador - N C D L B A O S; minúscula
                               // = ARRAY do tipo ('s' = AS CLASS ARRAY).
                               // 'S'+class também vem do canal _HB_INLINESELF
                               // (RD): o receptor de um bloco GERADO por
                               // diretiva (Self de INLINE/OPERATOR do
                               // hbclass, ou de uma DSL do usuário) - tipo
                               // declarado de FATO, mas fact-only: nunca
                               // ganha "chk" (o -kt não o impõe), então o
                               // consumidor tipa como confirmed, nunca
                               // guaranteed. Indistinguível de um AS CLASS
                               // escrito EXCETO por nameLine ausente + sem chk
      "class": "CAIXA" } ],    // só em AS CLASS / _HB_INLINESELF: o NOME COMO
                               // ESCRITO (sobrevive à classe não registrada)
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
      // ast-6: "ret": true SÓ no push que carrega o valor de RETURN
      // (campo AUSENTE nos demais - condição de IF/WHILE, limites de
      // FOR, BREAK <expr> saem sem ele); gancho hb_compAstReturn() na
      // redução RETURN Expression do harbour.y, gated por fAst
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
`CODEBLOCK` → `cbflags`+`params[]`+`body[]` (ast-11: `params` = os
parâmetros do bloco como declarados, `[{"sym","type","class"}]`, presos ao
nó — tipam o receptor pelo bloco EXATO); `ALIASVAR/ALIASEXPR` → `alias`+`var`+
`expr`; `SETGET` → `var`+`expr`; `MACRO` → `val`+`expr`; `RTVAR` → `val`.
Folhas com `val`: VARIABLE, FUNNAME, STRING (+ NUMERIC/LOGICAL/DATE).

Semânticas importantes:
- `stmt` = statement-expressão completo; `push` = expressão empurrada em
  contexto de valor (condição de IF/WHILE, valor de RETURN, limites de FOR).
  Desde o ast-6 o push do valor de RETURN é o ÚNICO com `"ret": true` —
  antes era indistinguível dos demais (fato provado por probe na B7).
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

### O que o compilador FAZ e NÃO FAZ com as tabelas (investigação P1, 2026-07-09)

Fatos verificados no fonte + probes executáveis (smoke1-4, sessão do
plano da fatia 2 — [plano-b9-fatia2-escada.md](plano-b9-fatia2-escada.md)):

- **O compilador REGISTRA e nunca CONFERE**: a família inteira de
  warnings de cheque forte existe na tabela (hbgenerr.c:114-150 —
  "Incompatible type in assignment" W0008, "Message '%s' not known in
  class '%s'" W0026, "Incompatible return type" W0014...) mas com ZERO
  emissores no fonte (`HB_COMP_WARN_MESSAGE_NOT_FOUND` só existe como
  `#define`, hberrors.h:161). Probe: `-w3` cala até no controle positivo
  (`u AS CLASS X; u:Bogus()`). Não há cheque de send, de atribuição nem
  inferência var-like — a propagação sobre as tabelas é 100% do
  consumidor (TypeOf da ferramenta). Warnings VIVOS do subsistema:
  W0019 (dup de declaração) e W0025 (classe não conhecida, só em SÍTIO
  DE DECLARAÇÃO). **Correção (revisão Codex da fatia 2, 2026-07-09)**:
  W0016/W0017 (contagem/tipo de parâmetro) NÃO são do subsistema
  DECLARE — os únicos emissores vivem no tratamento dos builtins i18n
  (hbexprb.c:1951-2034, família `hb_i18n_gettext`); chamada com
  assinatura divergente do DECLARE **não warna** (o cheque genérico
  também está morto). A assinatura fiel no DECLARE materializado é
  exigência de FIDELIDADE da tabela, não de compilação.
- **`AS CLASS X` com X desconhecida no módulo DEGRADA**: variável
  (hbmain.c:471-481), retorno de DECLARE (harbour.y:1239-1246) e método
  (harbour.y:1274-1281) caem para 'O'/'o' com W0025 — a anotação PERDE a
  classe (nem o dump a carrega). Regra mecânica de quem materializa:
  garantir a classe registrada no módulo ANTES da anotação.
- **UMA linha fecha a cadeia no módulo consumidor**:
  `DECLARE <Cls> <Mth>() AS CLASS <Cls>` (forma harbour.y:1252) registra
  a classe no módulo (mata o W0025), declara o membro E auto-declara a
  função-classe `<Cls>()` devolvendo a classe — probe smoke3: dump com
  `classes[{CLS, methods[{MTH, S, CLS}]}]` + `functions[{CLS, S, CLS}]`;
  compile-time puro (zero pcode). **Re-declarar classe que o módulo JÁ
  tem dá W0019** (probe smoke4) — sob `-es2` falha; para sítio no mesmo
  módulo da classe, a rota é `_HB_MEMBER` avulso (harbour.y:1255) —
  **CONFIRMADA por probe (F2.1, proba/proba2)**: sem W0019, gruda na
  ÚLTIMA classe declarada (`pLastClass`), então módulo multi-classe
  exige posição entre a classe-alvo e a próxima (determinístico);
  execução `-kt` aceita a local anotada. A forma DECLARE funciona
  igual para classe 100% runtime (`__clsNew`/`__clsAddMsg`, zero
  `_HB_CLASS`): o cheque é por NOME no objeto VIVO (probe probc).
- **O `-kt` impõe SÓ o que vê na tabela na ordem do parse — provado por
  execução (F2.1, probb)**: o embrulho de RETURN (harbour.y:433,
  `hb_compChkTypeRetWrap`) consulta o DECLARE da própria função no
  momento do parse do RETURN — DECLARE ANTES da definição embrulha
  (fábrica mentirosa dispara `expected S:PECA, got N`); DECLARE DEPOIS
  da definição NÃO embrulha (a mentira passa em silêncio). DECLARE de
  FUNÇÃO materializado (antes) vira invariante checada; DECLARE de
  MEMBRO não é imposto (a impl pode viver fora do módulo/projeto —
  ex.: `New` herdado na RTL) e permanece PROMESSA cujo papel é tipar o
  consumidor; a invariante reportável é a da variável anotada no site
  (coberta — RE.2, e desde o RE.5 a cobertura é FATO `chk` do ast-8).
- **Cobertura do `-kt` PÓS-RE.5 (K1-K3, 2026-07-10, provas pgb1/pgb2 +
  caso 88)**: param de bloco `AS CLASS` EXISTE (a classe atravessa o
  parse — antes morria em harbour.y:1024 e segfaultava o A6) e é
  IMPOSTO por prólogo de bloco a cada `Eval` (site nomeado pela função
  DONA: `MAIN:OX`); escrita a local anotada DENTRO de bloco (detached)
  é checada no pós-store (o registro `pDetached` carrega o tipo da
  declaração da dona). Seguem NÃO cobertos, por fato e com registro:
  escrita via `@ref` (K5 medido no corpus: zero receptores-objeto —
  fora) e `PARAMETERS AS` (K6 fora). Blocos compilados pelo MACRO
  compiler em runtime nunca têm cheque (declarações não existem lá).
- **W0019 de MÉTODO é condicional — candidato (g) ADOTADO (portão do
  meio da fatia 2, Diego, 2026-07-09)**: re-declarar método cujo tipo
  era desconhecido (`pMethod->cType == ' '`, hbmain.c:1193) NÃO warna —
  o merge projetado ("Last Declaration override", hbmain.c:1178) roda
  em silêncio e o membro ganha o tipo: `_HB_MEMBER <M>() AS CLASS <C>`
  repetido é COMPLEMENTO (dump carrega o tipo; execução `-kt` o impõe
  no store da local anotada — `BASE/3012`). Conflito real (tipo já
  conhecido) continua W0019; W0019 de FUNÇÃO (hbmain.c:1242) e de
  CLASSE (hbmain.c:1104) intactos. Resíduo declarado: dup
  sem-tipo→sem-tipo também silencia (nenhuma informação perdida).
  Probes pg1-pg5b + re-medição em
  [plano-b9-fatia2-escada.md](plano-b9-fatia2-escada.md) § F2.1.
- **Semântica do `AS CLASS` — leitura da documentação do hbclass.ch
  (2026-07-10, questão do Diego)**: `AS CLASS <X>` descreve sempre o
  VALOR de um slot ("o que mora/sai aqui é-um X"), nunca pertencimento
  — pertencimento de membro é POSICIONAL (`pLastClass`). Os autores
  chamam a maquinaria inteira de **"value type declarations"**
  (hbclass.ch:85) e o switch `HB_CLS_NO_DECLARATIONS` a traduz TODA
  para nada (hbclass.ch:137-144: `_HB_CLASS`/`_HB_MEMBER`/`DECLARE`/
  `AS <type>`/`AS CLASS <name>` → vazio) — prova autoral da inércia
  que o padrão-ouro do `annotate` verifica byte a byte. O mapeamento
  usuário→tabela é literal: `METHOD <m> [CONSTRUCTOR] [AS <type>]`
  vira `_HB_MEMBER <m>() [<-ctor-> AS CLASS <própria>] [AS <type>]`
  (hbclass.ch:282 — CONSTRUCTOR = retorno da instância);
  `VAR`/`DATA`/`CLASSDATA`/`EXPORT ... AS <type>` viram
  `_HB_MEMBER { [AS <type>] nomes }`. Confirmação autoral do checker
  vestigial: o DECLARE de exemplo do próprio HBClass vive em `#if 0`
  para "not generate **ignored by compiler** noise in .ppo files"
  (hbclass.ch:176-189).
- **`AS CLASS` em EXPRESSÃO é cast parseado e DESCARTADO**
  (harbour.y:845-875: sufixo `StrongType` aceito em `Self`, funcall,
  send, variável e lista parentetizada, com ação `{ $$ = $1; }`).
  O hbclass o usa em toda impl de método (`DECLARED METHOD` expande
  `local Self AS CLASS <C> := QSelf() AS CLASS <C>`, hbclass.ch:
  261-263) e no `ENDCLASS` (`RETURN s_oClass:Instance() AS CLASS ...`,
  hbclass.ch:257). O fato que FICA em tabela (e no dump) é o da LOCAL
  `Self AS CLASS <C>` — a fonte do canal de receptor para `::`; o
  cast da expressão não deixa rastro em tabela nenhuma.
- **`MESSAGE <M> AS <tipo> VIRTUAL` PERDE o tipo declarado — provado
  em dump** (probe pv2, 2026-07-10): hbclass.ch:368-370 casa
  `[ AS <type> ]` mas emite `_HB_MEMBER <M>` SEM ele (idem
  `DEFERRED`) — `MESSAGE Rende AS Numeric VIRTUAL` entra na tabela
  sem tipo enquanto `METHOD Conta() AS Numeric` entra com `'N'`.
  Nota: isso vale para tipos SIMPLES; `AS CLASS <X>` nem casa no slot
  `<type>` dessas regras de pp (E0030 — o fato F2.1 da topologia (g)),
  então retorno-classe de membro SÓ se escreve pela linha `_HB_MEMBER`
  avulsa. O membro sem-tipo resultante é completável pela rota (g)
  APENAS onde houver prova de retorno (virtual puro não tem impl na
  classe — sem prova, sem completador; relato honesto).

### TypeOf — propagação na ferramenta (regra FECHADA; extensões B7 e B7b pelos portões de 2026-07-08)

Regra local: a ferramenta classifica o receptor de send propagando tipos
declarados sobre `statements[]`: `VARIABLE` (classe declarada; senão
binding único = exatamente 1 write + 0 refs + um só ASSIGN de topo →
tipo do RHS), `FUNCALL` (retorno declarado), `SEND` (retorno declarado
do método na classe do obj), literais de valor, `LIST` (último item),
`SELF`. Sem ordem, sem caminhos. Sombras de codeblock: uso de local
externa dentro de bloco resolve como `detached` (classifica);
`local`+`block` é PARÂMETRO do bloco (não classifica — o CBVAR não
guarda classe).

**Extensão B7 (spec-b7-tipos-interprocedurais.md, decisões D1-D3)** —
**DORMENTE desde o RE.3 (portão do Diego, 2026-07-09, forma "a"): o
usages de produto NÃO consome nada desta extensão nem da B7b — o
veredito de send sai só do canal declarado, e o dispatch por grafo
as-written saiu do SendVerdict. A máquina abaixo fica no fonte como
camada SUGERIDORA, insumo do materializador (fatia 2 da B9); a
descrição segue válida para ESSE consumidor:**

- `FUNCALL` sem retorno declarado: união (com acordo) dos pushes
  ROTULADOS de RETURN (`"ret": true`, ast-6) da função do PROJETO;
  ciclo/módulo sem rótulo/função de fora → desconhecido.
- `SEND` cujo método não é declarado na classe do receptor: resolve pela
  CADEIA DE CONSTRUÇÃO como escrita — FUNREFs na árvore da função-classe
  (fato da expansão; IIF de condição constante segue só o ramo tomado,
  como o reduce) — subindo até o teto de runtime pelo ORÁCULO (D3:
  `src/rtl/tobject.prg` compilado com `-x`, cache por mtime). Método
  achado por REGISTRO = par (STRING, `@F()`) em itens diretos do mesmo
  ARGLIST (genérico — hbclass, `__clsAddMsg`, qualquer DSL); par com
  codeblock = inline, sem fato de retorno. Implementação cujo todo
  RETURN é `QSelf()` (nó `SELF` no dump) devolve o RECEPTOR por
  IDENTIDADE (probe executado). `::Super:` tipa pela cadeia (vínculo
  único).
- PARÂMETRO sem escrita/`@ref`: união dos argumentos de TODOS os call
  sites FUNCALL do projeto — só com o mundo fechado AUDITADO (macro em
  qualquer módulo, nome citado em string ou função referenciada por
  `@F()` ⇒ desconhecido). STATIC une só o módulo; pública pula módulos
  onde STATIC homônima a sombreia; argumento omitido = NIL.
- Conjuntos FINITOS >1 classe: `possible` NOMEANDO os candidatos —
  nunca decide.
- Venenos: `Self := x` (ASSIGN real; o prólogo `Self := Self` do método
  não conta) e `@Self` degradam a função inteira (regra sem ordem).
- TODA travessia de vínculo escrito marca o tipo (`via`) e o rótulo do
  veredito carrega a ressalva: `via construction chain, class graph as
  written` (D1: mundo fechado; o veneno do forjador da Q4 — vínculo
  escrito que NÃO é pai — decide errado no mundo aberto e o rótulo é o
  que mantém a honestidade; provado por execução no fixq4: tipagem
  aninhada `x := t:Pintar(); x:Pintar()` decide LOUSA em mundo fechado
  num site que em runtime é código morto). Fronteira: retorno por
  primitiva C (`__clsInst` etc.) não tem fato de compilação —
  `possible` honesto (fixofi permanece assim).

**Extensão B7b (spec-b7b-inferencia.md, portão de 2026-07-08 — fase
100% ferramenta, schema inalterado)**:

- **Retorno de MÉTODO (send encadeado)**: método DECLARADO na classe do
  receptor mas SEM tipo de retorno (o `_HB_MEMBER` sem `AS` — a forma
  normal do hbclass) cai para a implementação REGISTRADA da própria
  classe e tipa pela união com acordo dos pushes `ret` (ast-6) — a
  mesma máquina do retorno de função; o acerto declarado continua
  parando o dispatch ali (não sobe vínculos). Identidade `RETURN Self`
  encadeia (`o:Soma(1):Soma(2)`); corpo com Self ENVENENADO
  (`Self := x`/`@Self`) não vale como identidade nem tipa; ciclo entre
  métodos degrada pela guarda; retornos discordantes degradam pela
  união.
- **PARÂMETRO DE BLOCO é decidido por FATO da declaração**, não por
  linha de occurrence: o dump registra os params do bloco em
  `declarations[]` com `param: true` e `declLine` na linha da
  MATERIALIZAÇÃO do bloco, em ordem (param da FUNÇÃO tem `declLine` na
  linha da função). **Precisão provada na fatia 3 (ast-9)**: em
  statement CONTINUADO a materialização acontece no FIM do bloco —
  `declLine` cai na ÚLTIMA linha física (igual ao nó CODEBLOCK, por
  isso o binder continua consistente), enquanto o token escrito do
  param está na linha do `{|`; `nameLine`/`nameCol` carregam a posição
  ESCRITA (capturada no parse via `HB_CBVAR`, padrão K1). O binder
  léxico é o bloco mais interno da pilha do uso cuja linha declara o
  nome; duas CODEBLOCK na mesma linha = inatribuível (degrada). O
  `B7ParamType` (união de call sites) passou a aceitar SÓ parâmetro de
  função — param de bloco corrompia o índice da união (furo latente,
  fechado no B7b).
- **1º parâmetro de bloco de membro INLINE = o RECEPTOR**: fato do VM
  (classes.c:4554 — `hb_vmPush( hb_stackSelfItem() )` antes dos
  argumentos), sobre o registro como-escrito (par STRING+CODEBLOCK em
  itens diretos do mesmo ARGLIST na função-classe — genérico:
  hbclass `AddInline`, `__clsAddMsg`, qualquer DSL; provado em DSL
  não-espelho no caso 86 com param que NÃO se chama Self). Tipo =
  classe da função-classe, com `via` (um descendente que herde o
  inline chega com receptor próprio — mundo fechado). Param declarado
  (`{|x AS CLASS F|`) vence pelo canal declarado; 2º+ param não tipa
  por aqui.
- **Demais parâmetros de bloco: união dos sites de Eval rastreáveis**.
  O compilador traduz `Eval(b,…)` para o send `b:EVAL(…)` (fato do
  dump); rastreável = o bloco é obj DIRETO de um Eval, ou é o ÚNICO
  write (binding único, 0 refs) de uma local cujas leituras são TODAS
  obj de Eval na MESMA função. Qualquer outra aparição/leitura (arg de
  função/iterador, item de array, RETURN, `@ref`, param reescrito no
  corpo) = ponto cego ⇒ degrada. Argumento omitido = NIL.
- **A leitura de pares de registro (B7Regs) é em PROFUNDIDADE-0**: não
  desce em corpo de CODEBLOCK — registro dentro de bloco não roda na
  construção da classe (executaria por dispatch: fronteira de runtime).

**Extensão B9 (spec-b9-anotacoes-impostas.md, fase ativa 2026-07-08 —
core `-kt` + consumo; a REGRA DO FATO é o portão)**:

- **`-kt` (HB_COMPFLAG_CHKTYPE)**: o compilador emite cheques de
  runtime para as anotações `AS` da linguagem — prólogo da função (um
  por parâmetro anotado, hb_compChkTypeParams), pós-atribuição a local
  anotado (gancho no funil hb_compGenPopVar) e RETURN de função com
  `DECLARE ... AS` (o valor é EMBRULHADO em `__HB_CHKTYPE( expr, spec,
  site )` — helper em classes.c que devolve o 1º argumento). NIL falha
  (T2); is-a passa pelo objeto VIVO (`hb_clsIsParent` — classe montada
  em runtime passa por NOME, T3/veneno 3); violação = erro catchável
  nomeando `site`, declarado e recebido. O cheque de local é
  PÓS-armazenamento: quem RECOVERa segue com o valor gravado — a
  âncora vale nos caminhos sem violação. Zero impacto sem a flag:
  224/224 .hrb byte-idênticos; com a flag, fonte sem anotação é
  byte-idêntico (a forma dimensionada NÃO conta — abaixo). Os gates do
  subsistema DECLARE abrem também sob `-kt` (warnings seguem gated por
  nível). Atribuição DENTRO de corpo de codeblock fica fora desta
  fatia (índice de local é relativo ao bloco); registrado.
- **Camada `guaranteed` no usages**: anotação de classe em módulo com
  `"kt": true` E site COBERTO pela fatia 1 (RE.2, fase RE) é INVARIANTE
  imposta — o veredito sai
  `guaranteed send (receiver AS CLASS X imposed by -kt checks)`, acima
  da promessa declarada; vale inclusive com multi-write DIRETO (toda
  escrita coberta é checada). Cobertura (`B7KtCovered`, matriz do RE.1):
  nenhuma occurrence do símbolo com `access:"ref"` nem com
  `access:"write"` + `block:true` — escrita dentro de codeblock (store
  block-relative) e via `@ref` (o pop é do parâmetro do callee) NÃO são
  checadas; anotação não coberta fica no canal declared (promessa sem
  selo). Param de codeblock nunca leva a marca (o binding do Eval não é
  checado; a gramática nem transporta o nome da classe nesse caminho).
  A marca morre ao virar cadeia (`how` chain) — a invariante
  é do símbolo anotado, não viaja por retorno/união.
- **`dim` não é promessa**: `LOCAL a[n]` sempre carregou 'A' interno; o
  DeclType da ferramenta o consumia como promessa de array e EXCLUÍA
  sends que rodam (exposição pré-existente desde a B4f, fechada no
  ast-7): com `"dim": true` a declaração não tipa — cai para
  binding único/cadeia (a própria declaração dimensionada conta um
  write, então reatribuída degrada honesto para possible).
- **`__HB_CHKTYPE` é identidade**: nos dumps de módulo `-kt`, o push de
  RETURN declarado aparece embrulhado; o TypeOf resolve pelo miolo
  (fato do runtime: o helper devolve o 1º argumento).

Estender a regra além disto = novo portão.

### Resolução de dispatch (B4f-2, ferramenta — spec-b4f2-dispatch.md)

Sobre o tipo do receptor, o `usages Classe:Método` DECIDE o dispatch com a
regra da LINGUAGEM (classes.c, provada em runtime pelos probes da spec):
método PRÓPRIO vence herdado; em conflito entre pais vence o PRIMEIRO da
cláusula, em PROFUNDIDADE (flattening do `__clsNew`). Mensagens próprias =
união do registro por stringify e do canal `declared`.

**Q4 (revisão de generalidade, 2026-07-07 — caso 75): os "pais" do grafo
são VÍNCULOS ESCRITOS, não fato.** Os identificadores posicionados na
linha da declaração (markers das aplicações declarantes) são leitura por
FORMA: no hbclass a palavra após o FROM é pai, mas numa DSL qualquer o
mesmo lugar carrega argumento que NÃO é pai — provado com forjador passado
por `@ref`, a MESMA forma do pai do hbclass. A linguagem NÃO tem canal de
herança (o `DECLARE` não carrega superclasse — fato 4 da B4f-2), então o
teto é da linguagem: **acerto PRÓPRIO decide (regra do VM, independe de
pais); resolução que ATRAVESSA vínculo escrito é indecidível para
confirmar/excluir** (`DispatchVia` gateia todo consumidor). Camadas:

- `confirmed send (receiver class X via declared types / declared AS
  CLASS X)` — receptor da PRÓPRIA classe consultada (sem resolução de
  vínculos envolvida);
- `excluded send (dispatches to Y:M)` — acerto PRÓPRIO de outra dona,
  receptor de classe EXATA (cadeia declarada);
- `excluded send within the project's class graph (dispatches to Y:M)` —
  idem com receptor DECLARADO (promessa): mundo fechado do grafo, sem
  descendente que sequestre — o rótulo carrega a ressalva;
- `possible send (receiver class X may dispatch to C:M through written
  parents, unproven)` — o walk como-escrito alcança C:M ATRAVÉS de
  vínculo(s); o candidato é nomeado, mas vínculo não é fato de parentesco
  (antes do Q4 isto saía confirmed/excluded — era o único ponto do
  sistema capaz de resposta ERRADA);
- `possible send (descendant D of X may dispatch to C:M)` — descendente no
  projeto que sequestraria o dispatch impede a exclusão (nomeado);
- indecidível (vínculo de fora do projeto antes de um hit, classe
  desconhecida, classes criadas/alteradas em runtime) — camadas B4f de
  sempre, nunca excluded.

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
- resolução da consultada decidível (acerto PRÓPRIO — Q4: resolução que
  atravessa vínculo escrito é rebaixada a indecidível) em OUTRA dona
  provada no grafo (fato 5) → `excluded ... (declares/implements Y:M)`,
  fora das `Location[]`;
- indecidível (fato 9, vínculo escrito no caminho) ou dona fora do grafo →
  `possible (registered under X, relation to C unknown)`, nunca excluded.

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
- **Sites DENTRO da regra** (`usages`/`RuleSiteHits`, B4g): identificador
  ou palavra citado no TEXTO da diretiva — `in rule match`/`in rule
  result` (literal type 21) e `in rule restriction` (alternativa, com o
  marker do dono) — via `match[]`/`result[]`, com arquivo:linha:coluna da
  REGRA. Nome de MARKER fica de fora (variável local da regra). Fecha o
  último esconderijo de um nome; canal textual (a posição é no arquivo da
  regra, não no módulo — fora das `Location[]`).
- **rename-dsl (B4g: qualquer palavra do MATCH)**: alvo = regra cujo
  match contém a palavra — CABEÇA (qualquer tipo de token: `@`/`?` são
  cabeças de pontuação), keyword SECUNDÁRIA (literal identificador) ou
  palavra de RESTRIÇÃO. Edita (a) os tokens posicionados das aplicações
  (`marker 0` para palavra literal; recheio do marker de restrição para
  alternativa) e (b) as ocorrências no lado do MATCH da diretiva por
  POSIÇÃO-FATO (`match[]` — cada token com linha/coluna físicas reais; a
  reancoragem textual da cabeça MORREU na B4g). Recusas fato-based:
  builtin (`file null`), diretiva fora do projeto, nome novo já
  cabeça/palavra de match de regra (captura visível até em regra nunca
  aplicada)/abreviação dBase (4 letras, famílias sem `x`)/identificador
  no stream, aplicação ou token de diretiva sem posição (expansão),
  uso abreviado. Verificação padrão-ouro: rename consistente não muda a
  expansão → `.ppo` e `.hrb -gh -l` de TODOS os módulos byte-idênticos,
  senão rollback — restrição cujo valor VAZA para o resultado (stringify
  do marker) muda a expansão e recusa AQUI, honesto (caso 82). O
  `.ppo`/`.ppt` gravam SEMPRE ao lado do fonte (independe de `-o`/cwd) —
  preservar um `.ppo` pré-existente do usuário.
- **rename-function `--edit-rules` (B4g, upgrade do caso 74)**: nome
  citado dentro de regra do projeto → recusa ACIONÁVEL nomeando
  diretiva+posição (sem o flag, ANTES de qualquer edição — regra nunca
  aplicada não dispara o oráculo e ficaria órfã em silêncio); com o flag,
  os tokens de `match[]`/`result[]` entram no conjunto de edições e
  passam pelo MESMO oráculo (mapa de símbolos + rollback + execução).
  Builtin ou token sem posição → recusa nomeando o motivo.
- **Consulta por posição (revisão Q5)** (`ResolveAtQuery`, core do
  `resolve-at` e do `usages --at`): "o que está sob o cursor" responde
  por camadas de fato — (1) nome que preenche match marker (apptoken
  posicionado byte-exato; é a ÚNICA posição da assinatura de construto
  gerado — tokens[] colapsa): a dona vem do fecho de derivação DAQUELE
  site por três fatos somados — co-derivação (`PpMarkerOwners`),
  APLICAÇÃO-IDENTIDADE (P1a: a app da posição carrega todas as partes do
  composto como markers posicionados; necessário porque o `from` da
  implementação hbclass deriva das posições da DECLARAÇÃO — provado no
  probe da Q5) e canal declared sequencial (`_HB_CLASS`/`_HB_MEMBER`,
  inclusive a lista `{ }` — cobre DSL declarativa pura); dona única →
  `query: Dona:Nome`; mais de uma → cru honesto; (2) palavra de regra
  (marker 0) → a própria; (3) identificador do stream → cru (send é
  dispatch dinâmico: nunca promove). Homônimo resolve pelo SITE. Posição
  sem identificador → recusa (consumidor cai para a palavra crua). Dump
  sem rastro degrada para cru. Contrato de saída: linha `query: <spec>`
  antes do relato. Coluna é BYTE (editor UTF-16 desalinha → fallback).
  B4g estendeu a sites DENTRO de diretiva: posição no TEXTO de uma regra
  do próprio módulo responde a palavra por posição-fato (`match[]`/
  `result[]`) — e vem ANTES do stream, porque um clone de expansão
  carrega a MESMA posição (fato 13) e descreveria o site como
  identificador comum; consulta crua (o usages responde com os sites,
  `RuleSiteHits` inclusos).
- **Vocabulário do DONO (revisão Q6)** (`OwnerVocabMap`/`OwnerWord`): o
  rótulo de TIPO do dono (`cog declaration (rig TOTEM)`, `oficio
  definition Talha (tenda Banca)`) usa a cabeça da regra cuja expansão
  LIGOU o nome ao canal de classe — o `from` do próprio nome, colhido no
  `_HB_CLASS` do stream (cobre dona declarativa pura, sem função) e no
  nome da função-de-classe gerada (cobre registro runtime puro, sem canal
  declared). NÃO é a regra raiz do site do dono: `CREATE CLASS X` tem
  raiz `CREATE` (açúcar sobre açúcar) e quem declara é a regra `CLASS` —
  o rótulo diz o que o dono É, não como a linha dele começa; hbclass
  segue `(class ...)`. Dona sem derivação (canal escrito à mão) cai para
  "class", o nome do próprio canal da linguagem — nunca palpite. Os
  rótulos EPISTÊMICOS de send ("receiver class X via declared types")
  ficam como estão: ali "class" é o conceito da linguagem
  (`AS CLASS`/`_HB_CLASS`), não vocabulário do hbclass.
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
  (mesma política do rename-method). Na forma CRUA do comando a MENSAGEM do
  composto vem do FATO (`GenMsgPart`: a parte que NÃO nomeia função-de-classe
  do projeto; indecidível ⇒ recusa pedindo `Classe:Metodo`) — a última parte
  da colagem é forma-de-hbclass e elegia a DONA numa DSL que cola a mensagem
  primeiro (revisão Q1, caso 76 — fixture fixofi). O pcode muda de verdade
  (ordem de push); a verificação é `HrbSymbolsEqual` (símbolos/funções
  intactos) + rollback, não byte-idêntico.
- **call-graph ciente de método (B4e P2b)**: um índice de MENSAGENS de método é
  montado do rastro — cada função gerada composta decompõe por
  `GenNameParts`; a MENSAGEM é a parte que NÃO nomeia função-de-classe e a
  DONA a que nomeia (`GenMsgPart`, fato da co-derivação — revisão Q3, caso
  78: eleger a última parte era forma-de-hbclass, elegia a DONA em DSL
  mensagem-primeiro e o comando respondia VAZIO em silêncio). Composto sem
  dona identificável (DSL sem classe) fica FORA do índice de mensagens —
  honesto, sem dona fantasma por posição. `call-graph <método>`
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
  método = nome composto pelo rastro cuja parte-DONA nomeia uma função de
  CLASSE do projeto (`GenMsgPart`/`ClassFuncMap` — a dona é a parte que
  nomeia, em QUALQUER posição da colagem; composto de DSL sem classe segue
  no caminho de função). **A síntese do alvo (`METHOD ... CLASS` +
  protótipo) é a exceção DOCUMENTADA de biblioteca (V4 da revisão: o pp
  não roda ao contrário)** — o portão é FATO do rastro: o vocábulo da
  regra raiz que consumiu o nome no site escrito (`PpMarkerLift`); só a
  forma `method` (hbclass) recebe síntese. Contêiner de "método" de DSL
  própria DEGRADA para FUNÇÃO verificada com o fato relatado no output
  (revisão Q7, caso 79) — nunca síntese de hbclass em projeto alheio.
  **Self-análogo (Q7)**: `QSelf()` escrito no fonte vira nó `SELF` na
  árvore de statements (fato do dump; NÃO gera occurrence — o cheque de
  occurrences de SELF não o vê). Range com nó `SELF` e alvo FUNÇÃO recusa
  LIMPO nomeando a exceção: numa chamada comum o receptor não viaja e o
  comportamento mudaria EM SILÊNCIO (a verificação de símbolos passa —
  provado no probe da revisão: o nome da classe sumiu da saída com o
  comando dizendo "verified"). O corpo move VERBATIM (`::`/sends/`Super`
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
confirmed/excluded do usages (TypeOf). A regra POR DENTRO
(`match[]`/`result[]` em `ppRules[]`) entregue no **ast-5** (fase B4g,
2026-07-07; portão no ADR-001), consumida por usages (`RuleSiteHits`),
rename-dsl (palavra do match por posição-fato), rename-function
`--edit-rules` e resolve-at (posição dentro de diretiva). O canal do `-kt`
(`"kt"` no cabeçalho + `"dim"` nas declarations) entregue no **ast-7**
(fase B9, 2026-07-08), consumido pela camada guaranteed do usages e
pela correção do DeclType (dim não é promessa). O fato de COBERTURA
do `-kt` (`"chk": true` na occurrence de escrita cujo pós-store o
próprio emissor checou e na declaração de parâmetro — de FUNÇÃO ou de
BLOCO — cujo prólogo ele emitiu; compast.c `hb_compAstUseChk`/
`hb_compAstDeclChk`, padrão retro-tag do `hb_compAstTag`) entregue no
**ast-8** (RE.5 K4, 2026-07-10), consumido pelo `B7KtCovered` — a
cobertura do selo `guaranteed` é LEITURA de fato, não matriz replicada
(site coberto = toda escrita write/ref com `chk` + param com `chk` na
declaração; dump antigo sem `chk` degrada para não-coberto, nunca
overclaim). A ÂNCORA DE ESCRITA (`"nameLine"`/`"nameCol"` nas
declarations — posição do token ESCRITO do nome) entregue no **ast-9**
(B9 fatia 3, 2026-07-10; decisão D2 do Diego: TODAS as declarações),
consumida pelo materializador do `annotate` — a régua de unicidade de
token do `AnnNameCol` virou degrade de dump antigo. Mecanismo no core:
back-scan limitado no stream capturado (o parser consumiu o nome há no
máximo o lookahead; o match mais próximo É o token da declaração;
variável homônima da própria classe do `AS CLASS` é pulada UMA vez —
adversarial provado), e para param de BLOCO a posição é capturada no
PARSE (`BlockVarList` → `HB_CBVAR.iPosLine/iPosCol`, padrão K1) porque
a materialização acontece no fim do bloco, com o stream já além do
corpo. Nome sem token de fonte (prov ≠ 's': diretiva, include) = campo
AUSENTE, honesto.

**O leitor da ferramenta (`ReadAst`) exige o schema EXATO** — o que o core do branch
emite hoje (`AstSchema()`). Não há piso, teto, lista nem degradação: o dump nasce a cada
comando do compilador que está no `HB_BIN`, então um dump de outra versão só pode
significar **toolchain fora de passo**, e a resposta é recusa alta com as duas versões
nomeadas. **A escada de degradação por versão foi REMOVIDA** (cinco funções, 23 sítios) —
ela fingia ler um dump que não pode chegar e, pior, com um build velho teria rebaixado o
**veredito** (entregando `possible` onde há `confirmed`) **em silêncio**, que é o oposto
do que este produto promete. *Registro do que ela dizia, para não voltar: "dump antigo
degrada/recusa com o fato, sem quebrar" — a boa intenção que custava a mentira.*

**Regra aprendida no bump `ast-8`** (custou uma bissecção) **e depois EXCETUADA — e a
exceção era o bug**: o documento dizia *"portão de capacidade usa VERSÃO MÍNIMA, NUNCA
lista enumerada"* e, no mesmo parágrafo, abria mão dela para o `ReadAst` (*"o teto
fechado vive só no `ReadAst`"*). A P10 achou essa lista viva, e ela **matou a ferramenta
inteira** no instante em que o core versionou para `ast-16` — recusa de todo módulo, com
o diagnóstico enganoso *"dump missing"*, com o dump no lugar. **Regra excetuada não é
regra.**

Próximo a avaliar: span original de string no posTrack
(mataria `StrDelimsOk`). Ao mudar, versionar `"schema"` e atualizar este
documento NO MESMO commit.
