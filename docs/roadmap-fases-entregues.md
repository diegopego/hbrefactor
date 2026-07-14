> **ARQUIVO HISTÓRICO — registro, não intenção.** A intenção VIVA (fases ativas,
> pendências, backlog) mora em [roadmap.md](roadmap.md); aqui fica o registro
> completo das fases ENTREGUES. É **append-only**: cada limpeza do roadmap
> acrescenta as narrativas migradas ao FIM, verbatim, sem reescrever as anteriores.
> Começou como snapshot integral do roadmap v3 (2026-07-07); as migrações seguintes
> estão datadas nas seções de arquivamento.
> **Não se lê este arquivo para saber o que fazer** — só para saber o que já foi
> feito, e por quê.
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

## Fase R — Revisão de generalidade ✅ (2026-07-07) — narrativa migrada do roadmap (arquivada 2026-07-09)

**Escopo e checklist**: [revisao-generalidade.md](revisao-generalidade.md).
**Q4 ✅ FECHADA (2026-07-07, caso 75)**: o veneno do pai falso era real
(probe fixq4: forjador por `@ref` na linha da declaração virava pai e
`t:Pintar()` saía confirmed para um send que seria ERRO em runtime);
conserto `DispatchVia` — vínculo escrito nunca confirma/exclui, acerto
próprio decide; 7 asserts de herança flipam para possible nomeado
(**mudança de contrato, aguardava portão do Diego — absorvida pela
fase RE em 2026-07-09**); suíte 474/0.
**Q8 ✅ FECHADA (2026-07-07)**: auditoria commit a commit REFUTOU a
suspeita — nenhuma lógica keyed a biblioteca no core do branch, só
transporte 1:1 de canal da linguagem (gates fAst = tabelas vivas com
warnings nível-3 gated na emissão; schema espelha a gramática; canal de
tipos é write-only no core; evidência arquivo:linha no doc da revisão).
Pendência cosmética opcional: comentário de compast.c:106 (→ B6).
**Q1-Q3/Q7 ✅ FECHADAS (2026-07-07, casos 76-79, fixture fixofi)**: DSL
inventada NÃO-espelho (colagem MENSAGEM-primeiro `Talha_na_Banca`,
assinatura única sem par protótipo/impl, dispatch REAL
`__clsNew`/`__clsAddMsg`). Q2 = prova pura (o açúcar é só política de
unicidade sobre o motor genérico). Q1/Q3 = conserto `GenMsgPart`: a
mensagem do composto é a parte que NÃO nomeia função-de-classe (fato da
co-derivação) — eleger a última parte era forma-de-hbclass (call-graph
respondia VAZIO; o reorder cru elegia a dona). Q7 = a síntese
`METHOD ... CLASS` fica exclusiva da forma hbclass (portão = vocábulo da
regra raiz via `PpMarkerLift`; DSL própria degrada para FUNÇÃO verificada
com o fato relatado) + veneno novo morto: range com `QSelf()` extraído
para função mudava comportamento EM SILÊNCIO (receptor não viaja) — nó
`SELF` na árvore agora recusa limpo nomeando a exceção. Suíte 517/0.
**Q6 ✅ FECHADA (2026-07-07, caso 72 atualizado + caso 80 novo)**: rótulo
do DONO no vocabulário da DSL que o declarou (`cog declaration
(rig TOTEM)`, `oficio definition Talha (tenda Banca)` — prova na DSL
não-espelho). Semântica decidida por probe: a cabeça da regra cuja
expansão LIGOU o nome ao canal de classe (o `from` do próprio nome), NÃO
a regra raiz do site — `CREATE CLASS` tem raiz `create` e o hbclass segue
`(class ...)` porque a regra `CLASS` é quem declara; dona sem derivação
cai para "class" (o nome do canal da linguagem). Suíte 520/0.
**Q5 ✅ FECHADA (2026-07-07, casos 81 + 71 novo; opção B do Diego)**: o
`methodQuery` (regex hbclass da extensão, V1) morreu — a extensão manda a
POSIÇÃO do cursor (`usages --at arq:linha:col`, UMA compilação) e o CLI
resolve por fato (`ResolveAtQuery`, mesmo core do `resolve-at`
standalone): co-derivação do site + aplicação-identidade (P1a) + canal
declared. Homônimos pelo SITE; DSL qualquer promove (a regex só via
hbclass); send/posição-vazia degradam honesto. Extensão 0.6.0.

**A REVISÃO ESTÁ COMPLETA**: V1-V7 tratados, Q1-Q8 fechadas com prova
executável (casos 75-81 + atualizações 64/72-74), régua do caso 64
assertada nos casos novos, extensão sem regex de construto.

## Fase B-infra Etapa 2 — runner em Harbour ✅ (2026-07-08) — narrativa migrada do roadmap (arquivada 2026-07-09)

Mesma FORMA da Etapa 1 (pool por-caso, unidades bash intactas,
protocolo filho `--unit N` + `@@counts` + logs impressos na ordem), só
a tecnologia troca, em duas fatias independentes:

- **(a) checker Harbour** — `tests/tcheck.prg` (compilado pelo
  Makefile) substitui os **10 heredocs `python3`** das unidades
  18/26/42/62/65/66/70/72/82 (o "18/26" do desenho original cresceu):
  asserts sobre JSON via `hb_jsonDecode`, mesmos exit codes e mesmas
  saídas assertadas ("json ok", "consistente").
- **(b) despacho+join Harbour** — `tests/parrun.prg` via
  `hb_processOpen`/`hb_processValue` (fato verificado no fonte:
  `waitpid(WNOHANG)`, -1 enquanto roda) substitui o ramo `xargs -P`
  do run.sh; `JOBS>1` delega ao binário, `JOBS=1` continua bash
  sequencial com saída ao vivo (R7 preservado).

Fora do escopo (decisão de menor arrependimento, mesma da Etapa 1):
reescrever os 555 asserts em .prg (drift alto, valor novo nulo — as
unidades bash JÁ são auto-contidas) e o `occ_ast_diff.py` do
`make lexdiff` (fora do caminho do `make test`; morre quando o alvo
legado morrer). Critério de pronto, TODO provado por execução no
fechamento (2026-07-08): `python3` ausente do `run.sh` (resta 1 menção
em comentário — história); saída do `make test` **byte-idêntica** nos
dois modos (diff paralelo × `JOBS=1` limpo); 10/10 rodadas paralelas
sem flake e byte-idênticas entre si; wall-time 14 s (patamar da
Etapa 1); binários construídos pelo Makefile (`bin/tcheck`/`bin/parrun`
são dependências do alvo `test`).

## Registro de sessão 2026-07-09 — revisão externa Codex, commit da B9 fatia 1, abertura da fase RE

Sequência da sessão (pendências 1-3 do roadmap daquele dia, resolvidas):

1. **Revisão externa despachada e concluída** (instrumento
   [revisao-codex-zero-inferencia.md](revisao-codex-zero-inferencia.md),
   sem contaminação pelo juízo do Claude). Três rodadas: forma
   (gpt-5.4-mini; 6 achados aplicados), mérito Q1-Q5 (gpt-5.5) e
   auditoria de código do delta + ferramenta (gpt-5.5; achados A1-A5).
   Registro completo das rodadas e vereditos:
   [spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md).
2. **Fatia 1 da B9 commitada nos dois repos por decisão do Diego**
   (após a 1ª rodada): harbour-core `c1927dfcac` (fatia `-kt`, 8
   arquivos, schema ast-7); hbrefactor `6584aa8` (consumo ast-7 +
   guaranteed + fixkt/caso 87 + docs); depois `590a4a5` (achados de
   forma aplicados ao instrumento). Suíte 616/0 byte-idêntica.
3. **Convergência e decisão**: o veredito externo convergiu com o
   julgamento interno de 2026-07-08 (manter renames verificados +
   usages honesto; rebaixar B7/B7b; `-kt` legítimo com consumo a
   consertar). O Diego adotou o plano (2026-07-09) — fase RE aberta
   como prioridade 1, plano vinculante na spec acima.

Contexto pré-decisão preservado: o julgamento interno de 2026-07-08
dizia que, para refatoração semântica de legado, a linha não compensa
no teto medido (M-cov no mapa); vale manter renames verificados +
usages honesto; `-kt` é decisão de DIALETO, separada.

## Fase B9 — Tipos declarados impostos (`-kt`) + materializador `annotate` ✅ (fatias 1 e 2, 2026-07-08→10) — narrativa migrada do roadmap (arquivada 2026-07-10)

**Fatia 1 (2026-07-08; commitada 2026-07-09 — harbour-core
`c1927dfcac`, hbrefactor `6584aa8`)**: `-kt` no core (emissão
prólogo/local/RETURN + helper `__HB_CHKTYPE` com is-a no objeto vivo;
zero impacto 224/224; dimensionada NÃO é anotação — `HB_VSCOMP_DIMMED`);
schema **ast-7** (`kt` + `dim`); camada `guaranteed` no usages +
DeclType sem a falsa promessa do 'A' dimensionado; fixture fixkt +
caso 87 (17 checks, execução real); suíte 616/0. A auditoria externa
alegou overclaim do `guaranteed` (A1/A2); confirmado no RE.1 e
consertado no RE.2 (`B7KtCovered` restringe a marca aos sites
cobertos; caso 88). O RE.3 pôs a máquina B7/B7b DORMENTE (entrada
`B7Ctx`) e suspendeu as expectativas dos testes rebaixados em
testes-suspensos-re3.md — os itens [FATIA-2] viraram a semente do
critério de aceite da fatia 2.

