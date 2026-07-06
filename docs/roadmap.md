# Roadmap v3 — hbrefactor sobre AST do compilador (2026-07-05)

Responsável pela ferramenta: Claude (planejamento, implementação, verificação);
decisões de produto e autorizações (commits, PR upstream): Diego.
Regra de manutenção: **este documento é vivo** — toda fase concluída ganha
status aqui, e nenhuma fase começa sem escopo e critério de pronto escritos.
Regra transversal: fluxos definidos vivem em **Makefile**; hbmk2 direto é só
experimentação. Histórico completo do smoke test: [roadmap-v2-arquivado.md](roadmap-v2-arquivado.md).

---

## O que o smoke test provou (Fases 0-5 do v2, concluídas)

O hbrefactor atual (~2.700 linhas .prg, 118 checks, 10 comandos, dogfooding em
hbhttpd e staff500/101 módulos) e o patch `-x` do branch
`feature/refactoring-mechanism` são **um smoke test bem-sucedido** — por ordem
do Diego, tudo neles pode ser redesenhado/reescrito/descartado, aproveitando só
o que for útil. O que se provou e SOBREVIVE como fundação:

1. **Compilador como oráculo** via ganchos de 1 linha + arquivo novo
   (padrão `compoccur.c`) — funciona, `.hrb` byte-idêntico sem o switch.
2. **Verificação editor ≠ verificador**: recompilar antes/depois, comparar
   byte a byte (ou comparadores estruturais de HRB), rollback automático —
   pegou erro real (caso 7/stringify).
3. **hbmk2 como resolvedor de projeto** (`-traceonly`) — parsing próprio de
   .hbp/.hbc foi apagado; princípio "reutilizar o builder oficial".
4. **Fixtures como contrato de comportamento** (mini-projetos ≥2 .prg + .ch +
   .hbp; recusas; ida-e-volta byte-exata; execução idêntica).
5. **Limite encontrado que motivou o pivô**: réplicas sintáticas na ferramenta
   (TokenScan, StructureCheck, ParseParenSpan, LineWords, StmtEdits) são
   frágeis e a do reorder-params tinha rede fraca — a fonte da verdade
   sintática tem que ser o compilador.

## Decisão de arquitetura (2026-07-05, ordem do Diego)

Branch **novo** a partir do master: `feature/compiler-ast-dump`. O compilador
ganha ganchos de 1 linha (gated por flag, zero impacto sem o switch) que
alimentam uma estrutura nova (`src/compiler/compast.c`) e emitem uma **AST por
módulo** (`.ast.json`, schema `ast-1`): stream de tokens com coluna real e
proveniência através do pp, declarações/escopos/usos (paridade com o occ),
calls/sends, estrutura de blocos, árvores de statement com spans. **O dump é
gerado através do hbmk2** (`-prgflag=-x<dir>/`) — funciona com qualquer projeto
que o hbmk2 aceite. O hbrefactor se **redesenha** sobre essa AST e apaga toda
réplica sintática. Motor de decisão+edição+verificação permanece FORA do
compilador. Detalhes: plano da sessão + [arquitetura.md](arquitetura.md).

---

## Fases (escopo + critério de pronto mecânico)

> **bravo-experimento: FORA DO ESCOPO (ordem do Diego, 2026-07-05).** O ERP
> legado será REMOVIDO de `work/` pelo Diego e só volta quando ele liberar —
> depois que o hbrefactor estiver funcionando nos testes da suíte e no
> `work/hbhttpd`. Nenhuma fase abaixo depende dele; a conversão `.hbp` que
> chegou a ser planejada fica suspensa junto. Corpus de validação do projeto:
> **fixtures da suíte + work/hbhttpd**.

### Fase B0 — Mecanismo AST no core (branch novo)

