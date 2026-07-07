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

## Fatia 1 — ENTREGUE (v3 "canal de tipos da linguagem", 2026-07-06)

Fatia 0 entregue (caso 61, commit 02ed8db). O desenho passou por DOIS
portões: a v2 ("receivers[] com veredito no core") foi aprovada e depois
REVERTIDA pelo Diego com o requisito final — *quando qualquer programador
criar seus próprios comandos de pp, a refatoração deve lidar com eles SEM
alterar harbour nem hbrefactor* — que a v2 violava (`F():New()` é
convenção do hbclass bakeada no compilador). A v3 abaixo foi aprovada e é
o que está construído. Tudo com evidência arquivo:linha e probes no
scratchpad via hbmk2/harbour -x.

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
| 11 | `AS`/`DECLARE` são GRAMÁTICA DO COMPILADOR, não comando de biblioteca (desafio do Diego, provado): tokens no lexer, produções na gramática; probe sem NENHUM include compila `LOCAL o AS CLASS Foo` + `DECLARE F(x AS NUMERIC) AS CLASS Foo` com `.ppo` byte-idêntico ao fonte e W25 do COMPILADOR. A única relação do hbclass com `AS` é APAGÁ-LO sob `HB_CLS_NO_DECLARATIONS`. | complex.c:110/114/205-224; harbour.y:184-185/341-368/1226-1330; hbclass.ch:137-143; probe prova-as |
| 12 | O subsistema DECLARE inteiro é write-only (zero pcode; warnings de tipo nível 3/4 na tabela nem têm site de emissão) e gated por `iWarnings < 3` em 5 funções (ClassFind/ClassAdd/MethodAdd/DeclaredAdd/DeclaredParameterAdd). `hb_compClassAdd` AUTO-DECLARA a função-classe devolvendo `AS CLASS <Classe>`; `METHOD ... CONSTRUCTOR` faz o hbclass emitir `_HB_MEMBER ... AS CLASS _CLASS_NAME_` — a cadeia `Classe():New()` é TODA declarada. | hbmain.c:1067-1355; hbclass.ch:283; inventário Explore; probe prova-ctor |
| 13 | Tabelas DECLARE vivas no fim do módulo: `hb_compAstSave` roda ANTES do `hb_compDeclaredReset` do módulo seguinte. | hbmain.c:4599 vs 4300 |
| 14 | `HB_HDECLARED.pClass`/`pParamClasses[i]` NÃO são inicializados quando o tipo não é 'S' — lixo de malloc/realloc (segfault real na primeira versão do writer; corrigido com init NULL + guarda por cType). | hbmain.c allocs; crash probe |

### Requisito final do Diego (portão v3, 2026-07-06)

"Quando qualquer outro programador criar seus próprios comandos, o sistema
de refatoração deve ser capaz de lidar com eles também sem exigir
alterações ou no harbour ou no hbrefactor." Consequência: NENHUMA convenção
de biblioteca em lugar algum — nem `F():New()` reconhecido no core (v2),
nem regras hbclass na ferramenta (v0/A). O que sobra é exatamente o que a
linguagem oferece: **o canal de tipos da gramática** (fatos 11-12), que o
hbclass JÁ usa por inteiro (é só o primeiro cliente) e que qualquer comando
novo pode usar na expansão.

### O que foi construído no core (harbour, gated por `-x`)

1. **Gates do subsistema DECLARE abertos sob `fAst`**: os 5
   `iWarnings < 3` viram `iWarnings < 3 && ! fAst` (hbmain.c) — as tabelas
   passam a existir em QUALQUER nível de warning quando há dump; toda a
   emissão de warning continua gated por nível (nada novo aparece sem
   -w3), e o erro de `_HB_MEMBER` órfão só dispara em -w3 (comportamento
   de hoje preservado — projeto que compila continua compilando com -x).
   Higiene: `pClass = NULL` nos allocs de HB_HDECLARED (fato 14).
2. **`declarations[]` recapturado no PARSE** (gancho de 1 linha
   `hb_compAstDecl` em `hb_compVariableAdd`, compast.c): imune ao
   otimizador (fato 4 — o Self de método aparece, tipado) e ao gate -w3;
   `type` = caractere declarado, `class` = NOME COMO ESCRITO (fato 2:
   sobrevive à classe não registrada). Campo `used` morreu (era
   pós-otimizador; derivável de occurrences). Escopo novo `public`.
