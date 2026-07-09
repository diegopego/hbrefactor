# Revisão externa (Codex) — segunda opinião: zero inferência e classes como construto de PP

Instrumento de revisão INDEPENDENTE pedido pelo dono do projeto (Diego,
2026-07-09). O revisor NÃO deve assumir nada além do que está no código
e nos documentos citados; deve julgar contra as réguas do dono (abaixo),
com achados verificáveis (arquivo:linha), veredito por pergunta e
recomendação franca. Instrução explícita do dono: **não seja gentil —
contraponto real**. Não há compromisso com o desenho atual: propor
demolição parcial ou total é resposta válida.

**Proveniência do estado sob revisão** (registro pedido pela 1ª rodada
de revisão, 2026-07-09): harbour-core, branch
`feature/compiler-ast-dump` @ `c1927dfcac` (a fatia `-kt` inclusa);
hbrefactor, branch `master` @ `6584aa8` (consumo ast-7 + este
documento). Medições M-cov/M-cov 2 de 2026-07-08 — comando, corpus e
data por número na seção "Estado de fato".

## Glossário operacional (os termos das réguas e dos vereditos)

- **Fato** — informação que o CORE materializa em compilação ou
  execução (dump `-x`, oráculo de recompilação byte-a-byte, erro de
  runtime do `-kt`); sempre rastreável a arquivo:linha ou a
  comparação byte-a-byte.
- **Inferência** — conclusão derivada por análise da FERRAMENTA além
  do fato materializado (união de call sites, cadeia de retornos,
  binding único); pode ser correta e vir rotulada, mas não é fato.
- **Triagem** — saída probabilística/heurística cujo consumo previsto
  é conferência manual; por R1, não é produto.
- **Canal** — campo do dump por onde um fato viaja (ex.: `type` em
  `declarations[]`, `kt` no cabeçalho — docs/ast-schema.md).
- **Invariante imposta** — anotação que o runtime FALHA se violada
  (módulo compilado com `-kt`); vale em execução, não só como
  promessa escrita.
- **Vereditos do `usages`**: **confirmed** — receptor decidido por
  fato/promessa declarada (o rótulo diz o como); **excluded** — send
  provado fora do conjunto; **possible** — indecidido, rótulo honesto
  (não é claim); **guaranteed** — acima de confirmed: anotação em
  módulo `-kt`, invariante imposta em runtime.
- **"Classe especial"** (R2) — qualquer mecanismo da ferramenta ou do
  core keyed a classe/hbclass, em vez de genérico por construto de
  diretiva.

## Os dois repositórios sob revisão

1. **~/devel/harbour-core/harbour** — fork do Harbour, branch
   `feature/compiler-ast-dump`. Contém: (a) commits do mecanismo de dump
   AST (`-x`, schemas ast-1..ast-6 — ver `git log --oneline` do branch;
   arquivo central `src/compiler/compast.c` + ganchos gated em
   `src/compiler/harbour.y`/`src/compiler/hbmain.c`/`src/pp/ppcore.c`);
   (b) a fatia `-kt`, commitada em `c1927dfcac` (2026-07-09, após a 1ª
   rodada desta revisão): cheques de runtime para as anotações
   `AS <tipo>`/`AS CLASS` da gramática; helper `__HB_CHKTYPE` em
   `src/vm/classes.c`; emissão em `src/compiler/hbmain.c`
   (`hb_compChkType*`) e `src/compiler/harbour.y`; flag em
   `src/compiler/cmdcheck.c`; schema ast-7 com `"kt"`/`"dim"`.
   `git show c1927dfcac` mostra a fatia inteira.
2. **~/devel/hbrefactor** — a ferramenta de refatoração consumidora
   (`src/hbrefactor.prg`, ~8,3k linhas; suíte `tests/run.sh`, 616
   checks — proveniência na seção "Estado de fato"). Comandos: renames
   verificados por recompilação (local, static, memvar, param, função,
   método, palavra de DSL, marker de pp), extract, reorder, `usages`
   com vereditos em camadas
   (confirmed/excluded/possible/guaranteed), call-graph.

Documentos de referência (ler antes de julgar): `docs/roadmap.md`,
`docs/limites-e-alavancas.md` (números de cobertura medidos),
`docs/ast-schema.md` (contrato do dump e regras de consumo),
`docs/spec-b7-tipos-interprocedurais.md`, `docs/spec-b7b-inferencia.md`,
`docs/spec-b9-anotacoes-impostas.md`, `CLAUDE.md` (as regras do dono).

## As réguas do dono (o desenho DEVE satisfazê-las)

**R1 — REGRA DO FATO, meta ZERO INFERÊNCIA.** A ferramenta lida com
FATOS. Heurística e triagem (ajuda probabilística para conferência
manual) NÃO são produto. Quando o fato não existe em compilação, o
caminho é (a) ESTENDER O CORE para o fato passar a existir
(canal/invariante novo) ou (b) usar ferramenta do core como oráculo
(compilador-biblioteca, hbmk2, `.ppt`...) — nunca construir inferência.
**CORE = o projeto Harbour oficial INTEIRO** (compilador, pp, VM/RTL,
hbmk2, hbrun, utilitários), não só o compilador.

