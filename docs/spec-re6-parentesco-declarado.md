# Spec RE.6 — parentesco DECLARADO como fato do core (exclusão de send reconquistada)

Status: **RASCUNHO — PORTÃO DE ESCOPO ABERTO PELO DIEGO (2026-07-10),
ROTA A ESCOLHIDA (spec com A recomendada; B fica no portão D1).**
Nenhuma linha de código nem edição do core até o Diego abrir o portão
sobre as decisões D1-D6 abaixo. Origem: gaveta **RE.6** do
[spec-re-reescopo-pos-revisao.md:276](spec-re-reescopo-pos-revisao.md)
("contratos genéricos de diretiva", resposta da Q3 da revisão) — a
perna concreta é o **furo dos homônimos** (caso 66, o caso ORIGINAL do
Diego), Rota C do
[testes-suspensos-re3.md:72](testes-suspensos-re3.md) (SEM-ROTA hoje;
candidata explícita: "RE.6 se o core expuser parentesco imposto/provado
por classe"). É a fase-modelo da REGRA DO FATO aplicada de novo: **fato
ausente → estender o core para o fato existir**, aqui o parentesco
entre classes, hoje inexistente no dump (fato 4 da B4f-2,
[ast-schema.md:810](ast-schema.md)).

## O que é

`usages Classe:Método` decide **excluded** num send `oR:M()` quando prova
que aquele send NUNCA despacha para `Classe:M`. Antes da RE.3 isso saía
por travessia do grafo "as-written" (ler a palavra após `FROM/INHERIT`
como pai) — **inferência**, morta pela REGRA DO FATO. Sobrou o degrade
honesto: `possible send (receiver class R, relation to C unknown)`
([hbrefactor.prg:9571](../src/hbrefactor.prg#L9571)). A **tipagem** do
receptor já voltou por fato (Rota A do catálogo: materializador escreve
`AS CLASS`, `-kt` impõe — caso 94); o que falta é o **parentesco como
fato** para a exclusão fechar.

A RE.6 dá esse fato: o `hbclass.ch` (core) passa a **DECLARAR a herança
pelo canal declared da linguagem** — um irmão posicionado de
`_HB_CLASS`/`_HB_MEMBER` (proposta: `_HB_SUPER`). O parente vira
promessa DECLARADA e fechada do autor (a MESMA natureza de todo tipo
declarado), não leitura por forma. hbclass é só o **primeiro cliente**:
qualquer DSL que queira exclusão declara parentesco pelo mesmo canal
(contrato de extensão da linguagem,
[ast-schema.md:770](ast-schema.md)). O consumidor volta a fechar a
exclusão — mas sobre arestas de FATO, com degrade honesto quando o
fecho abre, e rótulo NOVO (regra 1 do catálogo RE.3: nenhum assert
verbatim).

## O problema, em fato verificado

1. **O dump não tem canal de herança**: fato 4 da B4f-2 —
   [ast-schema.md:810](ast-schema.md) ("o canal não carrega
   superclasse"); [:691](ast-schema.md#L691) ("o `DECLARE` não carrega
   superclasse"). O grafo de classes do consumidor
   (`ClassGraph`/`hGraph[owner]["members"]`,
   [hbrefactor.prg:445](../src/hbrefactor.prg#L445)) carrega membros,
   não pais.
2. **"Pai = palavra após FROM" é leitura por FORMA, não fato** (Q4,
   caso 75 — [ast-schema.md:685-694](ast-schema.md#L685)): numa DSL o
   mesmo lugar carrega argumento que não é pai (provado com forjador
   passado por `@ref`, a mesma forma do pai do hbclass). Por isso um
   `_HB_SUPER` **emitido pelo core** (o hbclass afirma o parentesco na
   expansão) é fato; ler o token `FROM` do fonte do app não é.
3. **`-kt` impõe is-a, não classe exata** (T3, decisão do Diego
   2026-07-08 — [spec-b9-anotacoes-impostas.md:93](spec-b9-anotacoes-impostas.md#L93);
   helper is-a no objeto, :13). Consequência central: `oR AS CLASS R`
   admite um DESCENDENTE de R; a exclusão tem de raciocinar sobre o
   fecho de descendentes, não só sobre R. **Sem esse fato, o acerto
   próprio sozinho não fecha.**
4. **A regra do VM é fato** (classes.c, probes da B4f):
   [ast-schema.md:680-683](ast-schema.md#L680) — método PRÓPRIO vence
   herdado; conflito entre pais vence o PRIMEIRO da cláusula, em
   profundidade. É a semântica que o fecho declarado tem de reproduzir
   por fato (membros declarados + arestas `_HB_SUPER`), sem replicar
   `classes.c`.
5. **O canal declared já é reconhecido pelo compilador e chega ao
   dump**: léxico [complex.c:158-159](../../harbour-core/harbour/src/compiler/complex.c)
   (`_HB_CLASS`→`DECLARE_CLASS`, `_HB_MEMBER`→`DECLARE_MEMBER`);
   gramática [harbour.y:1259-1260](../../harbour-core/harbour/src/compiler/harbour.y)
   (`hb_compClassAdd`); os tokens fluem no stream `-x` e o consumidor os
   LÊ posicionados ([hbrefactor.prg:617-619](../src/hbrefactor.prg#L617)).
   Um `_HB_SUPER` engancha nas MESMAS três peças.
6. **O hbclass.ch já captura os pais posicionalmente na expansão do
   `CREATE CLASS`**: [hbclass.ch:233-244](../../harbour-core/harbour/include/hbclass.ch)
   — `<!SuperClass1!> [,<!SuperClassN!>]` casa os nomes ESCRITOS (usados
   em `@<SuperClass1>()`), e emite `_HB_CLASS <ClassName> <FuncName>` na
   :237. Emitir `_HB_SUPER <SuperClass1>[, <SuperClassN>]` logo ali
   carrega os tokens com a posição do fonte (a mesma propriedade que
   mantém `_HB_MEMBER`/`_HB_CLASS` posicionados).
7. **O consumidor já TEVE o fecho — foi removido, não inventado**: a
   RE.3 removeu `ResolveDispatchMsg`/`DispatchHijackers`/`ClassDescendants`
   (nota em [spec-re-reescopo-pos-revisao.md:230](spec-re-reescopo-pos-revisao.md#L230)),
   porque as arestas de parentesco eram por-forma. A RE.6 re-funda essa
   travessia sobre arestas de FATO; o código pré-RE.3 é arqueologia de
   git (estado pré em `git show 1aa95a8:`), não desenho novo — o que
   MUDA é a fonte das arestas + o degrade honesto + o rótulo novo.

## O caso concreto (caso 66 — o caso original do Diego)

[tests/fixdis/d1.prg](../tests/fixdis/d1.prg): `UWMain` e `UWSecondary`,
homônimas não-parentes, ambas com `Paint()`. `usages UWMain:Paint`:

- `oS:Paint()` (d1.prg:69/78, `oS AS CLASS UWSecondary`) DEVE sair
  **excluded** — UWSecondary DECLARA `Paint` próprio (own-hit) e não tem
  UWMain no fecho de pais → nenhum descendente de UWSecondary despacha
  `Paint` para UWMain (o próprio Paint de UWSecondary sombreia). Hoje:
  `possible ... relation unknown` (Rota C, SEM-ROTA).
- O espelho `usages UWSecondary:Paint` no `oM:Paint()` (d1.prg:68):
  simétrico.
- Compõe com o caso 94 (Rota A): a cópia materializada dá `oS AS CLASS
  UWSecondary`, `-kt` impõe, e SÓ ENTÃO a exclusão fecha por fato — a
  RE.6 acrescenta a segunda perna (a exclusão) à tipagem já reconquistada.

## Semântica da exclusão sob is-a (o coração — precisão e honestidade)

Consulta `C:M`; site `oR:M()` com fato de receptor `R` (declarado/`-kt`,
is-a). O send é uso de `C:M` sse puder despachar para o corpo que `C:M`
resolve. Sob is-a, `oR` é `R` ou um descendente de `R`. Logo:

> **excluded** vale quando, sobre o **fecho DECLARADO** (arestas
> `_HB_SUPER` + membros `_HB_MEMBER`, ambos fato do core), para TODA
> classe `X` que `oR` poderia ser (`R` e todo descendente DECLARADO de
> `R`), o dono-de-`M` mais próximo na MRO declarada de `X` é uma classe
> `O != C` — E `C` não é uma classe que `oR` poderia ser cujo dono-de-M
> seja `C` (i.e. `C` não é `R` nem descendente de `R` que herde `M` de
> um ancestral comum resolvendo em `C`).

Condição suficiente a implementar (tiers, do barato ao completo):

- **Tier 1 — own-hit + C fora do subgrafo de R**: `R` declara `M`
  próprio (`_HB_MEMBER M` em `R`) E `C` não é `R` nem descendente
  declarado de `R`. Então own-hit dá `R:M` para `R` e para todo
  descendente que herde; override em descendente gera 3º corpo, nunca
  `C:M`. Exclui. (É o caso 66: UWSecondary own-hit em Paint, UWMain fora
  do subgrafo.)
- **Tier 2 — herança resolvida no fecho**: `R` não declara `M` mas o
  dono-de-M na MRO declarada de `R` (e de cada descendente declarado) é
  `O != C`, com o fecho de ancestrais de `R` COMPLETO (nenhuma aresta
  `_HB_SUPER` escapa para classe ausente do dump).

**Degrade honesto (`possible ... relation unknown`, comportamento de
hoje) sempre que:** o fecho de ancestrais de `R` abre (pai escapa para
classe não-declarada/runtime antes de descartar `C`); existe descendente
declarado de `R` cuja MRO resolve `M` em `C`; ou `C` é/pode-ser
ancestral de `R` que forneça `M`. **Nunca excluded fora de fato.**

O rótulo carrega a ressalva do mundo fechado DECLARADO — é a mesma
natureza de promessa do `confirmed ... via declared types` (tipo
declarado é promessa; [ast-schema.md:792](ast-schema.md#L792)): a
exclusão vale DENTRO do grafo declarado; uma subclasse declarada FORA do
dump que ligasse `R` a `C` a quebraria, e é exatamente o que a ressalva
nomeia. Isso é dedução sobre FATOS declarados (arestas do core), não
heurística — mesmo estatuto epistêmico do confirmed.

## Desenho (fatias)

- **F6.1 — canal `_HB_SUPER` no core (parentesco declarado, posicionado,
  genérico)**: (a) léxico: keyword `_HB_SUPER` → token `DECLARE_SUPER`
  (padrão complex.c:158-159); (b) gramática: regra
  `DECLARE_SUPER IdentName [',' IdentName]... Crlf` que registra os pais
  no `pLastClass` corrente (o `_HB_CLASS` anterior), via campo novo na
  `HB_HCLASS` ou lista de pais (padrão `hb_compClassAdd`); (c) dump: os
  tokens já fluem no stream `-x` posicionados — o consumidor pode LER
  `_HB_SUPER Y` como lê `_HB_CLASS`/`_HB_MEMBER`; emissão estrutural
  extra (para a forma `DECLARE`) é sub-decisão (D2); (d) `hbclass.ch`:
  emitir `_HB_SUPER <SuperClass1>[, <SuperClassN>]` sob o `_HB_CLASS` da
  expansão do `CREATE CLASS` (hbclass.ch:237), no `HB_CLS_NO_DECLARATIONS`
  vira no-op (padrão das :138-140). **Zero impacto**: como `_HB_CLASS`/
  `_HB_MEMBER`, o marcador não muda pcode nem comportamento — prova
  byte-idêntica na árvore inteira (protocolo RE.4/K, `.hrb` base × fix
  sem `-x`).
- **F6.2 — consumidor: fecho declarado + exclusão de send por fato**:
  estender o nó de `ClassGraph` com `parents` lidos do fato `_HB_SUPER`
  (posicionado); re-fundar a travessia removida na RE.3
  (`ResolveDispatchMsg`/`DispatchHijackers`/`ClassDescendants`, git
  pré-RE.3) SOBRE essas arestas de fato + membros declarados; ligar em
  [hbrefactor.prg:9571](../src/hbrefactor.prg#L9571) o veredito
  `excluded send within the declared class graph (dispatches to O:M)`
  quando a semântica acima FECHA, `possible ... relation unknown` no
  degrade. Portão de capacidade por `AstAtLeast` do fato novo (lição do
  bump, K4), nunca lista enumerada. `--json`: excluded fora das
  `Location[]` (Json66/Json72 re-baselinados).
- **F6.3 — suíte + extensão**: reconquista dos sends da Rota C
  ([testes-suspensos-re3.md:87-99](testes-suspensos-re3.md#L87)) como
  casos NOVOS assertando o rótulo de FATO no MESMO site do fixture
  (fixtures intocados): caso 66 (d1.prg:69/78, o caso do Diego — compõe
  com a cópia materializada do 94), casos 61/72/84/85. Fixture DSL
  **não-espelho** que declara SEU parentesco pelo canal (`_HB_SUPER`
  equivalente na expansão da própria DSL) — prova de generalidade da
  revisão R (a exclusão volta com vocabulário da DSL, régua do caso 64).
  Venenos assertados: pai que escapa → `possible` honesto; descendente
  declarado que sequestra → `possible` nomeado; determinismo. Sem o fato
  (dump antigo/módulo sem `_HB_SUPER`): saída BYTE-IDÊNTICA à de hoje.
  `extension.js` re-verificada (o `usages` já é exposto; confirmar que o
  novo rótulo aparece).

## Decisões para o portão (recomendações marcadas)

- **D1 — rota do parentesco**: **Rota A (recomendada, escolhida pelo
  Diego 2026-07-10)** = canal declarado no core (`_HB_SUPER`), fato
  estático, sem tocar o contrato do `usages`. Alternativa documentada:
  **Rota B** = oráculo de runtime (exec-registry da fatia 4 lê
  `__clsGetAncestors`/`__clsMsgType`) — fato real, zero edição de core,
  mas faz o `usages` DEPENDER de execução/snapshot (mudança de contrato,
  irmã do "usages nunca consome a máquina"), é parcial (registro
  preguiçoso) e o M1/M1b já mediu seu rendimento como nicho. B não é
  escolhida; fica registrada.
- **D2 — shape do marcador**: **`_HB_SUPER <Sup1>[, <SupN>]`
  (recomendado**: distinto, posicionado, genérico; lista cobre herança
  múltipla na ordem da cláusula = a ordem que o VM resolve) × estender a
  forma de dois nomes `_HB_CLASS <Classe> <X>` (hoje `X`=FuncName —
  colidiria) × forma de lista dentro do `_HB_CLASS`. Sub-decisão: emitir
  também estruturalmente no dump (campo na classe) ou só deixar o token
  fluir no stream — **recomendado começar pelo stream** (o consumidor já
  lê `_HB_CLASS`/`_HB_MEMBER` de lá; menor cirurgia no compast.c),
  promover a campo se a forma `DECLARE` pedir.
- **D3 — agressividade do fecho**: **Tier 1+2 com degrade honesto
  (recomendado**: own-hit resolve o caso 66 e a maioria; Tier 2 fecha
  herança declarada completa) × só Tier 1 (mais conservador, deixa
  herança pura em `possible`). Em ambos, fora do fecho declarado =
  `possible`, nunca excluded.
- **D4 — rótulo**: **`excluded send within the declared class graph
  (dispatches to O:M)` (recomendado**: FATO novo, carrega a ressalva do
  mundo fechado declarado) — NÃO reviver `within the project's/written
  class graph` (assinatura da inferência, regra 1 do catálogo RE.3). O
  `possible` de degrade permanece o de hoje, sem nomear parentesco não
  provado.
- **D5 — genérico > hbclass (contrato, não opção)**: o marcador é da
  LINGUAGEM; hbclass.ch é o primeiro cliente. Prova adversarial
  obrigatória: DSL não-espelho que declara parentesco próprio e ganha
  exclusão pelos MESMOS fatos, rótulo no vocabulário dela (revisão R;
  régua: nenhuma palavra da DSL do fixture em `src/hbrefactor.prg`).
- **D6 — escopo do fecho**: **só classes DECLARADAS (fecho do projeto),
  degrade honesto (recomendado)** × misturar a tabela viva (fatia 4) —
  FORA: não mistura com a alavanca D nem com o exec-registry; a RE.6 é
  estática e fechada por declaração.

## Venenos e caveats

- **is-a abre polimorfismo** (fato 3): a exclusão SÓ fecha com o fecho
  de descendentes declarado; descendente que poderia sequestrar o
  dispatch para `C` → `possible` nomeado (espelho do pré-RE.3
  `descendant D of X may dispatch`, agora por fato). Fora do dump =
  ressalva do rótulo.
- **Pai que escapa do projeto/runtime**: aresta `_HB_SUPER` para classe
  ausente do dump → fecho aberto → `possible` honesto. Nunca excluded
  com ancestral incógnito.
- **Herança múltipla**: `_HB_SUPER` lista os pais na ORDEM da cláusula;
  a resolução respeita "primeiro pai vence em profundidade" (fato 4).
  Verificar TODOS os ramos antes de excluir.
- **Own-hit vs herdado**: `C` descendente de `R` que HERDA `M` de um
  ancestral comum resolvendo em `C` faz `oR:M` (oR is-a R, poderia ser
  C) SER uso de `C:M` — não excluir; é o teste que o Tier 2 tem de
  passar (não basta `R != C`).
- **Q4 — não ler `FROM` por forma**: o fato é o `_HB_SUPER` emitido pelo
  core, nunca o token `INHERIT`/`FROM` do fonte do app. DSL que não
  emite o marcador → `possible` honesto, JAMAIS exclusão errada. É a
  guarda de generalidade.
- **Zero impacto do marcador**: `_HB_SUPER` não pode mudar pcode nem
  diagnóstico (como `_HB_CLASS`/`_HB_MEMBER`); prova byte-idêntica
  obrigatória, senão a fatia para.
- **Não replicar `classes.c`**: a resolução consome FATOS (membros +
  arestas declaradas), reproduzindo a regra do VM sobre o fecho — não
  reimplementa o algoritmo de `__clsNew`. Fronteira igual à do
  `DispatchVia` pré-RE.3, agora alimentada por fato.

## Critério de pronto (executável)

- Caso 66 (d1.prg:69/78, o caso do Diego) decide `excluded send within
  the declared class graph (dispatches to UWSECONDARY:PAINT)` por FATO,
  sobre a cópia materializada do 94 (tipagem) + `_HB_SUPER` (parentesco);
  o espelho simétrico idem. Casos 61/72/84/85 reconquistam a exclusão de
  send.
- DSL não-espelho declara parentesco próprio → exclusão com vocabulário
  da DSL (generalidade R provada); nenhuma palavra da DSL em
  `src/hbrefactor.prg`.
- Venenos assertados em suíte: pai que escapa → `possible`; descendente
  que sequestra → `possible` nomeado; `-kt` is-a respeitado.
- Sem o fato (dump sem `_HB_SUPER`): saída e edições BYTE-IDÊNTICAS às de
  hoje (caso de regressão; `AstAtLeast` gateia).
- Zero impacto do `_HB_SUPER` na árvore inteira (`.hrb` base × fix,
  protocolo K); `make lexdiff` limpo.
- Suíte verde byte-idêntica paralelo × `JOBS=1`; extensão VSCode expõe o
  rótulo na mesma entrega. Commits no core sob autorização por-commit do
  Diego.

## Executado — F6.1 (2026-07-10, portão de execução aberto pelo Diego "com as recomendações")

**F6.1 ENTREGUE + ZERO IMPACTO PROVADO.** Canal `_HB_SUPER` no core:
- **Léxico** ([complex.c:160](../../harbour-core/harbour/src/compiler/complex.c)):
  keyword `_HB_SUPER` → token `DECLARE_SUPER` (irmão de `_HB_CLASS`/
  `_HB_MEMBER`).
- **Gramática** ([harbour.y](../../harbour-core/harbour/src/compiler/harbour.y)):
  `%token ... DECLARE_SUPER`; regra `DECLARE_SUPER SuperList Crlf`
  (ação só `iVarScope=NONE`, ZERO pcode) + não-terminal `SuperList`
  (lista de `IdentName`). **Bison 3.8.2: 0 conflitos** novos. `.yyc`/
  `.yyh` versionados regenerados (o gerador é idêntico ao committed —
  base-regen bate byte a byte; o diff grande é só renumeração de tabelas
  pela gramática nova).
- **hbclass.ch**: emissão plana na expansão do `CLASS` (`CREATE CLASS`
  reduz a `CLASS`) — `_HB_CLASS <Cls> <Fn> [; _HB_SUPER <Sup1>] [, <SupN>] ;;`
  (o separador `;` DENTRO do opcional — senão classe SEM herança ganha um
  `;` espúrio, token type 30, que perturba o stream); no-op sob
  `HB_CLS_NO_DECLARATIONS`. `[ [ ] ]` aninhado no RESULT é proibido
  (E0018) — optionais IRMÃOS, como o `[ @<Sup1>() ][ , @<SupN>() ]` da
  :244.
- **O fato chega posicionado**: `hb_compAstToken`
  ([complex.c:519](../../harbour-core/harbour/src/compiler/complex.c))
  grava o token CRU antes da classificação de keyword → `_HB_SUPER`
  (prov `i`, linha do macro) seguido do(s) pai(s) com **prov `s`, linha/
  col da cláusula `FROM`/`INHERIT` do APP** (herda.prg: `Animal` L22 C25;
  multi `Animal, Robot` L36 ambos posicionados na ordem da cláusula).

**Zero impacto (pcode) PROVADO**: `.hrb` base+base-hbclass × fix+fix-hbclass
(sem `-x`), corpus 365 (`work/tests`+`work/rtl`+fixtures de classe, 64
com `CREATE CLASS`, 23 com `INHERIT`/`FROM`): **356 byte-idênticos, 0
divergências de pcode** (9 não-compiláveis standalone iguais nos dois).
O `_HB_SUPER` não muda uma linha de pcode.

**LIÇÃO DE TOOLCHAIN (custou o diagnóstico das 95 falhas)**: DOIS
binários embutem o compilador — `harbour` E **`hbmk2`** (`nm hbmk2`
mostra `hb_compClassAdd`/`hb_comp_yylex`; hbmk2 compila via `-hbcmp`
built-in). Rebuildar só o `harbour` deixou o hbmk2 com a gramática BASE
→ a suíte (que builda/dumpa via hbmk2) rejeitava o `_HB_SUPER` da
hbclass fix (`syntax error at 'UWMAIN'`) → **655/95**. Rebuildar hbmk2
(`make -B -C utils/hbmk2`, relinca `-lhbcplr` fix) → **750/0**. Regra:
`HB_REBUILD_PARSER=yes make -C src/compiler` + `make -B -C src/main` +
`make -B -C utils/hbmk2`.

**CONSUMIDOR ROBUSTO (achado que desimpede a F6.2)**: com o toolchain
completo, a suíte é **750/0** e o `make lexdiff` dá **0 divergências
REAIS** — os consumidores EXISTENTES (`usages`/`rename`/`extract`) são
robustos aos tokens `_HB_SUPER` novos E ao shift de +1 nas linhas prov
`i` do hbclass.ch (eles casam `_HB_CLASS`/`_HB_MEMBER` por texto e
ignoram o resto; leem posição de prov `s`, não de prov `i`). F6.1 é
fundação limpa e não-quebradora; a F6.2 só ACRESCENTA a leitura do
`_HB_SUPER` para a exclusão. (Nota: baseline atual = **750** checks; o
`740` do roadmap/exec-registry precede os casos 102/103 de projects-of,
commit `bc4645d`.)

Change-set do core (5 arquivos, sob portão de commit por-commit do
Diego): `complex.c` (+1), `harbour.y` (+12), `hbclass.ch` (+1/-1),
`harbour.yyc`/`harbour.yyh` (regen). Nada commitado.

## Executado — F6.2 + F6.3 (parcial) (2026-07-10)

**F6.2 ENTREGUE — a exclusão de send por FATO de parentesco.** Schema
`ast-10` (compast.c, gate `AstAtLeast(10)` - dump pré-ast-10 degrada
honesto). Consumidor (`src/hbrefactor.prg`): `ClassSuperFacts` lê
`_HB_SUPER` do stream de tokens (sequencial como o compilador: `_HB_CLASS`
muda a classe corrente, `_HB_SUPER` declara os pais na ordem da cláusula);
o nó do `ClassGraph` ganha o campo `super` (o by-form `parents` do Q4
segue intocado, gateado por `DispatchVia`); `ResolveDispatchSuper`
resolve M por FATO (próprio > super na ordem, 1º hit vence = regra do VM);
`SuperDescendants` dá o fecho is-a; `KinshipExcludes` exclui SÓ com dono
CONCRETO decidível != consultada E nenhum descendente que escape (NIL) ou
alcance a consultada. Ligado no `SendVerdict` (rótulo
`excluded send within the declared class graph (dispatches to O:M)`, fora
das `Location[]`). **Verificado correto** em: own-hit (66), override
(67), herança que herda a consultada → possible (67), herança múltipla
1º-pai (68), cadeia indecidível não afeta a decl (70), is-a com
descendente que sequestra → possible (68 ha.log), DSL por own-hit (72).

**F6.3 re-baseline ENTREGUE** (drift PRÉ-existente apresentado e
autorizado pelo Diego, 2026-07-10): 16 asserts dos casos 66/67/68/70/72/
92/94 e os validadores `Json66`/`Json72` do tcheck migrados para o rótulo
de FATO (a Rota C do catálogo RECONQUISTADA).

**F6.3 GENERALIDADE ENTREGUE (caso 104)**: fixture `fixkin` (DSL inventada
`kin.ch` - `SPROUT`/`OFFOF`/`BUD`, vocabulário próprio) declara o
parentesco SÓ pelo `_HB_SUPER` - o nome do pai vai como STRING para
`KinMake`, NUNCA como identificador na linha da função, então a leitura
por-forma do Q4 não o alcança. Prova adversarial do canal: na consulta
`Rogue:Show`, `oKid:Show()` sai `excluded (dispatches to BASE:SHOW)` SÓ
porque o `_HB_SUPER Base` da DSL prova a herança (sem ele, super vazio →
possible); e `oKid` herdando de `Base` é uso REAL na consulta `Base:Show`
(não exclui). hbclass é só o PRIMEIRO cliente do canal. Extensão: sem
mudança (o `usages --json` já deixa o excluded fora das `Location[]`,
flag `.T.` - o "find references" não lista). Venenos cobertos: pai que
escapa (69), descendente que sequestra (68 ha.log). CHANGELOG atualizado.
Suíte **757/0**; `make lexdiff` 0 divergências reais. Commits: core
`c2c26e5aa3` (F6.1) + `b07fef4060` (ast-10); consumidor+re-baseline
`6df5c50`; generalidade (fixkin+caso 104)+CHANGELOG sob portão.

## Fora do escopo

- Rota B (oráculo de runtime) e qualquer mistura com o exec-registry
  (fatia 4) ou a alavanca D — a RE.6 é estática e fechada por declaração.
- Reativar `B7Ctx`/inferência no veredito do `usages` (regra do catálogo
  RE.3; a máquina segue insumo do materializador).
- Reviver rótulos verbatim pré-RE.3 (`within the project's/written class
  graph`, `via construction chain`) — regra 1 do catálogo.
- q1:13/14 (param gerado por diretiva sem token escrito) — segue na sua
  rota (anotação na regra da DSL / hbclass.ch), ortogonal a esta fatia.
