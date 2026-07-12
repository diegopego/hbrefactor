# Spec B9 fatia 3 — materializador de param de bloco (2ª perna da Rota D)

Status: **EXECUTADA (2026-07-10, mesma sessão do portão — provas na
seção Executado).** Portão aberto pelo Diego na mesma data: D1 ACEITO
(contrato espelho da Rota B); D2 = TODAS as declarações (além da
recomendação mínima: o fato de posição sai para LOCAL/assinatura/
estáticas também — mata a régua de unicidade do `AnnNameCol` e
destrava a âncora do resíduo de assinatura); D3 = AMBAS as fontes
(receptor-inline + união de Evals convergente).
Origem: Rota D de [testes-suspensos-re3.md](testes-suspensos-re3.md)
(core PRONTO desde o RE.5; "falta o MATERIALIZADOR aprender a escrever
anotação em param de bloco") e resíduo "parâmetro" da B9 fatia 2
([spec-b9-fatia2-materializacao.md](spec-b9-fatia2-materializacao.md)).

## O que é

O RE.5 deixou a cobertura do `-kt` completa para blocos: anotação
`AS CLASS` em param de bloco EXISTE (K1), é IMPOSTA a cada Eval (K2),
escrita em bloco é checada (K3) e o fato `chk` chega ao dump (K4). O
caso 88 prova o lado LEITOR com anotação escrita à mão. Esta fatia
ensina o `annotate --apply` a ESCREVER a anotação em param de bloco —
fechando o ciclo materializa → impõe → o site decide nos sites de
codeblock do catálogo (fixb7b q1:85/89-90, q2:9) — e reconquista por
caso de suíte o site de detached (q1:82) que os probes mostram JÁ
decidível com o materializador atual.

## Fatos verificados (2026-07-10 — probes executados nesta sessão)

1. **q1:82 (detached de binding único) JÁ RECONQUISTADO em mecânica**:
   `annotate --apply` no fixb7b anota `LOCAL oDet AS CLASS MOEDA`
   (caminho existente de locais) e o site no bloco decide
   `confirmed send (receiver declared AS CLASS MOEDA, codeblock)`;
   com `-prgflag=-kt` no projeto sobe a `guaranteed ... imposed by -kt
   checks, codeblock` (probe P1 — a occurrence `detached` segue o
   caminho normal da declaração da dona, e a cobertura pós-K3/K4 fecha
   por fato `chk`). Falta SÓ o caso de suíte.
2. **Estado-alvo do param de bloco provado à mão, ponta a ponta**
   (probe P2): `{| oPar AS CLASS Moeda | oPar:Soma( 2 ) }` é INERTE
   sem `-kt` (`.hrb` byte-idêntico), compila limpo `-w3 -es2`, RODA
   sob `-kt` (cheque do prólogo K2 passa) e o usages decide
   `confirmed` → `guaranteed ... codeblock`. O padrão-ouro por edição
   da fatia 2 vale SEM ajuste para esta forma.
3. **Generalidade provada à mão na DSL não-espelho** (probe P2-DSL):
   em q2 (forno.ch), `{| tigela AS CLASS Fornalha | ... }` exige o
   registro puro `_HB_CLASS Fornalha` no módulo (classe de runtime da
   DSL não é conhecida do `-w3`: W0025 sem ele — o idioma nível 2 de
   registro JÁ existente resolve); com ele, compila limpo, roda sob
   `-kt` e o site decide `confirmed ... in FORNALHA`.
4. **A âncora de escrita NÃO tem fato hoje** (probe P3, o furo central
   da fatia): a declaração do dump carrega só `declLine` (compast.c:438
   grava `currLine`; coluna de token vem de `hb_pp_tokenPos`,
   compast.c:272, e não alcança a declaração). Dois modos de quebra:
   (a) na linha 85 há DOIS tokens `oPar` (col 14 = param, col 21 =
   uso) — a régua de unicidade do `AnnNameCol` (a âncora byte-exata
   das locais) recusa; (b) em bloco CONTINUADO (`bCont`, q1:89-90) a
   materialização acontece no FIM do bloco → `declLine` = última linha
   física (90), mas o token escrito está na linha 89 — âncora por
   `declLine` não acha token nenhum. Resolver por varredura de tokens
   entre `{|` e `|` seria réplica de gramática (proibida).
5. **O ponto exato do core para o fato da âncora**: o param de bloco
   nasce em `BlockVarList` (harbour.y:1024-1025, `hb_compExprCBVarAdd`)
   — ali o identificador acabou de ser consumido e o stream de tokens
   do compast está NO token escrito (o corpo ainda não foi parseado);
   `HB_CBVAR` (hbcompdf.h:109-118) já atravessa a classe até a
   materialização desde o K1 (`szFromClass`) — carregar a POSIÇÃO do
   token escrito é o mesmo padrão. As duas materializações (inline
   `hb_compExprCodeblockPush` em hbexprb.c; estendido harbour.y:1060)
   repassam a `hb_compVariableAdd` → `hb_compAstDecl`.
6. **A sugeridora já existe e está provada**: `B7InlineSelfType`
   (1º param de bloco INLINE registrado = receptor, classes.c:4554) e
   `B7BlockEvalType` (união dos sites de Eval rastreáveis) tipavam
   estes exatos sites antes do RE.3 (asserts do caso 86, verbatim no
   catálogo). O `AnnOne` hoje chama `TypeOf` com `xBlock = .F.` — o
   caminho de bloco nunca é consultado e o param de bloco cai em
   "sem-prova"; o `AnnApply` além disso pula `param` explicitamente
   (linha 7047, "assinatura = fatia futura").
7. **Selo `guaranteed` com granularidade por SÍMBOLO** (probe P2-DSL):
   `B7KtCovered` nega o selo se QUALQUER declaração param do símbolo
   na função dona está sem `chk` — em q2 há DOIS params `tigela` (os
   blocos `quente` e `morna`, mesma dona); anotar só um deixa
   `confirmed` sem selo (conservador, nunca overclaim). Anotar os dois
   (ambos 1º param → ambos sugeríveis) dissolve o caso no fixture; o
   degrade permanece para homônimo sem sugestão e fica DOCUMENTADO —
   fato block-id no dump é alavanca futura se o corpus morder.
8. **q1:13/14 (INLINE/OPERATOR do hbclass) NÃO têm site escrevível**:
   o bloco é gerado pela diretiva; o token do param (`Self`) tem
   proveniência de include (`prov` ≠ `'s'`) — não há onde escrever no
   fonte do aplicativo. Ficam FORA desta fatia com registro (rotas
   futuras honestas: anotação na REGRA da DSL do usuário; para o
   hbclass, extensão do próprio hbclass.ch no core — candidato próprio
   sob portão, custo: cheque por Eval em todo INLINE sob `-kt`).

## Decisões para o portão (recomendações marcadas)

- **D1 — contrato epistêmico**: materializar param de bloco é escrever
  sugestão da máquina dormente que NUNCA vira nível 1 por re-análise
  (o vínculo do param é o site de Eval, não uma declaração — diferente
  das locais). É o ESPELHO EXATO da Rota B já aceita (DECLARE de
  fábrica: sugestão direta → escreve → padrão-ouro verifica → `-kt`
  impõe dali em diante; mentira → BASE/3012 nomeado, caso 90 — "a
  imposição lavra a evidência condicional", spec-d § adendo).
  **Recomendação: aceitar o contrato** — sem ele a Rota D não existe.
- **D2 — escopo do fato de posição no core (ast-9)**: a âncora pede um
  campo novo na declaração do dump com a posição do token ESCRITO do
  nome (par linha+coluna próprios — em continuado a linha do token ≠
  `declLine`, fato 4b; presente só quando `prov 's'`). Alternativas:
  (a) SÓ param de bloco agora (mecanismo exato via `HB_CBVAR`, mínimo
  da fatia), campo desenhado GENÉRICO para as demais declarações
  preencherem em fatias futuras sem novo bump (aditivo, leitura por
  `AstAtLeast`); (b) já emitir também para LOCAL/param de assinatura
  (mata a régua de unicidade do `AnnNameCol` e destrava o resíduo
  "assinatura", mas pontos de captura distintos = mais superfície e
  mais prova de zero impacto nesta fatia). **Recomendação: (a)** —
  mínimo agora, genérico por desenho.
- **D3 — fontes de sugestão materializáveis**: receptor-inline
  (`B7InlineSelfType` — q2:9) e união de Evals CONVERGENTE a classe
  única (`B7BlockEvalType` — q1:85/89). A união é sugestão como
  qualquer outra sob D1 (venenos já degradam NIL: bloco que atravessa
  função, multi-write, param reescrito/@ref). **Recomendação: ambas**,
  com venenos assertados em suíte (bSolto/bMulti nunca anotados).

## Fatias (ordem = dependência; portão por fatia como sempre)

### F3.1 — core: fato de posição da declaração no dump (ast-9)
`HB_CBVAR` ganha a posição do token escrito, capturada na redução de
`BlockVarList` (mecanismo a provar na execução: back-scan no stream do
compast a partir do índice corrente — o corpo ainda não foi parseado,
o token casado mais próximo É o param; alternativa: posição corrente
do pp). As duas materializações repassam; `hb_compAstDecl` grava;
compast emite o par (nomes de campo decididos na execução; ausente
quando não-fonte). Schema **ast-9** (aditivo; portões por `AstAtLeast`,
regra do RE.5).
**Critério**: dump do q1 pristino carrega a posição exata dos params
`oPar` (85, col do token 14) e `oCont` (LINHA 89, não a 90 do
`declLine`); param gerado por diretiva (q1:13/14) SEM o campo ou com
proveniência não-fonte; zero impacto 224/224 byte-idêntico sem flags;
lexdiff limpo; suíte byte-idêntica.

### F3.2 — ferramenta: sugeridora de param de bloco no plano
`AnnPlan` varre declarações `param` com `declLine` fora da linha da
dona (idioma B7b); localiza o bloco pelo idioma existente
(`B7BlkLineCount == 1`, ambíguo degrada) e consulta a máquina dormente
pelo caminho de bloco (`B7InlineSelfType`/`B7BlockEvalType` via
`TypeOf` com contexto de bloco). Candidato com classe única → balde
novo do plano (`bp`, espelho do `fr` da Rota B), com registro
`_HB_CLASS` quando a classe não é conhecida do módulo (idioma nível 2
existente — fato 3); sem prova/veneno → relato honesto (`possible`,
nunca palpite). Relatório do `annotate` ganha a seção (JSON incluso).
**Critério**: no fixb7b pristino o relatório nomeia oPar/oCont (e os
2 `tigela` de q2) com a classe e a linha exata de escrita; bSolto,
bMulti, oExtra e q1:13/14 NÃO aparecem como escrevíveis (cada um com
sua razão).

### F3.3 — ferramenta: materializador escreve na âncora do fato
`AnnApply` escreve ` AS CLASS <X>` na posição do F3.1 (inserção
intra-linha após o token do nome — reuso integral de `AnnWriteAnnots`/
`AnnInsertAt`, ordenação DESC já trata múltiplas inserções na mesma
linha); padrão-ouro por edição + rollback SEM mudança (fato 2);
`B7KtMark`/`B7KtCovered` inalterados (leitores do fato `chk` — a
granularidade por símbolo fica, fato 7). Âncora ausente (dump antigo,
prov não-fonte) → pula com relato, nunca adivinha.
**Critério**: round-trip no fixb7b — cópia materializada compila
limpa, roda sob `-kt`, e os sites decidem: q1:85 e q1:89-90
(continuado!) `confirmed`/`guaranteed ... codeblock`; q2:9 idem em
FORNALHA (generalidade JUNTO, régua dos casos 64/72-74); venenos
intactos `possible`; fixture original intocado.

### F3.4 — suíte: reconquista da Rota D por caso
Casos novos no idioma dos 91-96 (cópia materializada, fixture
original intocado, `-prgflag=-kt` para o selo): (i) q1:82 —
detached de binding único, SÓ suíte (fato 1: nenhum código novo);
(ii) q1:85 + q1:89-90 — params de bloco por união de Evals, inclusive
o statement continuado; (iii) q2:9 — DSL não-espelho com registro
`_HB_CLASS` materializado; asserts adversariais: oExtra sem tipo,
bSolto/bMulti/13/14 sem anotação e sem selo. Catálogo
testes-suspensos atualizado (Rota D fecha ou registra o que sobrou);
casos 88/89 intactos ou re-baselinados com justificativa site a site.
**Critério**: suíte verde byte-idêntica paralelo × `JOBS=1`; lexdiff
limpo; CHANGELOG (entrada para o programador final) e extensão
conferida (o `annotate` não muda de superfície — validar que o
relatório novo não quebra o parse da extensão, harness do caso 71).

## Downstream e limites declarados

- **q1:13/14 seguem suspensos** (fato 8) — a Rota D fecha os itens
  escrevíveis; os gerados por diretiva esperam rota própria (regra da
  DSL / hbclass.ch no core), registrada no catálogo.
- Cheque de param de bloco roda A CADA Eval (K2) — custo em laço
  quente, opt-in `-kt`, já declarado no RE.5.
- Selo por símbolo: homônimo de param entre blocos da mesma dona sem
  sugestão para todos → `confirmed` sem selo (conservador, fato 7).
- A anotação materializada muda pcode SOB `-kt` por design (emite o
  prólogo); o inerte do padrão-ouro compara sem a flag (AnnNoKt,
  caso 97 segue válido).

## Executado (2026-07-10, mesma sessão do portão — provas por fatia)

**F3.1 (core, ast-9)**: `HB_ASTDECL.iNameLine/iNameCol` +
`hb_compAstNamePos` (back-scan limitado a 16 tokens no stream capturado;
pára no PRIMEIRO match de texto — match não-fonte = campo ausente,
nunca palpite; variável homônima da classe do próprio `AS CLASS` é
pulada UMA vez via `szSkipClass`); block param: `HB_CBVAR.iPosLine/
iPosCol` capturados na redução de `BlockVarList` (harbour.y, o corpo
ainda não parseado → o match mais próximo É o param) e retro-tag
`hb_compAstDeclPos` nas DUAS materializações (harbour.y ext;
hbexprb.c inline — padrão `hb_compAstDeclDim`). Emissão condicional
(`nameCol >= 0`). Provas: oPar 85/14 (o token do PARAM, não o uso da
col 21); oCont nameLine **89** (linha escrita; declLine segue 90 — a
spec do schema corrige a nota "declLine na linha do {|": em continuado
é a linha da MATERIALIZAÇÃO); Self de INLINE/`~1` SEM o campo;
adversarial `LOCAL conta AS CLASS Conta` → col da VAR. **Zero impacto
230/230** `.hrb` byte-idênticos (corpus work/tests, base worktree
`29eb2aa940` × fix; 6 não-compilam igual nos dois lados); lexdiff
0 divergências reais. Armadilha nova de build: dependência de HEADER
não é rastreada pelo make — mudar `hbcompdf.h` deixou `libhbmacro`/
objetos de expr STALE (layout velho do struct → segfault até sem
`-x`); cura: `make clean` em src/common+compiler+macro antes do
relink manual.

**F3.2 (sugeridora bp)**: balde `bp` no `AnnPlan` — declarações
`param` com `declLine` fora da linha da dona, sem tipo, bloco único na
linha (`AnnBlkAt`, régua do `B7BlockParam`), sugestão pelo caminho de
bloco do `TypeOf` (D3: receptor-inline E união de Evals convergente),
âncora presente exigida. Relatório e `--json` (`blockparams`) novos;
resumo ganha `params-bloco-anotáveis`. No fixb7b pristino: oPar(85),
oCont(89) e os DOIS `tigela` de q2 (com `_HB_CLASS FORNALHA` nomeado);
bSolto/bMulti/oExtra/Self 13-14 FORA.

**F3.3 (materializador)**: registro `_HB_CLASS` do bp entra no passo 2
(dedup por path+texto no `AnnQueueIns` — os dois tigela geram UM
registro); anotações bp no passo 5b a partir do plano RE-analisado
(linhas frescas do fato ast-9 pós-inserções); locais nível 1 usam a
âncora do fato com `AnnNameCol` rebaixado a degrade de dump antigo.
Padrão-ouro e rollback SEM mudança. Ciclo completo provado: 5
declarações + 8 anotações no fixb7b; inerte byte-idêntico sem `-kt`;
compila `-w3 -es2`; RODA sob `-kt`. Bônus medido: o registro
`_HB_CLASS` destravou a LOCAL `oFor` de q2 (classe de runtime da DSL →
n2 → anotada).

**F3.4 (suíte)**: casos **98** (Rota D q1:82, detached — só suíte,
fato 1 confirmado), **99** (q1:85 + q1:89-90 continuado + venenos
nunca anotados + 13/14 possible) e **100** (q2:9 DSL não-espelho:
generalidade JUNTO — registro único, oExtra intacto, roda sob `-kt`,
`guaranteed`; morna possible honesto). Casos 89/97 re-baselinados SÓ
nas contagens (4+3 → 5+8, justificado site a site no harness). Suíte
**729/0** byte-idêntica paralelo × `JOBS=1`; lexdiff limpo. Rota D do
catálogo FECHADA nos itens escrevíveis; q1:13/14 permanecem
suspensos com a rota futura registrada.

## Arquivos a tocar

- harbour-core (autorização por commit, como sempre): hbcompdf.h
  (HB_CBVAR posição), harbour.y (BlockVarList), hbexprb.c (repasse
  inline), hbmain.c (hb_compAstDecl assinatura/repasse), compast.c
  (captura + emissão, ast-9).
- hbrefactor: src/hbrefactor.prg (`AnnPlan`/`AnnOne` caminho bp,
  `AnnApply` balde bp, leitor da âncora ast-9), tests/run.sh +
  tests/tcheck.prg (casos novos), docs (ast-schema ast-9, roadmap,
  testes-suspensos, CHANGELOG).
