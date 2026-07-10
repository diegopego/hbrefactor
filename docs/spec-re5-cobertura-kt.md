# Spec RE.5 — cobertura completa do `-kt` (blocos, detached, fato de cobertura no dump)

Status: **K1-K4 EXECUTADAS (2026-07-10, mesma sessão do portão);
K5 MEDIDO → recomendação FORA; K6 FORA.** Resultados por fatia no fim
desta spec. Commits no core seguem um-a-um sob autorização. Regra do
roadmap cumprida: escopo + critério escritos ANTES da execução.
Origem: matriz de cobertura do RE.1
([spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md)) e
Rota D de [testes-suspensos-re3.md](testes-suspensos-re3.md).

## O que é

A fatia 1 da B9 impõe anotações em TRÊS pontos (prólogo de parâmetro de
assinatura, pós-store direto de local, RETURN de função DECLAREd). A
matriz do RE.1 nomeou os furos; o RE.2 parou o overclaim do consumidor
(`B7KtCovered` nega o selo nos sites não cobertos). Esta fase devolve
ALCANCE: estende a emissão no core para os furos que valem a pena e —
peça de doutrina — **substitui a réplica da matriz na ferramenta por
FATO de dump** (o core, que emite o cheque, passa a DIZER onde emitiu).

## Fatos verificados no fonte (2026-07-10, core `00ccbc20b3`)

1. **Emissor único e stack-neutral**: `hb_compChkTypeGenCall`
   (hbmain.c:2758-2782) — `PUSHFUNCSYM __HB_CHKTYPE + PUSHLOCAL iVar +
   2 strings + DOSHORT 3`; "legal at any opcode boundary". Chamadores:
   prólogo de assinatura (`hb_compChkTypeParams`, hbmain.c:2788,
   chamado de harbour.y:332/334), pós-store (hbmain.c:2877-2879) e
   RETURN wrap (`hb_compChkTypeRetWrap`, hbmain.c:2805, de
   harbour.y:433).
