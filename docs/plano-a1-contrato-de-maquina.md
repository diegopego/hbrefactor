# Plano — A.1: o CLI vira contrato de máquina para VSCode e Claude

**Ordem do Diego (2026-07-24/25):** *"hbrefactor é algo para ser consumido pelo vscode e
pelo claude. quero que o hbrefactor esteja ideal para o uso do claude e do vscode. não
importa o tamanho das alterações que isso implique. refaça a landing page se preciso."*

Este é o **plano** (o *como* e o *porquê*). A spec executável correspondente é a
**fase A.1** em [roadmap.md](roadmap.md) e a **§2.5** de
[spec-a-oraculo-para-agentes.md](spec-a-oraculo-para-agentes.md). Estado de retomada:
[handoff.md](handoff.md) § 0.

---

## 1. A decisão de arquitetura (final, não re-litigar)

**O CLI tem DOIS consumidores, os dois de primeira classe: a extensão VSCode e o agente
(Claude).** Não há terceiro. Logo:

1. **A saída de um comando é o ENVELOPE (JSON), e nada mais.** Um fato estruturado. A
   apresentação é 100% do consumidor: a IDE desenha a UI dela, o agente vira linguagem
   natural.
2. **NÃO existe renderizador humano no CLI.** A prosa por comando (`Prose()`) é arrasto —
   é a fonte da divergência que já se manifestou (o `usages Class:Method` com dado vazio e
   prosa rica). Ela some.
3. **A flag `--json` some.** Se a saída é SEMPRE o envelope, a flag não tem função.
4. **Exceção — `Usage()`/ajuda é texto puro** (`OutStd`/`OutErr`): não é resultado de
   comando, é ajuda de uso. Fica como está. O agente descobre a ferramenta pelo
   `describe`, não pela ajuda humana.

**Por que não um renderizador humano genérico** (a opção que eu propus e o Diego cortou):
mesmo um só, ele é complexidade que não serve a nenhum dos dois consumidores reais. O
humano que faz refactor de verdade usa a IDE ou o agente — nunca lê o CLI cru. O raro
humano no terminal lê JSON (ou usa `jq`). *"realmente só está provocando complexidade"*
(Diego).

**O envelope** (schema `cli-1`, já implementado em `EnvHash`/`Envelope`):
```json
{ "schema": "cli-1", "command": "...", "status": "ok|refused|usage",
  "reason": null|"<código>", "action": null|"stop-and-report|ask-human-then-retry|fix-environment",
  "detail": "<uma frase p/ o consumidor MOSTRAR>", "diagnostics": [ ],
  "result": { }, "edits": [ ] }
```

**Regras do envelope que não cedem** (spec §2.5):
- **forma estável**: todo campo sempre presente; flag nenhuma muda a forma, só o volume;
- **incerteza é campo POSITIVO, jamais ausência** (`certainty`/`scope`/`truncated` saem
  sempre) — um LLM perde o que está ausente, por construção;
- **o dado é SUPERCONJUNTO da prosa**, nunca subconjunto (o `text` da linha, o `kind`, o
  `owner` — tudo que a prosa mostrava é campo);
- **aviso é `diagnostics[]`**, nunca prosa no stderr (sob o contrato, stderr só carrega
  falha de processo);
- **nomes estáveis entre comandos**; posição é `Location` LSP em todo lugar.

---

## 2. A ORDEM (a única que converge sem um mar de vermelho)

Arrancar a flag AGORA deixaria ~1000 testes vermelhos de uma vez, sem distinguir "quebrei
a lógica" de "teste ainda não migrado". A ordem é VERTICAL, por comando:

### Passo 1 — Completar o CONTRATO de todos os 14 comandos *(a prosa fica como andaime)* ✅ COMPLETO (2026-07-25)
Cada comando modela o `result` inteiro. Os campos que a prosa computava viram campos do
dado. A régua-json (placar) mede a completude. **É este passo que torna a ferramenta ideal
para os dois consumidores** — o resto é limpeza.
- ✅ os 8 de leitura/relato (`usages`, `resolve-at`, `call-graph`, `find-dynamic-calls`,
  `dump`, `snapshot`, `verify`, `projects-of`);
- ✅ **`usages` com o flagrante CONSERTADO** (kind/owner/certainty/text em cada location);
- ✅ os verbos de edição: `rename` (e a família RenameFunction/Local/Static/Memvar/Method/
  RuleMarker/Dsl), `extract-function`, `inline-local`, `reorder-params`, `annotate`,
  `exec-registry`. **Placar PENDENTES da régua-json VAZIO (14/14).**