**R2 — CLASSES NÃO SÃO ESPECIAIS (palavras do dono: "esta coisa de
tratar classes de forma especial não era minha intenção").** A régua é
sobre a SINTAXE DE DEFINIÇÃO de classe, não sobre "classes" em sentido
amplo: a sintaxe do `include/hbclass.ch` é AÇÚCAR DE DIRETIVAS do
pré-processador — `#xcommand`/`#xtranslate` que expandem para chamadas
das primitivas de runtime `__clsNew`/`__clsAddMsg`/`__clsInst`
(implementadas em `src/vm/classes.c`, que é BIBLIOTECA de runtime,
camada distinta e independente do açúcar). Qualquer programador cria
construtos equivalentes com `#xcommand`/`#xtranslate` no próprio
aplicativo. A régua: a ferramenta deve tratar QUALQUER construto
criado por diretiva com o mesmo mecanismo — nada keyed a
classes/hbclass, nem no core nem na ferramenta.

## Estado de fato

**Medido** (número + comando + corpus + data):

- Código real, biblioteca (M-cov): hbhttpd, varredura das 53 mensagens
  distintas com `usages`, 408 sites de send (cobertura 408/408) —
  confirmed 130 (32%), excluded 2 (0,5%), possible 276 (68%). Medição
  de 2026-07-08; método e tabela na seção "M-cov" do
  limites-e-alavancas.md.
- Programas fechados (M-cov 2, delta da B7b): corpus `work/tests`
  (git-ignorado; 230 .prg copiados de tests do core, 76 com sends),
  harness persistido `tests/mcov2.sh` (por-programa, consulta bare por
  mensagem), 967 consultas / 6.249 sites, zero falhas; baseline
  re-medida com o binário pré-B7b no MESMO harness. confirmed
  1.597 (25,6%) → 1.715 (27,4%): +118 upgrades, zero downgrades.
  Medição de 2026-07-08; tabelas nas seções "M-cov 2" e "Delta da
  B7b" do limites-e-alavancas.md.
- Fatia `-kt` (commit `c1927dfcac`): zero impacto sem a flag — 224/224
  .hrb byte-idênticos (árvore src/ do harbour, 112 módulos × -w0 e
  -w3, protocolo padrão de zero impacto do branch, rodada de
  2026-07-08); cheques disparando em execução (fixture
  `tests/fixkt/`, caso 87 da suíte, 17 checks). Suíte completa da
  ferramenta: `tests/run.sh` — 616 checks / 0 falhas, saída
  byte-idêntica paralelo × JOBS=1 (2026-07-08, estado hoje em
  `6584aa8`).

**Diagnóstico** (inspeção manual do nó receptor no dump — inferido a
partir da medição, não medição cega; sites não localizados: 4 na
M-cov, 20 na M-cov 2): causas dominantes do indecidido — classes
montadas em runtime, parâmetros estruturalmente abertos (hbhttpd é
biblioteca: call sites fora do projeto), blocos avaliados na RTL.
Detalhamento por balde nas mesmas seções do limites-e-alavancas.md.

**Interpretação** (juízo, não fato — é isto que a revisão deve
desafiar): os baldes dominantes remanescentes são lidos como
inalcançáveis por análise estática (teorema de Rice); a própria M-cov 2
mostrou antes que parte do indecidido era lacuna de inferência fechável
(a B7b fechou 118 sites) — a fronteira entre "fechável" e "Rice" é
leitura, não medição.

## Perguntas ao revisor (responder UMA a UMA, com veredito)

**Q1.** O canal de tipos consumido pela ferramenta vem da GRAMÁTICA do
Harbour (`AS CLASS <nome>` → cType 'S'; subsistema
`DECLARE`/`_HB_CLASS`/`_HB_MEMBER`). A gramática em si privilegia
"classe" como conceito. Consumir/impor esse canal (ast-4/ast-7, `-kt`)
contradiz R2? Ou o canal é neutro porque é da LINGUAGEM e não da
biblioteca? Onde exatamente (arquivo:linha) o código trata classe como
mais do que "um construto qualquer de diretiva"?

**Q2.** A máquina de resolução de dispatch da ferramenta
(`ClassGraph`, `ResolveDispatch`, `B7MethodRet`, oráculo
`src/rtl/tobject.prg`, `SendVerdict` — hbrefactor.prg, região
~5900-7800) e a de cadeias de construção (B7/B7b: binding único, união
de call sites, retorno por pushes rotulados) — isso é INFERÊNCIA nos
termos de R1? Os rótulos com ressalva ("class graph as written",
"possible ... unproven") salvam a honestidade, mas o dono não quer
triagem: essas camadas deveriam existir?

**Q3.** Dado R1+R2, qual seria o SEU desenho para ferramentaria de
refatoração de Harbour? Especificamente: o que você manteria do que
existe (ex.: renames verificados por recompilação + oráculo, o dump
`-x`), o que removeria, e que extensão de CORE (no sentido amplo de R1)
você faria no lugar das anotações de classe — existe um caminho de
INVARIANTE genérica por construto de diretiva (em vez do sistema de
tipos class-aware da gramática)?

**Q4.** A fatia `-kt` (commit `c1927dfcac` no harbour-core): é
"estender o core" legítimo por R1, ou perpetua o privilégio de classe
por R2 (o ramo 'S' com is-a em `__HB_CHKTYPE`)? Vale manter,
re-desenhar ou reverter?

**Q5.** Veredito de viabilidade, franco: dado o teto medido e as
réguas, a linha atual compensa? O que você mataria, o que re-escoparia,
e o que consideraria o produto mínimo defensável?

## Formato da resposta

Por pergunta: veredito curto + evidência (arquivo:linha) + argumento.
Ao final: recomendação única e acionável (manter/re-escopar/redesenhar/
descartar, com a lista concreta do que fazer). Se discordar das
próprias réguas R1/R2 (ex.: "zero inferência é meta errada para este
domínio"), diga — o dono pediu contraponto, não obediência.
