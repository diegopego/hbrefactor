# Spec B7 — Tipos interprocedurais (alavanca B): receptor de send por fato

Status: **IMPLEMENTADA (fatias 1+2, 2026-07-08) — AGUARDA RITO D4**
(5 checks/6 sites flipam; nenhum assert alterado até a aprovação caso a
caso). Critério do fixext PROVADO por execução. Fronteira registrada:
retorno por primitiva C (`__clsInst` do fixofi) não tem fato de
compilação — permanece possible; o veneno do forjador (Q4/caso 75)
alcança a TIPAGEM aninhada em mundo fechado com o rótulo carregando a
ressalva (probe fixq4+m3 executado — ver seção TypeOf do ast-schema).
Decisões: D1 = travessia de vínculo escrito na tipagem VALE, em mundo
fechado com ressalva no rótulo (precedente da camada excluded
closed-world pós-Q4); D2 = gancho ast-6 APROVADO (entregue: `"ret":
true` no push de RETURN, prova de zero impacto 224/224 .hrb
byte-idênticos em -w0 E -w3, relink duplo harbour+hbmk2 conferido por
strings); D3 = teto de runtime pelo oráculo APROVADO (compilar
tobject.prg com -x, cache; degradação honesta sem a árvore); D4 =
flips apresentados caso a caso ANTES de mudar qualquer assert.
(A regra TypeOf do ast-schema era FECHADA — este portão é a extensão
autorizada; asserts existentes só mudam pelo rito D4.)
Motivação: fricção relatada (Diego, 2026-07-08) — no fixext, usages de
`Deposita` mistura os sends de `oC` (Conta) e `oV` (ContaVip): os 4
sends saem `possible (receiver unknown)` nas duas consultas.

## Fatos estabelecidos por probe (2026-07-08, dump real do fixext)

1. **Onde a cadeia quebra hoje**: `oC := Conta():New()` — `Conta()` JÁ
   tipa (`declared.functions`: auto-declaração `AS CLASS CONTA` que o
   `_HB_CLASS` emite), e `oC` é binding único (regra atual alcançaria).
   Quebra no `:New()`: CONTA não declara NEW (sem `METHOD New ...
   CONSTRUCTOR` no fixture) — o método vem herdado da raiz de runtime.
2. **O fato existe no fonte da linguagem**: `src/rtl/tobject.prg` —
   HBObject registrado por `HBClass():New(...)` + `AddMethod("NEW",
   @HBObject_New())`; `HBObject_New(...)` → `RETURN QSelf()` (devolve o
   RECEPTOR). Ou seja: "New herdado devolve a instância que o recebeu" é
   derivável COMPILANDO tobject.prg com `-x` (oráculo, não réplica) — a
   mesma técnica de registro runtime que a B4f-3 já lê (fixofi:
   `__clsNew`/`__clsAddMsg` por stringify).
3. **RETURN no dump**: o valor de RETURN vira statement `push` na árvore
   (`CONTAVIP_DEPOSITA`: push do `SEND NSALDO em SELF`), mas o push NÃO
   é rotulado — condição de IF/WHILE e limites de FOR também são push.
   Identificar RETURN por posição de token seria réplica; o fato limpo
   pede 1 gancho gated no core (ast-6, campo no push do RETURN).
4. **Custo zero fora do alvo**: nada disso toca pcode; é análise na
   ferramenta + (se aprovado) transporte de 1 rótulo no dump.

## Regra proposta (extensão da TypeOf: ponto fixo sobre o projeto)

Hoje a TypeOf é local e sem ordem (declarada + binding único + retorno
declarado). A extensão: **ponto fixo sobre os dumps de TODOS os módulos
do projeto**, com conjunto finito de classes por símbolo:

- **Reticulado**: `⊥` (sem fato) → conjuntos finitos de classes
  (com proveniência por elemento) → `⊤` (aberto = possible de hoje).
- **Sementes**: tipos declarados (`AS CLASS`, tabelas `declared`),
  retorno auto-declarado de função-classe, literais de valor.
- **Propagação**: ASSIGN une o conjunto do RHS ao símbolo; RETURN
  (rotulado, fato 3) une ao retorno da função; chamada une retorno da
  função ao site; parâmetro une os conjuntos dos argumentos de TODOS os
  call sites do projeto; send com receptor de conjunto conhecido propaga
  o retorno do método RESOLVIDO (regras B4f-2: acerto próprio decide).
  Itera até estabilizar (conjuntos só crescem; converge).
- **Venenos → ⊤, sempre**: símbolo passado por `@ref`; escrita via
  macro `&`; local capturada por codeblock que a escreve (detached
  write); `Self := x`; elemento de array/hash (não rastreado); FIELD/
  alias; função cujo nome aparece nos pontos cegos do
  `find-dynamic-calls` (string que a nomeia / `&` no projeto) tem
  parâmetros ⊤ — mundo fechado só com o fechamento AUDITADO.
