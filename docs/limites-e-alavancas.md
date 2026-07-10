# Limites da análise e alavancas de core (mapa permanente)

Análise honesta registrada em 2026-07-06 (pedido do Diego após a pergunta
"isso é verdade mesmo alterando o fonte do Harbour?"), extraída do roadmap
na limpeza de 2026-07-07 (o texto integral da época está no
[roadmap-fases-entregues.md](roadmap-fases-entregues.md)). Vale como mapa
do que a REGRA MAIOR (fatos de compilação, nunca heurística) pode e não
pode alcançar.

## O teto (vale para QUALQUER core)

A impossibilidade de completar o "amarelo" (tipo de receptor de send,
alcance de memvar, modelo de classe dinâmico) é da SEMÂNTICA da linguagem,
não da arquitetura do compilador: a classe de um receptor é propriedade de
runtime que pode depender da entrada do programa (`iif` sobre config,
`hb_Deserialize`, `&cVar`, `hb_hrbLoad`) — território do teorema de Rice.
Análise sound responde três coisas: "definitivamente sim",
"definitivamente não", "talvez" — e o "talvez" é irredutível no caso
geral. Segundo teto: programa Harbour pode SE OBSERVAR
(`ProcName()`/`ProcLine()`) — extract "perfeito" muda `ProcName(0)` no
trecho extraído; equivalência estrita sob auto-observação é violada por
definição, o contrato prático a exclui.

Três noções de "completo", da impossível à alcançável:
1. **para a linguagem** — impossível com qualquer core (teto acima);
2. **para um programa disciplinado** (fluxos estáticos, sem macro em
   receptor) — alcançável com análise de programa inteiro; cada "talvez"
   restante aponta a linha dinâmica culpada (relato acionável);
3. **para as execuções observadas** — alcançável por instrumentação de
   runtime; prova presença, nunca ausência.

**Correção registrada**: a afirmação anterior "nunca cobrirá parâmetro/
retorno/elemento de array" estava ERRADA como princípio — é limitação da
compilação separada (arquitetura, mudável), não da linguagem. Análise de
programa inteiro propaga tipos interprocedural quando os fluxos são
estaticamente conhecidos.

## Alavancas verificadas no fonte (2026-07-06, evidência arquivo:linha)

- **A. Tipagem declarada.** `AS CLASS <nome>` → `hb_compVarTypeNew(…,'S',…)`
  (harbour.y:356), campos `cType`/`pClass` em `HB_HVAR`
  (hbcompdf.h:96-106), gravação em hbmain.c:463-478; hbclass.ch declara
  `local Self AS CLASS <ClassName>` em todo método (hbclass.ch:263-265).
  **CONSUMIDA na B4f (ast-4)** — canal transportado 1:1. Caveat honesto:
  declaração é promessa do programador, o compilador não a verifica —
  consumir exige política explícita, distinta de fato verificado.
- **B. Programa inteiro.** Compilação separada é arquitetura; um passo de
  link-time sobre os dumps pode propagar tipos interprocedural — parâmetro
  com todos os call sites conhecidos (`calls[]` + árvores `parms` já no
  dump), retorno com todas as árvores de RETURN (contexto de valor já no
  dump). Reticulado de CONJUNTOS finitos de classes: "despacha para um de
  {A:M, B:M}" ainda é FATO; furo na cadeia (chamada dinâmica, macro) →
  desconhecido nomeando o culpado. Cresce o "verde por fato"
  arbitrariamente para código disciplinado. (Análise de 2026-07-07:
  candidata natural a fase futura.)
- **C. WITH OBJECT.** O objeto é empilhado em RUNTIME
  (`HB_P_WITHOBJECTSTART`, harbour.y:2001-2007) — mas a ASSOCIAÇÃO
  sintática send↔expressão do WITH é fato de parse, exportável no dump.
- **D. Introspecção de runtime.** `__dynsCount`/`__dynsGetName`/…
  (dynsym.c:677-727; padrão em src/rtl/profiler.prg:238-249),
  `__classSel()` (classes.c:4215), `__clsGetAncestors` (5383),
  `__objGetMsgList` (objfunc.prg) enumeram o mundo REALMENTE linkado.
  Caveats: prova presença, nunca ausência; `hb_hrbLoad()` RODA os INIT
  PROCEDUREs (runner.c) — harness tem efeitos colaterais possíveis.
  Extensão natural (análise 2026-07-07): **todo send do runtime passa por
  UM funil — `hb_vmSend()` (hvm.c:6092)**; gancho gated ali registraria
  (classe real, mensagem, site) das execuções observadas — terceiro nível
  epistêmico (confirmado-por-execução), jamais misturável ao estático.