**Escopo**: `compast.c` + ganchos de 1 linha (yylex/ExprNew/GenStatement+Push
via macro no-op p/ macro build/FunctionAdd/VariableAdd/VariableFind/r-w-x/
calls/sends/RTVar/blocos da gramática/codeblocks/save-free) + posição no pp
(hash lateral: tokenizer primário + `hb_pp_tokenClone`) + switch `-x[<file>|
<dir>/]` + infra (fAst, cmdcheck, hbusage, Makefile).
**Critério**: harbour-core inteiro compilado com/sem `-x` → `.hrb` todos
byte-idênticos; binário sem `-x` byte-idêntico ao master; fixtures de tortura
(tab, comentário inline, `[..]`, string multi-linha, `;`, linha reescrita por
#command, stringify, codeblock aninhado) → `.ast.json` conferido campo a campo
(coluna exata; col=null só onde deve; blocks; árvore de statement).

> **`-x` — resolvido (2026-07-05)**: não há conflito real. O `-x[<prefix>]`
> (prefixo do init de símbolos, saída `.c`) foi REMOVIDO do compilador em
> 2015-02-17 (druzus, reescrita do parser de linha de comando; `ChangeLog.txt`)
> — a letra `x` está livre há 11 anos e não carrega significado vivo. Mantido
> `-x`; racional gravado no próprio código (`cmdcheck.c`, `case 'X'`). A doc
> órfã que ainda anuncia o flag removido (`doc/en/compiler.txt`,
> `src/main/harbour.1`) fica intocada por ora (decisão do Diego).

### Fase B1 — Fundação do hbrefactor novo ✅ (2026-07-05)

> **Status**: CONCLUÍDA junto com a B0 (mecanismo no core provado: fixture de
> tortura 86/86 tokens byte-exatos incl. stringify e linhas reescritas;
> varredura de 112 módulos de src/ com `.hrb` byte-idênticos com/sem `-x` e
> novo vs antigo; `hbmk2 -prgflag=-x<dir>/` gerando dumps por módulo).
> Ferramenta nova (src/hbrefactor.prg v0.2.0): LoadProject via
> `-traceonly -rebuild`, dumps via hbmk2, leitor ast-1, `usages` com colunas
> reais (hbhttpd em 0,58s). `make lexdiff`: 4.405 concordantes, 324
> adjudicadas por desenho (diretivas; continuação `;`; nomes consumidos por
> regra/hbclass — a família que a B4 exporá; sends/alias que o TS excluía),
> **0 divergências reais** — e a porta ACHOU BUG no TokenScan arquivado
> (`x-- > y` lido como seta de alias através do espaço; AST correto,
> byte-provado). Paridade occ↔ast: 0 faltando / 0 não classificados em todo
> o corpus. Fricções corrigidas: `-traceonly` mudo sem `-rebuild` em projeto
> `-inc` em dia; nome do `-o` vazando no fallback do nome do dump.
>
> **Liberação (Diego, 2026-07-05): compatibilidade com o primeiro
> experimento NÃO é requisito.** O lexdiff e o comparador occ↔ast foram
> instrumentos de CONFIANÇA na transição — cumprido o papel, não são
> contratos. A estrutura da AST (schema, seções, granularidade) e a própria
> ferramenta podem ser recriadas da forma IDEAL, inclusive redesenhadas do
> zero, sempre que conveniente. O que permanece como contrato é o
> COMPORTAMENTO provado (fixtures: recusas, ida-e-volta byte-exata,
> verificação com rollback) — não formatos nem estruturas internas da era
> smoke test.

**Escopo**: dumps via `hbmk2 <alvos> -prgflag=-x<dir>/ -s`; leitor de
`.ast.json`; núcleo de fatos novo (tokens/blocos/statements/escopos).
**Critério**: comparador `occ↔ast-projection` campo-idêntico sobre as
fixtures + hbhttpd (dumps antigos gerados com o binário do branch velho, que
segue na árvore principal); `make lexdiff` — colunas do AST vs TokenScan —
com **0 divergências não adjudicadas** (adjudicadas → armadilhas-shx.md).

### Fase B2 — Comandos re-assentados sobre a AST ✅ (2026-07-05)

> **Status FINAL 2026-07-05 — fase concluída.** Specs (a)-(d) executadas;
> critério de pronto cumprido: `make test` verde completo com o run.sh da
> segunda encarnação (34 casos / 125 checks), ida-e-volta byte-exata dos
> renames (suíte + hbhttpd), dogfooding no hbhttpd (usages 0,5s;
> rename-local A→B→A byte-exato; reorder-params A→B→A byte-exato;
> extract-function real em UHtmlEncode verificado e revertido;
> rename-function pegando o DYNAMIC do .hbx real), e nenhuma réplica
> sintática no fonte novo (v0.3.0, ~2.500 linhas, 11 comandos).
>
> **(b) `extract-function` implementado** com fatos do compilador:
> estrutura por pares de `blocks[]` (pilha), saltos RETURN/EXIT/LOOP/BREAK
> por tokens + cobertura de par inteiro na seleção, data flow por
> occurrences (dentro/antes/depois; write-first+uso posterior = valor de
> retorno; só-dentro = migração da declaração), recusas para macro na
> seleção, declaração não-local na seleção e codeblock capturando local
> viva fora; verificação HrbExtractCheck (+1 símbolo exato) + rollback;
> grafia original via tokens. **Migração de declaração POR VARIÁVEL**
> (`DeclCutRange`): vãos entre vizinhos posicionados validados no texto —
> `LOCAL nI, cI, cRet := ""` migra nI/cI mesmo com inicializador alheio na
> linha (provado no hbhttpd; caso 33).
>
> **(c) `usages --json` re-validado** contra os asserts python dos casos
> 18/26 (Location[] com def+call e colunas reais).
>
> **(d) run.sh reescrito**: casos 0-30 preservados (greps adaptados às
> mensagens novas), modo degradado da era occ removido, casos novos
> 31 (reorder multi-linha + `,`/`)` em string de argumento — fecha a
> pendência da spec (a)), 32 (rename-function em statement continuado) e
> 33 (migração por variável). `make test` = contrato executável.
>
> **LIÇÃO DE DESIGN (registrada também no ast-schema.md)**: fechamentos,
> vírgulas e chaves NUNCA têm coluna no dump, e o `len` de string é o valor
> normalizado sem delimitadores — recorte de argumento por
> primeiro/último token posicionado corta `Foo( Len( "a,b)c" ), 2 )` no
> meio. O desenho certo (`BuildArgSpan`): faixa de ÍNDICES do stream +
> extensão de string validada byte a byte + casamento das bordas sem
> posição contra o fonte, com recusa em qualquer não-conferência. De
> quebra, `ApplyRangeEdits` deixou de pular edição não-conferente em
> silêncio (a verificação de símbolos do reorder não pegaria semântica
> trocada): agora recusa com rollback.
>
> Status anterior (histórico): 10 comandos vivos na segunda encarnação
> (src/hbrefactor.prg v0.2.0, ~1.700 linhas, ZERO sintaxe replicada):
> `usages` (colunas reais), `rename-local`/`rename-param` (coleta por SPAN
> de função + tokens; casos 1-7/13/24 verdes; ida-e-volta byte-exata em
> fixture e hbhttpd inclusive métodos `Classe:Método`), `rename-static`
> (file-wide + de função; caso 21), `rename-function` (spans de índice das
> statements p/ continuação `;`; strings=relato+`--force`; comparador
> estrutural HrbEquivalent; casos 10-12), `unused-locals` (19),
> `call-graph` (20), `find-dynamic-calls` (22; strings do próprio stream),
> `dump`. Receitas de consumo documentadas em [ast-schema.md](ast-schema.md)
> — LER ANTES de mexer na ferramenta.

**Restante da fase, como specs executáveis:**

**(a) `reorder-params` ✅ (2026-07-05)** — implementado com LIÇÃO DE DESIGN
importante, registrada também no ast-schema.md: os `tok` (birthTok) dos nós
da árvore nascem ATRASADOS pelo lookahead do bison — spans de subárvore NÃO
servem para recortar argumentos. O desenho certo: **balancear o STREAM de
tokens por TIPO** (padrão nome+`(`; 50/51/52/53/54/55 controlam profundidade,
29=`,` separa no nível 1), varrendo o SPAN DA FUNÇÃO (o registro de call em
statement continuado aponta a última linha física; o token do nome sabe a
sua). Resultado: casos 14 (comportamento idêntico por execução) e 15
("implicit NIL would move") verdes, e **call site multi-linha reordenado
corretamente** (poder novo — a era occ recusava). HrbSymbolsEqual portado.
Falta na suíte: caso com `,`/`)` dentro de string em argumento (spans por
token tornam trivial — só provar).

**(b) `extract-function <proj> <arq> <ini>-<fim> <nome> [--dry-run]` ✅ (2026-07-05)**
- Estrutura: `blocks[]` da função substitui o StructureCheck — recusar se
  qualquer `open` no intervalo não tem `close` no intervalo e vice-versa
  (parear por pilha, mesma kind). RETURN/EXIT/LOOP/BREAK cruzando a borda:
  detectar por tokens type 21 com esses textos no intervalo fora de
  bloco-fechado (regra da era occ) OU pelas statements.
- Data flow: occurrences da função no intervalo vs fora (antes/depois):
  参 = usada dentro+fora; write-first sem uso posterior = LOCAL da nova;
  usada só dentro (sem before/after, decl fora) = MIGRA a declaração
  (comportamento provado no caso 16 da era occ - ver
  smoketest/hbrefactor-occ.prg DeclNameRemoval como referência).
- Verificação: HrbExtractCheck (símbolos +1 exato; portar) + rollback +
  execução idêntica (caso 16).
- Grafia original dos nomes: recuperar do fonte via tokens (dump é uppercase
  em declarations/occurrences; tokens têm o texto original).

**(c) `--json` (casos 18/26) ✅ (2026-07-05)**: `usages --json` já emite LSP Location[];
  re-validar contra os asserts python dos casos 18/26 do run.sh antigo.

**(d) run.sh da segunda encarnação ✅ (2026-07-05)**: reescrever tests/run.sh dirigindo a
  ferramenta nova (mesmos comportamentos; números de caso preservados onde
  fizer sentido; casos novos: multi-linha do reorder, span/continuação do
  rename-function). `make test` volta a ser o contrato executável. Remover
  o modo degradado da era occ que não existe mais (cobertura parcial fica
  para quando um projeto real quebrado voltar ao escopo).

**Critério de pronto da fase**: `make test` verde completo com o run.sh
novo; ida-e-volta byte-exata dos renames; dogfooding no hbhttpd (usages +
1 rename por comando); TokenScan/LineWords/ParseParenSpan/StructureCheck/
StmtEdits ausentes do fonte novo (já verdade hoje).

### Fase B3 — Poderes novos ✅ (2026-07-05)

> **Status FINAL 2026-07-05 — fase concluída** (v0.3.0, 12 comandos;
> `make test` 37 casos / 143 checks verdes).
>
> **reorder-params com ARGUMENTO multi-linha**: já saiu de graça do
> `BuildArgSpan` da B2 (spans reais de fonte, não presos à linha) — o `;`
> de continuação viaja dentro do texto do argumento e o resultado é
> válido. Provado no caso 34 com execução idêntica.
>
> **`inline-local <proj> <arq> <função> <nome> [--dry-run]`**: substitui as
> leituras de uma LOCAL pela expressão do init e remove a declaração.
> Portões (a expressão é DUPLICADA e reavaliada em cada uso):
> 1. **Pureza por allowlist da árvore do compilador**: folhas
>    NIL/NUMERIC/DATE/TIMESTAMP/STRING/LOGICAL/VARIABLE + combinadores
>    IIF/LIST/OR/AND/NOT/EQUAL/EQ/NE/IN/LT/GT/LE/GE/PLUS/MINUS/MULT/DIV/
>    MOD/POWER/NEGATE; qualquer outro et (FUNCALL, SEND, MACRO, ARRAYAT,
>    ARRAY/HASH que criam identidade, atribuições, ++/--) recusa.
> 2. Única escrita = o init; leituras simples (access read), fora de
>    codeblock; variáveis da expressão não reescritas depois do próprio
>    init; declaração sozinha na linha, sem continuação nem comentário.
> 3. **Nome citado em string recusa SEM filtro de linha** — o token do
>    stringify (`<"v">`) nasce sintetizado com line 0/prov 'n' e a
>    verificação de símbolos NÃO pegaria a troca (diferente do rename, que
>    tem a rede byte-idêntica). Pego no caso 36; registrado no ast-schema.
> 4. Init vindo de #define recusa por construção (o valor expandido não
>    tem posição no fonte - BuildArgSpan falha; o texto certo seria o
>    próprio nome da regra, território da B4).
> Verificação: HrbSymbolsEqual no módulo editado (pcode muda
> legitimamente) + demais módulos byte-idênticos + rollback.
> Casos 35 (execução idêntica em função executada pelo Main da fixture) e
> 36 (5 recusas). Dogfooding hbhttpd: recusas corretas e explicadas
> (nCount++ = "use"; cI reescrita) - o corpus real não tem candidato
> limpo, que é o comportamento esperado de um portão conservador.

