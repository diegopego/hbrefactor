> **ARQUIVO HISTÓRICO (congelado em 2026-07-07)** — snapshot integral do
> roadmap v3 no dia da limpeza. A intenção VIVA (fases ativas, backlog,
> ordem de revisão) mora em [roadmap.md](roadmap.md); este arquivo
> preserva o registro completo das fases entregues e não é mais editado.
> ATENÇÃO (ordem do Diego, 2026-07-07): partes desta narrativa foram
> escritas com enquadramento hbclass-cêntrico — ler com
> [revisao-generalidade.md](revisao-generalidade.md) ao lado.

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
>    `<A>_<B>` [B4d: `MethodLift` removido; lifting agora vem do rastro
>    `from`, cobrindo colagens de qualquer forma] — cobre qualquer DSL que
>    cole nomes assim (hbclass.ch é o
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
>   [B4d: `PickFunc` reapontado para o rastro `from` (`MethodImplOf`);
>   `MethodLift` removido.]
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

### Fase B4b — Variáveis de escopo dinâmico e afins (caso especial, análise registrada) ✅

> **Status FINAL 2026-07-06 — fase concluída** (v0.5.0; `make test` 47
> casos / 232 checks verdes; casos 44–46 + fixture `tests/fixmv/` armada
> com sombra nos DOIS eixos, criação via macro e memvar implícita).
>
> **Entregue (nenhum gancho novo no core, como previsto):**
> - **Mapa de visibilidade absorvido pelo `usages`** (mesma decisão
>   genérico>específico da B4: sem comando `usages-memvar` dedicado):
>   criadores com linha exata (PRIVATE = declaration `scope private`;
>   PUBLIC = call `__MVPUBLIC` + occurrence na linha — fato asymmetric do
>   dump, documentado no ast-schema), alcance dinâmico por criador (fecho
>   transitivo dos callees; resolução STATIC-vence-no-módulo como o
>   linker), furos nomeados (macro `&`, sends, string com nome de função
>   do projeto = chamada dinâmica possível, função nem-projeto-nem-core),
>   sombra dinâmica (PRIVATE × PUBLIC homônimos), sombra léxica
>   (declaração local/static homônima — "usos ali NÃO são esta memvar"),
>   criação via `&` (call `__MV*` sem occurrence casada = nome invisível),
>   usos implícitos destacados, FIELD homônimo = relato-nunca-edição.
> - **`rename-memvar`** com a política fecho-FECHADO-e-limpo: exatamente
>   1 criador; todos os usos do projeto dentro do alcance; zero furos no
>   alcance (macro FORA do alcance = aviso + `--force`, pois nunca roda
>   com o PRIVATE vivo); nome novo sem vida de memvar (fusão) e sem
>   declaração léxica/param de codeblock homônima nas funções que usam o
>   velho (**a recusa-chave: mudaria binding em silêncio**); strings com
>   o nome = aviso + `--force` (TYPE/__mvGet); M->nome editado (alias de
>   memvar), `alias->campo`/`:msg` excluídos por tipo de token.
>   Verificação: HrbEquivalent (símbolo renomeado, pcode byte-idêntico)
>   em todos os módulos + rollback; suíte prova **execução idêntica** e
>   ida-e-volta A→B→A byte-exata (caso 45).
> - **Recusa reversa no `rename-local`** (spec item 3): novo nome que é
>   memvar/field referenciada na função → recusa ("a LOCAL nova
>   sombrearia esses usos"); caso 46 cobre.
> - **STATIC**: continua S via rename-static (nada mudou, como previsto).
>
> **R1 da B-infra adiantado (2026-07-06)**: `WorkDir()` agora é
> mkdir-atômico com nome aleatório e retry — 3 invocações concorrentes
> provadas com scratch distintos; pré-requisito da suíte paralela e de
> qualquer uso concorrente real (editor/LSP).

#### Análise original (mantida como registro)

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

### Fase B4c — rename-method (spec 2026-07-06, escrita antes de codar) ✅

> **Status FINAL 2026-07-06 — fase concluída** (`make test` 50 casos /
> 256 checks verdes; casos 47–49 + fixture `tests/fixmth/`; dogfooding
> hbhttpd: `UHttpdLog:IsOpen` A→B→A byte-exato; recusa de ambiguidade
> listando as 9 classes donas de `Paint` no corpus real).
>
> **REVISÃO DE ARQUITETURA (questionamento do Diego, 2026-07-06,
> incorporada antes de fechar)**: a primeira versão delimitava blocos de
> classe ligando por CABEÇAS de regra (`CREATE`/`CLASS`/`ENDCLASS`) —
> vocabulário do hbclass.ch DENTRO da ferramenta, a mesma família de
> réplica que a auditoria matou. Redesenhada para ZERO palavra-chave:
> os fatos de classe vêm do código EXPANDIDO que o compilador compilou —
> a função de REGISTRO da classe empurra o nome da classe e de TODOS os
> membros como STRINGs na árvore de statements (`HBClass():New("UWMenu",
> ...)`, `:AddMethod("Soma", ...)`, `:AddInline`, `:AddMultiData`).
> Âncoras por FORMA: função de classe = função que empurra STRING igual
> ao próprio nome; membros = as STRINGs dos statements dela
> (`ClassRegs`/`StmtStrings`); site de declaração = marker posicionado de
> `ppApplications` dentro do SPAN da função de classe (`DeclHits`);
> implementação = `MethodLift` (colagem). Sobre onde o fato DEVERIA
> morar: o compilador é cego a classes POR DESENHO (classe é construto
> de runtime montado por `__clsAddMsg`) — gancho no core ensinaria
> hbclass ao compilador (hostil ao upstream); instrumentar hbclass.ch =
> fork de include de sistema (candidato honesto: propor um hook opcional
> upstream, B6+); reflection em runtime executaria código do usuário.
> A leitura do expandido é a única fonte que já É fato do compilador.
>
> **Entregue**: `rename-method <proj> <Classe:Método>|<Método> <novo>`
> edita declaração (bloco) + implementação + sends (self `::` e
> externos); INLINE coberto (site = marker da declaração; corpo vira
> codeblock e o self-send interno converge com a edição de sends);
> forma sem classe resolve quando o nome é único no projeto. Política:
> unicidade da mensagem (send é despacho dinâmico — dono duplo recusa
> listando as classes); VAR/DATA fora do escopo (detectado pelo send de
> atribuição `_NOME`); nome novo sem vida de mensagem (membro registrado,
> implementação, send existente); strings do usuário com o nome = aviso
> + `--force` (as strings GERADAS pelo stringify se regeneram da edição
> do identificador; instáveis em posição, nunca são sites). Verificação:
> `HrbSymbolsRenamed` (símbolos/funções módulo os DOIS mapeamentos
> {MÉTODO→NOVO, CLASSE_MÉTODO→CLASSE_NOVO}; o pcode do módulo da classe
> muda DE VERDADE — strings de registro) + demais módulos `HrbEquivalent`
> byte-idênticos + rollback; execução idêntica é contrato da suíte.
>
> Limite documentado: classe SÓ com INLINE (sem nenhuma implementação
> separada) ainda é reconhecida (âncora é a STRING do próprio nome, não
> a colagem); classe construída fora do padrão função-de-registro (ex.:
> `__clsNew` manual) não é reconhecida — relato honesto de "não
> encontrado", nunca edição errada.
>
> **MORTE ANUNCIADA (ordem do Diego, 2026-07-06) — CONSUMADA na B4d**: as
> âncoras por forma desta fase (`MethodLift`/`ClassRegs`/`StmtStrings`/
> `DeclHits`) eram INTERINAS — heurísticas sobre o RESULTADO da expansão,
> que cobriam a colagem/stringify do hbclass mas não qualquer diretiva
> futura. Foram REMOVIDAS do código na **Fase B4d** (2026-07-06),
> substituídas pelo modelo de NOME DE MARKER sobre o rastro de derivação no pp
> (schema ast-3): spec completa em
> [spec-b4d-derivacao.md](spec-b4d-derivacao.md). Esta seção da B4c fica
> como registro histórico (a spec original abaixo é preservada).

#### Spec original (mantida como registro)

**O caso**: renomear um método de classe (`UWMenu:Paint` → `Draw`) exige
editar (a) a DECLARAÇÃO no bloco da classe, (b) a IMPLEMENTAÇÃO
(`METHOD Paint() CLASS UWMenu`), e (c) os SENDS (`o:Paint()`, `::Paint()`).
A B4 tornou (a) e (b) fatos com posição (markers de `ppApplications`;
`MethodLift` já liga função gerada ⇄ classe/método). O problema duro é
(c): **send é despacho DINÂMICO** — `o:Paint()` não declara a classe de
`o`; renomear sends às cegas sequestraria métodos homônimos de outras
classes.

**Política (o coração da fase)**:
1. **Unicidade de mensagem no projeto**: o rename só edita sends quando o
   nome do método é definido por UMA ÚNICA classe do projeto — detectado
   por (i) implementações: funções cujo `MethodLift` devolve
   `(outraClasse, nome)`; (ii) declarações sem implementação separada
   (INLINE/VAR/DATA): aplicações de regra cujos markers casam o nome em
   contexto de classe + strings type 41 geradas na linha da declaração.
   Nome não-único → recusa listando as classes.
2. **Nome novo sem vida de mensagem**: nenhum send/implementação/string
   com o nome novo no projeto (sequestro reverso); `NameAccepted` p/ a
   função gerada `CLASSE_NOVO`; `RuleHeadCollision`.
3. **Strings**: token type 41 == nome na MESMA linha de declaração/
   implementação é a string GERADA pelo stringify do marker — atualiza
   sozinha com a edição do identificador (não é site). Em qualquer outra
   linha = possível acesso por nome (`__objSendMsg`, `:&(...)`) — aviso +
   `--force`, nunca editada.
4. **Herança/override**: subclasse que redeclara o nome cai na recusa de
   unicidade por construção (duas classes definem) — sem análise extra.

**Verificação (nova, porque o pcode MUDA de verdade)**: o módulo da
classe embute o nome da mensagem em STRINGS de `__clsAddMsg` e o nome da
função gerada muda (`UWMENU_PAINT`→`UWMENU_DRAW`) — não há byte-idêntico
ali. Desenho: comparador de símbolos com MÚLTIPLOS mapeamentos esperados
({MÉTODO→NOVO, CLASSE_MÉTODO→CLASSE_NOVO}); módulos que só têm sends =
`HrbEquivalent` byte-idêntico como sempre; módulo da classe = símbolos
modulo mapeamentos + **execução idêntica** (contrato da suíte) +
rollback em qualquer não-conferência.

**Critério de pronto**: fixture com classe + sends externos (`o:Paint()`)
+ self-send (`::Paint()`) + método INLINE + segunda classe SEM colisão;
`rename-method` executa com execução idêntica e ida-e-volta A→B→A
byte-exata; fixture de recusa com duas classes homônimas no método;
recusa de string fora da linha de declaração sem `--force`; suíte verde;
dogfooding no hbhttpd (1 rename real A→B→A).

### Fase B4d — Refatoração genérica por rastro de derivação (entregue 2026-07-06) ✅

> **Status FINAL 2026-07-06 — fase concluída** (`make test` 287 passed /
> 0 failed; specs G1–G7 verdes, casos novos 50–53 + fixture INVENTADA
> `tests/fixppm/`; `make lexdiff` 0 divergências reais; dogfooding
> hbhttpd: `UHttpdLog:IsOpen` A→B→A byte-exato, `Paint` recusado listando
> as 9 classes donas). **Ordem do Diego**: funcionar com QUALQUER
> diretiva — classes, as cinco famílias, e o que vier a ser criado — sem
> nada por-DSL na ferramenta. Spec-driven: escopo/formato/specs G1–G7 e
> critérios mecânicos escritos ANTES do código em
> **[spec-b4d-derivacao.md](spec-b4d-derivacao.md)**.
>
> **Entregue no core (schema ast-3)**: campo `from` nos tokens
> SINTETIZADOS — de QUAL marker cada faixa de bytes deriva
> (`clone`/`paste`/`stringify` + `at`/`len` em bytes), gravado pelo pp no
> INSTANTE da síntese. Mesmo padrão B0/B4: lógica no pp, ganchos de 1
> linha gated por `fTrackPos`, tabela por módulo limpa em `hb_pp_reset`,
> accessors em `hbpp.h`, emissão em `compast.c`. Também copiado nos tokens
> consumidos de `ppApplications` (multi-passe: cópia no instante da
> aplicação). Zero impacto sem `-x` provado: 112/112 `.hrb` byte-idênticos
> com/sem `-x`; `harbour` E `hbmk2` relincados para ast-3
> (`strings ... | grep ast-`). Leitor `ReadAst` aceita ast-2|ast-3;
> comandos que exigem o rastro recusam dump antigo (`FromReady` = schema
> == ast-3).
>
> **Entregue na ferramenta (modelo de NOME DE MARKER)**: nome de marker =
> o valor escrito que preenche um match marker (`<x>`) de uma diretiva de
> pp, atravessando-a. Sementes por `(app, marker)` com
> fecho transitivo (`PpMarkerSeeds`); artefatos = fecho dos `from` com
> recorte byte-exato pela faixa (`PpMarkerArtifacts`/`PpMarkerRanges`,
> resolução recursiva por clone-de-composto); donos por CO-DERIVAÇÃO
> (`PpMarkerOwners`: o outro nome do paste que nomeia função, o nome da
> função que contém o stringify). `usages <nome>` com lifting
> generalizado — vocabulário da regra RAIZ (`PpMarkerLift`/`SeedRootRule`:
> "method definition" no hbclass, "handler definition" numa DSL de
> handlers, etc.), nome gerado só com `--show-expansion`. Novo comando
> `rename-pp-marker <proj> <nome> <novo> [--force] [--dry-run]`;
> `rename-method` vira AÇÚCAR do mesmo motor (política extra de unicidade
> de mensagem, porque send é despacho dinâmico). Verificação com o mapa de
> símbolos/strings COMPUTADO do rastro (`PredictText`: substitui as faixas
> do nome de marker pelo nome novo) — saída `predicted: SIMBOLO -> NOVO` /
> `predicted string: ...`, cada previsão conferida no dump pós-edição
> (`HrbSymbolsRenamed` com mapa computado; demais módulos `HrbEquivalent`
> byte-idênticos). Recusa por co-derivação (G5): símbolo previsto que já
> existe como função → recusa nomeando o artefato; fonte que soletra à mão
> um nome gerado que mudaria → recusa apontando o site órfão. As âncoras
> por FORMA da B4c (`MethodLift`/`ClassRegs`/`StmtStrings`/`DeclHits`)
> foram REMOVIDAS do código: nenhuma colagem `_` tentada, nenhuma
> comparação de STRING == nome de função.
>
> **Provas**: G1 (canônico hbclass), G2/G6 (colagem por prefixo `on_<n>`
> numa DSL 100% inventada — nenhuma palavra dela existe em include do core
> nem é mencionada na ferramenta — usages lifta + rename), G3 (stringify
> puro), G4 (clone+paste+stringify na mesma regra, chamada derivada
> cruzando módulos), G5 (co-derivação: vizinho intacto, colisões recusadas
> por nome); casos 50–53. Regressão total (G7): suíte 287/0, `make
> lexdiff` sem divergência nova, varredura src/ com/sem `-x` byte-idêntica.

### Fase B4e — Comandos de refatoração cientes de construtos de pp ✅ (2026-07-06)

**Ordem do Diego (2026-07-06)**: os recursos de refatoração devem ser
completos para o máximo de casos possível — os construtos que uma diretiva
de pp cria (método de classe, função gerada por DSL) têm que ser cobertos
por TODOS os comandos, não só pela família B4. **Spec-driven**: matriz de
auditoria, escopo por item (P0–P3) e critério de pronto em
**[spec-b4e-construct-aware.md](spec-b4e-construct-aware.md)** — escrito
ANTES do código. Princípio transversal: cada comando, sobre um construto de
pp, ou faz a refatoração correta e verificada, ou RECUSA LIMPA — nunca
corrompe nem falha de forma confusa.

> **P0 entregue (2026-07-06)**: bug de CORRUPÇÃO SILENCIOSA no
> `rename-local`/`rename-param`. Sites que compartilham a mesma `(linha,col)`
> de origem — clones de um único token-fonte que a expansão de pp
> multiplicou (o parâmetro de uma FUNCTION gerada, declarado e usado no
> corpo, deriva do mesmo marker) — geravam edição DUPLA na span: `nA`→`nAlfa`
> virava `nAlfalfa`, e como nome de local/param não entra no pcode o verify
> byte-idêntico deixava passar (exit 0). Fix: `DedupHits` por posição-fonte
> antes de aplicar as edições (vale p/ rename-local e rename-static). Caso 54
> (regressão): parâmetro de função gerada por DSL, nome novo que estende o
> antigo, edição única + round-trip byte-exato. Suíte 291/0.

> **P1a entregue (2026-07-06)**: `rename-param`/`rename-local` ciente da
> ASSINATURA de método. Renomear o param de um método precisa mover a
> DECLARAÇÃO fora do corpo — o protótipo no `CREATE CLASS` e a linha
> `METHOD ... CLASS` — não só os usos do corpo. Em `tokens[]` a posição da
> assinatura COLAPSA para a do protótipo (clone multi-passe), então o span da
> função só enxergava o corpo; renomear só ele deixava a declaração órfã e o
> hbclass recusava o build (casa protótipo↔implementação pela assinatura
> INTEIRA, nomes de param inclusos → `W0001 declaration mismatch`). Os sites
> da assinatura vêm agora dos markers posicionados de `ppApplications`
> (`SigParamHits`), escopados pela IDENTIDADE do nome gerado — classe+método,
> decompostos do rastro `from` por `GenNameParts` — para não colher param
> homônimo de outro método/classe (nenhuma aplicação mistura dois métodos).
> Nome de param não entra no pcode → a verificação byte-idêntica dos `.hrb`
> segue valendo. Fixture nova `fixsig/` (métodos de 2+ params, classe homônima
> — pronta p/ P1b). Caso 55 (proto+impl+corpo editados, nH intacto, execução
> idêntica, round-trip byte-exato, 2º método independente). Suíte 302/0.

> **P1b entregue (2026-07-06)**: `reorder-params` ciente de método. (1)
> Resolução por `PickFunc` (nome puro, `Classe:Método`, nome de método). (2) A
> assinatura (protótipo no `CREATE CLASS` + linha `METHOD ... CLASS`) reordena
> pelos sites de `ppApplications` (`SigParamHits`/`GenNameParts` da P1a, pois
> colapsa em `tokens[]`); o corpo NÃO é tocado (params guardam os nomes). (3)
> Os call sites de SEND (`o:Msg(a,b)`) reordenam os argumentos: o recorte de
> args foi extraído de `CallSitesArgs` para `ArgSpansAt` e reusado por
> `SendSitesArgs` (token da mensagem, anterior `:` type 58, seguido de `(`). (4)
> Política de unicidade da mensagem (mesma do rename-method, via
> `PpMarkerOwners`): só reordena os sends quando o método é de UMA classe do
> projeto — senão recusa NOMEANDO as classes (send é despacho dinâmico). O
> pcode muda legitimamente (ordem de push) → `HrbSymbolsEqual` (símbolos/funções
> intactos) + rollback. Caso 56 na fixture `fixsig/`: reorder de `Widget:Grow`
> edita assinatura + send, execução idêntica, round-trip byte-exato; reorder de
> `Widget:Resize` (homônimo em Widget+Panel) recusa nomeando as classes. Suíte
> 313/0.

> **P2b + P3 entregues (2026-07-06)**: P2b — `call-graph <método>` resolve o
> nome de método (bare/`Classe:Método`) para o símbolo GERADO e imprime a
> definição; os `sends` da mensagem viram arestas DINÂMICAS (`~>`, nunca
> estáticas), com o(s) alvo(s) `[dynamic: NOME_GERADO]` — mensagem homônima em
> várias classes lista todos (dispatch ambíguo visível). Índice de mensagens
> montado do rastro (`GenNameParts`: `<Classe>_<Metodo>` → método). P3 —
> `find-dynamic-calls` suprime o falso positivo do `&` INTERNO da expansão do
> hbclass.ch: só reporta `usesMacro` quando há macro REAL do usuário no span da
> função (token type 22 posicionado, `prov 's'` — `HasUserMacro`); um `&` de
> verdade continua flagado. Casos 57/58 na fixture `fixsig/`. Suíte 323/0.

> **P2a entregue (2026-07-06, desenho aprovado pelo Diego antes do código)**:
> `extract-function` em corpo de método com **suporte PLENO** (decisão do
> Diego; a recusa-limpa ficou como piso para os sub-casos intratáveis).
> Range em corpo de método extrai para um **novo `METHOD` da MESMA classe**
> (alvo decidido pelo CONTÊINER, não pelo range — correção pós-dogfooding no
> hbhttpd, mesmo dia: range sem `::` dentro de método virava função e
> surpreendia; caso 59d):
> o corpo move VERBATIM (`::`/sends/`Super` continuam válidos — mesma classe,
> mesmo binding, provado por execução), o protótipo entra logo após o do
> método de origem (mesma seção de visibilidade; PROTECTED interno funciona,
> scope é só de runtime) e o call site vira `::Nome( args )`. A análise
> fato-a-fato fechou SEM ast-4: Self é local comum (occurrences; sem
> declaration no dump), identidade/símbolo previsto vêm do rastro `from`
> (`GenNameParts`/`PredictText`), âncora do protótipo de `ppApplications`
> (`MethodProtoAnchor`), membros por strings de stringify contidas por
> índice na função da classe (`ClassMembersOf`), ancestrais pelos markers
> posicionados na linha da declaração (`ClassParentsOf`; palavra `FROM`
> filtrada por não chegar ao stream). Recusas fato-based: Self
> reatribuído/`@Self` no range, colisão com membro (próprio ou herdado no
> projeto), símbolo gerado existente, mensagem já ENVIADA (sombrearia
> dispatch), classe declarada em include, Self fora de método; pai fora do
> projeto = AVISO honesto. Verificação `HrbMethodExtractCheck`: +1 função
> prevista, símbolos novos ⊆ {gerado, mensagem}, string de registro no
> pcode da função da classe; rollback. Hardening no caminho: o scan de
> saltos do extract filtra `prov 's'` (linha de token de include colide com
> o range por coincidência). Fixture `fixext/` (2 classes + herança +
> Super + classe em include + pai core); casos 59 (pleno, execução
> idêntica) e 60 (recusas + aviso). **Fase B4e completa.**

> **Decisão registrada (Diego, 2026-07-06) — a ÚNICA exceção de biblioteca
> na ferramenta é a SÍNTESE do extract-function-para-método** (o texto
> `METHOD <nome>(...) CLASS <classe>` + protótipo, hard-coded). Motivo
> aceito: síntese é por-DSL por natureza — o pp não roda ao contrário; dos
> fatos de expansão dá para LER qualquer DSL, não para deduzir como
> ESCREVER um comando novo de DSL desconhecido. Toda a ANÁLISE permanece
> genérica (guarda automatizada: caso 64 falha se ferramenta/core
> mencionarem palavra de DSL). Opções avaliadas: manter (escolhida),
> método-só-com-flag `--as-method` (recusaria toda seleção com Self sem a
> flag), remover síntese (extract quase inútil em classes). Rede de
> segurança em qualquer caso: recompile-verify + rollback — DSL estranho
> gera recusa honesta, nunca edição errada.

### Fase B4f — classe do receptor de send (backlog 5) ✅ (2026-07-06)

**Spec executável**: [spec-b4f-receiver-type.md](spec-b4f-receiver-type.md)
(tabela fato→fonte com arquivo:linha, histórico dos DOIS portões, registro
como construído). **Requisito final do Diego (portão v3)**: quando qualquer
programador criar seus próprios comandos de pp, a refatoração deve lidar
com eles **sem alterar harbour nem hbrefactor** — o que matou tanto a
inferência na ferramenta quanto o veredito com convenção no core
(`F():New()` reconhecido por nome). **O desenho entregue: o CANAL DE TIPOS
DA LINGUAGEM** — `AS <tipo>`/`AS CLASS` e o subsistema `DECLARE`
(`_HB_CLASS`≡`DECLARE_CLASS`, `_HB_MEMBER`≡`DECLARE_MEMBER`) são GRAMÁTICA
do compilador (provado sem include algum, .ppo byte-idêntico), eram
write-only (zero pcode) e o hbclass já declara TUDO por eles (função-classe
auto-declarada; `CONSTRUCTOR` declara o retorno). O core transporta o canal
1:1; a ferramenta propaga tipos declarados; convenção não existe em lugar
nenhum.

> **Fatia 0 entregue (caso 61, commit 02ed8db)**: `usages` aceita
> `Classe:Método` (resolução PickFunc/rastro, definição filtrada pela
> classe) e TODO send vira camada honesta
> `possible send (dynamic dispatch, receiver unknown)`.

> **Fatia 1 entregue (casos 62-65, suíte 402/0)**:
> - **core (ast-4)**: gates `iWarnings < 3` do subsistema DECLARE abrem
>   sob `fAst` (warnings continuam gated por nível; erro de `_HB_MEMBER`
>   órfão preservado só em -w3); `declarations[]` recapturado no PARSE
>   (gancho `hb_compAstDecl` — o `Self` de método aparece TIPADO, imune ao
>   otimizador que o apagava; `class` = nome como escrito, sobrevive à
>   classe não registrada; `used` morreu; escopo `public` novo); seção
>   `declared` por módulo (tabelas HB_HCLASS/HB_HDECLARED 1:1). Zero
>   impacto sem `-x`: 32 comparações `.hrb` em -w0 E -w3, byte-idênticas;
>   relink duplo conferido. Bug latente de core corrigido no caminho:
>   `HB_HDECLARED.pClass`/`pParamClasses[i]` sem init (lixo quando tipo
>   não-'S' — segfault no primeiro writer; init NULL + guarda por cType).
> - **ferramenta**: `TypeOf` (propagação FECHADA de tipos declarados sobre
>   statements[]: declarada/binding único/FUNCALL/SEND encadeado/literais;
>   sombra de cb-param via scope detached×local; memvar/field fora) +
>   camadas no `usages`: confirmed (declarada direta OU cadeia declarada),
>   excluded (valor), possible (resto, nomeando classe parcial). Projeto
>   com dump antigo degrada para possible. Regressão de carona corrigida:
>   extract-to-method não trata mais o Self (agora declarado) como local
>   de data-flow.
> - **A prova do requisito (caso 64)**: DSL inventado (`gizmo.ch`) que
>   declara pelo canal na expansão → confirmed (inclusive send encadeado)
>   sem tocar em nada; greps garantem que ferramenta e core não mencionam
>   o DSL nem mensagem alguma por nome. Contrato de extensão documentado
>   no ast-schema.md. Caso 65 = consistência (invariantes re-deriváveis
>   dos fatos brutos).
> - O caso do hbhttpd responde: `g:Paint()` confirmed quando a cadeia/
>   declaração existe, `a:Paint()` com `a := {}` excluded, e o honesto
>   possible onde o fato não existe (ex.: classe sem ctor declarado —
>   idioma: declarar `CONSTRUCTOR`/`AS CLASS`).

### Fase B4f-2 — resolução de dispatch ✅ (2026-07-07)

O furo dos HOMÔNIMOS reportado pelo Diego (2026-07-06: duas classes com os
mesmos métodos → find-references lista o send da outra classe) expôs que a
B4f parou na classificação do receptor sem resolver o DISPATCH —
incompleta, não ajeito. Spec executável:
[spec-b4f2-dispatch.md](spec-b4f2-dispatch.md) (fatos 1-11 com evidência;
portão de 2026-07-06 aprovou camadas/rótulos e a lista ordenada de pais).

> **Entregue (casos 66-69, fixture fixdis/, suíte 424/0)**: tudo na
> FERRAMENTA, zero mudança de core/schema. `ClassParentsSeq` (pais na
> ordem TEXTUAL do FROM com flag dentro/fora do projeto — o par
> `{aIn,aOut}` perdia o interleaving, fato 9; `ClassParentsOf` virou
> visão dela), `ClassGraph` (classe → pais ordenados + mensagens próprias
> por stringify∪declared — fato 5), `ResolveDispatch` (regra da linguagem
> provada em runtime: próprio > pais na ordem, em PROFUNDIDADE; devolve
> dono, ausente-comprovado ou indecidível — pai de fora antes de um hit),
> `DispatchHijackers` (descendentes que sequestrariam a promessa) e
> `SendVerdict` (as camadas, extraídas do Usages). Camadas novas:
> confirmed com dispatch resolvido (herança alcançada, transitiva),
> `excluded (dispatches to X:M)` para instância exata,
> `excluded within the project's class graph` para receptor declarado
> (mundo fechado, ressalva no rótulo), `possible (descendant D ... may
> dispatch to C:M)` quando um descendente impede a exclusão. Todo
> excluded fora das Location[] do `--json`. Rótulos confirmed da B4f
> INALTERADOS quando a classe do receptor É a consultada (zero churn nos
> casos 61-65); indecidível continua nas camadas B4f de sempre. O caso 66
> é o cenário do Diego (UWMain/UWSecondary com e sem ctor declarado); 67
> herança simples (alcança/não alcança o pai); 68 herança múltipla (ordem
> do FROM decide; descendente nomeado impede promessa); 69 pai fora do
> projeto (indecidível = possible honesto; hit antes do pai de fora É
> decidível). Escopo não muda resolução; ACCESS/ASSIGN mesma tabela
> (fatos 10-11, registrados no ast-schema).

Ficam anotados para fatias futuras (mesma base `ResolveDispatch`):
call-graph estreitado; unicidade P1b/P2b relaxada; statics (agregação
módulo-inteiro); `WITH OBJECT`; tipos de PARÂMETRO declarados (já
transportados) em call sites; find-references a partir de SEND SITE na
extensão (a consulta crua não tem classe consultada — resolver o receptor
na posição do cursor); `rename-function` quando o nome aparece no CORPO
de uma regra de pp (hoje: recusa honesta com rollback, caso 74 — a
melhoria é NOMEAR o site na diretiva na recusa e, com opt-in, editar a
regra e re-verificar) — **PROMOVIDO a Fase B4g (2026-07-07)**.

Nota pós-entrega da fatia 1 (2026-07-06, commit f7b819f): `excluded`
saiu das Location[] do `--json` — o find-references da extensão VSCode
não lista não-referência provada (repro do Diego: `a := ""` ;
`a:Paint()`).

Nota pós-entrega 2 (2026-07-07, casos 70-71): o furo ESPELHO nas
DECLARAÇÕES — relato do Diego: a extensão ainda listava os protótipos
`METHOD Paint()` das OUTRAS classes (a string de registro da expansão
caía na camada genérica de strings, sem vínculo de dona). O passe de
declaração do `usages Classe:Método` vincula cada site à dona pelos
MESMOS fatos da posse do rename-method (containment por índice na função
gerada; co-derivação para a implementação separada) e decide com o
`ResolveDispatch` da CONSULTADA: dona == consultada → declaração; alvo
do dispatch da consultada (herança) → confirmado nomeando `dispatch
target of C:M`; outra dona provada no grafo → excluded (fora das
Location[]); indecidível → possible, nunca excluded (fato 9). A
implementação homônima (antes omitida em silêncio) sai `excluded` no
relato; a camada de strings não repete o que o passe respondeu. Caso 71:
a heurística `methodQuery` da extensão entrou no CONTRATO da suíte
(autorização do Diego para mudar o contrato; o harness node extrai a
função REAL do extension.js). Suíte 433/0.

### Fase B4f-3 — A PROVA DA GENERALIDADE: homônimos em DSLs customizadas ✅ (2026-07-07)

> **Entregue — PROVA POSITIVA (caso 72, fixture fixhom/, suíte 446/0,
> zero core)**: as duas DSLs inventadas (rig.ch: RIG/COG/FORGE, espelho
> estrutural do hbclass; amuleto.ch: AMULETO/DOTE, declarativa PURA) com
> donos homônimos entre si (Totem/Idolo:Brilho; Sol/Lua:Fulgor) e
> cruzados com classe hbclass (Farol:Brilho) resolvem NAS TRÊS DIREÇÕES
> — declaração, implementação por colagem e sends — com os rótulos no
> VOCABULÁRIO de cada DSL (`cog declaration (class TOTEM)`, `dote
> declaration (class SOL)`, `forge definition`). Dois consumos GENÉRICOS
> (não por-caso) fecharam os furos que os probes revelaram: (a) o passe
> de declaração ganhou a fonte do CANAL NO STREAM — `_HB_CLASS` muda a
> classe corrente (semântica sequencial do compilador) e `_HB_MEMBER`
> declara nela, nome POSICIONADO no site escrito (a string de registro de
> DSL nasce sem posição; a do hbclass é o mesmo site, dedup por posição);
> (b) donas SÓ do canal declared entram no ClassGraph com a interface
> declarada como PROMESSA FECHADA e pais vazios (fato 4: o canal não
> carrega superclasse) — o send homônimo da DSL declarativa saiu de
> `possible` para `excluded (dispatches to LUA:FULGOR)`. Régua do caso
> 64 mantida e ASSERTADA no caso 72: nenhuma palavra das DSLs em
> `src/hbrefactor.prg` (grep -w na suíte) nem no core. Limites honestos
> documentados no ast-schema (dona declarada = promessa; DSL que nem
> declara nem registra = `possible`, idioma: declarar).

> **Fatia 2 — alinhamento do Diego (2026-07-07)**: "generalidade" também
> significa COMANDOS NOVOS embrulhando classes JÁ EXISTENTES
> (pseudo-exemplo dele: `#command mybrowse <a> <b> => tbrowse`) — a
> instância e o send passam a existir só na EXPANSÃO e o fonte escrito só
> tem o comando. **Provado JÁ COBERTO, zero ajuste** (probe promovido a
> fixture m3.prg/browse.ch, checks no caso 72): `MYBROWSE g AT 1` →
> `g := Grade():New(1)` na expansão classifica `g` (cadeia de ctor);
> `MYPAINT g` (send só na expansão) sai CONFIRMADO no site ESCRITO do
> comando; `MYPAINT l` (homônimo através do comando) sai EXCLUÍDO
> (`dispatches to LOUSA:PINTAR`); `MYTELA t` embrulhando TBrowse (classe
> de FORA do projeto) fica `possible` honesto. Os fatos fluem da árvore
> EXPANDIDA (é nela que a B4f/B4f-2 sempre operou) e a posição lifta para
> o site escrito — nada era específico de forma escrita. Suíte 451/0.

> **Fatia 3 — DSL REAL do contrib + escrita/VAR (2026-07-07)**: o Diego
> apontou `contrib/xhb/cstruct.ch` como exemplo do que qualquer
> programador cria: classes de RUNTIME (`hb_CStructure`/`__clsNew`),
> regras de pp definidas DE DENTRO da expansão de outras regras e
> registro por stringify em `INIT PROCEDURE __INIT_<stru>` (sufixo `$`
> do compilador no nome). Caso 73: relato HONESTO em tudo — sites
> escritos listados, tudo `possible`, NUNCA excluded/confirmed falso (o
> teto é da linguagem). A sondagem revelou, e a fatia consumiu, DOIS
> fatos gerais que o usages perdia ATÉ EM CÓDIGO SEM AÇÚCAR: (a) a
> ESCRITA `o:x := v` envia a mensagem `_X` (fato 11) e a ÁRVORE guarda
> `ASSIGN → SEND` do nome BASE — writes agora casam, classificam pelo
> receptor/Self tipado e resolvem pelo PAR de dados da linguagem (VAR
> registra X e _X em runtime — provado no probe vprobe; ASSIGN explícito
> registra `_NOME` e resolve direto); (b) VAR declara via
> `_HB_MEMBER { a, b }` (a forma de LISTA do canal) e a string de
> registro nasce SEM posição — o site vem do canal no stream
> (`var declaration (class GRADE)` no caso 72 fatia 3).

> **Fatia 4 — construto-agnóstico (correção de rumo do Diego: "classes é
> somente um caso")**: caso 74 (fixsug/) prova o princípio FORA de
> classes: chamada de função que SÓ existe na expansão (`DOBRA k` →
> `k := Dobro(k)`) listada no site escrito; LOCAL declarado por comando
> (`CONTA m`) renomeado fim-a-fim editando o site do comando, verificado
> byte-idêntico; nome de função no CORPO de uma regra → `rename-function`
> RECUSA com rollback (o oráculo pega: quantidade de símbolos mudou) —
> nunca árvore quebrada. Suíte 467/0. O princípio virou regra durável no
> CLAUDE.md deste repo.

**Objetivo (ordem do Diego, 2026-07-07)**: PROVAR que a resolução de
homônimos (B4f-2 + fatia de declarações) vale para DSLs customizadas
criadas por `#xcommand` — com donos homônimos ENTRE SI, homônimos
CRUZADOS contra classes do hbclass e outros casos complexos — **sem
nenhum ajuste por-caso** no hbrefactor (nem no core): DSLs novas podem
ser escritas por qualquer programador a qualquer momento em seus
aplicativos. Prova positiva OU refutação honesta (fato faltante nomeado,
camada `possible`) — ajeito é inaceitável.

**Método** — fixtures adversariais com DSLs INVENTADAS (que a ferramenta
e o core não mencionam — a régua do caso 64):
1. DSL "espelho estrutural do hbclass" (gera função-dona + registro por
   strings + canal declared) com donos homônimos entre si;
2. DSL declarativa PURA (gizmo-style: `_HB_CLASS`/`_HB_MEMBER`, sem
   função geradora) com donos homônimos;
3. homônimos cruzados: mensagem de DSL == método de classe hbclass no
   mesmo projeto;
4. complexos que os probes revelarem (registrados na execução).

Se um fato EXISTIR mas não for consumido genericamente (ex.: classe do
canal declared sem função geradora fora do ClassGraph), o consumo
GENÉRICO é trabalho desta fase; fato AUSENTE = relato honesto documentado
no ast-schema (teto da linguagem, não da ferramenta).

**Critério de pronto**: casos na suíte cobrindo 1-3 verdes com a régua do
caso 64 (nenhuma palavra das DSLs em `src/hbrefactor.prg` nem no core);
limites honestos documentados; suíte inteira verde.

### Fase B4g — a diretiva como fonte de primeira classe (schema ast-5) — spec escrita, aguarda portão

**Spec executável (escrita ANTES do código, 2026-07-07):
[spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md)** — fatos
verificados com arquivo:linha, aprendizados do `.ppt`, probes P1-P5 e
portão do Diego antes do volume.

**O caso**: as fases B4-B4f fecharam as APLICAÇÕES das regras de pp; a
REGRA POR DENTRO continua não-endereçável — `ppRules` exporta só a cabeça
e um contador de markers, mas o pp SABE o papel de cada token da diretiva
(`pMatch`/`pResult`, ppcore.c:4042-4054: literal, marker e seu tipo,
grupo opcional, restrição). É a fronteira exata do caso 74: rename de
função citada no CORPO de uma regra recusa às cegas (o oráculo pega, mas
a ferramenta não sabe onde na diretiva o nome vive).

**Escopo**: core — `ppRules[]` ganha `match[]`/`result[]` (um item por
token: texto, papel, tipo de marker no vocabulário do pp, posição
byte-exata; snapshot no instante do registro via `hb_pp_trackRule`, que
JÁ dispara nos três pontos; gated `fTrackPos`, schema ast-5, zero impacto
sem `-x`). Ferramenta — `usages` nomeando sites dentro de regra;
recusa do caso 74 acionável + `--edit-rules` opt-in com o oráculo de
sempre; `rename-dsl` estendido a palavra secundária do match e palavra de
restrição; cabeça por posição-fato (morre a reancoragem textual);
extensão coberta na mesma fase. Tudo construto-agnóstico (régua do caso
64).

**Critério de pronto**: na spec (mecânico) — zero impacto -w0 E -w3 +
relink duplo; `match[]`/`result[]` byte-exatos contra os `.ch` das
fixtures; caso 74 upgrade com round-trip byte-exato e execução idêntica;
renames novos com `.ppo`/`.hrb` byte-idênticos; suíte + lexdiff verdes.

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

> **Fatia B4f-2 entregue (2026-07-07): lifting de método no `usages`**
> (extension.js v0.5.0): com o cursor na IMPLEMENTAÇÃO
> (`METHOD x ... CLASS Y`) ou no protótipo dentro do bloco
> CLASS/ENDCLASS (METHOD/ACCESS/ASSIGN, `CREATE CLASS` ou `CLASS`), o
> find-references consulta `Classe:Método` — a forma onde o CLI decide o
> dispatch (excluded fora das Location[]). Fora desses sites a consulta
> segue crua (send site não presume a classe; heurística de argumento
> como as demais — se errar, o CLI valida). Verificada com a
> `methodQuery` REAL extraída do extension.js contra os fixtures
> (13 checks: homônimos d1, CONSTRUCTOR, INLINE, ACCESS/ASSIGN,
> CLASS sem CREATE, negativos) + invocação fim-a-fim como a extensão
> (spec + `--json`; Location[] sem excluded). O harness entrou no
> contrato da suíte como caso 71 (autorização do Diego, 2026-07-07).

**Escopo restante**: revisar as saídas dos demais comandos ao novo CLI
(`--show-expansion` como opção); preview `--dry-run --json` se a
fricção pedir.
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
   (e"..." etc.). Ideal futuro: o dump (schema atual `ast-3`) carregar o
   span ORIGINAL da string (1 campo no posTrack do pp). Registrado no
   ast-schema.md.
3. Cheque textual de continuação (`Right(RTrim(linha),1) == ";"`) em 2
   pontos — falso positivo só RECUSA (conservador); fatos de statement
   multi-linha podem substituir depois.
4. Convenção `<CLASSE>_<MÉTODO>` (usages/PickFunc) — **MORTA na B4
   (2026-07-06)**: o lifting sobre `ppApplications` passou a responder com
   a posição real e o vocabulário do fonte. Na **B4d** o próprio
   `MethodLift` (e as demais âncoras por forma da B4c) foi REMOVIDO,
   substituído pelo lifting generalizado (`PpMarkerLift`/`SeedRootRule`)
   sobre o rastro de derivação (`from`, schema ast-3).

**C. Não-réplicas (auditadas e mantidas):** `HrbParse`+comparadores (formato
de ARQUIVO .hrb, não gramática; a alternativa `hb_hrbLoad` carregaria o
código no VM da ferramenta — pior); `CmdTokens` (parse do trace do hbmk2,
glue de builder); `ErrLines` (apresentação); `unused-locals` (já delega
W0003/W0032 ao compilador); `GapOnlySpace/GapOneComma/MatchBack/MatchFwd`
(validação de vãos entre tokens CONHECIDOS do stream, byte a byte, com
recusa na dúvida — é o padrão de edição, não decisão sintática própria).

## Limites da análise e alavancas de core (análise honesta, 2026-07-06)

Registro pedido pelo Diego após a pergunta "isso é verdade mesmo alterando o
fonte do Harbour?". Vale como mapa permanente do que a REGRA MAIOR (fatos de
compilação, nunca heurística) pode e não pode alcançar — e corrige uma
imprecisão de análise anterior.

### O teto (vale para QUALQUER core)

A impossibilidade de completar o "amarelo" (tipo de receptor de send, alcance
de memvar, modelo de classe dinâmico) é da SEMÂNTICA da linguagem, não da
arquitetura do compilador: a classe de um receptor é propriedade de runtime
que pode depender da entrada do programa (`iif` sobre config,
`hb_Deserialize`, `&cVar`, `hb_hrbLoad`) — território do teorema de Rice.
Análise sound responde três coisas: "definitivamente sim", "definitivamente
não", "talvez" — e o "talvez" é irredutível no caso geral. Segundo teto:
programa Harbour pode SE OBSERVAR (`ProcName()`/`ProcLine()`) — extract
"perfeito" muda `ProcName(0)` no trecho extraído; equivalência estrita sob
auto-observação é violada por definição, o contrato prático a exclui.

Três noções de "completo", da impossível à alcançável:
1. **para a linguagem** — impossível com qualquer core (teto acima);
2. **para um programa disciplinado** (fluxos estáticos, sem macro em
   receptor) — alcançável com análise de programa inteiro no core; cada
   "talvez" restante aponta a linha dinâmica culpada (relato acionável);
3. **para as execuções observadas** — alcançável por instrumentação de
   runtime; prova presença, nunca ausência.

**Correção registrada**: a afirmação anterior "nunca cobrirá parâmetro/
retorno/elemento de array" estava ERRADA como princípio — é limitação da
compilação separada (arquitetura, mudável), não da linguagem. Análise de
programa inteiro propaga tipos interprocedural quando os fluxos são
estaticamente conhecidos.

### Alavancas verificadas no fonte (2026-07-06, evidência arquivo:linha)

- **A. Tipagem declarada — a joia adormecida.** O compilador PARSEIA e
  ARMAZENA tipo declarado por variável: `AS CLASS <nome>` →
  `hb_compVarTypeNew(…,'S',…)` (harbour.y:356), campos `cType`/`pClass` em
  `HB_HVAR` (hbcompdf.h:96-106), gravação em hbmain.c:463-478. E o
  hbclass.ch JÁ DECLARA `local Self AS CLASS <ClassName> := QSelf()` em TODO
  método (hbclass.ch:263-265, via `DECLARED METHOD`). Hoje é código
  analiticamente MORTO: os warnings de tipo (ASSIGN_TYPE/OPERAND_TYPE/…,
  hberrors.h:143-152) não têm NENHUM call-site; o nome da classe só resolve
  `pClass` se houver `DECLARE CLASS` prévio (senão W25 + degrada p/ 'O'),
  mas o NOME declarado trafega em `HB_VARTYPE.szFromClass` no instante da
  declaração — capturável por gancho de dump. **Alavanca ast-4**:
  `declarations[]` ganha tipo/classe declarados; nó SEND ganha a classe
  declarada do receptor quando o receptor é variável tipada — `Self` a tem
  POR CONSTRUÇÃO em todo método. Caveat honesto: declaração é promessa do
  programador, o compilador não a verifica — consumir isso exige política
  explícita ("confio na declaração"), distinta de fato verificado.
- **B. Programa inteiro no core.** Compilação separada é arquitetura;
  o compilador (ou um passo de link-time sobre os dumps) pode propagar
  tipos interprocedural — parâmetro com todos os call sites conhecidos,
  retorno com todos os RETURNs de classe conhecida. Cresce o subconjunto
  "verde por fato" arbitrariamente para código disciplinado.
- **C. WITH OBJECT.** O objeto é empilhado em RUNTIME
  (`HB_P_WITHOBJECTSTART`, harbour.y:2001-2007; compilador só guarda
  contador de aninhamento) — mas a ASSOCIAÇÃO sintática send↔expressão do
  WITH é fato de parse, exportável no dump; se a expressão é variável
  tipada/construtor conhecido, o receptor herda o fato.
- **D. Introspecção de runtime (achados do Diego, todos confirmados).**
  `__dynsCount`/`__dynsGetName`/`__dynsGetIndex`/`__dynsIsFun`/
  `hb_IsFunction`/`__dynsGetPrf` (dynsym.c:677-727, exportados;
  padrão canônico no profiler, src/rtl/profiler.prg:238-249) enumeram o
  mundo REALMENTE linkado. Lado de classe é ainda mais rico: `__classSel()`
  (todas as mensagens de uma classe carregada, classes.c:4215),
  `__clsGetAncestors` (5383), `__clsMsgType` (5412), `__clsParent` (4253),
  `__objGetMsgList`/`__objGetMethodList`/`__objDerivedFrom`
  (objfunc.prg:72/104/222). Handle por nome: C-API `hb_clsFindClass`
  (classes.c:1519; sem HB_FUNC .prg direto — obtém-se chamando a
  class-function, validada por `hb_IsFunction`). **Usos**: membros de pai
  FORA do projeto viram enumeráveis (harness linkado ao projeto) — upgrade
  do aviso D5 do P2a; strings call-by-name validáveis contra o mundo real;
  `.hbx` de libs externas (`-hbx=`) reduz furos do alcance de memvar
  estaticamente. Caveats: prova presença, nunca ausência; `hb_hrbLoad()`
  .prg RODA os INIT PROCEDUREs (runner.c; flags `HB_HRB_BIND_*` só governam
  binding, nenhuma pula INITs) — harness tem efeitos colaterais possíveis.
- **E. Compilador como oráculo de strings.** `hb_CompileFromBuf()`
  (hbcmplib.c:230) compila string-fonte → pcode/.hrb; não há API "símbolos
  referenciados", mas o `HrbParse` DA FERRAMENTA já lê tabela de símbolos
  de .hrb → expressão-string vira lista de símbolos por FATO. Combinado com
  `ordKey()`/`DBOI_EXPRESSION` (devolvem a expressão-fonte gravada na tag,
  dbfcdx1.c:8217/dbfntx1.c:6962), UDF referenciada em índice `.cdx`/`.ntx`
  REAL vira verificável — parte do "vermelho" (nomes em dados externos)
  passa a checável PARA OS DADOS QUE SE TEM (nunca para dados futuros).
- **F. Validação de tradução.** Para transformações que mudam pcode
  legitimamente (extract/reorder), o core pode ganhar um verificador de
  equivalência POR TRANSFORMAÇÃO (corpo extraído = mesmas instruções
  realocadas + cola de chamada) — quase-prova específica, sem resolver
  equivalência geral (indecidível). Engenharia real, não pesquisa.

### O que nenhuma alavanca entrega

Decidir o caso geral dependente de entrada; enumerar nomes que nascem de
dados em runtime; equivalência estrita sob auto-observação (`ProcName`).
Para esses, o piso permanente é o da REGRA: recusa/relato honesto — nunca
palpite.

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
2. **rename-method**: PROMOVIDO a Fase B4c (2026-07-06) — a B4 destravou
   o bloqueio original (declaração METHOD visível via `ppApplications`).
   Spec executável na fase; hbhttpd (CREATE CLASS) segue como alvo de
   dogfooding.
3. Dedup de duplicatas de pré/pós-decremento: não-fazer mantido (v2).
4. **Projetos grandes de produção** (quando o Diego liberar): dogfooding
   final e conversões de projeto — só depois de suíte + hbhttpd verdes.
5. **`usages` de método: falso positivo em send de receptor de outro tipo**
   (relatado pelo Diego, 2026-07-06, dogfooding hbhttpd). `usages <método>`
   lista TODO `:<método>(` como uso, sem saber o tipo do receptor — é despacho
   dinâmico, o tipo só existe em runtime. Reproduzido: com
   `METHOD Paint() CLASS UWLayoutGrid`, uma `LOCAL a := {}` seguida de
   `a:Paint()` aparece como uso ("send in MAIN | a:Paint()") mesmo `a` sendo
   array, ao lado do `g:Paint()` legítimo (g é UWLayoutGrid). Mesma raiz da
   política de unicidade de mensagem de [B4e](#fase-b4e--comandos-de-refatoração-cientes-de-construtos-de-pp-em-andamento)
   (P1b/P2b) e do `[dynamic: …]` do call-graph: send não carrega classe.
   O fato faltante é o TIPO/classe do RECEPTOR do send.
   **Direção de correção — AJEITOS SÃO INACEITÁVEIS (princípio do Diego,
   2026-07-06).** Hierarquia obrigatória para suprir o fato faltante:
   (1) **PREFERIDO — análise em tempo de compilação no CORE do Harbour**
   (lexer/parser/pré-processador/dump AST), mesmo que custe MAIS código no
   core: o dump AST passa a carregar a classe RESOLVIDA no nó SEND quando o
   compilador a determina (ex.: `a := UWLayoutGrid():New()` — receptor com
   tipo estático); aí `usages` confirma cada uso por FATO do compilador, não
   por adivinhação — no mesmo espírito de `-x`/ppRules/rastro `from`, que já
   são análise de compilação no core. (2) **Receptor genuinamente dinâmico**
   (sem tipo estático): NÃO fingir — relato honesto "definição + sends
   POSSÍVEIS (despacho dinâmico, receptor de tipo desconhecido)", como o
   call-graph marca `[dynamic: …]`; recusar/relatar > inventar. (3) **Só se a
   análise de core for impossível**: introspecção CONFIÁVEL, no espírito do que
   o Harbour já tem (debugger, pp, i18n, hbrun). Heurística de inferência de
   tipo NA FERRAMENTA (flow analysis frágil sobre os `statements` do dump) é
   justamente o ajeito a evitar: o piso é o relato honesto de (2), o teto é o
   fato do core de (1). **Ver a seção
   [Limites da análise e alavancas de core](#limites-da-análise-e-alavancas-de-core-análise-honesta-2026-07-06)**:
   a alavanca A (tipagem declarada `AS CLASS`, que o hbclass.ch já emite
   para `Self` e o compilador já armazena) é o caminho ast-4 natural para
   este item; a alavanca D (introspecção runtime) cobre o mundo linkado.
   **Spec executável escrita (2026-07-06):
   [spec-b4f-receiver-type.md](spec-b4f-receiver-type.md)** — fatia 0 (só
   ferramenta: `Classe:Método` + relato em camadas) e fatia 1 (core, ast-4:
   `rcls` no nó SEND), com portão de desenho antes do volume.
   Observação secundária do mesmo teste: `usages` só aceita o nome CRU do
   método (`usages proj Paint`); a forma `Classe:Método` devolve 0 result(s)
   — alinhar com a resolução `Classe:Método` que rename-method/reorder/
   call-graph já fazem entra no mesmo item.
   **PROMOVIDO a Fase B4f (2026-07-06) e ✅ ENTREGUE na fase** (fatias 0 e
   1; ver a seção da fase para o registro final — o desenho MUDOU no
   portão: canal de tipos da linguagem, sem `rcls` no SEND). O histórico
   abaixo permanece como registro da evolução.
   **Fatia 0 ✅ ENTREGUE (2026-07-06, caso 61)**: `usages` aceita
   `Classe:Método` (resolução pela mesma via do PickFunc — rastro B4d — com
   a DEFINIÇÃO filtrada pela classe; homônimo em outra classe sai da lista)
   e TODO send no `usages` passa à camada honesta
   `possible send (dynamic dispatch, receiver unknown)` — o rótulo "send"
   seco morreu; o `a:Paint()` do relato aparece como possível, nunca como
   uso confirmado. Nota de escopo: na forma `Classe:Método` o protótipo
   dentro do `CREATE CLASS` não é listado (o relator de marker não filtra
   por classe) — a forma crua o cobre via "name through pp rule". Fatia 1
   entregue na fase com o desenho v3 (canal de tipos da linguagem).

## Fase B4g — a diretiva como fonte de primeira classe (schema ast-5) ✅ (2026-07-07)

Portão dos probes VENCIDO e decisões do Diego registradas no
**[adr-001-b4g-diretiva-fonte.md](adr-001-b4g-diretiva-fonte.md)** (probes
P1-P5 = fatos 8-13 da [spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md);
nenhum fallback necessário). Entregas:

- **Core (ast-5)**: `ppRules[]` ganhou `match[]`/`result[]` — um item por
  token do padrão, com papel (`literal|marker+mkind|restrict|opt-open/
  close`), marker 1-based (o mesmo de `ppApplications`) e posição
  byte-exata (col emitida também para `.ch` incluído — fato 8). Snapshot
  no instante do registro em `hb_pp_trackRuleAdd` (zero ganchos novos;
  padrão "cópia no instante" da B4d), accessors em `hbpp.h`, emissão em
  `compast.c`. **Zero impacto provado**: varredura de `src/` inteira
  (112 módulos × -w0 E -w3 = 224 comparações `.hrb`) byte-idêntica
  com/sem `-x`; relink duplo `harbour` E `hbmk2` conferido.
- **Ferramenta**: `usages` nomeia sites DENTRO de regra (`RuleSiteHits`:
  `in rule match/result/restriction`, posição no arquivo da regra);
  `rename-dsl` renomeia QUALQUER palavra do match (cabeça — inclusive de
  pontuação —, keyword secundária, palavra de restrição) com a diretiva
  editada por POSIÇÃO-FATO — **a reancoragem textual morreu**
  (DirectiveHeadEdits/DirectiveStart/WordOccs/IsIdByte removidas);
  restrição cujo valor vaza (stringify) recusa pela rede `.ppo` com
  rollback, honesto; `rename-function --edit-rules` (upgrade do caso 74:
  recusa ACIONÁVEL nomeando diretiva+posição ANTES de editar — pega até
  regra nunca aplicada, que o oráculo não via — e, com o flag, edita a
  diretiva pelo mesmo oráculo com round-trip A→B→A + execução idêntica);
  `resolve-at`/`usages --at` cobrem posição DENTRO de diretiva (camada
  antes do stream: o clone de expansão carrega a mesma posição — fato 13).
- **Extensão 0.7.0**: `cmdRenameFunction` com confirm-then-force para
  `--edit-rules`; de quebra, o confirm de `--force` (referências textuais)
  estava MORTO — a regex testava a mensagem em inglês e o CLI fala
  português — e foi consertado.
- **Suíte 555/0** + lexdiff 0 divergências reais. Fixtures do probe
  promovidas (`fixb4g/`: forja/molde — todos os mkinds, continuada em 3
  linhas, opcionais consecutivos REORDENADOS pelo pp, opcional aninhado,
  restrição que vaza e que não vaza, regra nascida de expansão) com
  invariantes campo a campo no caso 82; caso 65 aceita ast-4|ast-5; régua
  do caso 64 assertada para o vocabulário novo (fronteira de palavra).
- Decisão de desenho (Diego): `match[]` na ordem ARMAZENADA pelo pp
  (opcionais reordenados ficam como o pp casa; a ordem do fonte é
  recuperável pelas posições) — o dump transporta fato 1:1.

## Fase B-infra Etapa 1 — suíte paralela em bash ✅ (2026-07-07)

Desenho integral em [testes-paralelos.md](testes-paralelos.md) (forma:
pool dinâmico por-caso; tecnologia da Etapa 1: bash puro, zero dependência
nova, asserts INTACTOS — drift zero). Implementação no próprio
`tests/run.sh`:

- cada caso virou função auto-contida `unit_N` (R3); auditoria prévia
  achou UM acoplamento real — os casos 67-69 continuam no `$D` do caso 66
  e releem o `pm.log` dele — e eles viraram UMA unidade (`unit_66`);
  nenhuma outra variável herdada entre blocos; compiles em diretório de
  fixture compartilhado são todos `-s` (só leitura);
- driver: `JOBS<=1` roda em processo, na ordem, com saída ao vivo (R7 —
  depuração idêntica ao runner antigo); senão pool `xargs -P JOBS`
  (default `nproc`) re-invocando `run.sh --unit N` — cada unidade com
  `TMPDIR` próprio (R2; `hb_DirTemp()` o respeita, cinto-e-suspensório
  com o R1 da B4b), log em artefato próprio (R5, mata a intercalação) e
  contadores em-banda (`@@counts`); o join imprime os logs NA ORDEM dos
  casos — a saída paralela é BYTE-IDÊNTICA à sequencial — e soma o tally;
  unidade que morre sem contadores conta FAIL e mostra o log (silêncio
  nunca parece sucesso);
- `make test` = paralelo por default; `make test JOBS=1` sequencial.

Verificação (protocolo do doc): baseline 108,98 s (runner antigo,
resgatado do git); novo `JOBS=1` 109,34 s byte-idêntico; paralelo 20
cores 11-14 s (**~8×**); paridade byte-idêntica também no paralelo;
**10/10 rodadas consecutivas** idênticas, zero flake.

Lição de percurso (a armadilha do HB_BIN mordeu DE NOVO): a primeira
"prova" de paridade comparou duas cópias da MESMA linha de erro — sem
`HB_BIN`, os dois runners falham com saída idêntica e `diff` limpo. Prova
de paridade só vale conferindo ANTES que a baseline contém a suíte real
(o exit=1 inexplicado era o aviso).

## Fase B7 — tipos interprocedurais (alavanca B) ✅ (2026-07-08)

Promovida do backlog pela fricção do fixext (sends de homônimos
misturados no peek — `possible (receiver unknown)` para todos). Spec com
decisões D1-D4: [spec-b7-tipos-interprocedurais.md](spec-b7-tipos-interprocedurais.md).

**Core (ast-6, D2)**: `"ret": true` no push de RETURN (`hb_compAstReturn`,
harbour.y + compast.c; .yyc regenerado com bison 3.0.2 preservando o
patch manual do yynerrs); zero impacto provado 224/224 .hrb
byte-idênticos (112 módulos de src/, -w0 E -w3); relink duplo
harbour+hbmk2 conferido por strings.

**Análise (fatias 1+2, bloco B7* + TypeOf/SendReceiverType)**: ponto
fixo com conjuntos finitos de classes; oráculo D3 (tobject.prg com -x,
cache tamanho+mtime em ~/.cache/hbrefactor) — "New herdado devolve
QSelf()" é fato do fonte da linguagem, provado por probe executável;
cadeia de construção por FUNREF; fold de IIF constante + união dos
ramos de IIF de runtime (fechada no rito, caso 85); registro por pares
(STRING, @F()) genérico; retorno rotulado de fábrica sem DECLARE;
`::Super:` (D1: travessia de vínculo escrito na TIPAGEM, com ressalva
de mundo fechado no rótulo); venenos → ⊤ sempre (Self reescrito, @ref,
escrita destacada, memvar/field, pontos cegos auditados); união de
parâmetros por call sites do projeto; conjunto >1 nomeia candidatos.

**Rito D4 (2026-07-08, flips aprovados caso a caso pelo Diego)**:
baseline pré-rito 560/5; a previsão da spec (unidades 62/63/66/72/73/75)
errou parcialmente — flips reais em 39/61(×2)/63/66, 6 sites em 5
checks: w2.prg:7 e c2.prg:28 e r2.prg:28 → confirmed via cadeia;
c2.prg:30 e d1.prg:87/88 → excluded com despacho nomeado. "Declarar
ctor" virou reforço, não requisito (descrição do caso 66 reescrita).

**Cobertura (casos 84/85, 17 checks)**: caso 84 asserta o critério
fixext linha a linha (simetria das duas consultas; `::Super:Deposita`
com cadeia nomeada); caso 85 (fixture nova fixb7) prova fábrica sem
DECLARE, união de call sites (`receiver one of DISCO or PECA`), IIF de
runtime como união dos ramos, e os 3 venenos com send observável
degradando honesto. Generalidade: fixq4 (caso 75) e fixofi intactos —
fronteira `__clsInst` (primitiva C) permanece honesta.

Fechamento provado por execução: suíte **582/0**, saída BYTE-IDÊNTICA
paralelo × `JOBS=1`. Lição de fixture: send `::Msg()` NÃO conta como
uso de SELF para o W0032 — o uso que conta é acesso a VAR (a fixture
fixb7 documenta a forma no comentário).

## Fase B7b — inferência fatia 3: retorno de método, Self em INLINE, blocos ✅ (2026-07-08)

Portão aberto pela M-cov 2 (decisão do Diego: mais inferência sobre os
fatos que JÁ temos antes de qualquer extensão de linguagem; B9 na
gaveta). Spec: [spec-b7b-inferencia.md](spec-b7b-inferencia.md).
**100% ferramenta — zero mudança no core, schema ast-6 inalterado.**

**Alvo 1 — retorno de MÉTODO (send encadeado, 697 sites medidos)**:
método DECLARADO sem tipo de retorno (o `_HB_MEMBER` sem `AS`, a forma
normal do hbclass) deixou de curto-circuitar em NIL: cai para a
implementação REGISTRADA da própria classe e tipa pela união com acordo
dos pushes `ret` (ast-6) — `TypeOf`/`B7MethodRet`, mesmo memo/guardas
do retorno de função; o acerto declarado continua parando o dispatch
(não sobe vínculos). Identidade `RETURN Self` encadeia
(`o:Soma(1):Soma(2)`); venenos honestos: Self reescrito no corpo (o
furo pré-existente do `B7AllRetsSelf` sem cheque de veneno foi fechado
junto), ciclo entre métodos, retornos discordantes.

**Alvo 2 — Self em corpo INLINE/OPERATOR (padrão money)**: parâmetro de
bloco decidido por FATO da declaração (`declarations[]` com
`param: true` e `declLine` na linha do `{|`, em ordem — binder léxico
pela pilha de blocos do uso; 2 blocos na mesma linha = inatribuível);
o 1º parâmetro de bloco de membro INLINE registrado É o receptor —
fato do VM (classes.c:4554 empilha Self como 1º argumento do bloco)
sobre o registro como-escrito (par STRING+CODEBLOCK em ARGLIST da
função-classe, leitura em profundidade-0), com `via` no rótulo.
**Portão de generalidade fechado**: DSL não-espelho (fixb7b/forno.ch,
`__clsNew`/`__clsAddMsg`/`HB_OO_MSG_INLINE`, param `tigela` ≠ Self)
ganha o MESMO fato, com dispatch provado por execução; 2º+ parâmetro
degrada honesto; régua do caso 64 assertada (nenhuma palavra da DSL na
ferramenta).

**Alvo 3 — blocos**: (a) detached de binding único lida dentro do bloco
classifica (a decisão de sombra por linha de occurrence morreu — por
declaração, imune à convenção de última-linha-física dos statements
continuados); (b) parâmetro de bloco tipa pela união dos argumentos dos
sites de Eval RASTREÁVEIS (o compilador traduz `Eval(b,…)` no send
`b:EVAL(…)` — fato do dump): bloco obj direto de Eval ou binding único
de local com TODAS as leituras em obj de Eval, na mesma função; pontos
cegos (leitura fora de Eval, `@ref`, multi-write, param reescrito)
degradam. Hardening que fechou furo latente: `B7ParamType` só aceita
parâmetro da FUNÇÃO (declLine na linha da função) — param de bloco
corrompia o índice da união de call sites.

**Cobertura (caso 86, fixture fixb7b, 18 checks)**: os 3 alvos +
venenos, hbclass E DSL própria, statement continuado, executável
(imprime e roda — o ciclo Gira↔Volta é estático nos `ret` e termina em
runtime por contador). Suíte **600/0**, byte-idêntica paralelo ×
`JOBS=1`.

**M-cov 2 re-rodada no MESMO corpus** (harness `tests/mcov2.sh`, binário
antigo × novo): delta registrado na seção M-cov 2 do
[limites-e-alavancas.md](limites-e-alavancas.md).