- **E. Compilador como oráculo de strings.** `hb_compileFromBuf()`
  (hbcmplib.c:230) + `HrbParse` da ferramenta: expressão-string → lista de
  símbolos por FATO; com `ordKey()`/`DBOI_EXPRESSION`
  (dbfcdx1.c:8217/dbfntx1.c:6962), UDF em índice real vira verificável
  PARA OS DADOS QUE SE TEM.
- **F. Validação de tradução.** Verificador de equivalência POR
  TRANSFORMAÇÃO (corpo extraído = mesmas instruções realocadas + cola) —
  quase-prova específica sem resolver equivalência geral (indecidível).

## O que nenhuma alavanca entrega

Decidir o caso geral dependente de entrada; enumerar nomes que nascem de
dados em runtime; equivalência estrita sob auto-observação. Para esses, o
piso permanente é o da REGRA: recusa/relato honesto — nunca palpite.

## M-cov — medição de cobertura em código real (2026-07-08, hbhttpd)

Método: varredura das 53 mensagens distintas do corpus com `usages`
(408 sites de send, cobertura 408/408); causa dos "possible"
diagnosticada pelo nó receptor no dump. Números:

| Camada | Sites | % |
|---|---|---|
| confirmed | 130 | 32% |
| excluded / conjunto nomeado | 2 | 0,5% |
| possible | 276 | 68% |

Causas do possible: **local sem cadeia 132** (dominado pelo sistema de
classes PRÓPRIO do hbhttpd montado em runtime — fronteira fixofi — e
por objetos nascidos na VM, ex. `oErr` de RECOVER); **parâmetro cuja
união não fecha 89** (hbhttpd é biblioteca: call sites fora do
projeto — abertura ESTRUTURAL, não falha da análise); elemento de
array/hash 18; retorno sem fato 15; memvar/field 11; outros 11.
**Macro como receptor: ZERO** no corpus.

Leitura: os baldes dominantes não são alcançáveis por mais inferência —
o fato não existe em compilação. Cobrir mais exige FONTES NOVAS de
fato (alavancas D e G). Caveats: um corpus só, e é biblioteca (infla o
balde de parâmetros); diagnóstico por inspeção do nó (4 sites não
localizados); repetir em código de produção quando liberado.

## Alavanca G — tipo declarado IMPOSTO (extensão semântica, proposta do Diego)

A sintaxe de anotação JÁ EXISTE na gramática **para o sistema de tipos
inteiro** (`AS NUMERIC/CHARACTER/DATE/LOGICAL/BLOCK/ARRAY/OBJECT` +
`AS CLASS <nome>` — classe é SÓ UM CASO, o 'S') e **no idioma inteiro**:
parâmetros formais (harbour.y:371-372), locals (:1145), FIELDs (:1213),
MEMVARs (:1224), parâmetros de codeblock (:1019), variável de macro
(:1132) e retorno via `DECLARE ... AS` (:1228). Hoje o canal morre
na compilação (warnings -w3 + transporte ast-4) — é promessa não
verificada (caveat da alavanca A).

A extensão é SEMÂNTICA, não sintática: sob flag opt-in do compilador
(`-kt`, decidido T5), o compilador EMITE
um cheque de runtime na entrada da função para cada parâmetro anotado
com classe — pcode chamando helper de runtime (VM intocada); violação
= erro nomeando site/esperado/recebido. A anotação vira INVARIANTE da
linguagem (fail-fast): terceira fonte de fato, distinta do fato
estático (incondicional) e da evidência de execução (presença).

Alcance frente à M-cov: fecha o balde de parâmetros (89) e — porque o
cheque é de RUNTIME — alcança receptores que a estática nunca verá:
classes montadas dinamicamente (cheque por nome no objeto vivo) e
objetos nascidos na VM (`oErr AS CLASS Error`). Não alcança: mensagem
por macro, caso geral dependente de entrada (Rice fica). Fontes
continuam compilando em QUALQUER Harbour (sintaxe padrão); só a flag
muda comportamento — compatibilidade preservada (restrição do Diego,
2026-07-08). Ciclo virtuoso com a ferramenta: materialização (a B7
escreve os `AS CLASS` que provou) → flag os impõe → a análise confirma
estaticamente nas âncoras. Fase: spec-b9-anotacoes-impostas.md.

## Alavanca D — adendo verificado (2026-07-08): o gêmeo das macros