**Escopo**: reorder-params multi-linha (spans reais de argumentos);
inline-local (árvore de expressão + análise de pureza).
**Critério**: fixtures de comportamento (execução idêntica) + recusas; checks
novos na suíte.

### Fase B4 — DSLs customizadas de pré-processador (caso especial, análise registrada) ✅

> **Status FINAL 2026-07-06 — fase concluída** (v0.4.0, 12 comandos;
> `make test` 44 casos / 200 checks verdes; specs S1–S5 = casos 38–42,
> guarda estrutural REPEAT = caso 43).
>
> **Decisões de desenho (questionamentos do Diego, 2026-07-05,
> incorporados):**
> 1. **Sem comando de busca dedicado**: `usages` responde TAMBÉM para
>    palavra de DSL (definição da diretiva + aplicações + palavras
>    secundárias, via `DslHits`) — o programador não precisa saber em que
>    "mundo" a palavra vive antes de perguntar. Ficou específico só o
>    `rename-dsl`, porque a EDIÇÃO tem semântica própria (edita diretiva
>    + sites; verificação `.ppo`+`.hrb` byte-idênticos, diferente das
>    verificações dos outros renames) — consistente com a família
>    rename-<espécie> existente. O `usages-dsl` planejado morreu antes de
>    nascer como comando; virou seção do `usages`.
> 2. **Genericidade é requisito**: a ferramenta opera SÓ sobre os fatos
>    genéricos do funil único (`hb_pp_patternReplace`): cabeça, kind,
>    arquivo/linha da diretiva, atribuição token→marker (marker 0 =
>    palavra literal da regra). Nada no código é por-família ou
>    por-DSL-conhecida — vale para `#command`/`#xcommand`/`#translate`/
>    `#xtranslate`/`#define` E para qualquer comando novo que o usuário
>    crie por diretiva (provado com DSL inventada na fixture, regras
>    DINÂMICAS que o hbclass.ch registra por método, e regras builtin).
>    Única peça por-PADRÃO (não por-DSL): o lifting `MethodLift` casa
>    função gerada com aplicação na mesma linha cujos markers concatenam
>    `<A>_<B>` — cobre qualquer DSL que cole nomes assim (hbclass.ch é o
>    caso canônico), e falha para colagens diferentes (aí é relato normal
>    de função, nunca resposta errada).
>
> **Entregue na ferramenta:**
> - `usages <palavra-de-DSL>`: diretiva (`menu.ch:8: directive (#command
>   MENUITEM, 4 marker(s))` — linha na convenção do pp: última linha
>   física de diretiva continuada), aplicações com coluna byte-exata
>   (inclusive uso continuado por `;`: cada token na sua linha física),
>   palavras secundárias (`ACTION`, `SAY`...) como `keyword` da regra,
>   builtin com `(builtin)`, multi-passe visível ("sem posição no fonte").
> - `rename-dsl <velha> <nova>`: edita os sites (tokens marker 0
>   posicionados) + a cabeça no lado do MATCH da diretiva (reancorada no
>   início físico `#<kind>`; `#define` = caso degenerado, 1ª ocorrência).
>   Recusas: builtin; diretiva fora do projeto; nome novo já cabeça de
>   regra OU colisão por abreviação dBase (4 letras, famílias sem `x`,
>   checada nos DOIS sentidos); nome novo já identificador no projeto
>   (captura); aplicação sem posição (multi-passe/include); uso abreviado
>   da cabeça. Verificação padrão-ouro: `.ppo` E `.hrb` de TODOS os
>   módulos byte-idênticos, senão rollback; ida-e-volta A→B→A byte-exata
>   provada nas três famílias (casos 38/41).
> - **Lifting**: `usages Paint` → `method definition Paint (class
>   UWMenu)` com posição real; `UWMENU_PAINT` só com `--show-expansion`;
>   `PickFunc` aceita `Classe:Metodo`/método puro via `MethodLift` — a
>   convenção textual `<CLASSE>_<MÉTODO>` morreu (caso 29 atualizado).
> - **Réplica textual morta** (item B.1 da auditoria): `DefineCollision`/
>   `PpHeadIn` apagadas → `RuleHeadCollision` sobre `ppRules` em
>   rename-local/rename-static/extract-function (cobre includes
>   aninhados, builtin aplicadas e abreviação dBase — o textual não via
>   nenhum dos três).
> - **S5**: `ppApplications` casa 1:1 com o `.ppt` (`-p+`) em contagem,
>   ordem, linhas e kinds (caso 42, comparador no runner).
>
> **Armadilha nova documentada (CLAUDE.md do core + ast-schema)**: o
> hbmk2 compila com o compilador EMBUTIDO — hbmk2 velho emite dump ast-1
> sem `ppRules` mesmo com `harbour` novo; conferir
> `strings $HB_BIN/hbmk2 | grep ast-`.
>
> Status anterior (2026-07-05): mecanismo no core pronto e verificado
> (item 1 da lista abaixo). Implementado em `src/pp/ppcore.c` (mesmo padrão da posTbl
> B0: lógica no pp, ganchos de 1 linha gated por `fTrackPos`): registro
> de regra nos pontos de `#define` (defineNew→defineAdd) e
> `#[x]translate`/`#[x]command` (directiveNew), aplicação no funil único
> `hb_pp_patternReplace` — com os marker results ainda vivos, o que dá a
> atribuição token→marker sem replicar gramática (marker 0 = palavra
> literal da regra). Regras builtin/API (std rules, -D) ganham registro
> LAZY na 1ª aplicação com `file: null`. Tabelas por módulo (limpas em
> hb_pp_reset), 5 accessors públicos em hbpp.h, emissão em compast.c;
> schema → **ast-2** (spec: [ast-schema.md](ast-schema.md)).
> **Verificação**: smoke test com DSL (REPEAT@5:3, UNTIL@7:3,
> MENUITEM@8:3 + ACTION/AT com colunas exatas; recheio de marker com
> proveniência certa — valor de #define aponta a linha do .ch; multi-
> passe visível); varredura dos 112 .prg de src/ → 112/112 `.hrb`
> byte-idênticos com/sem `-x`, 112/112 dumps ast-2 válidos (27.417
> aplicações registradas), 0 divergências; leitor da ferramenta aceita
> ast-1|ast-2 e `make test` verde (38 casos / 155 checks).
>
> **Notas do Diego (2026-07-05) incorporadas ao escopo das fixtures:**
> 1. O comando de DSL da fixture deve receber MÚLTIPLOS argumentos
>    (testar reposicionamento de argumentos, entre outros) — o smoke já
>    usa `MENUITEM <label> ACTION <act> AT <row>, <col>` com o resultado
>    reordenando os markers.
> 2. Além do `.ppo`, o `-p+` do harbour gera `.ppt` (trace do pp, uma
>    linha por aplicação, saída do MESMO funil onde vive o gancho) —
>    instrumento de validação cruzada 1:1 de `ppApplications`.
> 3. `#command`/`#xcommand`: o USO precisa estar numa linha só (multi-
>    linha exige `;`); `#[x]translate` opera SUBSTITUINDO no meio da
>    statement — as fixtures devem cobrir as duas famílias.
>
> **Armadilha pré-existente descoberta (vira fixture)**: a std.ch tem
> `#command ENDIF <*x*> => endif` — o wild marker engole `; ENDDO` que
> venha depois na expansão (provado em binário pristino; não é regressão
> do branch). `UNTIL <c> => IF <c> ; EXIT ; ENDIF ; ENDDO` perde o ENDDO
> e dá E0017; a forma clássica que funciona: `IF <c> ; EXIT ; END ; END`.
> O exemplo de UNTIL abaixo mantém a forma ilustrativa original.