**Como ficou (o desenho, para não re-derivar):**
- **`edits[]`** (top-level `{uri, range, newText}`, formato LSP `WorkspaceEdit`) sai **só
  sob `--dry-run`** (a régua da spec §2.2: "o que a ferramenta FARIA"); aplicado, sai
  vazio. Builders por representação interna: `WorkFromToken` (troca uniforme dos 7 renames),
  `WorkFromRange` (span de inline/reorder), `WholeDocEdit` (extract = documento inteiro
  reestruturado, honesto e aplicável).
- **`result.locations`** (LSP `{uri, range}`) sai **sempre** — é o que a prosa listava por
  sítio; o dado é superconjunto da prosa (`EditsToLocations` tira o `newText`).
- **`result.verdict`**: `"applied"` (escreveu + verificou) × `"preview"` (`--dry-run`);
  espelha o `verify`. **`result.proof`** = a força da verificação, campo próprio:
  `pcode-identical` (renames byte-idênticos), `expansion-identical` (dsl/rule-marker,
  `.ppo`+`.hrb`), `symbols-preserved` (reorder/inline/extract, pcode muda legítimo),
  `symbols-renamed` (data/method/pp-marker), `gold-standard` (annotate). NIL sob preview
  (nada foi verificado).
- **`result.scope`** (P17 `{complete, unseen[]}`, `ScopeField`) nos verbos com alcance
  condicional (function/static/memvar/dsl/rule-marker); o rename de LOCAL não tem (homônimo
  em ramo pulado é outra variável). `SayScope` cala sob `--json` (o alcance é o campo).
- **avisos → `diagnostics[]`**: referências textuais (`--force`), P4/P5 descartado, P16(b)
  `__LINE__` (`WarnDynLines`), parent fora do projeto. O canal humano (prosa/stderr) fica
  byte-idêntico sem `--json`.
- **recusas load-bearing** (`--force`, `--edit-rules`) ganharam `reason`
  `"textual-refs-require-force"` + `action` `ACT_RETRY` — o que o passo 4 (extensão) lê no
  lugar dos regexes. (A migração dos ~300 códigos de recusa restantes fica para o passo 2.)
- **exec-registry**: o retrato rtr-1 vira `result.snapshot` (aninhado) + `summary`; annotate
  reusa a estrutura do antigo `--json <file>` como `result` do relatório.
- Provas: casos declarativos 133-136 (rename dry-run/aplicado, inline, extract) + 132
  reproposto (exec-registry). Placar régua-json 14/14. `make test` 1046/0.

### Passo 2 — Migrar os ~468 asserts de prosa (`*.log`) para o ENVELOPE *(EM ANDAMENTO)*
Comando a comando. Os ~200 greps em fonte/`.ppo`/`.ast.json` **continuam válidos** (não
dependem de prosa).

**A REGRA DE OURO (Diego, 2026-07-25): fixture EXPECTED, padrão TDD — casedir onde couber.**
Um `grep` de campo (mesmo estruturado, via `tcheck enveq`) é **frágil**: prova um pedaço, não
o que a ferramenta NÃO disse. O caso declarativo (`tests/casedir.sh`: `before/` + `cmd` +
`out` byte a byte [+ `after/`]) prova o envelope **inteiro** — é o menos frágil. **Preferir
casedir para toda asserção de saída de comando único.** Reservar o imperativo + helpers
estruturados só para o que casedir não modela (idempotência A→B→A, saída-de-programa
idêntica, baterias multi-passo de recusa).

**Ferramentas de asserção estruturada** (`tcheck`, para o caso imperativo): `enveq <json>
<dot-path> <val>` (campo == valor; `result.` implícito), `envhas <json> <path> <substr>`,
`envrow <json> <array> "k=v;k=v"` (linha de `edges`/`findings`/`locations` casa os pares),
`envloc <json> <arquivo:linha> ["kind in owner"]`.

**GAP DE COMPLETUDE achado (e consertado) ao migrar o caso 38:** o `usages` de uma **palavra
de pp/DSL** emitia envelope **mais pobre que a prosa** — `kind: "occurrence"` genérico, `text:
null`, e faltavam a **diretiva** e o **in-rule-match**. A régua-canais não pegou porque só
exercitava `usages Dupla` (função simples). Consertado em `DslHits`/`RuleSiteHits` (a location
recebe a MESMA classificação que a prosa já monta — §2.5.0, um fato duas vistas); régua-canais
**estendida a uma palavra de DSL**; caso **137** (fixture expected byte-a-byte) trava as 5
locations com kind+text. **Nota de método: cada comando com prosa mais rica que `usages Dupla`
merece um caso da régua-canais próprio — o gap volta calado sem isso.**