A AST de TODA macro existe completa no momento em que ela compila em
runtime: `Main : Expression` (macro.y:257-266) tem a árvore inteira em
`$1` — construída pelo MESMO motor `hb_compExprNew*` do compilador
principal — antes do pcode. O padrão de compartilhamento de fonte já
existe (macroa.c: `#define HB_MACRO_SUPPORT` + `#include "hbexpra.c"`),
e o ponto único de gate é `hb_macroCompile()` (vm/macro.c:798). Um
gancho gated ali (dump de string + árvore + exprType + flags HB_SM +
status) é o irmão do funil `hb_vmSend`: evidência de execução para
macros — prova presença, nunca ausência. Mais simples que o dump do
compilador (sem pp, sem from/ppRules).

## M-cov 2 — programas fechados (2026-07-08, tests do core em work/tests)

Corpus-contraponto à M-cov (que era biblioteca): os tests do core
copiados para `work/tests` (230 .prg; 230 compilam standalone; 76 têm
sends). Método: medição POR-PROGRAMA (cada test é um programa fechado
independente — um projetão único poluiria homônimos entre programas);
817 consultas `usages`, 5.686 linhas de send agregadas.

| Camada | % |
|---|---|
| confirmed | 25,7% |
| excluded | 0,2% |
| possible fora de codeblock | 45,8% |
| possible dentro de codeblock | 28,3% |

Causas (nó receptor no dump) — fora de bloco: local sem cadeia 915,
**send encadeado 697**, parâmetro 390, local multi-write 292, retorno
sem fato 125, resto ~160. Dentro de bloco: local detached multi-write
1.284 (loops do rto_get), **parâmetro de bloco 320**.

**Interpretação (muda a escada de alavancas)**: os baldes dominantes
NÃO são o caso-anotação — são **lacunas de INFERÊNCIA fecháveis sem
tocar em linguagem**: (a) send encadeado = a B7 infere retorno de
FUNÇÃO mas não de MÉTODO, embora os rótulos `ret` (ast-6) já existam
nos corpos; (b) o padrão money: `::sends` em corpo de método
INLINE/OPERATOR — o corpo compila como codeblock onde Self não tem
canal, mas a CO-DERIVAÇÃO (B4d) liga o bloco à classe dona: o fato
existe; (c) parâmetro de bloco: união via sites de Eval. O que sobra
de dinamismo genuíno (cls*cast = testes de TORTURA de casting,
2.260 sites) é alvo da alavanca D — e note: são programas que RODAM.

Caveats: corpus adversarial (tortura de casting + GET afogado em
blocos), não retrato de produção; diagnóstico por inspeção do nó (20
não localizados); a régua final continua sendo o dogfooding no código
do Diego. Consequência registrada (decisão do Diego, 2026-07-08):
**escada revisada — inferência (fase B7b) > alavanca D > alavanca G/B9
(gaveta, decisões T1-T5 preservadas)**.

### Delta da B7b (2026-07-08, mesmo corpus — harness `tests/mcov2.sh`)

Método: harness reconstruído e PERSISTIDO (`tests/mcov2.sh`, corpus git-ignorado em work/tests — por-
programa, mensagens = syms distintos de `sends[]` do dump, consulta
bare por mensagem, paralelo por programa); a enumeração mecânica dá
**967 consultas / 6.249 sites** (a medição original reportou 817/5.686
— enumeração mais inclusiva aqui, ex. formas `_X`; as PROPORÇÕES
reproduzem 25,6/0,2/45,6/28,6 ≈ 25,7/0,2/45,8/28,3). Para o delta ser
limpo, a BASELINE foi re-medida com o binário pré-B7b no MESMO
harness; zero consultas falhadas; flips pareados site a site.

| Camada | pré-B7b | pós-B7b |
|---|---|---|
| confirmed | 1.597 (25,6%) | **1.715 (27,4%)** |
| excluded | 10 (0,2%) | 10 (0,2%) |
| possible fora de codeblock | 2.852 (45,6%) | 2.835 (45,4%) |
| possible dentro de codeblock | 1.790 (28,6%) | 1.689 (27,0%) |
| (confirmed dentro de bloco) | 0 | **101** |

**118 upgrades possible→confirmed, ZERO downgrades** (o hardening do
`B7ParamType` não rebaixou nada no corpus). Onde fechou: clsscope 54,
**money 20 (o padrão epônimo do alvo 2 — INLINE/OPERATOR)**, overload
16, stripem 11, html 7, inhprob 5, classch 4, dbgcls 1. Dos 118, 101
dentro de bloco (INLINE + detached/Eval) e 17 fora (send encadeado).