**O caso**: programadores criam "DSLs" com diretivas — `#command`/`#xcommand`/
`#translate`/`#xtranslate`/`#define` — que encapsulam código Harbour:

```
#xcommand REPEAT => DO WHILE .T.
#xcommand UNTIL <cond> => IF <cond> ; EXIT ; ENDIF ; ENDDO
#command MENUITEM <label> ACTION <act> => MenuAdd( <label>, {|| <act> } )
```

O fonte passa a conter construções que **não existem na linguagem** — e é esse
fonte que a refatoração edita. Três sub-problemas, com situações distintas:

**(a) Símbolos Harbour DENTRO de uso de DSL — JÁ RESOLVIDO (provado no B0).**
Identificadores que atravessam a regra via match marker (`<cond>`, `<act>`)
chegam ao compilador como clones que **preservam linha/coluna do fonte
original** (proveniência no `hb_pp_tokenClone`; fixture de tortura: 86/86
byte-exatos, incluindo stringify). Rename de local/var/função usada dentro de
`MENUITEM "x" ACTION Foo( nTotal )` funciona pelo fluxo normal: o dump dá a
posição exata de `nTotal`/`Foo`, a edição é no fonte, a verificação recompila.

**(b) Estrutura de bloco CRIADA pela DSL — JÁ RESOLVIDO por construção.** Os
eventos de bloco vêm das ações da gramática sobre o código **expandido** (é o
que o compilador vê): `REPEAT`/`UNTIL` geram `while open/close` nas linhas
físicas certas. `extract-function` que corta uma DSL no meio (seleção com
`REPEAT` sem o `UNTIL`) é recusado pelo balanceamento — sem heurística.

