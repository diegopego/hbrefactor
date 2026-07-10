# Spec B9 fatia 4 — execução controlada como 2ª FONTE da sugeridora

Status: **FATIA FECHADA (2026-07-10, mesma sessão do portão): F4.1 +
F4.2 (M1/M1b) ENTREGUES; F4.3 (escrita) MORTA POR MEDIÇÃO — decisão do
Diego sobre o M1b.** O critério de matar do desenho foi ACIONADO:
casting no core bem escrito é 0-1% (rtl/gtwvg/xhb) e classe invisível
à estática é nicho de startup/por-APP — o 38% do cls\*cast era
tortura, não idioma. O `exec-registry` fica como instrumento de
inventário/diagnóstico (valor provado: método sem corpo no hbhttpd,
QUIT do xhb nomeado, registradores paramétricos relatados). Esta spec
fica na GAVETA (padrão B8): a escrita reabre se fricção real em
código do core a pedir, do § Desenho/F4.3 em diante. Portão original:
D1-D6 aceitas nas recomendações, mesma data. Origem: adendo refinado da
[spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md) § Adendo
(registro 2026-07-10, refinamento do Diego) — é o resíduo 3 da B9 no
[roadmap](roadmap.md). NÃO é a alavanca D (que segue com portão
fechado): aqui não há gancho no core nem camada `observed` — há
ferramenta do core usada como oráculo e materialização verificada.

## O que é