3. **Seção `declared` por módulo**: transporte 1:1 das tabelas
   HB_HCLASS/HB_HDECLARED no fim do módulo (fato 13) — classes com
   assinaturas de métodos (retorno/params, classe quando 'S'), funções
   declaradas (inclui a auto-declaração da função-classe, fato 12).
   Nenhuma struct do compilador mudou; nenhum nome de mensagem/convenção
   no writer (o caso 64 verifica por grep).
4. Schema `ast-4`; `sends[]`/`statements[]`/`tokens[]`/pp intactos. Prova
   de zero impacto: 32 comparações `.hrb` com/sem `-x`, em -w0 E -w3
   (os gates mexem justamente abaixo de -w3), byte-idênticas; relink
   duplo verificado por `strings`.

### O que foi construído na ferramenta (hbrefactor)

1. `ReadAst` aceita ast-2/3/4; `FromReady` = ast-3+; `Ast4Ready`/
   `DeclTables` (agregado do projeto — as tabelas são por módulo) gateiam
   a classificação: projeto com dump antigo degrada para `possible`.
2. **`TypeOf`** — propagação determinística de tipos DECLARADOS sobre a
   árvore de `statements[]`, regra FECHADA (sem ordem/caminhos/fixpoint):
   VARIABLE (classe declarada; senão binding único = 1 write + 0 refs +
   um só ASSIGN de topo → tipo do RHS; ciclos quebrados por conjunto
   visitado), SELF, FUNCALL (retorno declarado), SEND (retorno declarado
   do método na classe do obj — cobre send ENCADEADO de graça), literais
   de valor, LIST (último item). Sombra de codeblock: `detached` =
   local externa (classifica); `local`+block = parâmetro do bloco (não —
   fato 8). memvar/field: nunca (escopo dinâmico).
3. `usages`: cada send classificado via `SendReceiverType` (join
   linha+mensagem entre `sends[]` e os nós SEND de `statements[]`;
   candidatos múltiplos só classificam se concordarem; WITH OBJECT/macro
   → desconhecido). Camadas impressas:
   - `confirmed send (receiver declared AS CLASS X)` — declaração direta
     (Self incluso);
   - `confirmed send (receiver class X via declared types)` — cadeia
     declarada (ctor, DECLARE à mão, DSL próprio);
   - `excluded send (receiver holds a value of kind <k>)` — binding único
     a literal de valor;
   - `possible send (receiver class X, relation to Y unknown)` — classe
     conhecida ≠ consultada (herança múltipla NÃO deixa excluir);
   - `possible send (dynamic dispatch, receiver unknown)` — resto
     (fatia 0).
4. Regressão corrigida de carona: o extract-to-method migrava o `SELF`
   (que agora aparece em declarations) como local — SELF é o RECEPTOR,
   fora da partição de data-flow.

### Casos entregues (suíte 402/0)

- **61** (fatia 0): `Classe:Método` + camada possible; `a := {}` promovido
  a excluded pela fatia 1.
- **62**: canal completo — ctor-cadeia confirmed, `AS CLASS` confirmed,
  `::`/Self confirmed, `a := {}` excluded, `@` possible, reatribuída
  possible, `DECLARE` à mão confirmed, cross-módulo confirmed.
- **63**: honestidade — classe SEM ctor declarado e função desconhecida
  ficam possible; nome cru também classifica.
- **64 (A PROVA DO REQUISITO)**: DSL INVENTADO (`gizmo.ch`: CONTRAPTION/
  APTITUDE/GIZMO) que declara pelo canal na expansão → confirmed,
  inclusive encadeado, SEM nenhuma mudança em harbour/hbrefactor — e
  greps provam que ferramenta e core não mencionam o DSL nem mensagens
  por nome.
- **65**: consistência — invariantes do ast-4 sobre o dump real (Self
  tipado em todo método, declared coerente, binding único re-derivado de
  occurrences+statements, contraexemplo com 2 writes).

### Caveats honestos (registrados no ast-schema.md)

Tipo declarado é PROMESSA (não verificado em runtime; polimorfismo);
`excluded` por valor não cobre classes ESCALARES associadas em runtime (o
rótulo nomeia o fato); classe conhecida ≠ consultada fica possible
(herança múltipla); classe não registrada no módulo degrada o retorno nas
tabelas declared (idioma: declare a classe no módulo).

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