**(c) As PALAVRAS da própria DSL — LACUNA, é o trabalho desta fase.** Os
tokens `REPEAT`/`MENUITEM`/`ACTION` são **consumidos pelo pp** e nunca chegam
ao yylex: não estão no stream do dump. Renomear a palavra da DSL (definição +
todos os usos), achar usos de uma diretiva (`usages` de DSL) ou avisar que uma
edição toca área casada por regra exige fatos novos:

1. **Dump ast-2 — seção `ppRules` + `ppApplications`**: gancho único em
   `hb_pp_patternReplace` (ppcore.c:4587 — funil de TODA aplicação de
   define/translate/command, com `pState`+`pRule`+tokens casados, que JÁ têm
   posição na tabela do pp) exporta, por aplicação: id da regra, tipo, span
   dos tokens consumidos no fonte (inclusive a posição da palavra-chave) e
   linha. Um segundo gancho pequeno no registro de regra (`hb_pp_ruleAdd`-
   like) exporta a definição: arquivo/linha da diretiva, cabeça, markers.
   Mesmo padrão do B0: lógica no compast/pp-side, chamadas de 1 linha.
2. **Comandos novos sobre esses fatos**: `usages-dsl <palavra>` (aplicações +
   definição); `rename-dsl` = renomear a cabeça na diretiva + em todos os
   sites de aplicação (a posição da palavra vem de `ppApplications`).
   Absorve o antigo item "rename-define" do backlog (um `#define` constante é
   o caso degenerado: regra sem markers).
3. **Critério forte disponível (padrão-ouro da Fase 0 do smoke test)**:
   rename consistente (definição + usos) produz expansão idêntica → `.ppo`
   normalizado e `.hrb` **byte-idênticos** antes/depois. A verificação
   independente continua sendo o juiz.

**Recusas/armadilhas a registrar em fixtures** (território H herdado da
tabela S/H/X): abreviação dBase de `#command` (4 letras — `MENUITEM` casa
`MENU`? conservadorismo: recusar quando a nova/velha palavra colide por
abreviação com outra regra); regras re-aplicadas em multi-passe (proveniência
atravessa clone-de-clone — já coberto, mas fixture dedicada); palavra de DSL
igual a identificador comum no mesmo projeto (o dump distingue: aplicação de
regra × token do stream); `#undef`/redefinição no meio do projeto (a mesma
palavra pode ser DSL num módulo e não noutro — fatos são POR MÓDULO, decidir
por módulo); stringify/duplicação de marker no resultado (edição é no fonte,
recompile-verify cobre — provado).

**Princípio de apresentação (nota do Diego, 2026-07-05): o programador vê o
COMANDO, não a transformação.** As classes do hbclass.ch são o exemplo
clássico e canônico: quem escreve `METHOD Paint() CLASS UWMenu` pensa em
"método Paint da classe UWMenu" — nunca em `UWMENU_PAINT()`, `__clsAddMsg`
ou nos sends de `ADDMETHOD` que a expansão gera. Consequências de projeto:

1. **A ferramenta responde no vocabulário do fonte.** `usages Paint` deve
   dizer "definição do método Paint (classe UWMenu), widgets.prg:309" — não
   "função UWMENU_PAINT" nem "convenção de nome" (a heurística de sufixo da
   era smoke test morre quando os fatos reais existirem).
2. **`ppApplications` é a ponte de volta (lifting).** Cada aplicação de
   regra liga: span consumido no FONTE (tokens com posição, ex.: `METHOD`,
   `Paint`, `CLASS`, `UWMenu` na linha 309) ⇄ regra aplicada (hbclass.ch,
   linha da diretiva) ⇄ artefatos da EXPANSÃO (a função `UWMENU_PAINT` que
   aparece em `functions`, os sends gerados). Com o mapa, todo fato do
   mundo expandido é traduzido de volta para o comando que o programador
   escreveu antes de ser exibido ou editado.
3. **Medição já existente**: a porta `lexdiff` da B1 adjudicou no hbhttpd
   exatamente essa família (nomes de método/classe consumidos pela regra,
   linhas `METHOD ... CLASS ...` sem tokens) — são os sites que hoje só o
   TokenScan textual enxerga e que o `ppApplications` tornará fatos de
   primeira classe, com a regra e o span exatos em vez de texto solto.
