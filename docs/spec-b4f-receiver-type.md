# Spec B4f — tipo do receptor de send (backlog 5: `usages` de método sem falso positivo)

Spec-driven: ORDEM DE SERVIÇO escrita ANTES do código (regra do roadmap).
Escrita em 2026-07-06, na sessão que entregou a P2a, para transferir o
contexto quente (sondagens com evidência arquivo:linha) à sessão executora.
Ler antes: [roadmap.md](roadmap.md) (Backlog item 5 + seção "Limites da
análise e alavancas de core"), [ast-schema.md](ast-schema.md), CLAUDE.md dos
dois repos.

## O problema (reportado pelo Diego, dogfooding hbhttpd, 2026-07-06)

`usages <método>` lista TODO `x:<método>(` como uso — send não carrega
classe. Reproduzido: `LOCAL a := {}` seguido de `a:Paint()` aparece como uso
de `UWLayoutGrid:Paint` ao lado do `g:Paint()` legítimo. Secundário: `usages`
não aceita a forma `Classe:Método` (0 resultados), desalinhado de
rename-method/reorder/call-graph.

## REGRA MAIOR (do Diego — comanda o desenho)

Ajeito é inaceitável. Fato faltante → (1) análise de compilação no CORE
(preferido, mesmo custando código; schema versiona ast-3→ast-4 com
ast-schema.md no mesmo commit); (2) genuinamente dinâmico → relato honesto;
(3) introspecção confiável só se o core for impossível. **Inferência de tipo
por flow analysis NA FERRAMENTA é o ajeito a evitar** (nota do Diego no
backlog 5) — o que for análise mora no compilador.

## Fatos já verificados no fonte (sondagem 2026-07-06, não refazer)

- O compilador PARSEIA e ARMAZENA tipo declarado: `AS CLASS <nome>` →
  `hb_compVarTypeNew(…,'S',…)` (harbour.y:356); `HB_HVAR.cType`/`pClass`
  (hbcompdf.h:96-106); gravação em hbmain.c:463-478. O NOME da classe
  trafega em `HB_VARTYPE.szFromClass` no instante da declaração —
  **capturável por gancho de dump ali** (o `pClass` só resolve com
  `DECLARE CLASS` prévio; sem ele degrada p/ 'O' com W25, mas o NOME
  declarado está disponível no ponto certo).
- **hbclass.ch:263-265 declara `local Self AS CLASS <ClassName> := QSelf()`
  em TODO método** (regra `DECLARED METHOD`, base de METHOD/ACCESS/ASSIGN)
  — receptor `Self` tem classe POR CONSTRUÇÃO, sem custo novo de sintaxe.
- Hoje esse tipo é analiticamente MORTO no compilador (warnings de tipo sem
  call-site) — exportá-lo não muda comportamento de compilação.
- No dump ast-3 o nó SEND já traz `obj` (`VARIABLE X` ou `VARIABLE SELF`) —
  o que falta é só o TIPO de X.
- Caveat honesto a manter no desenho: tipo declarado é PROMESSA do
  programador (o compilador não o verifica em runtime) — o relato da
  ferramenta distingue "confirmado por declaração" de "verificado".

## Fatias (cada uma entregável e testável por si)

### Fatia 0 — só ferramenta, sem schema novo (barata, fazer primeiro)

1. `usages` aceita `Classe:Método` (mesma resolução de PickFunc/P2b).
2. Relato honesto em CAMADAS já no ast-3: definição + sends rotulados
   `possible (dynamic dispatch, receiver unknown)` — remove a MENTIRA do
   rótulo "uso" sem esperar o ast-4 (o call-graph já faz isso com `~>`).
**Pronto**: caso na suíte; a saída do caso do Diego muda de "uso" para
"possível", e `usages UWLayoutGrid:Paint` resolve.

### Fatia 1 — core: SEND ganha a classe do receptor quando determinável (ast-4)

Gancho(s) gated por `fAst`/`fTrackPos` (padrão do branch), zero impacto sem
`-x` (prova: `.hrb` byte-idênticos com/sem, árvore inteira):

- `declarations[]` ganha `"type"`/`"class"` (capturado de
  `HB_VARTYPE.szFromClass` na criação da variável) — Self entra de graça.
- Nó SEND ganha `"rcls"` quando o receptor é variável com classe DECLARADA
  (Self incluso). Cobertura imediata: todo `::`/`Self:` — a maior parte dos
  sends de código OO.
- **Local monomórfica (o caso `a := {}` do Diego)**: decidir NO DESENHO da
  sessão executora onde mora a análise "local atribuída exatamente uma vez,
  sem ref/@, sem macro na função" — a REGRA MAIOR manda core; sondar se o
  compilador tem visão da função inteira no ponto certo (fim de função,
  antes do dump). Alternativa aceitável dentro da regra: o core emite só
  FATOS por variável já disponíveis (contagens/formas de atribuição) e a
  FERRAMENTA cruza dois fatos de compilador (ex.: "única atribuição é
  FUNCALL F" × "F é função de classe pelo rastro") — cruzar fatos ≠
  inferir; o portão do Diego decide a fronteira.
- Versionar `ast-3` → `ast-4`; `ReadAst` aceita ambos; camada "confirmed"
  exige ast-4 (padrão `FromReady`); ast-schema.md no MESMO commit; relink
  duplo (`harbour` E `hbmk2` — armadilha documentada).

**Pronto**: `usages UWLayoutGrid:Paint` no hbhttpd responde em camadas —
`g:Paint()` com `g` de classe conhecida = confirmed; `a:Paint()` com
`a := {}` = excluded ou possible (conforme a fronteira aprovada); zero
impacto sem `-x` provado; suíte verde.

## Desenho da fatia 1 — PROPOSTO AO PORTÃO (sessão executora, 2026-07-06)

Fatia 0 entregue (caso 61). Tudo abaixo é sondagem NOVA desta sessão, com
evidência arquivo:linha e probes no scratchpad via hbmk2/harbour -x.

### Tabela fato→fonte (sondados nesta sessão)

| # | Fato | Fonte |
|---|------|-------|
| 1 | `_HB_CLASS` É o token `DECLARE_CLASS` (lexer), e o CREATE CLASS do hbclass.ch emite `_HB_CLASS <Classe> <FuncClasse>` → `hb_compClassAdd` → a classe fica REGISTRADA na tabela do compilador no próprio módulo. Por isso `Self AS CLASS <C>` resolve `pClass` de verdade e NÃO dá W25 (fixcls limpa sob `-w3 -es2`). | complex.c:158; hbclass.ch:237; harbour.y:1246-1247; probe |
| 2 | `AS CLASS Foo` com classe NÃO registrada: W25 (nível 3) e `cType` degrada p/ `'O'` — o NOME declarado se PERDE do `HB_HVAR` (só `HB_VARTYPE.szFromClass` o tem, no instante da declaração). O ponteiro é identifier interned (vida = compilação inteira). | hbmain.c:463-478; harbour.y:355; probe t25 |
| 3 | `declarations[]` do dump é escrito NO FIM DO MÓDULO a partir do `pLocals`/`pStatics` VIVOS — ou seja, PÓS-otimizador. | compast.c:1210-1216, 942-961 |
| 4 | O otimizador de pcode ("Selfifying" + "Delete unused") REMOVE locais de `pLocals` no fim da função: o `Self` de todo método SOME de `declarations[]` (probe: UWMENU_PAINT decls `[]`; `local o := QSelf()` idem). Trait pré-existente do ast-3 (locais deletados já são omissos hoje). | hbopt.c:1675-1698, 1719-1741; probes |
| 5 | `statements[]` serializa a árvore VIVA no reduce de cada statement (parse-time): nesse instante `pLocals` está INTACTO (Self incluso, com `pClass` resolvido), e toda declaração precede statement executável por gramática. | compast.c:89-91; hbmain.c:398 (E de decl pós-exec) |
| 6 | No serializer, o nó SEND expõe `pObject`; receptor variável = `HB_ET_VARIABLE` com `asSymbol.name`. `::x`/`Self:x` chega como VARIABLE `"SELF"` (lexer sintetiza). | compast.c:724-737, 662-673; complex.c:820-822 |
| 7 | O `sends[]` plano nasce em `hb_compGenMessage` (genc) SEM o receptor no contexto — enriquecê-lo exigiria mudar assinatura de API do core. Desnecessário: join por (linha, msg) com `statements[]`. | hbmain.c:2664-2680 |
| 8 | Parâmetros de codeblock vivem em `value.asCodeblock.pLocals` (`HB_CBVAR`: nome + tipo, SEM nome de classe) — receptor que é param de cb NUNCA pode ganhar classe, e local externa homônima não pode ser confundida com ele. | hbcompdf.h:110-116, 403-409 |
| 9 | A forma monomórfica do Diego JÁ está no ast-3: `LOCAL o := UWMenu():New()` dumpa `ASSIGN{left: VARIABLE O, right: SEND{msg NEW, obj: FUNCALL{fun: UWMENU}}}`; `LOCAL a := {}` dumpa `ASSIGN{right: ARRAY}`; `occurrences[]` já conta write/read/ref por variável. | probe hbmk2 w2.ast.json |
| 10 | `QSelf()` lexa como token SELF (`HB_ET_SELF`). `-s` (syntax only) NÃO grava dump — armadilha de sondagem. | complex.c:147; harbour.y:603; probe |

### O que o ast-4 ganha (core, tudo gated por `-x`)

1. **`declarations[]` + `"type"`/`"class"`**: campo novo `szClassName` no
   `HB_HVAR` (1 linha no branch `'S'` de hbmain.c copiando
   `pVarType->szFromClass` — sobrevive ao caso classe-não-registrada do
   fato 2) + writer emite `"type"` quando `cType != ' '` e `"class"` quando
   houver. Parâmetros (`ParamList`) entram pela mesma via. O `Self` de
   método NÃO aparece aqui (fato 4 — trait mantido e documentado; a classe
   do Self chega pelo item 2, que roda antes do otimizador).
2. **SEND em `statements[]` + `"rcls"`**: na serialização (fato 5), quando
   `pObject` é VARIABLE — incluindo `"SELF"` (fato 6) — resolver o nome em
   `pLocals`/`pStatics`/estáticas file-wide do dono; se a variável tem
   classe declarada, emitir `"rcls": "<CLASSE>"`. Pilha de nomes de
   cb-params na descida (fato 8) impede rcls indevido em param de bloco
   homônimo. WITH OBJECT / receptor-expressão / macro: sem `rcls`, honesto.
   Cobertura imediata: TODO `::`/`Self:` + toda variável `AS CLASS`.
   Mudança inteira dentro do serializer do compast.c (que só roda com
   `-x`) — fora dele, só o campo do item 1.
3. `sends[]` plano INALTERADO (compat); schema `ast-4`; `FromReady` da
   ferramenta aceita ast-3 e ast-4, camada "confirmed" exige ast-4;
   ast-schema.md no mesmo commit; prova `.hrb` byte-idêntico com/sem `-x`
   na árvore inteira; relink duplo (harbour E hbmk2).

### A fronteira da local monomórfica (decisão do portão)

**Opção A (recomendada) — a ferramenta CRUZA três fatos já estampados**
(nenhum código novo no core além do acima): para um send com
`obj: VARIABLE V` (statements, ast-3 já tem):
- fato 1: `occurrences[]` de V na função — exatamente 1 write, 0 `ref`;
- fato 2: o statement desse write — `ASSIGN` cujo RHS é
  `SEND NEW sobre FUNCALL F` (ou, para exclusão, literal nunca-objeto:
  ARRAY/HASH/STRING/NUMERIC/LOGICAL/DATE);
- fato 3: F é classe do projeto (rastro de derivação — registro que a
  ferramenta já constrói desde a B4d).
Por que isso NÃO é a flow analysis proibida: não há ordem, caminho nem
fixpoint — é um join estático de fatos do compilador. Sustentação: com
única atribuição, o único valor não-NIL que V pode carregar é instância de
F (send em NIL é erro de runtime, nunca dispatch em outra classe); `@V`
excluído pelo fato 1; macro `&` NÃO alcança LOCAL (fato de linguagem);
write dentro de codeblock conta como write (block:true).

**Opção B — o core estampa** (ex.: `declarations[]` ganha `"new": "F"`
quando a única atribuição é `F():New()`): mais superfície de core
(rastreamento incremental por variável em cada ASSIGN + estado por
função), e a classe-idade de F é fato de PROJETO (multi-módulo) que o
compilador de UM módulo não possui — a ferramenta faria o join final de
qualquer jeito. Só compensa se contagem de writes for considerada
"análise que deve morar no core".

### Camadas do relato `usages` no ast-4 (proposta)

- `confirmed send (receiver declared AS CLASS X)` — `rcls` == classe
  consultada. Caveat mantido no rótulo/doc: tipo declarado é PROMESSA
  (não verificado em runtime; polimorfismo pode despachar p/ override em
  subclasse).
- `confirmed send (single assignment V := X():New())` — se Opção A
  aprovada.
- `excluded (receiver can never be an object: V := {})` — SÓ pelo fato
  nunca-objeto (única atribuição a literal não-objeto). Exclusão por
  "classe declarada não relacionada" seria UNSOUND (herança múltipla do
  Harbour: `FROM a, b` permite parentesco fora da cadeia direta) — classe
  declarada não relacionada fica `possible`, com a classe NOMEADA no
  rótulo.
- `possible send (dynamic dispatch, receiver unknown)` — resto (fatia 0).

### Fatia 2 — consumidores extras (anotar, não fazer nesta fase)

call-graph com alvos estreitados por `rcls`; política de unicidade de
P1b/P2b relaxada quando o receptor é conhecido. Backlog.

## Portão (igual P2a)

Apresentar ao Diego a tabela fato→fonte + o desenho da fatia 1 (em
particular a fronteira core×ferramenta da monomórfica) ANTES do volume.
Sondar cada fato novo no scratchpad via hbmk2 (não harbour direto).

## Regras operacionais da sessão executora

Compilar fixture antes de usar; `make test` é o contrato (casos 61+);
commits um a um com autorização explícita do Diego; exportar `HB_BIN` fora
do Makefile (CLAUDE.md); mudança de core = provar zero impacto sem `-x`.
