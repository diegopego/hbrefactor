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

### Fase B2 — Comandos re-assentados sobre a AST (EM ANDAMENTO)

> **Status 2026-07-05**: 10 comandos vivos na segunda encarnação
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

**(b) `extract-function <proj> <arq> <ini>-<fim> <nome> [--dry-run]`**
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

**(c) `--json` (casos 18/26)**: `usages --json` já emite LSP Location[];
  re-validar contra os asserts python dos casos 18/26 do run.sh antigo.

**(d) run.sh da segunda encarnação**: reescrever tests/run.sh dirigindo a
  ferramenta nova (mesmos comportamentos; números de caso preservados onde
  fizer sentido; casos novos: multi-linha do reorder, span/continuação do
  rename-function). `make test` volta a ser o contrato executável. Remover
  o modo degradado da era occ que não existe mais (cobertura parcial fica
  para quando um projeto real quebrado voltar ao escopo).

**Critério de pronto da fase**: `make test` verde completo com o run.sh
novo; ida-e-volta byte-exata dos renames; dogfooding no hbhttpd (usages +
1 rename por comando); TokenScan/LineWords/ParseParenSpan/StructureCheck/
StmtEdits ausentes do fonte novo (já verdade hoje).

### Fase B3 — Poderes novos

**Escopo**: reorder-params multi-linha (spans reais de argumentos);
inline-local (árvore de expressão + análise de pureza).
**Critério**: fixtures de comportamento (execução idêntica) + recusas; checks
novos na suíte.

### Fase B4 — DSLs customizadas de pré-processador (caso especial, análise registrada)

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

**Critério de pronto da fase**: fixture com a DSL acima (REPEAT/UNTIL +
MENUITEM) num mini-projeto ≥2 .prg + .ch: `usages-dsl` lista definição e
aplicações com colunas; `rename-dsl MENUITEM MENU_ITEM` edita .ch + usos e
verifica `.ppo`/`.hrb` byte-idênticos; seleção de extract cortando REPEAT é
recusada; **`usages Paint` numa fixture com classe responde no vocabulário
método/classe (lifting provado)**; suíte verde.

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

### Fase B5 — Extensão VSCode re-apontada

**Escopo**: a extensão é fina (CLI faz tudo) — ajustar specs/saídas ao novo
CLI; manter os 9 comandos; preview `--dry-run --json` se a fricção pedir.
**Critério**: Diego usa no dia a dia; sem regressão nos fluxos atuais.

### Fase B6 — PR upstream (bloqueada: só quando o Diego mandar)

**Escopo**: mensagem com consumidor real; 1 arquivo novo + ganchos opt-in;
prova de zero impacto (árvore inteira com/sem `-x`, binário idêntico ao
master, macro build no-op); regen bison 3.8.2 documentado; split opcional em
2 PRs (pp-posição; módulo AST). ChangeLog via `bin/commit.hb`; uncrustify.

---

## Backlog (herdado + novo, por valor)

1. **Velocidade em projetos grandes**: `-inc` do hbmk2 já dá dumps
   incrementais na Fase B1; verificação proporcional à edição (compilar só o
   alvo) fica para quando o uso real doer.
2. **rename-define**: ABSORVIDO pela Fase B4 (DSLs de pré-processador) — o
   `#define` constante é o caso degenerado de regra sem markers. Caso de
   estudo herdado: regra `( x & y ) => HB_BITAND` de um hbcompat.ch legado
   que sequestra `!&(...)` — vira fixture de recusa/aviso da B4.
3. **rename-method**: exige nomes de mensagem de `__clsAddMsg` (declaração
   METHOD é invisível — nome viaja como string); avaliar se entra no ast-1
   ou num ast-2. hbhttpd (CREATE CLASS) é o alvo de teste.
4. Dedup de duplicatas de pré/pós-decremento: não-fazer mantido (v2).
5. **Projetos grandes de produção** (quando o Diego liberar): dogfooding
   final e conversões de projeto — só depois de suíte + hbhttpd verdes.
