# Revisão externa (Codex) — segunda opinião: zero inferência e classes como construto de PP

Instrumento de revisão INDEPENDENTE pedido pelo dono do projeto (Diego,
2026-07-09). O revisor NÃO deve assumir nada além do que está no código
e nos documentos citados; deve julgar contra as réguas do dono (abaixo),
com achados verificáveis (arquivo:linha), veredito por pergunta e
recomendação franca. Instrução explícita do dono: **não seja gentil —
contraponto real**. Não há compromisso com o desenho atual: propor
demolição parcial ou total é resposta válida.

## Os dois repositórios sob revisão

1. **~/devel/harbour-core/harbour** — fork do Harbour, branch
   `feature/compiler-ast-dump`. Contém: (a) commits do mecanismo de dump
   AST (`-x`, schemas ast-1..ast-6 — ver `git log --oneline` do branch;
   arquivo central `src/compiler/compast.c` + ganchos gated em
   `harbour.y`/`hbmain.c`/`ppcore.c`); (b) **na árvore de trabalho, SEM
   commit**: a fatia `-kt` (cheques de runtime para as anotações
   `AS <tipo>`/`AS CLASS` da gramática; helper `__HB_CHKTYPE` em
   `src/vm/classes.c`; emissão em `src/compiler/hbmain.c`
   (`hb_compChkType*`) e `harbour.y`; flag em `cmdcheck.c`; schema
   ast-7 com `"kt"`/`"dim"`). `git status`/`git diff` mostram a fatia.
2. **~/devel/hbrefactor** — a ferramenta de refatoração consumidora
   (`src/hbrefactor.prg`, ~8,3k linhas; suíte `tests/run.sh`, 616
   checks). Comandos: renames verificados por recompilação (local,
   static, memvar, param, função, método, palavra de DSL, marker de
   pp), extract, reorder, `usages` com vereditos em camadas
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
tratar classes de forma especial não era minha intenção").** Classes no
Harbour são AÇÚCAR DE DIRETIVAS do pré-processador (hbclass.ch expande
para chamadas de primitivas de runtime — `__clsNew`/`__clsAddMsg`/
`__clsInst`); qualquer programador cria construtos equivalentes com
`#xcommand`/`#xtranslate` no próprio aplicativo. A ferramenta deve
tratar QUALQUER construto criado por diretiva com o mesmo mecanismo —
nada keyed a classes/hbclass, nem no core nem na ferramenta.

## Estado de fato (sem juízo — números medidos)

- Cobertura de decisão sobre sends em código real (hbhttpd, 408 sites):
  32% decidido, 68% "possible". Em corpus de 76 programas fechados
  (6.249 sites): 25,6% antes / 27,4% depois da última fase de
  inferência (B7b, +118 sites). Causas dominantes do indecidido:
  classes montadas em runtime, parâmetros estruturalmente abertos,
  blocos avaliados na RTL — inalcançáveis por análise estática
  (teorema de Rice). Detalhes: seções M-cov/M-cov 2 do
  limites-e-alavancas.md.
- A fatia `-kt` (não commitada) provou: zero impacto sem a flag
  (224/224 .hrb byte-idênticos na árvore src/), cheques funcionando em
  execução (fixture `tests/fixkt/`, caso 87 da suíte).

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

**Q4.** A fatia `-kt` não commitada: é "estender o core" legítimo por
R1, ou perpetua o privilégio de classe por R2 (o ramo 'S' com is-a em
`__HB_CHKTYPE`)? Vale commitar, re-desenhar ou descartar?

**Q5.** Veredito de viabilidade, franco: dado o teto medido e as
réguas, a linha atual compensa? O que você mataria, o que re-escoparia,
e o que consideraria o produto mínimo defensável?

## Formato da resposta

Por pergunta: veredito curto + evidência (arquivo:linha) + argumento.
Ao final: recomendação única e acionável (manter/re-escopar/redesenhar/
descartar, com a lista concreta do que fazer). Se discordar das
próprias réguas R1/R2 (ex.: "zero inferência é meta errada para este
domínio"), diga — o dono pediu contraponto, não obediência.