**Fatia 2 — a escada de declarações (2026-07-09→10)**: a discussão do
P1 (argumento do Diego: "o compilador já sabe o tipo de
`t := Cls():New()`") gerou a investigação que dissolveu os portões
P1/P2/P3 da spec v1: o cheque de tipos do core é vestigial (zero
emissores), mas hbclass declara retorno de CONSTRUCTOR e UMA linha
`DECLARE` fecha a cadeia no módulo do site (probes smoke1-4). Nasceu a
ESCADA (nível 1 fato puro / nível 2 one-liner que falta / nível 3 só
relata — decisão do Diego: nunca edita) e o plano
plano-b9-fatia2-escada.md, executado F2.0-F2.5:

- **F2.0-F2.3 (2026-07-09)**: fatos no ast-schema (§ FAZ/NÃO FAZ);
  probes (a)-(e)+(g) — `_HB_MEMBER` avulso sem W0019, ordem
  DECLARE→FUNCTION é imposição, DECLARE cobre classe runtime-pura,
  topologia (g) presa só no W0019; spec v2; comando `annotate`
  (relatório) revive a máquina por `B7Ctx` (W0034 morto); tabela de
  alcance: TODAS as sementes Rota A/B fecham por nível 2; corpus
  hbhttpd = 13 fábricas declaráveis + 18 métodos presos no (g).
- **PORTÃO DO MEIO (Diego, 2026-07-09)**: candidato **(g) ADOTADO** —
  W0019 de método silenciado SÓ quando a re-declaração COMPLETA tipo
  ausente (hbmain.c:1174-1180; conflito real segue warnando), provado
  nas seis pontas + re-medição (fixb7b 2→0, hbhttpd 18→0); core
  `b758cf376a`. Candidato (f) ADIADO.
- **F2.4 núcleo (2026-07-09)**: `annotate --apply` — pipeline
  bottom-up (baseline → one-liners → padrão-ouro → re-análise →
  AS CLASS → padrão-ouro), âncoras ESTRUTURAIS resolvidas por fato do
  dump, padrão-ouro = inerte byte-idêntico sem `-kt` (compilação `-l`)
  + compila limpo `-w3 -es2` + roda sob `-kt`; `RollbackAll` + recusa
  nomeada. Caso 89 (fixb7b round-trip: os sends do caso 86 degradados
  no RE.3 voltam a `confirmed via declared types`); extensão VSCode
  `annotate`/`annotateApply` (0.9.0); suíte 636/0.
- **F2.4 complemento (2026-07-10)**: caso 90 — ROLLBACK PROVOCADO
  (fixture fixrbk: `_HB_MEMBER ACHA() AS CLASS MOEDA` com runtime
  devolvendo N; pertencimento por posição/pLastClass, o `AS CLASS` do
  `_HB_MEMBER` é tipo de RETORNO — hbclass.ch:282, precisão do Diego;
  pristino roda limpo sob `-kt` porque promessa de membro não é
  imposta; o `--apply` materializa, o cheque pós-store pega EM
  EXECUÇÃO, fontes voltam BYTE A BYTE e a recusa nomeia o BASE/3012 —
  idioma `AnnChkLine`); casos 91-96 — round-trip por semente
  (fixcls/fixmth/fixrcv/fixdis/fixext/fixb7): `confirmed declared` →
  `guaranteed ... imposed by -kt checks` no MESMO site, originais
  intocados, recusas honestas assertadas (nível 3 não edita; espelho
  segue `possible` — Rota C sem rota). Duas correções que as sementes
  provocaram: registro PURO `_HB_CLASS <Cls>` para nível 1 com classe
  fora do módulo do site (substituiu o regtext `DECLARE ... New()` que
  prometia membro inventado) e atribuição HONESTA de falha
  pré-existente (pristino roda sob `-kt` antes da edição; se já falha,
  o passo é pulado nomeando — falha do projeto nunca vira culpa da
  edição; destrava projeto-servidor). Suíte **692/0**.
- **F2.5 (2026-07-10)**: testes-suspensos-re3 Rotas A/B RECONQUISTADAS
  (caso a caso na tabela); M-annotate re-medida — relatório delta zero
  e ciclo completo no corpus: 31 declarações + 7 anotações verificadas
  em ~3 s, re-relatório DRENA (13/18/7 → 0; resíduo estrutural 284
  sem-prova + 1 nível 3); CHANGELOG.md para o programador final.

Resíduos em aberto (fatia futura, portão de ESCOPO do Diego): projeto
já-`-kt` (strip no baseline inerte), anotação de PARÂMETRO
(`SigParamHits`), candidato (f) como coluna-delta.

Adendo (mesma sessão, 2026-07-10): o Diego abriu o escopo do resíduo
(1) — **projeto já-`-kt`**: `AnnNoKt` remove só o `-kt` dos flags
resolvidos para os `.hrb` do teste inerte (a anotação sob `-kt` muda
pcode por DESIGN — ela emite os cheques); a execução de verificação
segue com o projeto como está. Caso 97 (fixb7b + `-prgflag=-kt`):
antes recusava "a edição NÃO é inerte"; agora anota, os cheques rodam
e o site coberto sai `guaranteed` DIRETO — invariante no mesmo passo.
Suíte 699/0 byte-idêntica paralelo × JOBS=1; lexdiff limpo. Resíduo
que segue aberto: anotação de PARÂMETRO (rendimento auto-escrevível
baixo — quase sempre nível 3) e candidato (f) como coluna-delta.

---

# ARQUIVAMENTO 2026-07-13 — narrativas migradas do roadmap.md

Fases ENTREGUES (ou mortas) cuja narrativa integral saiu do `roadmap.md` para
cumprir a regra de manutenção dele: **o roadmap carrega estado atual + o que
está por fazer; o registro completo mora aqui.** Nada foi reescrito — os blocos
abaixo são o texto VERBATIM do roadmap no dia do arquivamento. As pendências
VIVAS que estavam enterradas nestas narrativas (portão D-P5, fila da P-AUDIT,
P12, P-DOC, resíduos da B9, dívida da SITE-EX) foram EXTRAÍDAS e continuam no
roadmap, na seção "Pendências vivas".

---

## [arquivada] Fase RE — re-escopo pós-revisão externa (RE.1-RE.6 fechados)

### RE — Re-escopo pós-revisão externa — **PRIORIDADE 1 (portão aberto pelo Diego, 2026-07-09)**

A revisão externa independente (Codex, 3 rodadas em 2026-07-09 —
instrumento
[revisao-codex-zero-inferencia.md](revisao-codex-zero-inferencia.md))
convergiu com o julgamento interno de 2026-07-08: **manter** dump
`-x`/rastreamento PP/refatorações verificadas; **`-kt` é R1-legítimo
mas o consumo overclaima** (`guaranteed` para sites que o cheque não
cobre); **B7/B7b são inferência** → rebaixar a sugeridora/
materializadora. Plano vinculante com achados A1-A6, itens RE.1-RE.6,
guarda de fase e critérios executáveis (**RE.1-RE.4 FECHADOS em
2026-07-09** — RE.1: A1/A2/A5 confirmados com probes, extras gap de
`@ref` e A6, segfault upstream com `AS CLASS` em param de codeblock;
RE.2: marca `kt` restrita a site coberto, caso 88; RE.3, portão
aberto na forma "a" + possible sem nomes de inferência: máquina
B7/B7b/dispatch-por-grafo DORMENTE, usages só-fato, M-cov 3 com
confirmed 1.715→545 100% canal declarado, casos 39/61/63/66-69/72/75/
84-86 re-baselinados — o furo dos homônimos degradou nos sends;
RE.4: `pPosTbl` limpo no reset, 460/460 byte-idêntico, harbour-core
`ef0abe3688`. Suíte 622/0 byte-idêntica. **RE.5 EXECUTADO
(2026-07-10, portão aberto pelo Diego na mesma sessão da spec):
[spec-re5-cobertura-kt.md](spec-re5-cobertura-kt.md)** — K1 (A6 morto:
classe de param de bloco EXISTE e chega ao dump), K2 (prólogo de bloco
impõe por Eval), K3 (pós-store de detached em bloco), K4 (fato `chk`
no dump, **ast-8**; `B7KtCovered` virou LEITOR — a matriz replicada
morreu; portões de capacidade convertidos a `AstAtLeast`, lição do
bump); K5 MEDIDO (zero receptores-objeto em @ref no corpus → FORA
com registro), K6 FORA. Caso 88 re-baselinado como matriz por FATO
(escrita em bloco e param de bloco AS CLASS RECONQUISTADOS →
`guaranteed`; site 5 era INESCREVÍVEL antes do A6). Zero impacto
1085/1085 (+3 = o próprio A6 no compilador base); suíte **700/0**
byte-idêntica paralelo × `JOBS=1`; lexdiff limpo. Commits do core sob
autorização. **RE.6 — F6.1+F6.2+F6.3 ENTREGUES (2026-07-10, D1-D6 como
recomendados): o FURO DOS HOMÔNIMOS (caso 66, o caso original do Diego)
FECHADO por FATO.**
[spec-re6-parentesco-declarado.md](spec-re6-parentesco-declarado.md)
§ Executado — F6.1: canal `_HB_SUPER` no core (léxico+gramática
0-conflitos+hbclass.ch, pai posicionado prov `s`; `.hrb` 356/0
byte-idêntico; lição hbmk2 = 2º binário que embute o compilador,
commit `c2c26e5aa3`). F6.2: schema `ast-10` (`b07fef4060`) + consumidor
(`ClassSuperFacts`/`ResolveDispatchSuper`/`KinshipExcludes`, exclusão de
send por parentesco de FATO com degrade honesto sob is-a). F6.3:
re-baseline dos 16 asserts da Rota C + generalidade adversarial (caso
104, DSL inventada declara herança só via `_HB_SUPER`) + CHANGELOG;
suíte **757/0**, lexdiff 0. Commit consumidor+re-baseline `6df5c50`;
generalidade+CHANGELOG sob portão. Parentesco DECLARADO reconquistou a
exclusão de SEND sobre arestas de FATO:
**[spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md)**
— retomada de sessão COMEÇA por lá. Registro narrativo da sessão
2026-07-09 (rodadas, commits `c1927dfcac`/`6584aa8`/`590a4a5`) no
[arquivo](roadmap-fases-entregues.md).

---

## [arquivada] Fase R + stub da B4g

### R — Revisão de generalidade ✅ CONCLUÍDA (2026-07-07) — narrativa no [arquivo](roadmap-fases-entregues.md)

V1-V7 tratados, Q1-Q8 fechadas com prova executável (casos 75-81 +
atualizações 64/72-74); checklist e achados:
[revisao-generalidade.md](revisao-generalidade.md). Pendência viva que
sobrou: os 7 asserts de herança flipados para possible nomeado (Q4)
foram **mudança de contrato que aguardava portão do Diego** — absorvida
pela fase RE (o rebaixamento de B7/B7b decide o contrato final).

### B4g ✅ ENTREGUE (2026-07-07) — registro no [arquivo](roadmap-fases-entregues.md)

Portão + decisões: [adr-001-b4g-diretiva-fonte.md](adr-001-b4g-diretiva-fonte.md);
spec (fatos 1-13): [spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md).
Todos os critérios mecânicos fechados (zero impacto 224/224; byte-exato
campo a campo no caso 82; caso 74 acionável com round-trip; suíte 555/0 +
lexdiff limpo; extensão 0.7.0).

---

## [arquivada] Fase B5 — extensão VSCode (fatias 0.6.0 → 0.13.0) e B5.1

### B5 — Extensão VSCode (restante)

Fatias entregues no arquivo; **consulta por POSIÇÃO entregue (Q5,
extensão 0.6.0)**; **B4g entregue (0.7.0)**: confirm-then-force de
`--edit-rules` no rename-function + conserto do confirm de `--force`
(regex testava mensagem em inglês, CLI fala português — estava morto).
**`--show-expansion` entregue (0.7.1, 2026-07-08 — decisão do Diego:
SEMPRE-ligado no usages da extensão, sem comando/setting novos)**: o
flag é só-rótulo do canal (` -> CAIXA_SOMA`, ` -> derives ...`) e o
`--json` do peek é byte-idêntico com/sem ele (provado em fixmth e
fixppm), então suprimir custaria caro — cada invocação recompila o
projeto (`hbmk2 -rebuild`) e re-perguntar pagaria outra compilação;
divergência com o default do CLI documentada no README da extensão;
guarda executável no harness do caso 71.
**HB_BIN definitivo (0.7.2, 2026-07-08)**: a validação do Diego morreu
com "o projeto não compila" porque o host de desenvolvimento não tinha
`hbrefactor.hbBin` configurado — sem `HB_BIN` o CLI cai no hbmk2 do
PATH (sem `-x`), sintoma já catalogado no CLAUDE.md. Conserto em três
camadas: default do setting = layout do repo
(`~/devel/harbour-core/harbour/bin/linux/gcc`, o mesmo do Makefile);
dica honesta no `AstDumps` do CLI nomeando a causa quando o build falha
com `HB_BIN` vazio; 2 guardas novas no harness do caso 71 (13 pass).
**Picker ciente do arquivo entregue (0.8.0, 2026-07-08)**: subcomando
`projects-of <arq> <candidatos...> [--json]` no CLI — pertencer = o
hbmk2 resolve o arquivo como fonte na linha de comando do compilador
(`LoadProject`/`-traceonly`, medido ~3 ms por candidato ⇒ sem cache),
identidade por caminho canônico COMPLETO (nome+ext daria falso positivo
entre projetos com `main.prg` distintos — provado no caso 83); órfão =
resposta vazia com exit 0, nenhum candidato resolvido = exit != 0 (a
pergunta falhou, não é órfão). Na extensão a decisão é pura
(`pickerChoices`): dono único entra SEM pergunta, fonte compartilhada
pergunta só entre os donos, órfão/falha degrada para a lista completa;
`projCtx` (relatórios de projeto inteiro) inalterado. Provas: caso 83
novo (10 checks, inclui a armadilha do basename e a forma absoluta da
extensão) + 9 guardas novas no harness do caso 71 (22 pass); suíte
**565/0**.
**Descoberta por proximidade entregue (0.11.0, 2026-07-10)**: o Diego
relatou que no dia a dia o picker mostrava vários `.hbp` (às vezes o
mesmo repetido) e o `.hbp` do próprio diretório do arquivo SUMIA.
Diagnóstico (três raízes, todas na extensão): (1) `findFiles` com teto
de **32** truncava a lista em ordem indefinida ANTES da lógica de dono
rodar — neste workspace há 158 `.hbp`/`.hbc`, então o do diretório caía
fora; (2) zero ordenação (a `fsPath` crua na ordem de varredura); (3)
zero dedup. Conserto **no CLI** (fiel à extensão fina — o walk-up e a
ordenação são inteligência, não podem morar na extensão): o
`projects-of` ganha um **modo DESCOBERTA** — `projects-of <arq> [--root
<dir>]... [--json]` sem candidatos. A ferramenta ACHA o projeto por
FATO: caminha os diretórios ANCESTRAIS (dir do arquivo → raiz que o
contém) listando `.hbp/.hbc` (só nome por extensão — nunca parse de
`.hbp`), sonda o hbmk2 do mais PRÓXIMO ao mais distante (`FileOwnedBy`
fatorado de `ProjectsOf`) e, só se nenhum ancestral for dono, amplia
varrendo a(s) raiz(es) (adaptativo; teto `OWNER_BROADEN_CAP` avisa se
truncar). Devolve `{ owners, candidates }` JÁ ordenados por proximidade
(`RankByProximity`, matemática de caminho pura). **A proximidade é só
APRESENTAÇÃO; o veredito de posse continua sendo fato do hbmk2** — o
auto-select ainda exige dono ÚNICO de fato, nunca "o mais próximo". Na
extensão: `ownerOf` passa o arquivo + as raízes do workspace e renderiza
(rótulos legíveis: nome do `.hbp` + diretório); `findFiles` perde o teto
e deduplica (só usado no caminho SEM arquivo/degradado); `pickerChoices`
intacto. Modo FILTRO legado (candidatos explícitos, array JSON, ordem
dos candidatos) preservado byte-a-byte → caso 83 inalterado. Provas:
caso 102 novo (6 checks: dono único, fonte compartilhada nearest-first,
decoy mais perto que NÃO é dono, órfão, objeto JSON) + 6 guardas novas
no harness do caso 71 (32 pass).
Restante, por fricção do uso diário:

- ~~preview `--dry-run --json` se a fricção pedir.~~ **ABSORVIDO pela fase A**
  (2026-07-13): não era fricção de uso diário, era a falta de um CONTRATO DE
  MÁQUINA — o mesmo buraco que faz a extensão casar prosa. Ver a fase A.1.

**Critério**: Diego usa no dia a dia; sem regressão.

#### B5.1 — `.hbp` multi-alvo reconhecido por inteiro ✅ ENTREGUE (2026-07-10)

Sintoma do Diego: `.hbp` com estrutura/flags mais complexa "não era
reconhecido". Raiz: um `.hbp` pode resolver para **vários alvos de build**
— `-hbcontainer` referenciando sub-`.hbp`, referência direta a outro
`.hbp`, ou `-target=` — e o `hbmk2 -traceonly` imprime **uma linha
"Harbour compiler command" por alvo**. O `LoadProject` lia só a PRIMEIRA;
as fontes dos demais alvos ficavam invisíveis e o `.hbp` deixava de ser
reconhecido como dono delas (owners vazio no `projects-of`). Fix:
`LoadProject` captura TODAS as linhas de comando e **une** fontes/includes/
flags/hbx com dedup (`AddUniq`). Fiel à REGRA DO FATO — `.hbm` (coleção de
opções), `.hbc` (pacote), `-i`, `${macros}` e filtros `{...}` já vêm
**resolvidos DENTRO de cada comando** pelo hbmk2; a ferramenta nunca
parseia `.hbp`, só lê o comando do compilador que o builder oficial
emitiu. Prova: caso 103 novo (4 checks: fixtures limpas, dono do 1º alvo,
dono do 2º alvo — a regressão —, descoberta do container). A API de plugin
do hbmk2 foi avaliada como canal alternativo e DESCARTADA: expõe
`hbmk_AddInput_*` (escrita) e vars como `cTARGETNAME`, mas **não** a lista
de fontes resolvida (leitura) — o comando do `-traceonly` continua sendo o
canal de fato mais completo.
Limite conhecido (não do escopo deste fix): se dois alvos compilam módulos
de MESMO nome-base em diretórios distintos, o dump `.ast.json` é chaveado
só pelo nome-base (`ReadAst`) e colidiria — só afeta análise, não a posse.

---

## [arquivada] Fase U — verbos unificados (fatias 1 e 2 entregues)

### U — Verbos de refatoração unificados (`rename`/`extract`/`reorder`) — **FATIA 1 ENTREGUE (2026-07-11; portão aberto pelo Diego, D-U1 descontinuar+remover, D-U2 os 8 de uma vez)**

**Fatia 1 EXECUTADA:** `rename <projeto> <arq:linha:col> <novo>` — o KIND vem
do FATO sob o cursor (papel estrutural do site + escopo declarado da função
dona), despacha ao `rename-*` específico por dentro com saída **byte-idêntica
por construção**. Peças: `ResolveAtQuery` ganha chaves aditivas `role`/`owner`
(zero mudança nos consumidores antigos); `ResolveRenameAt`/`FuncAtLine`/
`IsProjectFunction` classificam a posição nos oito alvos; `Rename` reconstrói
a argv exata e delega. Recusa nomeando a exceção em posição ambígua/sem fato
(D-U3, degrade honesto). Os oito `rename-*` ficam **descontinuados** no
`--help` mas funcionais nesta fatia (são o motor da delegação E o oráculo do
teste). Extensão 0.12.0: comando único "Rename Symbol" (estilo F2). Prova:
**caso 107** (29 checks). **Endurecido por DUAS rodadas de revisão externa
comparada (Codex gpt-5.5 + Claude) na mesma sessão.** A rodada 2 destravou um
FATO NOVO DO CORE: distinguir "nome que a diretiva vira CÓDIGO" de "símbolo
ligado num comando" é `'p'aste/'s'tringify × 'c'lone` — fato POR-MARKER que o
pp já tem. **Decisão do Diego: expor como canal do core (`ast-12`)** —
`hb_compAstMarkerGenerates` carimba `"generates": true` no recheio de marker
que gera (reverse-scan do `from`, puro no dump); o `ResolveRenameAt` lê o fato
e decide marker×binding. Fecha o cluster: mirror `REGISTRO Salva` (marker que
gera + LOCAL homônimo que a expansão fabrica → pp-marker, não local), Codex #2
(marker×local), #4 (dsl-word×local → dsl), #3 (chamada continuada por coluna),
#1 (duas statics homônimas → `--file`). Param de método (clone, em função de
nome gerado) segue `rename-param` — um flag "declaração gerada" o quebraria.
Suíte **797/0** byte-idêntica paralelo; **lexdiff 0 divergências reais** (o
canal ast-12 não muda pcode); rebuild harbour + hbmk2 (compast.c). § Revisão
da spec tem o placar das duas rodadas. Specs:
**[spec-u-verbos-unificados.md](spec-u-verbos-unificados.md)** +
**[adr-002-rename-unificado.md](adr-002-rename-unificado.md)**;
`generates`/ast-12 em [ast-schema.md](ast-schema.md). **O achado da operação
de derivação do pp (clone × paste/stringify) como FATO de resolução —
possivelmente arquitetural, com limites e perguntas em aberto honestos — tem
ADR próprio: [adr-003-derivacao-pp-como-fato.md](adr-003-derivacao-pp-como-fato.md).**
**Fatia 2 — ENTREGUE (2026-07-11, decisão do Diego "remover + dropar os
~13"):** a superfície pública dos oito `rename-*` foi REMOVIDA do `Main`/
`Usage` (as funções `Rename*` viram delegados internos do `Rename()`);
`rename-*` digitado à mão recebe redirecionamento honesto ("removido na fase
U; use `rename <arq:linha:col>`"). Harness migrado por FATO: **98 invocações
`rename-*`** → 76 viraram `rename <pos>` (a saída do delegado é idêntica, os
asserts ficaram), 9 oráculos do caso 107 viraram asserção **golden**, 1 (VAR
membro) migrada; **13 testes da INTERFACE removida DROPADOS** (cases 6/49
inteiros; parciais em 13/29/38/40/46/77 — ambiguidade de nome-cru que a
posição resolve, seletor, "não existe" sem posição). A migração destravou e
consertou um BUG do canal ast-12: um marker que só STRINGIFICA por
`#xtranslate` DENTRO de um comando (`? EVENTO x`) tinha o `from` do token
sobrevivente re-clonado pelo comando externo — o reverse-scan agora varre
também os tokens CONSUMIDOS das aplicações (que guardam a op original).
Extensão 0.13.0 (os 5 comandos por-kind removidos, só "Rename Symbol").
Suíte **782/0** (103 casos), lexdiff 0; rebuild harbour+hbmk2 (compast.c).
Registro completo da motivação abaixo (preservado).

**A pergunta, firme**: por que a CLI expõe OITO comandos de rename
(`rename-local`, `rename-static`, `rename-memvar`, `rename-param`,
`rename-function`, `rename-method`, `rename-dsl`, `rename-pp-marker`) mais
`extract-function`, `inline-local`, `reorder-params`? Para renomear, o
usuário precisa CLASSIFICAR de antemão o alvo — é local ou static? memvar
ou param? método ou função ou palavra de DSL ou marcador de pp? Isso é
justo o trabalho que **o compilador já fez** e que a ferramenta consome em
`usages --at` / `resolve-at` / `ResolveAtQuery` (Q5): dado um ponto, o
FATO diz o que o nome é. Fazer o usuário repetir essa taxonomia no sufixo
do comando é uma **réplica sintática na superfície da CLI** — o mesmo
anti-padrão que O NORTE proíbe no motor (sem ajuste por-caso; a fonte da
verdade é o compilador, não uma tabela de tipos remontada à mão, aqui na
UX).

**Proposta a avaliar**: colapsar para os verbos que descrevem a AÇÃO, não a
espécie do alvo — `rename <arq:linha:col> <novo>`, `extract`, `reorder` —
despachando pelo fato da árvore no ponto (a máquina do `resolve-at` já
existe e já é o caminho da extensão). O KIND deixa de ser escolha do
usuário e vira consequência do que está sob o cursor.

**Contra-argumentos honestos (para o portão, não varrer)**:
- Os sufixos explícitos são também um CONTRATO/salvaguarda: `rename` cego
  num ponto ambíguo poderia renomear a coisa errada em silêncio. Resposta
  proposta: degradar honesto — desambiguar/recusar nomeando a exceção
  (idioma já usado no SELF/dispatch), NUNCA adivinhar. Isso pode custar uma
  pergunta interativa que hoje o sufixo dispensa.
- Alguns comandos carregam semântica/flags próprias que o verbo único
  precisa PRESERVAR, não perder: `rename-function --edit-rules` (caso 74),
  `rename-pp-marker` genérico, `rename-dsl` de qualquer palavra do match
  (B4g). Unificar sem regressão dessas capacidades é o custo real.
- Scripts/harness (os ~565 casos) e a extensão chamam os nomes antigos —
  aliases retrocompatíveis ou migração registrada, decisão do Diego.
- Peso fraco a favor de manter separado: o sufixo é auto-documentado no
  `--help` e no shell-completion; um `rename` único esconde o alcance.

**Critério de pronto (executável, se o portão abrir)**: `rename
<arq:linha:col> <novo>` resolve o KIND pelo fato e produz saída
BYTE-IDÊNTICA ao `rename-*` específico correspondente, provado em casos
cobrindo os oito alvos (local/static/memvar/param/function/method/dsl/
pp-marker); ponto ambíguo ou sem fato degrada honesto (recusa nomeada, sem
adivinhação); capacidades por-flag preservadas sob o verbo; nomes antigos
viram aliases OU a remoção fica registrada em ADR; `extract`/`reorder`
recebem o mesmo tratamento se o fato os cobrir. Zero regressão na suíte.

---

## [arquivada] Fase P — investigação exaustiva do pp (ENCERRADA 2026-07-13)

### P — Investigação exaustiva do pp para refatoração — **EM CURSO (portão aberto pelo Diego, 2026-07-11; D-P0 U-2 antes, D-P1 dois eixos, D-P2 investigação+capacidade)**

**P1 — ENTREGUE (2026-07-11): veredito do genOp + o primeiro pedaço do GRAFO
(ast-13, genealogia de regra) com consumidores.** Spec:
**[spec-p-pp-refatoracao.md](spec-p-pp-refatoracao.md)**; a tese arquitetural
(grafo de transformação do pp, recomendações do Diego, oráculo `.ppo`/`.ppt`):
**[adr-004](adr-004-grafo-transformacao-pp.md)**. (1) Granularidade
paste×stringify (adr-003:82-86): `genOp` isolado recusado — a resolução usa o
booleano `generates` (casos 51/52/107), a predição já lê a distinção do rastro
`from`, stringify não exige `--force`. (2) Prova adversarial revelou a colisão
de homônimo (`? Vendas()` colhido por nome lexical); DUAS hipóteses minhas
caíram por execução (filtro `generates` quebra método — clone multi-passe;
"conserto por binding" era desnecessário) e **a visão do Diego venceu: o
conserto era completar o GRAFO**. (3) **ast-13 entregue**: genealogia de regra
(`from` nos tokens de match/result de regra GERADA — liga a regra à aplicação
criadora; `ppcore.c`/`hbpp.h`/`compast.c`) + derivação sobrevivendo ao clone
(`hb_pp_tokenClone`); consumidores: coleta de sementes v2 (gate de
pertencimento por fato), `genrule` na resolução (nome que VIRA regra =
pp-marker mesmo sem `generates`), verificação com renome opcional do nome cru
(`hOpt`). O homônimo deixou de ser degrade e virou rename CORRETO; o marker
que gera regra (`DEFREGRA <n> => #xcommand USA <n> => ...`) ficou renomeável
nas duas posições. Prova: **caso 108** (14 checks, fixture `fixgen`
não-espelho) + regras METHOD do hbclass real; suíte **796/0**, lexdiff 0,
zero drift nos 782 pré-existentes. Também fecha o miolo de **P6
"regra-em-expansão"** por antecipação. **Commits (core + ferramenta) pendentes
de autorização por-commit do Diego.**

**P2 — ENTREGUE (2026-07-11): "marker que gera E passa adiante" (adr-003:87-90)
FECHADO como o P1 — veredito + prova, sem canal novo.** A pergunta: um marker
`<n>` usado como GERADOR (paste `s_<n>` / stringify `<"n">`) E como PASS-THROUGH
(clone `<n>`) na MESMA regra — `generates` vence → `rename-pp-marker`; erra? A
investigação (método-oráculo `.ppo`/`.ppt`, portão em 2 rodadas, a 2ª a pedido do
Diego com os artefatos) provou que **não há corrupção silenciosa**: a segurança é
ESTRUTURAL — a rede dupla (recompilação `-es2` + símbolos/identidade do `.hrb`)
confere o ARTEFATO COMPILADO FINAL, indiferente à multiplicidade (o pp não põe
teto no nº de usos no destino — provado com paste×3 e paste×2+stringify×2) e ao
aninhamento (diretiva que gera `#xtranslate` nem registra; só `#[x]command`
gerado entra no grafo — o alcance do ast-13/108). Todo caso é rollback honesto OU
re-derivação verificada. Decisão do Diego: opção A (fechar como P1, sem `genOp`).
Entrega: fixture `tests/fixp2` (DSL inventada LOG/WRAP/SNAP) + **caso 109** (17
checks: re-target verificado, dois rollbacks, multiplicidade completa); suíte
**813/0** byte-idêntica, sem tocar o core/motor (lexdiff não requerido). O
REGISTRO é a entrega tanto quanto a prova (ordem do Diego): mecânica do pp e o
princípio estrutural em [spec-p § P2](spec-p-pp-refatoracao.md),
[adr-004](adr-004-grafo-transformacao-pp.md) e
[limites-e-alavancas.md](limites-e-alavancas.md).

A rodada 2 da fase U destravou a operação de derivação do pp
(`clone`/`paste`/`stringify`) como fato de resolução (ast-12, `generates`);
o [adr-003](adr-003-derivacao-pp-como-fato.md) registrou que o achado ABRE
perguntas — não fecha portão — e nomeou 6 eixos em aberto + o critério de
matar ("fato sem consumidor = fato local, não arquitetura"). Diego pediu
(2026-07-11) **investigar AO EXTREMO as possibilidades e limitações do pp
para refatoração**, aproveitando esses achados; a fase é **EXAURIDA antes de
avançar outras frentes ativas**. É o esgotamento sistemático: cada pergunta
aberta e cada fato que o `ppcore` sabe-e-não-exporta vira veredito provado —
capacidade, fato novo (`ast-N`) ou recusa honesta documentada.

**Decisões do portão (Diego, 2026-07-11):** **D-P0** — a fase U **fatia 2**
(corte da superfície pública dos 8 `rename-*` + migração do harness) fecha
ANTES, como pré-requisito. **D-P1** — DOIS eixos: pp como **FONTE DE FATO** (o
que o `ppcore` sabe e não exporta) E pp como **INSTRUMENTO** de reescrita (o
próprio pp do core como motor/oráculo; pode terminar em recusa, mas decidida
por prova). **D-P2** — **investigação + capacidade**: todo fato que sobreviver
à prova adversarial aterrissa como consumo mínimo na ferramenta + caso na
suíte (responde ao critério de matar do adr-003).

**Fatias** (ordem: U-2 → Eixo A P1–P6 → Eixo B P7 → Eixo C P8 → P9 → P10;
**P1 ✅ + P2 ✅ ENTREGUES (2026-07-11); P4 ✅ + P5 ✅ + P3 ✅ ENTREGUES
(2026-07-12)**):
- **Eixo A (fonte de fato):** P1 ✅ granularidade `paste`×`stringify`
  (adr-003:82-86, `genOp` recusado; `ast-13` foi para a genealogia);
  P2 ✅ marker que gera E passa adiante (adr-003:87-90, veredito estrutural,
  caso 109); **P4 ✅ + P5 ✅ os 15 mkinds EXAURIDOS (2026-07-12, caso 111,
  fixture fixmk)**: sintaxe de cada um tirada do PARSER; 13 com consumo provado,
  2 com recusa documentada — **a do `strdump` caiu em 2026-07-13** (é o `#<x>`, e o
  `std.ch` o usa em 6 regras; placar real: 14 consumidos, 1 recusado — só o `dynval`.
  Ver `pp-corpus/strdump.md`); `<@>` (reference) desvendado — é o GUARDA ANTI-RECURSÃO de
  regras circulares (ChangeLog do core 2010; uso real hbfoxpro.ch:63) e a
  ferramenta o preserva por construção. TRÊS consumos: `restrict` VALIDADO
  (recusa antes de editar, nomeando as alternativas — re-baseline do caso 82),
  `wild`/marker-não-usado separado de palavra-de-regra **POR FATO** (canal novo
  **`ast-14`** no core: todo marker de match é numerado, gated, `lexdiff` 0 —
  matou uma heurística de texto minha que o Diego pegou), `logical`/`nul`
  RELATADOS (valor descartado: não edita, avisa). Suíte 835/0;
  [spec-p § P4+P5](spec-p-pp-refatoracao.md); commit do core sob autorização.
  **P3 ✅ `generates` para `usages`/find-references ENTREGUE (2026-07-12,
  caso 112, fixture `fixgen/hom.*` reaproveitada do caso 108)**: achado
  adversarial provou que `usages --at` misturava um marker de pp com um
  símbolo homônimo do programa (`LABEL Vendas`, stringify, `generates:
  true`, sem dono × `FUNCTION Vendas()` real) — o mesmo blob de 4 hits em
  qualquer um dos quatro sites, porque `--at` calculava `role`/`generates`/
  `genrule` via `ResolveAtQuery` e os descartava (`src/hbrefactor.prg:425`),
  caindo no pipeline global por-nome de `usages <nome>` sem `--at`. Diego
  decidiu ESTREITAR (portão): `Usages()` agora consome esses três campos —
  `lAtPp` (site é mecânica de pp: `dsl`/`ppdiscard`/`ppmarker`+`generates`
  ou `genrule`) desliga as categorias que só casam por texto contra um
  símbolo DECLARADO; `lAtSym` (identificador comum OU `ppmarker` CLONE sem
  `generates`/`genrule` — o próprio símbolo atravessando um `#command`,
  ex. `? Vendas()`) desliga as categorias que só existem para achar
  mecânica de pp; `role == "method"` fica fora dos dois, intocado (já tinha
  filtro por `cClass`/`cOwnerQ`). `hAtPairs` (o fecho de derivação do site
  ESPECÍFICO clicado, exposto por `ResolveAtQuery` como novo campo
  `"pairs"`) restringe `PpMarkerHits`/`PpMarkerLift`/`PpMarkerSeeds`/
  `MethodImplOf` via parâmetro OPCIONAL (default NIL — zero impacto nos
  chamadores do `rename`) para não misturar OUTRA aplicação independente
  que colou o mesmo texto alhures (`MAKE Vendas`, regra diferente). Zero
  canal novo de core — tudo já existia no dump, só passou a ser consumido.
  `usages <nome>` sem `--at` fica byte-idêntico ao de sempre. Suíte
  **844/0** (835 + 9 checks), zero regressão nos casos 50/107-111.
  **Resíduo → ABSORVIDO pela fase A (2026-07-13):** artefatos derivados
  (paste/stringify) como `Location` estruturada no `--json` (item 2 do escopo
  original) — hoje só texto colado sob `--show-expansion`. Não era "quando
  doer": é o mesmo buraco do contrato de máquina (fase A.1).
  [spec-p § P3](spec-p-pp-refatoracao.md#eixo-a--p3-generates-para-usagesfind-references--entregue-2026-07-12).
  **P6 ✅ ESTRUTURA da regra ENTREGUE (2026-07-12, caso 113, fixture
  `fixp6` não-espelho)**: o miolo "regra-em-expansão" já caíra na P1
  (ast-13); os três restantes têm veredito. (a) **Regra sem cabeça**
  (`head: null`, match começa com marker — `ppcore.c:1161`): funciona
  **por CONSTRUÇÃO**, zero código novo — a ferramenta nunca chaveou no
  `head`, só em `marker == 0` e nas posições de `match[]`/`result[]`;
  resolve, lista e RENOMEIA (uso + regra no `.ch`, round-trip byte-exato).
  **Fecha o item 3 do backlog** com algo melhor que o "relato" que ele
  pedia. *(Corpus: zero regras sem cabeça em `include/`+`contrib/` do
  core — forma legal, ninguém usa.)* (b) **Opcionais reordenados**: o pp
  casa os grupos `[ ]` em QUALQUER ordem (e ausentes); a partir da linha
  INVERTIDA a keyword pega as duas ordens + a regra, o LOCAL que só
  atravessa resolve `rename-local`, o marker gerador prevê paste E
  stringify — nenhuma posição se perde (elas vêm do que o pp CONSUMIU,
  não da ordem declarada). (c) **Multi-passe**: o fecho de derivação
  atravessa as passadas (regra reaplicada sobre o resultado de outra);
  **limite honesto registrado** — palavra de DSL EMITIDA no result de
  outra regra não tem posição no fonte, e a ferramenta **recusa nomeando
  o motivo** em vez de editar só o visível. (d) **A guarda de órfão
  estava CEGA e foi consertada POR FATO** (achado ao sondar (b), mas
  geral): ela testava "grafia manual = token SEM `from`" e não via a
  grafia manual dentro de um comando — `? vk_Escudo()` passa pelo `?`
  (que é `#command` e CLONA), então o token chega COM `from`. Medido: o
  `--dry-run` **APROVAVA** um rename que o apply desfazia tarde com
  *"contagem de símbolos mudou"* (dry-run e apply DISCORDAVAM). O fato
  que separa já existia (ast-12: `clone` = grafia do usuário, orfanável;
  `paste`/`stringify` = texto FABRICADO = o artefato que o rename
  re-deriva) — a guarda passou a excluir por índice de ARTEFATO. Agora
  recusa antes de tocar no arquivo, nomeando o site, e dry-run == apply
  (mesmo padrão do `restrict`/P5). Suíte **866/0** (+22), zero core, zero
  regressão.
  [spec-p § P6](spec-p-pp-refatoracao.md#eixo-a--p6-estrutura-da-regra--entregue-2026-07-12).
- **Eixo B (instrumento):** **P7 ✅ VEREDITO PARTIDO (2026-07-12), decidido por
  execução — [spec-p § P7](spec-p-pp-refatoracao.md#eixo-b--p7-o-pp-do-core-como-instrumento--veredito-partido-2026-07-12)**.
  (a) **pp como ESCRITOR de fonte: RECUSA PROVADA.** Existe o instrumento que
  parecia salvar a ideia — **`-u`** (sem o command def set padrão) ISOLA de
  verdade: o pp aplica só as regras de migração e deixa o resto da linguagem em
  paz (`? "oi"` NÃO vira `QOut`). Mas o `.ppo` é **irreversivelmente
  destrutivo**: medido, 4 comentários → **0**, `#include` destruído, formatação
  normalizada. Guarda o código e SÓ o código. Colide com o contrato executável
  (caso 107 exige *"comentário com o nome velho INTACTO"*) e com a regra
  fundadora (**nunca editar o não-verificável**). Um canal que apaga comentário
  não pode gravar arquivo. (b) **pp como ORÁCULO: VIÁVEL — e uma perna JÁ ESTAVA
  EM PRODUÇÃO, só não nomeada**: o padrão-ouro do `rename-dsl` (*expansão
  idêntica → `.ppo` e `.hrb` byte-idênticos; diferença = rollback*,
  [hbrefactor.prg:5715](../src/hbrefactor.prg)). O pp é ótimo **calculador do
  QUE**, péssimo **escritor do ONDE**. (c) **Migração de DSL — desenho pronto,
  NÃO construída:** o pp computa o texto novo (`-u` + regra), a FERRAMENTA
  escreve por posição de byte (sites já posicionados em `ppApplications[]`),
  preservando comentário/formatação. Barrada por DUAS regras do projeto, não por
  dificuldade: é **verbo novo → portão D-P5 do Diego**, e o **critério de matar
  do adr-003** (*"fato sem consumidor = fato local, não arquitetura"*) — o
  isolamento por `-u` é fato novo mas **hoje sem cliente**.
- **Eixo C (editar a regra):** **P8 ✅ ENTREGUE (2026-07-12, caso 114)** — rename
  do nome de MARKER da regra. O `<n>` é **variável local da diretiva** (não vira
  símbolo; o `<n>` de outra regra é OUTRA variável), então: identidade =
  **(regra, NÚMERO do marker)**, nunca o texto — o conjunto de edição sai do
  `ast-5` (todo token com `role: "marker"` e o mesmo `marker: N`, dos DOIS
  lados), o que mantém match e result coerentes por construção (o `<"n">`
  stringify é o MESMO marker 1 do match). É um **ALPHA-RENAME**, e isso dá a
  verificação mais forte da ferramenta **de graça**: `.ppo` e `.hrb` byte-
  idênticos obrigatórios (nada pode mudar), usos intactos, round-trip byte-exato,
  colisão (fundir dois markers) recusada antes de editar. **O `.ch` deixou de ser
  inalcançável** — e aqui o Diego corrigiu um desvio meu: eu ia responder "de quem
  é este include" pelo DUMP (mais barato); a regra é **usar o canal correto, e
  estender o core se ele não der a informação**. O canal correto já existia:
  **`harbour -gd`** (dependencies list, `-sm` = mínimo), que dá o **caminho
  resolvido** (`inc/far.ch`, não o `far.ch` cru — resolução do CORE, a ferramenta
  não re-implementa busca de include) e o **fecho transitivo**. Armadilha achada:
  o harbour grava o `.d` **no CWD**, não ao lado do fonte — adivinhar deixava
  **lixo no projeto**; conserto `-o<tmp>`. `projects-of` num `.ch` agora responde
  o dono por fato, e a **extensão VSCode passa a funcionar com o include em foco
  sem código novo**. Suíte **882/0**, zero core.
  [spec-p § P8](spec-p-pp-refatoracao.md).
- **P9 ✅ ENTREGUE (2026-07-13): o custo do reverse-scan era QUADRÁTICO — medido,
  consertado no core, equivalência provada.** O adr-003:96-98 registrara o custo do
  `generates` como *"barato no dump de um módulo; um ponto a vigiar"*. A medição (a
  entrega desta fatia) desmentiu: `hb_compAstMarkerGenerates` respondia **por token
  consultado**, e cada resposta varria o fluxo de tokens inteiro E todas as
  aplicações → **O(markers × módulo)**. Módulo de **16k linhas expandidas: 69,30 s**
  de dump (contra fração de segundo para compilar); dobrar N quadruplicava o tempo.
  Conserto (`compast.c`): a resposta é propriedade do par **(aplicação, marker)** →
  o conjunto é construído **uma vez por módulo**, numa passada linear sobre as MESMAS
  duas fontes, e o token responde por lookup. **16k → 0,21 s (330×)**, e o
  crescimento virou **linear** (64k = 0,94 s). Sem canal novo, sem campo novo, sem
  mudança de semântica — e a prova disso é o ponto: os **847 dumps** do corpus (toda
  fixture + 6 módulos reais do core) saem **byte a byte idênticos** ao binário
  anterior. Suíte **961/0**, lexdiff 0. O que sobra é linear e dominado por escrever
  o JSON (64k linhas = 107 MB) — se doer, o alvo é o TAMANHO do dump, não mais a
  busca do fato. [spec-p § P9](spec-p-pp-refatoracao.md).
  **⚠️ DUAS CORREÇÕES no MESMO dia, ambas pegas pelo Diego. Registro completo porque é
  o mesmo erro, cometido três vezes seguidas: MEDIR O QUE EU ACHO, não o que roda.**
  **(1)** O 330× é do **stress sintético** (uma aplicação de pp por linha); ANUNCIEI que
  "16k linhas expandidas é tamanho de aplicação real" **sem medir** — invenção.
  **(2)** Ao re-medir "de verdade", montei uma tabela com TRÊS projetos — e **um deles,
  o `gtwvg`, NÃO COMPILA** (contrib Windows-only: `!win`, erro do compilador C). A
  ferramenta **RECUSA** o projeto; os 7,49 s que publiquei mediam um **comando
  abortado** (gera dumps, morre, não lê nada). Descoberto na fatia V-1, ao instrumentar
  a ferramenta: `ler+parsear = 0 ms`. **Por que eu fiz isso é o que importa:** depois do
  vexame do 330×, a tabela era a minha DEFESA (*"olha, desta vez eu medi"*) — e para
  sustentar a defesa eu precisava de volume, então enfiei um projeto sem conferir se ele
  passava. **A mentira voltou pela porta que abri para me redimir.**
  **A medição válida** (comando completo, projeto que compila, lê e analisa):
  **xhb, 43 módulos: 12,35 → 8,36 s** (~1,5×, um terço da espera); hbhttpd (3 módulos):
  1,16 → 1,07 s. A manchete "um terço" **sobrevive** — só a evidência podre saiu.
  **E a TABELA saiu dos anúncios (decisão do Diego, 2026-07-13, à pergunta *"pra que
  serve esta tabela publicada?"*):** ela não servia ao leitor (não é a máquina dele, nem
  o projeto dele, e ele não reproduz), servia **a mim**. É medidor — a mesma coisa que
  saiu das páginas, escondida numa superfície onde eu achei que passaria. Nos anúncios
  fica a AFIRMAÇÃO (linear; ~1/3 em código real; o catastrófico é patológico) + o
  **comando** para o leitor medir no projeto DELE. Número medido vive aqui e na spec —
  registro datado da entrega, não promessa viva ao leitor.
- **P10 ✅ ENTREGUE (2026-07-13): síntese — e a completude achou um BUG que teria
  matado a ferramenta.** (a) **O `adr-003` está FECHADO**: as 5 perguntas que ele
  abriu têm veredito, respondidas *pelo critério que ele mesmo fixou* — granularidade
  (booleano certo, `genOp` recusado, P1); marker que gera E passa (segurança
  ESTRUTURAL, P2); custo (era quadrático, P9); "descoberta ruim" (**passou no
  critério, e por pouco**: o 2º consumidor apareceu por BUG, não por elegância — o
  `usages --at` estava errado sem o fato, P3); e o **acoplamento**, cuja resposta
  inverte a pergunta — o medo era perder independência do pp, e a fase provou que
  **independência do core é o que PRODUZ réplica degradada** (cada desacoplamento que
  restava virou bug: `ast-15`, `ast-14`, a aritmética de colisão do P11, a busca de
  include do P8). (b) **`ast-schema.md` alcança o core** (título dizia `ast-14`).
  (c) **O BUG que a completude achou:** o canal `ast-16` entrou no core **sem
  versionar o `HB_AST_SCHEMA`** — o dump entregava os campos novos declarando-se
  `ast-15`, e o `NEWS`/página mandam o consumidor *conferir esse campo*: contrato
  mentindo. Ao consertar o número, a ferramenta **recusou o projeto inteiro** — o
  `ReadAst` tinha **lista ENUMERADA** de versões aceitas, que morre em silêncio a cada
  bump (e ainda mentia no diagnóstico: *"dump missing"*, com o dump no lugar). **Um
  esquecimento escondia o outro.** O `ast-schema.md` já registrara essa lição no bump
  `ast-8` ("portão usa VERSÃO MÍNIMA, NUNCA lista") e **abria exceção para o
  `ReadAst`** — a exceção era o bug. Conserto: core versiona (`ast-16`), leitor vira
  **PISO** (`AstAtLeast`), dump velho é dito com o nome certo. **Caso 122** guarda a
  régua (lista enumerada não volta). Suíte **965/0**, ppcorpus 42/0, lexdiff 0.
  **Commit do core pendente de autorização por-commit do Diego.**

**FASE P ENCERRADA (2026-07-13).** Saldo: 4 canais novos no core (`ast-13`..`ast-16`),
zero heurística nova na ferramenta, e três erros meus registrados com nome.
- **P11 — ENTREGUE (2026-07-12): o pp VIVO como oráculo; morre a última gramática
  replicada, e com ela um SEQUESTRO DE REGRA silencioso.** A API está mapeada e a
  **equivalência com o pp do build foi PROVADA** (mesma regra, mesmo site, mesmo
  texto — `make ppcorpus`). O limite honesto: **o pp destrói o que você ALIMENTA**,
  não "o arquivo" — a linha inteira entra e o comentário dela não volta; logo o
  escritor alimenta o **span da statement** (posições que o dump já tem) e grava só
  o span. Isso **confirma o Diego e derruba a minha recusa do P7** de vez.
  **Consumo (caso 116):** o `AbbrevClash` — que replicava a aritmética dBase do
  `ppcore.c` — foi substituído por uma **regra-sonda** perguntada ao pp. A réplica
  era degradada em 3 frentes (ignorava o TIPO do token; passava `"?"` como tipo da
  regra renomeada, desligando meia checagem; só via "uma cabeça é prefixo da
  outra") e escondia um furo **provado, não deduzido**: renomear uma cabeça para um
  nome que começa com 4+ letras da cabeça de outra regra **sequestrava** essa outra
  regra — e como ela podia não ter **nenhum site**, o `.ppo`/`.hrb` saía
  byte-idêntico e a ferramenta imprimia *"verified"*. Ambiguidade **latente**,
  silenciosa. Agora recusa-se **só o que o rename CRIA** (a ambiguidade
  pré-existente é do usuário — `MENUITEM`/`MENUBOX` já disputam `MENU` hoje) e a
  recusa exibe a **grafia-testemunha**. Completude sem constante mágica: varre-se
  **todo** prefixo do nome novo e o **pp** diz quais casam. Suíte **904/0**,
  `ppcorpus` **42/0**, **zero core** (o canal certo já existia — era só parar de
  replicá-lo). → [pp-corpus/pp-as-instrument.md](pp-corpus/pp-as-instrument.md) ·
  [pp-corpus/abbreviation.md](pp-corpus/abbreviation.md). **Pendente: o portão
  D-P5** (migração de DSL como verbo) — agora com o instrumento CERTO na mão.
  A fonte que derrubou a recusa do P7 foi apontada pelo Diego:
  [`tests/hbpp/hbpptest.prg`](../../harbour-core/harbour/tests/hbpp/hbpptest.prg)
  do core — o `hb_compileFromBuf` (fichado na [spec-b8](spec-b8-macros.md)) NÃO foi
  preciso: a fatia pedia o **pp**, não o compilador inteiro em buffer.
- **P12 — o pp como ENGENHO DE BUSCA (ideia do Diego, 2026-07-12)**: usar o
  casador do pp para **ACHAR**, não para transformar — busca estrutural, lint com
  regras do usuário, codemod. O trunfo não é técnico e sim de adoção: a linguagem
  de consulta seria a do `#xcommand`, que **todo programador Harbour já sabe
  escrever** — e quem casa é o casador do CORE, não uma réplica. Hipótese central a
  sondar: o canal de fato **já existe** (`ppApplications` + ast-13/14/15 dão site,
  posições e o que casou em cada marker); o que falta é **injetar a regra de
  consulta** — e uma regra **no-op** com o `<@>` (o guarda anti-recursão, já fichado
  no corpus) pode registrar a aplicação **sem alterar o código**. Se confirmar,
  a 1ª versão sai **sem mudança no core**. Plano de sondagem, usos candidatos e
  limites honestos: **[pp-corpus/pp-as-search.md](pp-corpus/pp-as-search.md)**.
  **NADA PROVADO AINDA** — o arquivo é plano, não registro.
  **CONSUMIDOR NOMEADO pela fase A (2026-07-13)**: a primeira coisa que um agente faz
  antes de editar é **PROCURAR** — e hoje ele grepa. Busca estrutural cujo casador é
  **o do core** é capacidade de agente por excelência. A fase A não executa a P12; ela
  responde a pergunta que a P12 deixava no ar (*"quem consome isto?"*).
- **P13 — 1º achado ENTREGUE: `ast-16` (2026-07-12, caso 117)**. A diretiva tem
  **tempo de vida léxico**, e o dump agora o exporta: a diretiva de **remoção** entra
  em `ppRules` como registro próprio (com `match[]` POSICIONADO, logo editável por
  posição), com **`undoes`** = id da regra que removeu (`null` = **órfão**, não
  removeu nada) e **`removed`** na regra que morreu. Caiu junto um **bug de schema
  pré-existente**: o modo de comparação era um BOOLEANO (`é x?`), então a família
  **`y`** (exata e case-sensitive) saía rotulada `"command"` — o dump **afirmava que
  uma regra exata casa abreviado**, e a sonda do P11 acreditaria nele. Agora o `kind`
  carrega a família como o pp a vê (`command`/`xcommand`/`ycommand` × `un…`).
  **O conserto do vazamento custou ZERO linha de lógica na ferramenta** — com o fato,
  a remoção virou "mais uma regra com aquela cabeça" e a maquinaria de rename por
  posição que já existia passou a editá-la sozinha. É a demonstração mais limpa da
  REGRA DO FATO na fase inteira. Core: `ppcore.c`, `hbpp.h` (os `HB_PP_CMP_*` viram
  públicos — a API de rastreio agora reporta o modo), `compast.c`. **`lexdiff` 0**,
  suíte **913/0**, `ppcorpus` 42/0. **Commit do core sob autorização.**
  → [pp-corpus/directive-scope.md](pp-corpus/directive-scope.md)
  **Resíduos (a explorar):** o escopo como MECANISMO (injetar regra → casar →
  remover) alimenta o **P12**; e o `#un…` órfão é fato SEM consumidor (diagnóstico de
  código morto).
- **P13 (registro do achado original)**: a sondagem rendeu DOIS achados provados
  antes de a fatia começar: **(a) BUG no hbrefactor** — o `rename` de cabeça de DSL ignora o
  `#un*`, deixa-o **órfão**, e a regra **VAZA** para além do ponto de desligamento
  (provado por `.ppo`: um uso depois do `#xuncommand` que era código CRU passa a
  EXPANDIR); a rede `.ppo`/`.hrb` **não pega**, o mesmo ponto cego do sequestro do
  P11. **(b) LACUNA DO CORE (`ast-16`)** — o dump **não exporta** o `#un*`: o
  `ppRules` traz só a regra criada, e a diretiva de remoção é **invisível**. O pp
  SABE (ele executou a remoção); o dump descarta — **a mesma omissão do `ast-14` e
  do `ast-15`, pela terceira vez**. Pela regra do Diego ("lacuna pausa e
  experimenta"), o conserto do bug **espera o `ast-16`**: procurar `#xuncommand` por
  TEXTO seria réplica de gramática (cega para as 6 grafias, para a abreviação
  `#UNCOMM` e para o `.ch` incluído). Usos que o escopo promove (a explorar): é o
  mecanismo de **injeção/remoção da regra de consulta** que faltava ao **P12**, e
  habilita codemod com escopo. → [pp-corpus/directive-scope.md](pp-corpus/directive-scope.md)
- **P-AUDIT — 1º achado ENTREGUE: `ast-15` (2026-07-12, caso 115)**. A varredura
  achou de cara **réplica de gramática + RECUSA FALSA**, o mesmo formato do bug do
  P5. `AbbrevClash` reescreve à mão a abreviação dBase do pp (regra real:
  `ppcore.c:2533`), e o `RenameDsl` a usava para **adivinhar por prefixo** se um
  literal consumido era "a minha palavra abreviada" — porque o dump só dizia
  `marker: 0` ("é literal"), nunca QUAL literal. Furo provado em 6 linhas: numa
  regra cuja keyword SECUNDÁRIA é prefixo de 4+ letras da CABEÇA, a secundária
  **escrita por extenso** era lida como abreviação da cabeça, e o rename da cabeça
  **recusava falsamente** (*"normalize para X"* num site já normalizado) — a cabeça
  daquela DSL ficava **irrenomeável**. Conserto onde o fato nasce: o pp PAREIA
  token-fonte com token do padrão ao casar e **descartava** o par do literal (a
  mesma omissão do `ast-14`, do outro lado); agora cada token consumido carrega
  **`ruletok`** = índice do literal no `match[]` da regra. Core: `ppcore.c` (gated
  por `fTrackPos`), `hbpp.h`, `compast.c` (**ast-14 → ast-15**). **`lexdiff` 0**,
  suíte **892/0**, `ppcorpus` 27/0. **Commit do core sob autorização.** Resíduo: o
  `AbbrevClash` segue vivo para a pergunta DIFERENTE ("o nome NOVO colidiria com
  outra cabeça sob abreviação?") — predição de casamento FUTURO, que o dump não
  responde; canal certo = perguntar ao pp (**P11**).
- **P-AUDIT (continua) — varredura anti-heurística (ordem do Diego, 2026-07-12)**: revisar o
  `src/hbrefactor.prg` inteiro atrás de código que (a) voltou a se apoiar em
  **heurística/inferência**, ou (b) pegou o **caminho mais barato** em vez de
  extrair a informação correta do core (estendendo-o quando preciso). O gatilho
  foi flagrante e é a régua: no P8 eu ia responder posse de include pelo dump
  porque era mais barato, quando o canal certo (`harbour -gd`) já existia — e no
  P5 o Diego já tinha pego uma classificação por COMPARAÇÃO DE TEXTO que virou o
  `ast-14`. Alvos conhecidos a auditar: `ResolveInclude` (re-implementa a busca
  de include do compilador — hoje inofensivo porque o dump já traz o caminho
  resolvido, mas é cópia degradada por design); qualquer casamento por texto onde
  exista número/id no dump; qualquer "se não é X, então é Y" sem fato que separe.
  Saída: lista site a site (arquivo:linha) com veredito — fato disponível, fato a
  criar no core, ou recusa honesta.
  **Fila NOMEADA (do catálogo de erros de 2026-07-12, CLAUDE.md § GATILHOS):**
  (i) `ResolveInclude` — re-implementa a busca de include do compilador (gatilho
  4); hoje inofensivo porque o dump já traz o caminho RESOLVIDO, mas é cópia
  degradada por design: ou morre, ou passa a consumir `harbour -gd`.
  (ii) ~~Resíduo do `AbbrevClash`~~ — **MORTO (P11, `c391408`)**. Ele reescrevia a
  aritmética de abreviação do `ppcore.c:2533` para prever casamento FUTURO ("o nome
  NOVO colidiria com outra cabeça?"). O `HeadClashWitness` agora sobe um **pp vivo**
  (`__pp_init`/`__pp_process`) e deixa o próprio preprocessador responder. Zero
  ocorrências de `AbbrevClash` no fonte — conferido, não lembrado.
  **Mas o `HeadClashWitness` ENTRA na fila no lugar dele:** ele varre os prefixos do
  nome novo apoiado numa propriedade que EU li do core ("toda grafia que casa uma
  cabeça é prefixo dela"). Quem julga cada candidato é o pp — mas a **completude do
  conjunto de candidatos** é raciocínio meu sobre o core, e isso é auditável.
  (iii) varrer os "se não é X, então é Y" (gatilho 3) e as comparações de texto
  onde o dump já tem número/id (gatilho 1).
  (iv) o **`#un…` órfão** (`undoes: null`, `ast-16`): fato disponível, **sem
  consumidor** — é código morto silencioso que a ferramenta poderia diagnosticar.
  (v) toda chave OPCIONAL do dump lida SEM `hb_HGetDef` (`marker`, `ruletok`, `from`,
  `col`, `undoes`) — acesso direto é `BASE/1132` em produção e a suíte não pega.

  > **A P-AUDIT é para uma SESSÃO DEDICADA E LIMPA** — o prompt está pronto em
  > [prompt-revisao-anti-heuristica.md](prompt-revisao-anti-heuristica.md). Não a rode
  > como apêndice de uma entrega: quem acabou de escrever o código é o pior juiz dele.

- **P-AUDIT — VARREDURA EXECUTADA (sessão dedicada, 2026-07-12)**: três achados
  **provados por fixture executável**, um passe explícito, uma hipótese registrada.
  **Nenhum precisa de extensão do core** — os três são fato JÁ disponível (dois deles
  já implementados no próprio arquivo) e apenas não consultado. Portão do Diego aberto
  para consertar (2026-07-12: *"coloque no roadmap para resolver e comece já"*).
  Ordem de conserto = risco:

  - **A1 ✅ ENTREGUE (2026-07-12, caso 119; suíte 942/0)** — **a fronteira do projeto era o
    CWD do processo** (`hbrefactor.prg` 3049 `RenameFunction --edit-rules`, 6157 `RenameDsl`,
    6466 `RenameRuleMarker`).
    O guard que promete "recuso editar include de sistema/compartilhado" pergunta só
    *"o caminho começa com `hb_cwd()`?"* — e erra nas DUAS direções, provado:
    (a) **recusa falsa** — o mesmo projeto, a mesma regra, invocado de outro diretório:
    `directive in '<proj>/menu.ch' outside the project directory`; (b) **autorização
    falsa, a que morde** — com `cwd = ~`, o `hbclass.ch` do CORE entra no plano de
    edição (`hbclass.ch:250:11`), e sem `--dry-run` o `hb_MemoWrit` grava. **A rede não
    salva**: ela confere `.ppo`/`.hrb` byte-idênticos DOS MÓDULOS DO PROJETO, e um
    rename consistente não muda expansão nenhuma → passa sem rollback → mutação
    silenciosa de um include compartilhado que quebra todo outro projeto da máquina.
    *Gatilho 6 (canal barato) + 3.* **Fato já disponível, e o predicado certo já existe
    no arquivo**: `DirAtOrAbove( cSpec, cAbs )` ancora no diretório do `.hbp` (é o que o
    `projects-of` usa) e `IncludeOwnedBy`/`ModuleDeps` respondem posse pelo `harbour -gd`
    (caminho resolvido, fecho transitivo). Ancorar no SPEC preserva o comportamento de
    hoje no caso normal (cwd = dir do projeto).
    **Como ficou:** `ProjectOwnsFile( hProj, cPath )` — o corredor é o diretório do(s)
    `.hbp` (união, quando o spec resolve para vários), sobre o `DirAtOrAbove` que já
    existia. Fixture `fixout/` (include **compartilhado fora** do diretório do projeto,
    mas **dentro** do cwd) + o rename-dsl do `fixdsl` invocado **de outro cwd** — as duas
    direções na suíte. Medido no binário de HEAD antes do conserto: ele editava o
    `shared/lib.ch` e dizia **`verified`**.

  - **A2 ✅ ENTREGUE (2026-07-12, caso 120)** — **o `removed` do ast-16 era fato SEM
    CONSUMIDOR → recusa falsa** (`RuleHeadCollision`, 2607; consumido por 5 verbos). Regra já morta por
    `#xuncommand` continua sendo tratada como viva: renomear um LOCAL para `PINTA`
    recusa (`collides with a preprocessor rule (#xcommand PINTA, y.ch:1)`) — e a
    mão-livre compila limpo sob `-w3 -es2`, porque a regra morta não captura nada.
    É a recusa falsa da classe do caso 115 (nome irrenomeável por uma regra que não
    existe mais). *Gatilho 3.* **Fato já no dump** (`removed: true`; o registro da
    remoção traz `file`/`line`; `undoes` liga os dois). A leitura honesta NÃO é "pule
    regra `removed`" — uma regra removida na linha 100 ainda captura na linha 50 —, é
    *"a regra está VIVA neste sítio?"*: decidível pela linha quando remoção e sítio
    estão no mesmo arquivo; onde a ordem não decide, a recusa conservadora FICA.
    **Como ficou:** `RuleDeadInModule( hAst, hRule )` — a regra é pulada **só** quando
    (a) traz `removed`, (b) o registro da remoção (o que carrega `undoes` com o id dela)
    mora **no arquivo do próprio módulo**, e (c) **nenhum token de fonte do módulo
    precede** a linha do desligamento (então a regra não viveu sobre código nenhum aqui).
    Fora disso — remoção em outro arquivo, ou código antes dela —, o fato não decide e a
    recusa fica. Fixture `fixlife/` prova os dois lados (módulo `dead` libera, módulo
    `alive` recusa).

  - **A3 ✅ ENTREGUE (2026-07-12, caso 120)** — **`RenameFunction` era o único verbo sem o
    guard de cabeça de regra** (2891; os outros cinco chamam `RuleHeadCollision`: 2128
    local, 2769 static, 3384 extract, 7007 memvar, 11538 method). Provado: `#xcommand
    PINTA <x>` + `rename Foo → PINTA` não recusava, o call site virava `PINTA( 2 )` e era
    CAPTURADO pela regra; a rede pegava (`the number of symbols/functions changed -
    rollback`) e restaurava. Dano: nenhum; custo: o usuário levava um erro de verificação
    em vez do FATO. *Omissão, não heurística.* Agora recusa nomeando a regra.

  - **A4 ✅ ENTREGUE (2026-07-12, caso 121, fixture `fixa4` não-espelho; suíte 961/0,
    ppcorpus 42/0, zero core)** — e o plano escrito estava **ERRADO**, o que só o probe
    mostrou. O plano dizia: as colisões do próprio `rename-dsl` tratam regra MORTA como
    viva, basta consultar o `RuleDeadInModule`. **Falso.** Três probes executáveis
    provaram que o `#un…` **remove por PADRÃO, não por cabeça, e ignora o `result`** — logo
    "a regra está desligada" **não licencia** renomear outra cabeça para o nome dela: se o
    padrão da regra renomeada casar o do `#un…`, a diretiva recém-renomeada **morre junto**
    e o site passa a expandir pela OUTRA regra. **Compila limpo — troca SILENCIOSA de
    semântica** (`aq_(1,1)` → `aq_(1,2)`). Consultar só a morte teria trocado a recusa
    falsa por um **aceite-que-desfaz** (a rede `.ppo`/`.hrb` só pega no apply), quebrando o
    `dry-run == apply` que o A2/P5/P6 conquistaram.
    **O fato que separa os dois casos é do CORE, e já existia**: `ast-16` (`undoes` = id da
    regra que a remoção tirou da mesa). `DelKillsRule` monta um módulo com as **duas
    diretivas REAIS** — a regra já com o nome novo + a remoção como está no fonte — compila
    e **pergunta ao dump quem morreu**. Não se compara padrão a padrão na ferramenta (seria
    réplica da busca de regra do pp), não se sintetiza grafia de teste (réplica da
    gramática), e **não se modela a ordem de registro do pp** — a pergunta é local, de duas
    linhas. *(Armadilha achada e evitada: sondar com **sentinela no result** MUDA a
    identidade da regra para efeito de remoção — o marker de match não usado no result é
    numerado diferente (`ast-14`) — e teria dado a resposta ERRADA.)*
    Fecha também o `HeadClashWitness` (sequestro reverso do P11) e o check de "match word",
    que também não liam o tempo de vida — e o **`#un…` órfão** (`undoes: null`) ganha
    consumidor: o `usages` da palavra o marca como `ORPHAN: removes no rule (dead
    directive)` — **relato, nunca edição** (o Harbour aceita o órfão em silêncio, e o
    programador acha que desligou a regra que segue VIVA).
    *(Achado de tabela: as 10 mensagens de `--dry-run` da CLI ainda estavam em PORTUGUÊS,
    apesar do commit que declarou o produto inglês — traduzidas.)*

  **Passa (registrado, não é achado):** `HeadClashWitness` — a completude do conjunto de
  candidatos é raciocínio sobre o core, e é VERDADEIRA (`hb_pp_tokenValueCmp`,
  ppcore.c:2704: só casa por prefixo no modo dBase, por igualdade nos demais; um witness
  casa as duas cabeças, logo é prefixo de ambas). Quem julga cada candidato é o pp vivo.
  **Hipóteses registradas (não consegui quebrar):** `ResolveInclude` — o dump já traz o
  caminho resolvido (`hb_pp_FileNew` reescreve `szFileName` para o caminho ONDE ABRIU,
  ppcore.c:2945-3060), então o fallback dos `-i` é código dormente; ou morre, ou consome
  `ModuleDeps`. Família `y` (case-sensitive, `HB_PP_CMP_CASE` = memcmp): a ferramenta
  uniformiza toda palavra de regra com `Upper()` e funde duas regras `y` que o core vê
  como distintas — erro fail-closed, sem quebra demonstrada.
  **Descartado COM PROVA:** `ProjectMember` por basename — o hbmk2 colapsa dois fontes
  homônimos no MESMO `.o` (link falha), então projeto com fontes homônimos não existe:
  o basename é único por FATO do builder, não por sorte.

**P-DOC — corpus exploratório/explicativo do PP (ESSENCIAL, ordem do Diego,
2026-07-11):** uma bateria de testes que casa diretivas REAIS do Harbour
(examples/, contribs/, os `.ch` do core — std.ch, hbclass.ch, box.ch, inkey.ch,
set.ch…) com seus `.ppo` (saída expandida) E `.ppt` (traço passo a passo), no
MESMO formato explicativo que a investigação P2 usou para explicar ao Diego:
texto técnico quando preciso, mas SEMPRE explicando também para o público-alvo
programador Harbour. **Objetivo:** entender A FUNDO o potencial do pp usando as
diretivas que já existem no ecossistema — o que cada diretiva real gera, como o
pp a transforma passo a passo, e o que a ferramenta consegue (ou não) refatorar
nela. Vira **fonte essencial de conhecimento do PP** (para o Diego, para o
usuário final e para as próprias fatias P). **Formato:** fixture por família de
diretiva + o par `.ppo`/`.ppt` anotado + a explicação bilíngue (técnica +
programador). Encaixa na fase P (alimenta Eixo A/fonte-de-fato e Eixo
B/instrumento) e no mapa do alcançável. **Spec + método:
[spec-pdoc-corpus-pp.md](spec-pdoc-corpus-pp.md); corpus vivo:
[pp-corpus/README.md](pp-corpus/README.md).** Método = os QUATRO oráculos (`.ppo` + `.ppt` +
ast dump + fixture COMPILÁVEL); suíte SEPARADA do contrato (`make ppcorpus`, não
`make test`) porque é exploratória E o core será estendido para gerar mais
informação durante a fase (permissão do Diego). **Organização (ordem do Diego):**
diretório `docs/pp-corpus/` — índice + UM ARQUIVO POR FAMÍLIA (o Claude do futuro
carrega só o que precisa; monolito estoura contexto). **Regra dura (Diego):** cada
LACUNA real (info que os oráculos NÃO dão) PAUSA a exploração e vira experimento
de core imediato; consumo-futuro (fato derivável) NÃO pausa. **Famílias 1-4
ENTREGUES (2026-07-11):** SET EXACT (restrict+smart-quote), @…SAY (grupos
opcionais), STORE (grupo que repete), hbclass (OO é pp: paste + genealogia ast-13
+ `Self AS CLASS`); `make ppcorpus` 16/16, contrato 813/0 intocado. **LACUNA
encontrada → experimentada → RESOLVIDA no mesmo dia (regra do Diego "lacuna pausa
e experimenta"):** o `rename` de DATA/VAR member de classe recusava; virou a
capacidade **rename-DATA** entregue (fatia 1, completude do rename-method, zero
core — ver backlog + [spec-rename-data.md](spec-rename-data.md); suíte 825/0).
Exploração do corpus RETOMÁVEL: próxima família na ordem = um contrib (medição).

**Portões pontuais a submeter durante a execução:** D-P3 (fato provado vira
`ast-N` OU fica computado do `from`?), D-P4 (restrict-validation e
rename-de-literal-da-regra são capacidades desejadas OU fato sem comando?),
D-P5 (se o Eixo B for viável, migração de DSL ganha verbo próprio?).

**Critério de pronto ("exaurida"):** cada uma das 6 perguntas do adr-003 com
veredito registrado; cada match-mkind e result-mkind com fixture provando
consumo OU recusa documentada no ast-schema; Eixo B com veredito provado; todo
fato sobrevivente com consumidor + caso na suíte (nenhum `ast-N` sem cliente);
passe de completude sem conceito de pp não exercitado; suíte verde
byte-idêntica + `lexdiff 0` por bump; régua do caso 64 em cada fixture nova.
Toda prova em **DSL inventada NÃO-espelho** ([revisao-generalidade.md:57-64](revisao-generalidade.md)).
**Fora do escopo:** nome de classe, macros (B8), herança (RE.6), colisão de
módulos homônimos. Spec dedicada a criar: `docs/spec-p-pp-refatoracao.md`
(molde da [spec-u](spec-u-verbos-unificados.md)). Plano detalhado salvo em
`~/.claude/plans/crie-um-plano-para-enchanted-flask.md`.

---

## [arquivada] Fase L — locais mortos (MORTA no dia em que nasceu)

### L — Locais mortos ~~por FATO (`ast-17` + verbo que remove)~~ — **MORTA NO DIA EM QUE NASCEU (Diego, 2026-07-13): o COMANDO SAIU**

Registro completo porque a fase inteira foi um **erro de julgamento meu, corrigido por
uma pergunta de duas linhas do Diego** — e o valor está em como ele chegou lá.

**O caminho.** (1) Fui propor **paralelizar** o `unused-locals` (fatia 3 da fase V): ele
dispara o compilador 43× em série. (2) O Diego perguntou ***"pra que serve o
unused-locals?"*** — e não servia: ele **raspa `stderr`** (`"W0003" $ cLine`) e só
**relata** o que o `-w3` já relata. (3) Eu então propus **fase L**: canal `ast-17` no core
(o compilador tem o fato num enum — `HB_VU_NOT_USED`/`HB_VU_INITIALIZED`/`HB_VU_USED`,
`hbcomp.h:112-114` — e o joga fora numa string) + um verbo que **REMOVE** o local morto.
(4) O Diego: ***"muito trabalho pra algo que o compilador já avisa"***. **Fase morta, e
o comando REMOVIDO** (CLI + extensão VSCode + manual + página).

**Por que ele está certo, e eu errado três vezes seguidas.** Meu instinto foi sempre
*salvar* o verbo — primeiro otimizando, depois "promovendo" a refatoração de verdade com
canal novo no core. Mas o valor do produto nunca esteve ali: o compilador **já avisa**, de
graça, em todo build com `-w3`, continuamente. Um canal de core + um verbo + um oráculo
próprio (o `.hrb` byte-idêntico **não serve**: remover código muda o pcode legitimamente)
é caro, e compraria... um aviso que o usuário já tem. **A pergunta certa não era "como
faço isto melhor?", era "isto tem de existir?"** — e ela veio dele, não de mim.

**E havia um footgun no fim do caminho:** `LOCAL lOk := SaveEverything()` — a variável é
morta, o *save* não é. Apagar a linha deixa código que **compila limpo, passa em tudo, e
parou de salvar**. Preservar o efeito (`SaveEverything()` como statement) era possível,
mas é exatamente o tipo de risco que não se assume por um ganho que é zero.

**O que FICA da fase, e vale ouro:** *(a)* a sonda do `-ge<mode>` (**dois** modos —
`0=Clipper`, `1=IDE`; **JSON de erro não existe**; o `--hbinfo` do hbmk2 é JSON de *build*)
— então **raspar texto de diagnóstico não tem alternativa boa: o canal certo seria o dump,
e o comando certo era nenhum**; *(b)* a régua: **superfície de produto que duplica o core é
peso, não capacidade** — a mesma família do "não existe compatibilidade" de hoje cedo.
*(c)* O `unused-locals` era o **único verbo que não tocava na AST**. Sintoma, não detalhe.

> **A sonda (a) virou item de fase (2026-07-13).** "JSON de erro não existe" é uma LACUNA DO
> CORE, e o `-ge<mode>` já ter dois modos torna o conserto uma EXTENSÃO de opção existente, não
> uma flag nova. Vive na **fase A.4** — com o veredito honesto de que **o hbrefactor é o
> consumidor mais fraco dele** (a ferramenta usa o compilador como oráculo binário e tira os
> fatos do dump). Quem o sustenta é o painel Problems, o agente do usuário, e o fato de ser um
> PR pequeno e não-controverso.

---

## [arquivada] B-infra, B9, RD, RD-c

### B-infra — suíte paralela ✅ ENTREGUE (Etapas 1 e 2) — narrativa no [arquivo](roadmap-fases-entregues.md)

Racional: [testes-paralelos.md](testes-paralelos.md). Etapa 1
(2026-07-07): pool bash por-caso, 109 s → 11-14 s (~8×). Etapa 2
(2026-07-08): runner em Harbour (`tests/parrun.prg` +
`tests/tcheck.prg`), python fora do `make test`, paridade
byte-idêntica nos dois modos.
### B9 — Tipos declarados impostos (`-kt`) + materializador `annotate` — ✅ ENTREGUE (fatias 1 e 2, 2026-07-08→10) — narrativa no [arquivo](roadmap-fases-entregues.md)

A fase-modelo da REGRA DO FATO: fato ausente → **estender o core** —
a anotação `AS <tipo>`/`AS CLASS` virou INVARIANTE imposta (fail-fast
sob `-kt`, cheque por NOME no objeto VIVO: cobre classes de runtime
que a estática nunca alcança) e o `annotate` fechou o ciclo virtuoso:
a máquina B7/B7b (dormente, RE.3) SUGERE → o comando ESCREVE
declarações da linguagem pela ESCADA (nível 1 fato puro; nível 2
one-liner `DECLARE`/`_HB_MEMBER`/`_HB_CLASS`; nível 3 SÓ relata) com
padrão-ouro por edição (inerte byte-idêntico sem `-kt` + compila limpo
+ roda sob `-kt`) e rollback → o `-kt` IMPÕE → o site decide por fato
(`confirmed declared` → `guaranteed`). Specs:
[spec-b9-anotacoes-impostas.md](spec-b9-anotacoes-impostas.md) (fatia
1) e [spec-b9-fatia2-materializacao.md](spec-b9-fatia2-materializacao.md)
(fatia 2); plano executado F2.0-F2.5:
[plano-b9-fatia2-escada.md](plano-b9-fatia2-escada.md); candidato (g)
de core ADOTADO (`b758cf376a`). Casos 87-96 (execução real; round-trip
por semente [FATIA-2]; ROLLBACK PROVOCADO com recusa nomeando o
BASE/3012); [testes-suspensos-re3.md](testes-suspensos-re3.md) Rotas
A/B **RECONQUISTADAS**; extensão VSCode 0.9.0; corpus hbhttpd: 31
declarações + 7 anotações verificadas, re-relatório DRENA (M-annotate
no [limites-e-alavancas.md](limites-e-alavancas.md)). Suíte **692/0**
byte-idêntica paralelo × `JOBS=1`; lexdiff limpo.

**Projeto já-`-kt` ENTREGUE (2026-07-10, escopo aberto pelo Diego)**:
o teste inerte compila baseline/pós-edição SEM a flag (`AnnNoKt`) — a
anotação sob `-kt` muda pcode por DESIGN (emite os cheques); caso 97:
quem já adotou `-kt` anota e o site coberto sai `guaranteed` direto.
Suíte **699/0** byte-idêntica paralelo × `JOBS=1`.

**Fatia 3 — materializador de param de bloco (2ª perna da Rota D) —
✅ EXECUTADA (2026-07-10, mesma sessão do portão; decisões do Diego:
D1 contrato espelho da Rota B, D2 fato de posição para TODAS as
declarações, D3 ambas as fontes)**:
**[spec-b9-fatia3-param-bloco.md](spec-b9-fatia3-param-bloco.md)** §
Executado — F3.1: âncora de escrita como FATO do dump (**ast-9**:
`nameLine`/`nameCol` = posição do token ESCRITO do nome; param de
bloco captura no parse via `HB_CBVAR`, padrão K1; ausente = param de
diretiva, inescrevível — honesto), zero impacto 230/230, adversarial
`LOCAL conta AS CLASS Conta` provado; F3.2/F3.3: balde `bp` do
`annotate` (sugestão pelo caminho de bloco da máquina dormente:
receptor-inline + união de Evals convergente) + escrita na âncora do
fato com registro `_HB_CLASS` quando a classe de runtime não é
conhecida do módulo; `AnnNameCol` (régua de unicidade) rebaixado a
degrade de dump antigo; F3.4: casos 98-100 fecham a Rota D nos itens
escrevíveis (detached, params q1 inclusive CONTINUADO, DSL
não-espelho JUNTO), venenos assertados, 89/97 re-baselinados só nas
contagens. Suíte **729/0** byte-idêntica paralelo × `JOBS=1`; lexdiff
limpo. q1:13/14 seguem suspensos com rota futura registrada
(anotação na regra da DSL / hbclass.ch no core). Commits do core sob
autorização.

### RD — Rota da diretiva (q1:13/14): tipo do receptor INLINE por FATO — ✅ **ENTREGUE (2026-07-10, mecanismo M-B; suíte 762/0)**

O furo que sobrou da B9 fatia 3 (fato 8): o `Self` gerado pela diretiva
`INLINE`/`OPERATOR`/`ACCESS`/`ASSIGN` do hbclass.ch NÃO tem token de
fonte, então os sends `::Msg()` dentro do bloco degradavam para
`possible` (q1:13/14 suspenso, caso 99). Alvo: o tipo do receptor
INLINE vira FATO de compilação, **nascendo genérico** (regra da DSL do
usuário; hbclass.ch = instância core). Experimento E0-E2 (2026-07-10):
**(E0)** gap = 2 params `SELF` (declLine 13/14) com `class:None`;
**(E2, empírico)** a ferramenta JÁ consome `type:'S'+class` num param de
bloco → `confirmed send (receiver declared AS CLASS MOEDA, codeblock)`,
ZERO mudança no consumidor (caminho vivo K2 do RE.5, TypeOf/DeclType);
**inércia** provada byte-idêntica sem `-kt`; **custo -kt** confirmado
(`__HB_CHKTYPE(Self,"S:MOEDA","MOEDA:SELF")` por Eval). O problema
colapsa em: preencher `type:'S'+class` no dump SEM o cheque `-kt`.
**Mecanismo M-B (canal dedicado, sem AS CLASS — escolha do Diego sobre
M-A/M-C)**: `bType` sentinela `HB_VARTYPE_INLINE_SELF` para "classe
fact-only" — flui `VarType→CBVAR→HVAR→pDecl` sozinho; `hb_compChkTypeGenCall`
(único emissor do cheque) pula o sentinela → cobre bloco simples E
estendido; `hb_compAstWriteType` mapeia sentinela→`'S'` só na escrita do
dump (E2 de graça); keyword `_HB_INLINESELF` no léxico (molde `_HB_SUPER`)
que hbclass.ch emite no `Self`, no-op sob `HB_CLS_NO_DECLARATIONS`.
Bônus: sem resolução de classe (linha hbmain.c:471 pulada) → sem W0025,
funciona até p/ classe de runtime não-registrada (DSL não-espelho).
**EXECUTADO (2026-07-10)**: 6 edições no core — sentinela
`HB_VARTYPE_INLINE_SELF` (hbcomp.h), keyword `_HB_INLINESELF` (complex.c),
`%token`+2 produções `BlockVarList` (harbour.y, bison regen 0-conflitos),
skip no `hb_compChkTypeGenCall` (hbmain.c), mapa sentinela→`'S'` no
`hb_compAstWriteType` (compast.c), os 4 blocos `INLINE`/`OPERATOR` +
no-op sob `HB_CLS_NO_DECLARATIONS` (hbclass.ch). Provas: **E1** dump
com `type:'S'+class` e `.c` `-kt` **byte-idêntico** ao original (zero
cheque); **E2** q1:13/14 = `confirmed` sem mudar a ferramenta (mesmo sob
`-kt`: confirmed, nunca guaranteed — fact-only); **E3** caso 105 novo
(DSL não-espelho fixself: FORGE/BELLOW/STOKE, receptor `oIt` gerado por
diretiva tipado só pelo canal — régua do caso 64); **zero-impacto** 43
módulos `-kt` M-B×original byte-idênticos; suíte **762/0**, lexdiff limpo.
Casos 86/99 re-baselinados (q1:13/14 `possible`→`confirmed`, portão do
Diego). Consumidor NÃO muda (canal declarado vivo, TypeOf/DeclType/K2).
Commits do core sob autorização por-commit. Rebuild: harbour E hbmk2
(libhbcplr). Fallback M-C (`AS CLASS` impõe) ficou desnecessário.

**Resíduos em aberto (fatias futuras da B9, portão de ESCOPO do
Diego)**: (1) anotação de PARÂMETRO de assinatura (colapsa em
`tokens[]`, pede o idioma `SigParamHits`; rendimento auto-escrevível
baixo hoje — param quase sempre é nível 3; o fato de posição da
fatia 3/D2 destrava a âncora se emitido para assinaturas); (2)
candidato (f) de core ADIADO (New implícito — protótipo como
coluna-delta quando reabrir); (3) execução controlada como 2ª FONTE
da sugeridora — **fatia 4 FECHADA (2026-07-10): F4.1+F4.2 entregues;
F4.3 (escrita) MORTA POR MEDIÇÃO (decisão do Diego sobre o M1b —
critério de matar acionado; spec na gaveta, padrão B8)**:
**[spec-b9-fatia4-execucao-controlada.md](spec-b9-fatia4-execucao-controlada.md)**
§ Executado — `exec-registry` entrega o retrato da tabela viva
(driver `-hbexe`+`-main=`, seleção 100% fato, proveniência por
chamada, flush por `EXIT PROCEDURE` contra QUIT do código executado,
schema `rtr-1` determinístico, zero edição no core; fixture fixreg +
caso 101; suíte **740/0** byte-idêntica). M1+M1b no
[mapa](limites-e-alavancas.md) (régua recalibrada: corpus = código do
CORE, regra no CLAUDE.md): casting raro no core bem escrito (rtl ~0%,
gtwvg ~1%, xhb ~0%; 38% do cls\*cast é tortura); classe invisível à
estática existe (escalares de startup do xhb) mas é nicho; registrador
paramétrico fica fora do alcance honesto — continuar/matar a escrita
(F4.3) é decisão do Diego sobre estes números.

### RD-c — Completude M-B: acessadores de DATA do hbclass + params no nó (ast-11) — ✅ **ENTREGUE (2026-07-11; suíte 768/0)**

A RD carimbou o `Self` gerado dos blocos `INLINE`/`OPERATOR`/`MESSAGE`,
mas deixou de fora os **acessadores de DATA** do dialeto Class(y)
(`VAR ... IN`/`IS`/`IS ... IN`/`IS ... TO`, hbclass.ch ~484-502): cada um
gera um getter `{|Self| Self:<msg>...}` E um `"_"`setter
`{|Self,param| Self:<msg> := param}`. Emitir o marcador `_HB_INLINESELF`
neles (8 blocos) foi **necessário mas não suficiente**: os dois blocos
caem na MESMA linha de fonte, e o consumidor degradava para `possible`
pela régua "dois blocos numa linha ⇒ a declaração do param é inatribuível
a um bloco só" (`B7BlockParam`, casamento por `declLine`). **Escolha do
Diego (portão, sobre relaxar-o-consumidor × aceitar-o-limite): numerar os
blocos no core** — que refinei para o mais direto: o nó `CODEBLOCK` passa
a carregar seus **próprios params tipados** no dump (`"params":[{sym,type,
class}]`, schema **ast-11**, compast.c dump-only lendo de
`asCodeblock.pLocals`). O consumidor tipa o receptor de um send pelo bloco
**EXATO** em que ele está (`hBlk["params"]`), sem casar por linha — a
ambiguidade some e resolve até o caso adversarial de dois blocos com
receptores de classes diferentes. Provas: **E1** dump com `"params"` +
`type:'S'`/class no `Self` (param sem tipo NÃO vaza classe); **E2** getter
E setter de `VAR nEcho IS nRaw` (2 blocos na linha 15) AMBOS `confirmed`,
mais a delegação via membro (`IS nCount TO oPart`, `Self:oPart` confirmed)
e o `oG:nRaw` de fonte; **custo-zero** `.c -kt` byte-idêntico (marcador ×
sem-marcador, mesmo nome de saída) — fact-only estendido aos acessadores;
**zero drift** (762 asserções antigas intactas — o caminho params-first
devolve o MESMO tipo que o antigo para bloco-único-por-linha); suíte
**768/0**, lexdiff 0 divergências. Fixture `fixdel` + caso 106 (formas do
CORE hbclass; a generalidade da rota já é do caso 105 com DSL inventada).
Consumidor lê `"params"` de QUALQUER nó de bloco — nada keyed a hbclass.
Rebuild: harbour E hbmk2 (compast.c → libhbcplr; sem regen de parser, não
toquei harbour.y). Commits do core sob autorização por-commit do Diego.

---

## [arquivada] Fase SITE-EX — suíte dos exemplos da página + CLI em inglês

### SITE-EX — suíte dos exemplos da página + CLI em inglês — ✅ **ENTREGUE (2026-07-12; suíte 923/0)**

**Escopo.** A landing page publicava transcripts **inventados** (`vendas.hbp`,
`billing.hbp`, classes `Payment`/`Logger` — projetos inexistentes) e uma saída de
terminal com números que nenhuma execução produziu. Entrega em três pernas:

1. **CLI em inglês** (decisão do Diego, 2026-07-12): ~380 literais de saída
   traduzidos, 48 asserções da suíte reescritas, extensão VSCode + o harness dela +
   `docs/manual.md` reacoplados (a extensão casava `/nenhum identificador/` e teria
   quebrado calada). Pré-requisito para a página poder exibir saída **verbatim**.
2. **Suíte dos exemplos** (`tests/site/`, `tools/site-examples.sh`): 10 exemplos,
   quatro portas cada (antes compila / exit esperado / depois compila / recusa e
   relatório deixam o fonte byte a byte intacto). `make site-examples` regrava os
   blocos por EXECUÇÃO; **`make site-check` FALHA** se a página divergir. Portão
   provado vivo (adulterar uma linha de transcript quebra o build). Contrato,
   cicatriz e como adicionar: `tests/site/README.md`; regra durável no CLAUDE.md.
3. **Conserto achado pela suíte**: `extract-function` dava **recusa falsa** em
   qualquer trecho com `SWITCH` — a guarda de salto só aceitava `for`/`while` como
   estrutura que cobre um `EXIT`, e o `EXIT` do `CASE` é do `SWITCH`. O fato já vinha
   do compilador (`blocks[]` exporta o kind `switch`); a ferramenta o ignorava. `LOOP`
   **não** entrou na lista (ele continua o laço externo e o salto é real). Caso 118 +
   fixture `tests/fixsw` travam os dois lados.

**Critério de pronto (atingido).** `make test` 923/0; `make site-check` verde nos
dois portões (indicadores medidos + exemplos executados); zero projeto inexistente
citado nos blocos gerados da página.

**Dívida aberta.** As seções profundas da página (rename de DATA, genealogia de
regra, tempo de vida de diretiva, sequestro por abreviação) ainda têm transcript
**colado à mão** — corretos hoje (rodados um a um), mas FORA do portão, e portanto
sujeitos ao mesmo apodrecimento. Migrá-los para `tests/site/` é o próximo passo.

---

## [arquivada] Fase A.2 — `snapshot`/`verify`, o oráculo exposto (2026-07-13)

*A fase A segue ATIVA no roadmap (A.1/A.3/A.4 em portão fechado); só a narrativa da
fatia ENTREGUE migrou para cá. O LIMITE do `CHANGED` e o "fica de fora" continuam no
roadmap — governam o resto da fase.*

#### A.2 — `verify`: o ORÁCULO EXPOSTO — ✅ **ENTREGUE (2026-07-13, portão aberto pelo Diego; caso 123, suíte 978/0)**

Duas chamadas, e a máquina que **já existia** passa a servir edições que a ferramenta **não
fez**: `snapshot <project>` grava a linha de base (pcode + cópia dos fontes); o agente edita à
vontade; `verify <project> [--rollback]` responde com **três vereditos** — `PRESERVED` (prova),
`CHANGED` (**ausência** de prova, com o DELTA) e `BROKEN` (erro objetivo, `--rollback` restaura
byte a byte). **O agente ganha liberdade sem ganhar impunidade.** Nada no core faz isso.

> **LIMITE, e é o CORAÇÃO do desenho:** identidade de pcode é oráculo **DE UM LADO SÓ**.
> **`PRESERVED` é PROVA; `CHANGED` NÃO é prova de quebra** — um `extract-function` legítimo muda
> o pcode. Ler "mudou" como "está errado" seria **chutar a intenção do autor** = heurística. Por
> isso o `CHANGED` **sai com exit 0** e **nenhuma palavra de reprovação** — e o caso 123 trava
> isso com uma régua textual (`! grep -qiE "wrong|incorrect|broke|invalid|failed"`).

**O `CHANGED` é a saída MAIS valiosa, não a pior.** Ele traz o **delta que o COMPILADOR viu**
(`pcode of MAIN changed`; `new function CALCULA`; `new symbol CALCULA`), lido do `.hrb` pelo
`HrbParse` que já existia. **Um diff de texto mostra linhas; isto mostra o que o compilador
entendeu que mudou** — o que nenhum LLM finge e nenhum grep dá.

**SONDA que derriscou a fatia ANTES de codar** (spec § 3.4): o pcode carrega número de linha
(`HB_P_LINE`), o que faria `PRESERVED` nunca disparar. **Não dispara porque a ferramenta já
compila com `-gh -l`** — e o `-l` suprime a informação de linha. **Já estava lá**: o oráculo é
insensível a formatação e sensível a semântica, por decisão anterior, não por sorte.

**CICATRIZ (o gatilho de basename, e eu caí nele).** Chaveei o snapshot pelo **texto do spec**
(`"app.hbp"`) — dois projetos homônimos em diretórios diferentes **liam a linha de base um do
outro**. É o **gatilho nº 5 do CLAUDE.md**, escrito e ignorado. Pego pelo caso 123d, cuja quarta
sub-fixture enxergou o snapshot da primeira. Chave agora é **caminho canônico** (`hb_cwd()` +
spec). *(Snapshot alheio é fato VELHO de outro programa — e agir sobre fato velho é o que esta
ferramenta promete nunca fazer.)*

**Fica de fora, honesto:** a relação de equivalência do `verify` é a **mais estrita** (identidade
byte a byte do `.hrb`). Os degraus mais frouxos que os verbos usam por dentro (`HrbEquivalent`
para rename; `HrbExtractCheck` para extract) **dependem de saber o que se esperava mudar** — e
numa edição que a ferramenta não fez **não existe expectativa**. Usá-los seria inventar intenção.

---

## [arquivado] Itens de backlog FECHADOS (limpeza de 2026-07-13)

Saíram do backlog do roadmap porque já têm veredito. Registro:

- **Rename de DATA/VAR member — ✅ ENTREGUE (fatia 1, 2026-07-11; lacuna achada
  pelo P-DOC e fechada no MESMO dia pela regra "lacuna pausa e experimenta").**
  O `rename` sobre `VAR nSaldo`/`::nSaldo` agora edita declaração + getter +
  setter, mapeia `NOME→novo` E `_NOME→_novo`, e recusa homônimo entre classes
  (unicidade). Completude do rename-method para DATA (sem comando novo), zero
  mudança de core. Spec: [spec-rename-data.md](spec-rename-data.md); provas: caso
  48 re-baselinado + caso 110 (fixdata); suíte 825/0. **Fatia 2 (backlog):**
  `ACCESS`/`ASSIGN` (getter/setter explícitos), DATA herdada de superclasse, e o
  `resolve-at` de `::membro` escopando a classe (rename a partir do site de USO).
0c. ~~**Velocidade em projetos grandes**: `-inc` já dá dumps incrementais;
   verificação proporcional à edição quando o uso real doer.~~ **PROMOVIDO a FASE V
   (Diego, 2026-07-13)** — deixou de ser "quando doer": está medido que dói (xhb,
   42 módulos: 8,36 s por comando, edite-se 1 linha ou 20). Ver a fase acima.
1. **Análise de programa inteiro (tipos interprocedurais)** — **PROMOVIDA
   para a fase B7 (2026-07-08)**, spec no portão:
   [spec-b7-tipos-interprocedurais.md](spec-b7-tipos-interprocedurais.md).
   Ponto fixo sobre os dumps com conjuntos finitos de classes — alavanca
   B do [mapa](limites-e-alavancas.md); nota de probe: RETURN vira `push`
   no dump mas SEM rótulo (D2 da spec propõe o gancho ast-6).
   **Fricção relatada (Diego, 2026-07-08, fixext)**: usages de `Deposita`
   mistura os sends de `oC` (Conta) e `oV` (ContaVip) — os 4 sends saem
   `possible (receiver unknown)` nas DUAS consultas e o peek junta tudo.
   A separação por homônimo nas definições/declarações JÁ funciona
   (caso 81: excluded com fato nos dois sentidos); o que falta é tipar o
   RECEPTOR dos sends. Alvo executável: com `oC := Conta():New()` /
   `oV := ContaVip():New()` no MAIN, a consulta `CONTAVIP:Deposita` deve
   excluir os sends de `oC` e confirmar o de `oV`, cada um com seu fato;
   receptor sem fato (parâmetro de fora, macro, `Self := oOutra` do
   próprio fixture) permanece possible — o contrato de 3 camadas fica.
2. **Evidência de execução — PROMOVIDA a fase D no portão
   (2026-07-08)**: spec própria com fatos re-auditados
   ([spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md));
   ver a seção da fase acima.
3. ~~**Regra sem cabeça** (`head null`, hbcompat legado): dump já registra;
   candidata a fixture de RELATO se um projeto real trouxer o caso.~~
   ✅ **FECHADO pela P6 (2026-07-12, caso 113)** — e com algo melhor que o
   relato que este item pedia: a ferramenta **resolve, lista e RENOMEIA** a
   regra sem cabeça **por construção** (nunca chaveou no `head`; opera em
   `marker == 0` e nas posições de `match[]`/`result[]`), com round-trip
   byte-exato. Zero código novo. *(Corpus: zero ocorrências em
   `include/`+`contrib/` do core — forma legal que ninguém usa, daí nunca
   ter aparecido.)*