4. **Vale para toda DSL, não só classes**: `MENUITEM ... ACTION ...` deve
   aparecer como "comando MENUITEM (regra sua, arquivo X)" nos relatórios —
   a ferramenta nunca vaza `MenuAdd(...)` para o usuário a menos que ele
   peça a expansão (`--show-expansion` como opção de depuração).

**Specs de teste — DSLs complexas (nota do Diego, 2026-07-05; formato
spec-driven para execução em sessão nova).** Os testes de refatoração de
DSL criada com `#command`/`#xcommand`/`#[x]translate`/`#define` precisam
cobrir DSLs COMPLEXAS, não só as didáticas. Cada spec abaixo é um caso da
suíte (fixture mini-projeto ≥2 .prg + .ch próprio quando a DSL for do
usuário; include de sistema quando for do core):

- **S1 — DSL didática multi-argumento** (já no smoke da B4): dado
  `#command MENUITEM <label> ACTION <act> AT <row>, <col>` (resultado
  REORDENA os markers) e `#xtranslate SQUARED(<n>)`, quando `usages-dsl`/
  `rename-dsl` rodam, então definição+aplicações saem com colunas exatas
  e o rename verifica `.ppo`/`.hrb` byte-idênticos. O comando de teste
  TEM que receber mais de um argumento (reposicionamento de argumentos
  entre as coisas a provar).
- **S2 — classes hbclass.ch (caso canônico de DSL complexa)**: dado um
  mini-projeto com `CREATE CLASS ... METHOD Paint() ... ENDCLASS` e
  `METHOD Paint() CLASS UWMenu` (multi-regra, multi-passe, nomes gerados
  `UWMENU_PAINT`), quando `usages Paint` roda, então a resposta vem no
  vocabulário método/classe via lifting por `ppApplications` (nunca
  `UWMENU_PAINT`, salvo `--show-expansion`); as aplicações das regras do
  hbclass.ch aparecem com spans no fonte do usuário.
- **S3 — comando complexo do core estilo TBROWSE/@...SAY** (std.ch, com
  cláusulas opcionais `[...]`, markers repetíveis e lista): dado fonte
  usando `@ row, col SAY ... GET ...`/TBROWSE-família, quando o dump é
  gerado, então cada aplicação registra a regra builtin (`file: null`)
  com os recheios de marker certos — e a ferramenta NÃO oferece
  rename-dsl de regra sem arquivo (não há diretiva a editar; relato).
- **S4 — as duas famílias**: `#[x]command` (uso preso a uma linha; multi-
  linha só com `;`) e `#[x]translate` (substituição no meio da statement,
  inclusive múltiplas na mesma linha) — casos separados provando spans
  corretos em ambos.
- **S5 — validação cruzada `.ppt`**: `harbour -p+` no módulo da fixture;
  `ppApplications` casa 1:1 (contagem, ordem, linhas) com o trace.

**Critério de pronto da fase**: fixture com a DSL acima (REPEAT/UNTIL +
MENUITEM) num mini-projeto ≥2 .prg + .ch: `usages-dsl` lista definição e
aplicações com colunas; `rename-dsl MENUITEM MENU_ITEM` edita .ch + usos e
verifica `.ppo`/`.hrb` byte-idênticos; seleção de extract cortando REPEAT é
recusada; **`usages Paint` numa fixture com classe responde no vocabulário
método/classe (lifting provado)**; specs S1-S5 na suíte; suíte verde.

### Fase B4b — Variáveis de escopo dinâmico e afins (caso especial, análise registrada)

**O caso**: em Harbour uma variável pode ser LOCAL/parâmetro (léxica),
STATIC (léxica ao módulo/função), PRIVATE/PUBLIC (memvar de escopo
**DINÂMICO** — criada em runtime e visível em toda a extensão dinâmica, isto
é, nos callees da função criadora), declarada MEMVAR, não declarada
(memvar implícita) ou FIELD/`alias->` (ligada a workarea em runtime). Entre
elas há **shadowing** em dois eixos: léxico (um LOCAL `x` numa função vence
qualquer memvar `x` ali) e dinâmico (um PRIVATE `x` sombreia o PUBLIC `x`
enquanto viver; dois PRIVATEs homônimos em ramos distintos do call stack).

**O que o compilador já decide — e o dump ast-1 já entrega (não adivinhamos):**
- Cada ocorrência vem com o escopo **resolvido pelo compilador** para aquele
  ponto: `local`/`detached`/`static`(+filewide)/`memvar`/`field`/
  `memvar_implicit`. O shadowing LÉXICO intra-função, portanto, já chega
  decidido: se `x` é LOCAL na função F, os usos em F vêm como `local`; na
  função G sem o LOCAL, vêm como `memvar` — são coisas diferentes e o dump
  as distingue por construção.
- Criações PRIVATE/PUBLIC com init (hook RTVar, acesso w/u), declarações
  MEMVAR por função, `M->`/`alias->` classificados, calls/sends (para
  raciocinar sobre extensão dinâmica) e `usesMacro` por função (macro pode
  criar/ler memvar invisível ao compilador).

**O que é análise NOVA da ferramenta (nenhum gancho novo no core):**
1. **Modelo de visibilidade por nome** (`usages-memvar <nome>`, read-only):
   criadores (PRIVATE/PUBLIC, com módulo/função/linha), declaradores
   (MEMVAR), usos por classe; **alcance dinâmico potencial** de cada PRIVATE
   = fecho transitivo dos callees a partir do criador, pelo call graph do
   projeto; furos do fecho sinalizados: chamadas dinâmicas
   (`find-dynamic-calls`), sends (métodos), funções fora do projeto,
   `usesMacro` no alcance.
2. **Relato de shadowing**: (a) função no alcance com LOCAL homônimo — usos
   ali NÃO são a memvar (o dump já os liga ao local; mostrar como
   "sombreado"); (b) mais de um criador PRIVATE homônimo; (c) PUBLIC +
   PRIVATE homônimos (sombra dinâmica); (d) mesma memvar criada em módulos
   distintos.
