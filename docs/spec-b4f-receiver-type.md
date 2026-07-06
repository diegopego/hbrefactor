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