- **Consumo**: receptor com conjunto unitário → confirmed/excluded
  pelas camadas B4f-2 existentes; conjunto finito >1 → possible
  nomeando os candidatos; ⊤ → possible como hoje. Todo rótulo novo
  nomeia a cadeia de fato (mesma disciplina dos rótulos atuais).

## Decisões do portão (Diego)

**D1 — Travessia de vínculo escrito na TIPAGEM.** Para tipar
`Conta():New()` é preciso resolver NEW em CONTA — que só existe via
pai escrito (raiz HBObject). A Q4 fixou: travessia de vínculo escrito
não confirma/exclui DISPATCH. Aplicada dura à tipagem, o fixext
continua possible (o objetivo morre). Alternativa (recomendada): a
tipagem que atravessa vínculo escrito vale com a MESMA natureza da
camada "excluded ... within the project's class graph" que sobreviveu à
Q4 — mundo fechado do grafo, rótulo carregando a ressalva (ex.:
`excluded send (receiver class CONTA via construction chain, class
graph as written)`). Forte: precedente epistêmico já existe e o rótulo
é honesto. Fraco: um forjador de hierarquia (veneno da Q4) tornaria o
rótulo enganoso NO MUNDO ABERTO — a ressalva no rótulo é o que o
mantém honesto.

**D2 — Gancho ast-6 no core (RETURN rotulado no push).** 1 linha gated
(`fAst`) no reduce do RETURN marcando o push (`"ret": true`). Forte:
mata a ambiguidade push-de-RETURN × push-de-condição sem réplica.
Fraco: toca o core (protocolo completo: zero impacto -w0 E -w3 com
`.hrb` byte-idênticos, relink duplo harbour E hbmk2) e adianta um bump
de schema. Alternativa sem core: não usar RETURN não-declarado (o
ponto fixo só propaga retornos declarados + QSelf da raiz) — cobre o
fixext mas NÃO cobre fábrica sem DECLARE (`FUNCTION NovaConta();
RETURN Conta():New()`), que é o caso real de projeto grande.

**D3 — Teto de runtime pelo oráculo.** Compilar UMA vez (com cache) os
fontes de classe do runtime do próprio Harbour (`src/rtl/tobject.prg`;
avaliar `tclass.prg`) com `-x` e consumir esses dumps no ponto fixo —
"HBObject:NEW devolve QSelf()" vira fato de compilação do fonte da
linguagem, não convenção embutida. Forte: zero réplica, e QSelf() é o
único fato admitido à mão (VM: devolve o receptor do método corrente —
probe executável). Fraco: acopla a análise ao layout da árvore de
fontes (HB_BIN/../../../src/rtl) — degrada honesto (sem a árvore, sem
o fato: possible como hoje). **Fato de QSelf() PROVADO por execução
(probe qself.prg, 2026-07-08)**: classe registrada em runtime puro
(`__clsNew`/`__clsAddMsg`), método `RETURN QSelf()` — o retorno é o
RECEPTOR por IDENTIDADE (escrita via retorno visível no original;
segunda instância intacta), não cópia nem nova instância.

**D4 — Flips de asserts existentes.** 12 asserts de `possible send` na
suíte (unidades 62, 63, 66, 72, 73, 75) podem flipar para confirmed/
excluded/possible-nomeado conforme a forma do fixture. A enumeração
exata (quais flipam e com que rótulo) é a PRIMEIRA entrega da
implementação, apresentada ao Diego caso a caso antes de mudar
qualquer assert (mesma disciplina dos 7 flips da Q4).

## Critério de pronto (executável)

No fixext (`tests/fixext/e1.prg`, MAIN com `oC := Conta():New()` /
`oV := ContaVip():New()`):

- `usages fixext.hbp ContaVip:Deposita` → sends de `oC` (71/73)
  EXCLUÍDOS com fato nomeado; send de `oV` (74) confirmado;
  `::Super:Deposita` (64) com rótulo que nomeie a cadeia (não mais
  "receiver unknown").
- `usages fixext.hbp Conta:Deposita` → simétrico.
- `Self := oOutra` (método Troca) envenena `Self` dali em diante —
  permanece possible (o fixture já carrega o veneno de graça).
- Generalidade (régua dos casos 64/72-74): a mesma capacidade provada
  em DSL NÃO-espelho com dispatch runtime próprio (fixofi) — nenhum
  vocábulo de fixture na ferramenta; nada keyed a hbclass.
- Suíte verde com os flips D4 aprovados um a um; casos novos cobrindo:
  fábrica sem DECLARE (se D2 aprovada), veneno @ref, veneno detached
  write, parâmetro com múltiplos call sites (união), conjunto >1.