3. **Política de rename (território H por natureza)**:
   `rename-memvar` só quando o fecho é FECHADO e limpo — um único criador,
   todos os usos alcançáveis a partir dele, nenhum furo (dinâmico/macro/
   externo), nenhum homônimo — senão relato e recusa. **Recusa-chave (muda
   binding em silêncio)**: renomear memvar para um nome que alguma função do
   alcance declara LOCAL — o uso deixaria de ser memvar e viraria o local;
   o inverso idem (rename-local para nome de memvar visível — a recusa por
   colisão do smoke test continua valendo, agora com o mapa completo).
   FIELD/`alias->`: dado externo (schema de tabela) — **relato, nunca
   edição** (política de strings estendida a campos).
4. **STATIC**: léxica — continua S (rename-static provado no smoke test);
   o filewide do dump cobre o caso módulo-inteiro.

**Critério de pronto**: fixture armada com shadowing nos dois eixos
(PUBLIC x + PRIVATE x em callee + LOCAL x numa terceira função + uso
implícito + criação via macro numa quarta) num mini-projeto ≥2 .prg:
`usages-memvar` imprime o mapa correto (criadores, alcance, sombreados,
furos); `rename-memvar` recusa nos casos sujos com mensagem explicando o
furo, executa no caso limpo com **comportamento idêntico por execução**
(padrão da Fase 2 do smoke test) e ida-e-volta byte-exata dos fontes.

### Fase B5 — Extensão VSCode re-apontada (em andamento)

> **Fatia da B4 entregue (2026-07-06)**: a extensão ganhou o comando
> `hbrefactor: Rename directive/command word (pp DSL)`
> (`hbrefactor.renameDsl`, chama `rename-dsl` com a palavra sob o cursor,
> projeto inteiro), e o `usages` já enxerga palavra de DSL de graça (a
> busca foi fundida no `usages` do CLI na B4). extension.js v0.3.0, 10
> comandos. **Bug pré-existente corrigido no caminho**: `usages --json`
> com spec ABSOLUTO — exatamente o que a extensão passa — DUPLICAVA o
> prefixo do cwd no URI (`hb_FNameMerge` concatenando caminho já
> absoluto), quebrando o painel de referências; trocado por `hb_PathJoin`;
> regressão no caso 18 (spec absoluto). Provado end-to-end simulando a
> invocação da extensão (rename-dsl round-trip byte-exato; usages
> devolvendo os 3 sites com URI limpo).

**Escopo restante**: revisar as saídas dos demais comandos ao novo CLI
(lifting método/classe no `usages`, `--show-expansion` como opção);
preview `--dry-run --json` se a fricção pedir.
**Critério**: Diego usa no dia a dia; sem regressão nos fluxos atuais.

### Fase B6 — PR upstream (bloqueada: só quando o Diego mandar)

**Escopo**: mensagem com consumidor real; 1 arquivo novo + ganchos opt-in;
prova de zero impacto (árvore inteira com/sem `-x`, binário idêntico ao
master, macro build no-op); **build limpo** (o `compast.c` introduz um
warning do gcc — `compast.c:578` `-Wtype-limits`: `iType >= 0` sempre
verdadeiro porque `HB_EXPRTYPE` é enum sem sinal; corrigir tirando o
`iType >= 0 &&`, o limite de cima já basta); regen bison 3.8.2 documentado;
split opcional em 2 PRs (pp-posição; módulo AST). ChangeLog via
`bin/commit.hb`; uncrustify.

### Fase B-infra — suíte de testes paralela (pool dinâmico), em duas etapas

> Racional completo (análise das formas e das tecnologias, eixo a eixo):
> [testes-paralelos.md](testes-paralelos.md). Aqui fica a spec executável.

**Forma** (travada, comum às duas etapas): `make test` roda os ~34 casos em
**pool dinâmico de processos** (teto ~`nproc`, workers puxam o próximo caso ao
liberar — auto-balanceia as pontas longas 14/16/31 que compilam+linkam+executam),
**grão por-caso** (fronteira que o `fresh()` já dá em `tests/tmp/caseN`), cada
caso com working dir **e** `TMPDIR` isolados, **resultado por artefato** (exit +
saída capturada, mata a intercalação) com **tally no join** (some com os
contadores globais `PASS`/`FAIL`). Thread/socket/`make -j`/GNU parallel/tmux
avaliados e descartados (ver [testes-paralelos.md](testes-paralelos.md)).