**§5 — leaks de português no PRODUTO consertados** (o CLI é inglês; a conversa é PT): a recusa
de sequestro (`sequestraria`→`hijack`), o aviso de string do extract (`soletra`→`spells out`,
e roteado a `diagnostics[]` sob `--json`), e a recusa de órfão (`renomear`→`renaming`).

### Passo 3 — Arrancar a prosa e o modo
Quando NENHUM teste ler prosa: deletar `Prose()` (a função e os 133 sítios — o fato já
está no result), `s_lJson`, `s_lEmitted`, `TakeJsonFlag`, o gate de
`no-machine-contract-yet`, o envelope-fallback, a flag `--json`. Vira sempre-envelope.

### Passo 4 — Extensão VSCode reacoplada
Os 4 regexes de prosa (`extension.js` 235/280/290/368) morrem: a extensão lê `reason`/
`action`/`verdict` como campos. O `verify` já tem `verdict` campo (mata o `/BROKEN/`).

### Passo 5 — Landing page e manual
A `tests/site/` mostra transcrição do CLI (prosa). Sem prosa, ou a página passa a mostrar a
experiência da **IDE**, ou aceita blocos de JSON. Decisão do Diego pendente (registrada no
handoff). O manual (`docs/manual.md`) idem.

---

## 3. Os PORTÕES executáveis (já existem, mantê-los)

- **`tests/regua-json.sh`** — nenhum comando sai calado sob o contrato; **placar** de
  pendentes explícito (`annotate exec-registry` hoje) que encolhe a cada migração. Mede
  COMPLETUDE, não só não-mudez (rejeita o fallback).
- **`tests/regua-canais.sh`** — a prosa não mostra fato que o JSON não tenha. **Recusa
  passar sem ter medido** (já passou por vacuidade uma vez — sem `HB_BIN`). No passo 3 ela
  vira redundante (não há prosa) e sai.
- **`tests/casedir.sh`** — o formato declarativo (before/cmd/after/exit/out), byte a byte.

---

## 4. Armadilhas (custaram caro nesta sessão)

- **Régua que passa por VACUIDADE** — sem `HB_BIN`, o binário não roda, as listas ficam
  vazias, a régua passa. **Aconteceu 3×.** Toda régua nova tem de RECUSAR passar sem medir.
- **`Say`/`Prose`**: `SAY` é palavra da linguagem (`@ ... SAY`). O canal humano chama-se
  **`Prose()`** (vai ser deletado no passo 3, mas até lá não renomear para `Say`).
- **Artefato vazando no `before/`** de um caso: NUNCA rodar o comando dentro de `before/`;
  copiar para um tmp. `annotate`/`exec-registry` geram `.astr.json`/binário.
- **`hb_jsonEncode( h, .T. )`** formata array/objeto vazio como `[\n  ]` — o esperado tem de
  casar o formato exato. **A recomendação que estava aqui — *"gerar de uma execução real, nunca
  escrever à mão"* — foi REVOGADA pelo Diego (2026-07-26): é a premissa errada que construiu a
  pasta `tests/cases/` inteira.** Gravar congela o defeito atual como se fosse contrato; o
  esperado se escreve À MÃO, ANTES (`tests/README.md` § 2, cicatrizes § 6.4). O formato exato do
  JSON se acerta no primeiro diff — é só isso que ele custa.
- **`kind` e `certainty` SEPARADOS**: o `SendVerdict` devolve "confirmed send (...)"; a
  certeza é a 1a palavra (`FirstWord`), o kind é "send". Não misturar no campo.
- **`LocationsJson` devolve HASH-array, não string** (mudou nesta sessão): o `tcheck.JLoad`
  desembrulha `result.locations`.

---

## 5. O critério de PRONTO (executável)

- `describe --json` lista todos os comandos; comando vivo fora dele reprova a suíte.
- Todo comando emite o envelope; a régua-json com **placar vazio** (14/14).
- Nenhuma decisão de fluxo da extensão casa prosa (grep no `extension.js` = 0).
- `certainty`/`scope`/`truncated` presentes em 100% dos vereditos.
- `--dry-run` devolve `edits[]` nos verbos que editam.
- Régua do não-objetivo: nenhum `anthropic|openai|api[_-]?key|https?://` no fonte.
- `make test` verde; `make ppcorpus` verde; `make site-check` verde (após o passo 5).