2. **O guard do pós-store exclui blocos DE PROPÓSITO** (fatia 1):
   `iScope == HB_VS_LOCAL_VAR && functions.pLast->szName` — dentro de
   bloco o escopo é `HB_VS_CBLOCAL_VAR` e `pLast` é a pseudo-função do
   bloco (`hb_compFunctionNew(NULL,...)`, hbmain.c:3754 — `szName ==
   NULL`). O comentário da fatia 1 declara o recorte ("assignments
   inside codeblock bodies stay out of this slice").
3. **Bloco é pseudo-função com prólogo natural**: params de bloco viram
   locals da pseudo-função ANTES do corpo, em DOIS caminhos — inline
   (`hb_compExprCodeblockPush`, include/hbexprb.c, loop
   `hb_compVariableAdd`) e estendido (harbour.y:1060). A precondição do
   `hb_compChkTypeParams` ("pLocals holds exactly the formal
   parameters") vale NESSES pontos — o prólogo de bloco é REUSO direto.
4. **A classe do param de bloco morre DUAS vezes** (mecanismo do A6):
   o parse descarta `szFromClass` (harbour.y:1024-1025 passam só
   `$2->cVarType`; `HB_CBVAR` nem tem o campo — hbcompdf.h:109-115) e
   as DUAS materializações passam `NULL` (`hb_compVarTypeNew(...,
   pVar->bType, NULL)`). Com tipo 'S' e classe NULL,
   `hb_compVariableAdd` → `hb_compClassFind(NULL)` (hbmain.c:475) →
   `strcmp(pClass->szName, NULL)` (hbmain.c:1083) → **SIGSEGV** quando
   o módulo conhece classes (A6, repro mini2.prg do RE.1); sem classes
   no módulo, W0025 imprime `Class '(null)'` e degrada para 'O'.
5. **Escrita via `@ref` não tem site sintático no callee** (o pop é do
   parâmetro do CALLEE, probe3 do RE.1); a única âncora sintática é o
   CALLER (`F( @x )` é visível na chamada — re-cheque pós-call).
6. **`PARAMETERS x AS`** gera `POPMEMVAR` sem cheque (hbmain.c:2904;
   caminho `MemvarList`, harbour.y:1229) — anotação entra no canal e
   nunca é imposta (A2).
7. **A ferramenta hoje REPLICA a matriz**: `B7KtCovered`
   (src/hbrefactor.prg) decide cobertura por heurística de fatos do
   dump (ausência de occurrence `ref`/write em bloco) — réplica fiel,
   mas réplica ("nenhuma réplica de gramática na ferramenta").

## Fatias propostas (portão POR FATIA; ordem = dependência)

### K1 — A6: a anotação de param de bloco passa a EXISTIR (core, bugfix)
`HB_CBVAR` ganha `szFromClass`; harbour.y:1024-1025 passam
`$2->szFromClass`; as duas materializações repassam a classe;
`hb_compClassFind` ganha guarda de `szClassName == NULL` (mata a
CLASSE de segfault, não só o repro). Efeito: `{| oX AS CLASS Conta |`
compila, o dump carrega a classe (hoje o dump PERDE — RE.1), W0025
honesto quando a classe não está no módulo. **Zero emissão -kt nova.**
É bugfix de upstream + transporte de fato.
**Critério**: repro mini2 compila sem crash nos 4 modos (`-w3`, `-kt`,
`-x`, estoque); dump do probe carrega `type S + class`; zero impacto
224/224 byte-idêntico sem flags; lexdiff limpo; suíte verde.

### K2 — prólogo de bloco: `-kt` impõe param de bloco (core)
Chamar o equivalente de `hb_compChkTypeParams` nos DOIS pontos do fato
3 (após materializar os params, antes do corpo). O site do cheque
nomeia a função DONA (caminhada `pOwner` como em `hb_compCodeBlockEnd`,
hbmain.c:3806-3813): `"MAIN:OX"`. Depende de K1 (sem classe não há o
que impor).
**Custo declarado**: o cheque roda A CADA `Eval()` do bloco — em laço
quente é custo real; `-kt` é opt-in duplo (T1) e a doutrina fail-fast
aceita, mas fica ESCRITO.
**Critério**: probe executável — bloco com param anotado recebendo
valor errado aborta `BASE/3012` nomeando `FUNC:PARAM`; valor certo (e
subclasse, T3) passa; fixkt estendido + caso de suíte; zero impacto
sem `-kt`; suíte byte-idêntica.

### K3 — pós-store de detached: escrita em bloco a local anotada (core)
Estender o guard do fato 2 para `HB_VS_CBLOCAL_VAR` (o `pVar` de
`hb_compVariableFind` é o HVAR da função dona — `cType`/`pClass` já
estão lá; o `PUSHLOCAL iVar` block-relative relê o valor recém-gravado
pela MESMA referência detached). Site nomeado pela dona (K2).
**Critério**: o probe2 do RE.1 (escrita em bloco que hoje passa em
silêncio) passa a abortar com mentira e a passar com verdade; t3.prg
do fixkt re-baselinado APENAS onde a cobertura virou real (o caso 88
inverte: site coberto AGORA ganha selo — mudança de contrato do
`guaranteed`, ver K4); suíte byte-idêntica.

### K4 — fato de cobertura no dump + morte da réplica (core ast-8 + ferramenta)
O core passa a MARCAR o que impôs: occurrence de escrita coberta ganha
`"chk": true` no dump; declaração com prólogo emitido (assinatura,
param de bloco K2) ganha `"chk": true`. `B7KtCovered` vira LEITOR do
fato (a heurística morre); `usages`/`annotate` não mudam de contrato —
mudam de fonte. Schema **ast-8** (aditivo; leitor aceita ast-2..8).
**Critério**: `B7KtCovered` sem nenhuma inferência estrutural própria
(régua: a função só consulta `chk`); casos 87/88 intactos ou
re-baselinados com justificativa site a site; ast-schema.md documenta
o campo; suíte byte-idêntica paralelo × JOBS=1.

### K5 — [DECISÃO DIEGO] `@ref`: re-cheque pós-call no caller
Única âncora sintática é o caller (fato 5): após statement que passa
local anotada por `@`, emitir o cheque da local. Honestidade: o
re-cheque é PÓS-FATO (pega a mentira DEPOIS do retorno, não no store
dentro do callee) — fail-fast de statement, não de store. Custo: um
cheque por call-com-@ de local anotada.
**Recomendação: medir no corpus ANTES** (M-cov: quantas escritas @ref
em locais anotáveis existem?) — se ~zero, declarar FORA com registro
honesto (o gap segue na matriz, sem selo — RE.2 já protege).

### K6 — [DECISÃO DIEGO] `PARAMETERS x AS` (memvar)
Emissão pós-`POPMEMVAR` no statement PARAMETERS. Legado puro; o gate
memvar do usages já responde `possible` honesto.
**Recomendação: FORA** (registro honesto na matriz), salvo fricção
real de corpus.

## Downstream (dependências honestas — NÃO são desta fase)

A Rota D dos testes-suspensos (sites de codeblock do caso 86, q2:9 da
DSL não-espelho) precisa de K1+K2+K3 **e** de o materializador
aprender a ESCREVER anotação em param de bloco (idioma de assinatura —
parente do resíduo "parâmetro" da B9 fatia 2, que segue sob portão
próprio). RE.5 entrega a cobertura e a prova fixkt-style; a reconquista
da Rota D abre depois, com as duas pernas em pé.

## Venenos e limites declarados

- Cheque em bloco roda por Eval (K2/K3) — custo em laço quente,
  opt-in, declarado.
- K5 muda a SEMÂNTICA do ponto de falha (pós-call) — se entrar, o
  rótulo/doc tem que dizer isso.
- Emissão nova = pcode novo sob `-kt`: os `.hrb` de projetos `-kt`
  mudam entre versões do core — esperado (o strip do baseline do
  `annotate` já compila inerte SEM a flag; caso 97 segue válido).
- Protocolo de zero impacto da fatia 1 vale para TODA fatia: sem
  `-kt`/`-x`, byte-idêntico no corpus 224/224 + lexdiff limpo.

## Arquivos a tocar

- harbour-core (autorização por commit, como sempre): hbcompdf.h
  (HB_CBVAR), harbour.y (1024/1025/1060 + prólogo ext), hbexprb.c
  (CodeblockPush + prólogo inline), hbmain.c (ClassFind guard, guard
  do pós-store, GenCall site-pela-dona; K4: emissão do fato `chk` no
  compast), compast.c (ast-8).
- hbrefactor: `B7KtCovered` (K4), fixtures fixkt/casos novos,
  ast-schema.md, roadmap.

## Executado (2026-07-10 — provas por fatia)

**K1 (A6/classe existe)**: `HB_CBVAR.szFromClass` + grammar
(harbour.y:1024-1025) + as DUAS materializações (harbour.y ext-block;
hbexprb.c inline) + guarda NULL em `hb_compClassFind`. Provas: mini2
exit 139→0 nos 4 modos; dump carrega `type S + class` em bloco inline
E estendido; W0025 nomeia a classe REAL (`FANTASMA`, não `(null)`) e
degrada limpo. Regeneração de parser: `HB_REBUILD_PARSER=yes` + sync
dos `.yyc`/`.yyh` (o build COPIA os pré-gerados — wart documentado).

**K2 (prólogo de bloco)**: `hb_compChkTypeParams` chamado nos dois
pontos de materialização; site nomeado pela DONA (caminhada `pOwner`
no `hb_compChkTypeGenCall`). Prova pgb1: valor certo passa, subclasse
(is-a) passa, mentira aborta `expected S:CONTA, got N: MAIN:OX` vindo
de `(b)MAIN`. Cheque roda a cada Eval (custo declarado, opt-in).

**K3 (pós-store detached)**: o registro da lista `pDetached` agora
COPIA `cType`/`pClass`/`uiFlags` da declaração da dona (era hardwired
`' '` — e `uiFlags` nem era inicializado); guard do pós-store cobre
`HB_VS_CBLOCAL_VAR` e blocos (pseudo-função `szName NULL`). Prova
pgb2: o cenário do probe2 do RE.1 (escrita em bloco que passava em
silêncio) agora aborta `expected S:CONTA, got C: MAIN:OC`; sem `-kt`
comportamento intacto. Armadilha de build que custou o diagnóstico:
hbmk2 usa o compilador EMBUTIDO ("built-in") — binário de hbmk2 STALE
roda o core velho mesmo com libhbcplr nova; relink manual obrigatório.

**K4 (fato `chk`, ast-8)**: `HB_ASTUSE.fChk`/`HB_ASTDECL.fChk` +
retro-taggers (`hb_compAstUseChk`/`hb_compAstDeclChk`, padrão do
`hb_compAstTag`); `hb_compChkTypeGenCall` devolve se emitiu e os DOIS
chamadores marcam o fato; schema **ast-8** (aditivo). Ferramenta:
`B7KtCovered` virou LEITOR (site coberto = toda escrita write/ref com
`chk` + declaração de param com `chk`) — a matriz replicada do RE.2
morreu; caminho de param de bloco declarado ganhou a marca kt (o fato
existe). Caso 88 re-baselinado como "matriz por FATO": site 1 (escrita
em bloco) RECONQUISTADO → `guaranteed`; site 5 NOVO (param de bloco
`AS CLASS`, inescrevível antes do K1) → `guaranteed ... codeblock`;
@ref e PARAMETERS seguem sem selo, honestos. Suíte **700/0**
byte-idêntica paralelo × `JOBS=1`; lexdiff limpo.

**Incidente que virou regra (custou ~1 h de bissecção)**: o bump para
ast-8 apagou em silêncio lifting/canal/regras — os portões de
capacidade da ferramenta (`FromReady`/`Ast4Ready`/`RuleToksReady`/
`B7Ret6` e 2 gates do tcheck) ENUMERAVAM versões de schema em vez de
exigir mínimo. Todos convertidos para `AstAtLeast( hAst, nMin )`
(prefixo `ast-` + `Val() >= nMin`); o teto fechado continua só no
`ReadAst`. Regra: portão de capacidade NUNCA enumera versões.

**K5 (@ref) — MEDIDO, recomendação FORA**: no corpus hbhttpd há 122
escritas `@ref` em locais, 36 símbolos distintos — TODOS value-kind
(`c*`/`n*`/`a*`/`t*`/handle/xValue); **zero receptores-objeto**. O
selo de classe não perde nada; o re-cheque pós-call mudaria o ponto de
falha (pós-fato) por benefício zero medido. Fica FORA com este
registro; reabre se o corpus real mudar.

**K6 (PARAMETERS) — FORA** (decisão do portão; legado, gate memvar já
responde `possible` honesto).

**Zero impacto (pacote completo)**: base × fix sobre o corpus, sem
flags novas: 1085/1085 `.hrb` byte-idênticos; as 3 "divergências" são
o próprio A6 — o compilador BASE segfaulta no t3.prg novo (site 5),
o corrigido compila; 28 programas não compilam igual nos dois lados
(fixtures que pedem contexto de projeto).

**Downstream aberto (inalterado)**: a Rota D do catálogo (sites do
fixb7b q1/q2) espera o MATERIALIZADOR aprender param de bloco
(parente do resíduo "parâmetro" da B9) — a cobertura do core está
pronta; a reconquista dos itens do catálogo abre com as duas pernas.