**Pré-requisito de código (R1, absoluto)**: `WorkDir()`
([src/hbrefactor.prg:211-218](../src/hbrefactor.prg#L211-L218)) usa
`hb_DirTemp() + "hbrefactor_" + timestamp` de **resolução de 1 s, sem
PID/aleatório** → duas invocações no mesmo segundo colidem no mesmo scratch e se
sobrescrevem. Dar nome **único** (PID + contador/aleatório). Corrige também
qualquer uso concorrente real (editor/LSP). **Nenhuma forma paralela é correta
antes disto.**

- **Etapa 1 — runner em Bash pool** (agora; drift ~zero, zero dep nova).
  Reestrutura `tests/run.sh`: cada caso vira unidade invocável sem estado global;
  despacho `xargs -P`/`wait -n` com teto; `TMPDIR=tests/tmp/caseN` por caso;
  artefato + tally no join; mantém os asserts atuais; `JOBS=1` reproduz o
  sequencial para depurar um caso. `make test` continua a porta de entrada.
- **Etapa 2 — migração para Harbour `hb_processOpen`** (quando reescrever o
  `run.sh`; dogfood + toolchain única). Runner em `.prg` com pool nativo
  (spawn+pipe+exit), **removendo o Python** dos casos 18/26 via `hb_jsonDecode`.
  Mesma forma; só troca a tecnologia.

**Critério de pronto (mecânico, por etapa)**: (i) **paridade** — mesmo conjunto
pass/fail que o runner anterior (sequencial → Etapa 1; Etapa 1 → Etapa 2), diff
por caso, zero regressão / zero falso-verde; (ii) **sem flakiness** — suíte
paralela 10× seguidas sem falha intermitente (prova o isolamento de scratch);
(iii) **ganho** — wall-time paralelo < baseline sequencial, redução da ordem de
`min(nproc, nº de casos)`, limitada pelas pontas longas; (iv) `make test` verde e
`JOBS=1` sequencial para depuração.

---

## Auditoria de gramática duplicada (2026-07-05, pedido do Diego) ✅

Varredura completa do fonte novo atrás de conhecimento sintático replicado e
responsabilidades transferíveis ao compilador/Harbour. Gatilho: Diego pegou o
`IsReserved` — e estava certo: a lista divergia do oráculo nas duas direções
(prova empírica: 26 de 39 "reservadas" eram ACEITAS pelo compilador como
variável, ex. LOOP/EXIT/EACH/STATIC; ENDFOR, rejeitado, faltava). Não existe
"lista de reservadas" consultável no compilador: reserva é CONTEXTUAL na
gramática — flatten em lista é que era o erro.

**A. Transferido ao compilador/Harbour (feito nesta auditoria):**
1. `IsReserved` + `IsValidIdent` + `IsIdStart/IsIdChar` **APAGADAS** →
   `NameAccepted()`: um trecho mínimo (`LOCAL <nome>` p/ variável;
   `FUNCTION <nome>()` p/ função) vai a **`hb_compileFromBuf()`** — o
   compilador como BIBLIOTECA (hbcmplib.c, o mesmo embutido do hbmk2;
   hbmk2 linka `hbcplr` sozinho ao ver a referência) — com o dialeto
   `-k*` do projeto. Sem processo externo, sem arquivo temporário. Bônus:
   a tabela interna de funções protegidas do compilador
   (`hb_compGetFuncID`/`HB_FN_RESERVED`, que rejeita `FUNCTION Len()`)
   passa a valer de graça. Sobrou só `OneWord()` (anti-injeção do trecho:
   nome sem espaço/controle — não sabe o que é identificador).
2. `find-dynamic-calls`: cheque de "string parece identificador" APAGADO —
   nome ∈ funções do projeto (fato do compilador) já implica identificador.
3. `rename-function` ganhou dois guardas de sequestro de chamadas:
   **`CoreFunction()`** (aviso + `--force` quando o nome novo é função do
   core/runtime - defini-la no projeto sombreia a nativa) e recusa dura
   quando o nome novo **já é chamado** no projeto (fato `calls[]` do dump).
   Caso 37 cobre os seis comportamentos.
   **Achados do Diego integrados (2026-07-05)**: `CoreFunction` usa DUAS
   fontes existentes do Harbour - **`include/harbour.hbx`** (lista canônica
   COMPLETA das 1.591 públicas do core, achada pelos `-i` que o hbmk2
   resolveu; pega `hb_MilliSeconds` etc.) e **`hb_IsFunction()`**
   (símbolos vivos no runtime da ferramenta) como complemento. Provado
   que `hb_IsFunction` sozinho NÃO via função core não-linkada na
   ferramenta (`HB_MILLISECONDS` → .F. em binário que não a referencia) -
   o `.hbx` era a peça que faltava. Dos demais achados: `-hbx=` p/
   públicas do projeto = já coberto por `functions[]` do dump;
   `__dynsCount/__dynsGetName` (padrão do profiler.prg) = mesma
   limitação de linkage do hb_IsFunction, dispensados.

**B. Réplicas conservadoras REMANESCENTES, com plano (não urgente):**
1. `DefineCollision`/`PpHeadIn` — **MORTA na B4 (2026-07-06)**: substituída
   por `RuleHeadCollision` sobre os fatos `ppRules` do dump (cobre includes
   aninhados, regras builtin aplicadas e abreviação dBase, que o parse
   textual não via).
2. `StrDelimsOk`/`TokStartCol`/`TokEndCol` (delimitadores de string `"` `'`
   `[..]`) — validação byte-exata conservadora, recusa o que não prova
   (e"..." etc.). Ideal futuro: dump `ast-2` carregar o span ORIGINAL da
   string (1 campo no posTrack do pp). Registrado no ast-schema.md.
3. Cheque textual de continuação (`Right(RTrim(linha),1) == ";"`) em 2
   pontos — falso positivo só RECUSA (conservador); fatos de statement
   multi-linha podem substituir depois.
4. Convenção `<CLASSE>_<MÉTODO>` (usages/PickFunc) — **MORTA na B4
   (2026-07-06)**: `MethodLift` sobre `ppApplications` (par de markers que
   concatena no nome gerado) responde com a posição real e o vocabulário
   do fonte.

**C. Não-réplicas (auditadas e mantidas):** `HrbParse`+comparadores (formato
de ARQUIVO .hrb, não gramática; a alternativa `hb_hrbLoad` carregaria o
código no VM da ferramenta — pior); `CmdTokens` (parse do trace do hbmk2,
glue de builder); `ErrLines` (apresentação); `unused-locals` (já delega
W0003/W0032 ao compilador); `GapOnlySpace/GapOneComma/MatchBack/MatchFwd`
(validação de vãos entre tokens CONHECIDOS do stream, byte a byte, com
recusa na dúvida — é o padrão de edição, não decisão sintática própria).

## Backlog (herdado + novo, por valor)

0. **Velocidade em projetos grandes**: `-inc` do hbmk2 já dá dumps
   incrementais na Fase B1; verificação proporcional à edição (compilar só o
   alvo) fica para quando o uso real doer.
1. **rename-define**: ✅ ENTREGUE na B4 (2026-07-06) — o `#define`
   constante é o caso degenerado de regra sem markers e o `rename-dsl` o
   cobre (caso 38, round-trip byte-exato). Resta como estudo futuro a
   regra SEM cabeça (`head null`, ex. `( x & y ) => HB_BITAND` de
   hbcompat.ch legado que sequestra `!&(...)`): o dump a registra, mas
   rename de regra sem cabeça não existe (não há palavra a renomear) —
   candidata a fixture de RELATO se um projeto real trouxer o caso.
2. **rename-method**: exige nomes de mensagem de `__clsAddMsg` (declaração
   METHOD é invisível — nome viaja como string); avaliar se entra no ast-1
   ou num ast-2. hbhttpd (CREATE CLASS) é o alvo de teste.
3. Dedup de duplicatas de pré/pós-decremento: não-fazer mantido (v2).
4. **Projetos grandes de produção** (quando o Diego liberar): dogfooding
   final e conversões de projeto — só depois de suíte + hbhttpd verdes.