Leitura honesta do que NÃO fechou: os **cls\*cast de tortura permanecem
intactos** (classes montadas dinamicamente — alvo da alavanca D, como
o critério exigia); o balde "send encadeado 697" fecha pouco NESTE
corpus porque os encadeados dominantes atravessam construção dinâmica
de tortura; os blocos de GET/tbrowse (SETGET/param de bloco) têm os
Evals NA RTL, fora do projeto — ponto cego estrutural, degrade
honesto; detached multi-write (1.284) permanece ⊤ por regra (sem
ordem). O mecanismo está provado onde o fato existe (caso 86); a
régua final segue sendo o dogfooding em código de produção.

**ESCADA RE-REVISADA — A REGRA DO FATO (Diego, 2026-07-08, ao ver o
portão da alavanca D; revoga a escada do início do dia)**: hbrefactor
lida com FATOS; heurística e TRIAGEM não são produto; **meta = ZERO
INFERÊNCIA**. Fato ausente → estender o CORE para o fato existir
(caminho canônico: **alavanca G/B9**, anotação vira invariante imposta
— fecha por RUNTIME os baldes que a estática nunca vê) ou usar
ferramenta do core como oráculo — nunca construir inferência nova. A
inferência entregue (B7/B7b) converge para MATERIALIZADORA de anotações
(ciclo virtuoso desta seção), não fonte de veredito de longo prazo. A
alavanca D na forma triagem (camada observed para priorizar conferência)
foi RECUSADA; evidência de execução só volta com consumo 100% fato.

## M-cov 3 — o retrato honesto pós-RE.3 (2026-07-09, mesmo corpus/harness)

O RE.3 (portão do Diego, forma "a": inferência some do `usages`;
possible sem nomes derivados de inferência) executado; medição
`tests/mcov2.sh` no mesmo corpus work/tests (967 consultas, 6.249
sites, zero falhas):

| Camada | pós-B7b (pré-RE.3) | pós-RE.3 |
|---|---|---|
| confirmed | 1.715 (27,4%) | **545 (8,7%)** |
| excluded | 10 (0,2%) | 10 (0,2%) |
| possible fora de codeblock | 2.835 (45,4%) | 3.904 (62,5%) |
| possible dentro de codeblock | 1.689 (27,0%) | 1.790 (28,6%) |
| (confirmed dentro de bloco) | 101 | **0** |

Proveniência do que ficou: TODO confirmed é canal declarado (`declared
AS CLASS` do próprio símbolo ou cadeia de declarados `via declared
types`); os 10 excluded são value-kind declarado. 1.170 sites que a
inferência decidia (cadeia de construção, uniões, grafo as-written,
Self de INLINE, pushes ret) degradaram para o possible pleno — a
separação boa/veneno que a máquina fazia colapsou no MESMO rótulo, por
decisão (a máquina virou SUGERIDORA: insumo do materializador, fatia 2
da B9, onde essa separação renasce como anotação PROVADA e imposta).
Consequência de produto notável: o furo dos homônimos (caso 66) volta
a possible nos SENDS — a exclusão dependia de mundo fechado sobre
parents as-written; os sites de DECLARAÇÃO homônimos seguem
excluded/confirmed (fato do canal declarado). O caminho de volta do
alcance é o ciclo virtuoso: materializar `AS CLASS` provados → `-kt`
impõe → guaranteed/confirmed por FATO (alavanca G), não re-ligar a
inferência.

## M-annotate — alcance da escada de declarações (2026-07-09, F2.3 do plano da fatia 2)

Primeiro snapshot do `annotate --dry-run` (estágio 1 — relatório;
plano-b9-fatia2-escada.md, tabela completa lá). Sementes [FATIA-2]:
TODAS as de Rota A/B fecham por **nível 2** (one-liners DECLARE/
`_HB_MEMBER` nomeados, zero confiança em `via`); as de send encadeado
(caso 86) dependem do candidato de core (g) — membro declarado sem
tipo, merge já funciona, só o W0019 bloqueia. Corpus hbhttpd (322
locais): nível1=7, nível2=0, nível3=1, sem-prova=284 (o balde aberto
da M-cov), **retornos-declaráveis=13** (fábricas do DSL UW*, impostos
sob -kt) e **métodos-(g)=18** — no corpus real a alavanca dominante é
o candidato (g), e o ganho de locais vem da RE-ANÁLISE iterativa após
materializar os retornos (pipeline do estágio 2). O relatório é o
insumo do PORTÃO DO MEIO (decisões: candidatos (f)/(g) de core;
abertura da edição F2.4).