O maior balde do mapa que a estática não alcança é o de **classes
montadas em runtime** (M-cov: cls\*cast 2.260 sites; hbhttpd "local sem
cadeia" dominado por sistema de classes próprio). A fatia dá à
sugeridora do `annotate` uma **segunda fonte**: rodar em sandbox SÓ o
código de REGISTRO de classes (driver próprio, nunca o Main do app),
ler a tabela viva (`__clsCntClasses`/`__className`/`__classSel`/
`__clsGetAncestors`/`__clsMsgType`) e materializar os
registros/completadores correspondentes (`_HB_CLASS`/`_HB_MEMBER`, o
idioma nível 2 já existente), com proveniência no relatório — que o
`-kt` impõe dali em diante.

A propriedade que a viabiliza sob a REGRA DO FATO: **a imposição lavra
a evidência condicional**. O sandbox só SUGERE; o veredito é do cheque
imposto em toda execução real — retrato errado → BASE/3012 nomeando
site e tipos (o idioma do caso 90). Nenhum veredito estático consome o
snapshot; nenhuma mistura com a alavanca D.

## Fatos verificados (2026-07-10 — probes desta sessão)

1. **Ler a tabela viva é core puro, de `.prg`, sem canal novo**:
   `__clsCntClasses` (classes.c:4108), `__className` (classes.c:4207),
   `__classSel` (classes.c:4215), `__clsGetAncestors` (classes.c:5464),
   `__clsMsgType` (classes.c:5493). Esta fatia não deve exigir NENHUMA
   edição no core — é o braço "usar ferramenta do core como oráculo"
   da REGRA DO FATO.
2. **Baseline de programa vazio = 1 classe (`ERROR`)** — probe
   executado (clsbase.prg, toolchain `HB_BIN`): o diff "classes do
   projeto" × "classes da VM/RTL" é subtração por NOME, trivial e
   determinística.
3. **O registro é PREGUIÇOSO**: classe estilo hbclass só entra na
   tabela quando a class function roda pela 1ª vez; só linkar não
   registra nada. INIT PROCEDUREs rodam sozinhas antes do entry (fato
   do dump: sufixo `$`, ast-schema.md:764). Consequência: o driver
   precisa CHAMAR funções de registro — a seleção do que chamar é a
   decisão central (D2).
4. **O precedente de execução JÁ EXISTE e é MAIOR**: o padrão-ouro do
   `--apply` builda e RODA o programa INTEIRO do usuário a cada edição
   runnable (`AnnKtRun`, hbrefactor.prg:7474 — `timeout 30`, GT:CGI,
   workdir temporário). A 2ª fonte roda MENOS que a barra já aceita:
   driver sem o Main do app.
5. **`hbmk2 -main=<func>`** (hbmk2.prg:2979, help :16053) permite o
   driver ter entry próprio sem colidir com o MAIN do projeto,
   compilando os módulos com as MESMAS flags/includes do `.hbp` (o
   builder oficial resolve, regra de casa).
6. **A seleção tem canais 100% fato**: o dump carrega `calls[]` por
   função (ast-schema.md:320) — funções que chamam primitivas `__CLS*`
   são enumeráveis por fato; as class functions dos pares de registro
   já vivem no `clsmap` (`ClassFuncMap`, hbrefactor.prg:7541).
7. **A tabela viva distingue seletor de CAST**: `__clsMsgType` devolve
   `HB_OO_MSG_SUPER` (hboo.ch:81) para mensagens de cast de
   superclasse — o padrão exato da tortura cls\*cast (`o:myclass1:x1`)
   é identificável por fato na tabela, e `__clsGetAncestors` +
   `__className` dão o alvo do cast.
8. **Os receptáculos estão prontos**: `AnnPlan` (hbrefactor.prg:6378)
   retorna baldes (`rep`/`fr`/`mr`/`bp`) que o relatório/JSON/`--apply`
   consomem; o idioma nível 2 de one-liners (`_HB_CLASS`/`_HB_MEMBER`)
   e o padrão-ouro por edição (`AnnGoldCheck`, hbrefactor.prg:7443 —
   inerte byte-idêntico + compila limpo + roda sob `-kt`) valem sem
   ajuste para a fonte nova.
9. **Honestidade sobre o alvo**: clsccast.prg USA hbclass.ch — a
   tortura é de CASTING (seletores SUPER criados em runtime), não de
   classe anônima; o rendimento REAL da fonte nesses 2.260 sites e no
   hbhttpd é exatamente o que a medição M1 responde ANTES de construir
   a escrita (idioma M0 da spec-b8).

## Desenho (fatias)

- **F4.1 — executor + snapshot `.astr.json`**: subcomando/flag gera um
  driver `.prg` em temp (entry próprio via `-main=`), compila junto
  com os módulos do projeto (hbmk2, precedente `AnnKtRun`) e roda com
  timeout em workdir isolado. O driver: (a) tira o retrato da tabela
  ANTES de chamar qualquer coisa (baseline real do processo, cobre
  INITs que já rodaram); (b) chama a lista SELECIONADA (D2), cada
  chamada protegida por `errorBlock` + `BEGIN SEQUENCE` (função que
  quebra não derruba a colheita — entra no relato como "não colhida");
  (c) grava o snapshot: classes novas por chamada (proveniência =
  delta entre chamadas), com seletores, tipo de mensagem
  (`__clsMsgType`) e ancestrais, ordenado por nome (determinismo).
  Schema versionado (`rtr-1`), carimbo vindo de fora (suíte passa
  carimbo fixo).
- **F4.2 — M1, medição ANTES da escrita**: rodar F4.1 em cls\*cast +
  hbhttpd; medir (a) classes/seletores revelados que NENHUM canal
  estático conhece, (b) sites `possible` que os referenciam, (c)
  fração que viraria decidível com registro+anotação. Números
  dimensionam F4.3 e vão para o mapa. **Critério de matar**: rendimento
  ~zero → a fatia de escrita morre com relato e o snapshot fica como
  instrumento de diagnóstico.
- **F4.3 — balde `rt` no annotate**: com a flag (D4) e o snapshot, a
  sugeridora ganha a 2ª fonte: one-liners `_HB_CLASS` (registro de
  classe de runtime desconhecida do módulo — mesma auto-sabotagem do
  W0025) e, conforme D5, `_HB_MEMBER` de existência/cast. Relatório
  SEMPRE com proveniência: `materializado a partir de execução de F()
  [run <carimbo>]`. `--apply` escreve com o padrão-ouro existente.
  Sem flag/sem snapshot: relatório e edições BYTE-IDÊNTICOS aos de
  hoje.
- **F4.4 — suíte + extensão**: fixture DSL não-espelho que registra
  classe com nome COMPUTADO (a estática não alcança por construção —
  régua de generalidade da revisão R); caso de retrato ERRADO (registro
  mudou após o snapshot → recusa/BASE nomeando, espelho do caso 90);
  caso de determinismo (2 runs → snapshot byte-idêntico); caso de
  opt-in ausente (zero mudança). `extension.js` expõe o fluxo na mesma
  fase (regra de casa).

## Decisões para o portão (recomendações marcadas)

- **D1 — mecanismo de execução**: driver compilado com
  `hbmk2 -main=` (**recomendado**: mesmas flags/includes do projeto,
  precedente AnnKtRun, zero canal novo) × `hb_hrbLoad` em host próprio
  (roda INITs no load; exigiria host e `-gh` por módulo — mais peças).
- **D2 — seleção do que rodar** (o parente do problema da spec-b8):
  **v1 recomendada = união por FATO**: INITs (rodam sozinhas) + class
  functions do `clsmap` + funções cujo `calls[]` contém primitivas
  `__CLS*` — lista ENUMERADA por fato do dump, zero heurística; o
  relatório diz o que rodou, o que quebrou e o que ficou de fora.
  Alternativas: só INITs (mais estreito, rendimento menor); lista
  manual `--run=F1,F2` (pode COMPOR com a v1 desde já — o usuário
  conhece seu bootstrap).
- **D3 — contenção**: subprocess + workdir temp + timeout + GT:CGI
  (**recomendado**: exatamente a barra que o `AnnKtRun` já pratica;
  documentar HONESTO que I/O do código executado não é contível sem
  sandbox de SO) × sandbox de SO (bwrap/firejail — dependência
  externa, fora do escopo).
- **D4 — opt-in**: flag explícita SEMPRE; a fonte NUNCA roda no fluxo
  padrão do annotate (executar código do usuário é ação real — espelho
  do contrato do `--apply`). Aqui não há alternativa: é contrato.
- **D5 — o que materializar na v1**: **recomendado = shape puro que a
  tabela prova**: `_HB_CLASS` (existência) + `_HB_MEMBER` de
  existência; seletor de CAST com alvo provado
  (`HB_OO_MSG_SUPER` + ancestral) entra como
  `_HB_MEMBER <Cast>() AS CLASS <Alvo>` SE a verificação na fase
  confirmar o fato ponta a ponta. FORA: `DECLARE` de retorno de
  factory — exigiria OBSERVAR retornos (rodar factories), extensão
  futura com decisão própria.
- **D6 — onde vive o snapshot**: `.astr.json` por projeto, ao lado do
  `.ast.json` (**recomendado**; carimbo por parâmetro para a suíte
  ser determinística) × embutir no relatório (perde reuso entre
  invocações).

## Venenos e caveats

- **Retrato condicional**: o snapshot prova o que RODOU com aqueles
  caminhos; classe registrada condicionalmente pode FALTAR (falta =
  site segue `possible` honesto — a fonte sugere, nunca decide) e
  retrato ERRADO é lavrado pelo `-kt` na primeira execução real
  (BASE/3012 nomeando — caso 90).
- **Efeitos colaterais**: código de registro pode tocar arquivo/rede;
  a barra é a mesma do `AnnKtRun` (que roda o programa INTEIRO), com
  opt-in explícito (D4) e relatório nomeando o que rodou.
- **Determinismo**: snapshot ordenado por nome; nome de classe derivado
  de dado variável (relógio/aleatório) → instabilidade DETECTÁVEL
  (diff entre 2 runs) e relatada; a suíte cobre o caso determinístico.
- **Função de registro com parâmetro obrigatório**: chamada sem args
  pode quebrar → protegida, relatada como "não colhida"; NUNCA
  inventar argumentos (seria heurística).
- **Colisões de nome**: classe de runtime homônima de classe
  compilada, ou homônima de classe da VM/RTL do baseline (`ERROR`) —
  o diff por nome as esconderia/confundiria; relatar nominalmente,
  jamais sobrescrever declaração existente.
- **Duplicação com a fonte estática**: classe que a sugeridora
  estática JÁ prova não ganha entrada pela 2ª fonte (dedup no plano,
  como o `_HB_CLASS` da fatia 3) — a execução só acrescenta o que
  nenhum canal estático tem.

## Critério de pronto (executável)

- Fixture DSL não-espelho com nome de classe computado: annotate+flag
  mostra o balde `rt` com proveniência; `--apply` materializa com o
  padrão-ouro; o projeto roda sob `-kt`; o site decide por fato
  (`confirmed`/`guaranteed` conforme cobertura).
- Retrato errado provocado → recusa nomeando site e tipos (espelho do
  caso 90), rollback intacto.
- Sem a flag: saída e edições byte-idênticas às de hoje (zero mudança
  de comportamento; caso de suíte).
- Snapshot determinístico: 2 runs byte-idênticos na fixture.
- M1 registrado no mapa (cls\*cast + hbhttpd) ANTES de F4.3, com
  decisão explícita continuar/matar.
- Suíte verde byte-idêntica paralelo × `JOBS=1`; `make lexdiff` limpo;
  extensão VSCode expõe a capacidade na mesma entrega.

## Executado — F4.1 + F4.2 (2026-07-10, mesma sessão do portão)

**F4.1 ENTREGUE**: subcomando `exec-registry <projeto> [--out] [--stamp]
[--run F1,F2]` (opt-in por invocação explícita — D4: nunca roda dentro
do annotate). Seleção por fato (D2): clsmap + `calls[]` com prefixo
`__CLS` + `--run`; MAIN e STATIC ficam de fora COM relato; INIT conta
como startup. Driver gerado com entry `HBREF_REGDRV`, compilado
`hbmk2 -hbexe <projeto> driver -main=` (D1 — **`-hbexe` ANTES do
projeto**: o primeiro seletor de alvo vence, `l_lTargetSelected`
hbmk2.prg:2596; lib `-hblib` vira exe com o driver) e rodado com a
contenção do `AnnKtRun` (D3: `timeout 30` + GT:CGI + workdir temp).
Cada chamada protegida por `errorBlock`+`BEGIN SEQUENCE` (quebra =
`failed`, nunca derruba a colheita; argumento jamais inventado).
Snapshot `rtr-1`: classes ordenadas por nome com proveniência por
chamada (`startup` = delta de entrada), seletores com `__clsMsgType`
(cast SUPER=5 colhido — o padrão cls\*cast), ancestrais por nome, VM
separada por baseline nominal (`ERROR`). Determinístico byte a byte
(carimbo vem de fora). Fixture **fixreg** (DSL não-espelho FORJA METAL,
nome de classe COMPUTADO — inexistente em qualquer fonte) + **caso
101** (11 checks: proveniência, startup, failed protegido, tcheck
`rtr101` profundo com self-cast SUPER=5, determinismo, `--run` compõe
+ inexistente honesto, fixture intocada, régua do caso 64 da própria
DSL). Suíte **740/0** byte-idêntica paralelo × `JOBS=1`. Lição de
régua: "lavra" era palavra da DSL fixofi — o fonte da ferramenta usa
"impõe/sela" (a régua do caso 64 pegou na primeira rodada).

**F4.2 (M1) MEDIDO — números no
[mapa § M1](limites-e-alavancas.md)**: classes novas (sem canal
estático) = **0 nos dois corpora reais** (tudo hbclass; o mundo
`__clsNew`-puro só existe na fixture, por construção); o rendimento
real é o **seletor de CAST**: 24 pares em cls\*cast = primeiro salto
de **669/1.752 sends (38%)**, com receptor provável pela sugeridora
(escrita única por construção escrita) — o elo que falta é
`_HB_MEMBER <Cast>() AS CLASS <Alvo>`, idioma (g) existente; hbhttpd =
**0 sites de cast** (o balde de lá é receptor-identidade, fora do
alcance desta fonte). Achado colateral: `-hbexe` expôs
`UWSecondary:Add` declarado sem implementação no hbhttpd (recusa
nomeando o símbolo). **Decisão continuar/matar F4.3 = portão do
Diego.** Régua RECALIBRADA na apresentação do M1 (Diego, 2026-07-10,
regra no CLAUDE.md): a decisão se toma sobre código do CORE — não
sobre o código do Diego (bravo = só exploração).

**M1b EXECUTADA (mesma sessão; números no
[mapa § M1b](limites-e-alavancas.md))**: corpus ampliado rtl+gtwvg+xhb
(144 dumps limpos). Casting no core bem escrito é RARO (rtl ~0%,
gtwvg ~1% — idioma real `::WvgWindow:...` mas concentrado e win-only,
xhb ~0%); o 38% do cls\*cast é tortura, não idioma. A execução no xhb
provou o mundo classe-invisível em código real (6 escalares de
startup sem `CREATE CLASS`; proveniência cruzada TCGI→THTML) e os
limites honestos (registrador PARAMÉTRICO `HB_CSTRUCT*` falha sem
args — classes por-APP fora do alcance de retrato de lib; QUIT real
de `TStreamFileReader` no meio da colheita → driver ganhou flush por
`EXIT PROCEDURE`, retrato parcial com abortador nomeado em
`aborted`). Suíte re-verificada 740/0 após o flush.

## Fora do escopo

- Alavanca D (gancho em `hb_objGetMethod`, camada `observed` em sites)
  — portão fechado continua; nada desta fatia toca o core.
- Rodar factories / observar valores de retorno (`DECLARE` de retorno
  por execução) — extensão futura com decisão própria do Diego.
- Macros / `.astc.json` (spec-b8, na gaveta dela).
- Sandbox de SO.
