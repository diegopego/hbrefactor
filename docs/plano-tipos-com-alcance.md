# Tipos declarados COM ALCANCE — e o cursor que os consome

> **Este arquivo é PLANO, não registro.** Nada aqui foi provado, nada foi implementado.
> A spec executável (escopo + critério de pronto) mora na **P14** do [roadmap.md](roadmap.md).
> Origem: sessão de 2026-07-13 (situação levantada pelo Diego; exploração e desenho nesta sessão).

---

## O pedido que abriu a investigação

Num projeto com classes homônimas — três classes, todas com `METHOD Brilho()`:

```prg
CREATE CLASS Farol
   METHOD New() CONSTRUCTOR
   METHOD Brilho()
ENDCLASS
METHOD Brilho() CLASS Farol
   RETURN 1
// ... idem Totem, idem Idolo

PROCEDURE UsaRig()
   LOCAL oF := Farol():New()
   LOCAL oT := Totem():New()
   LOCAL oI := Idolo():New()

   oF:Brilho()
   oT:Brilho()
   oI:Brilho()
RETURN
```

**A coluna do cursor tem de selecionar QUAL símbolo está em jogo:**

- cursor sobre **`oF`** → os usos **daquele** `oF` (o local daquela função), e nada de método;
- cursor sobre **`Brilho`** em `oF:Brilho()` → declaração + definição do `METHOD Brilho` **de Farol**,
  e só os envios que atingem Farol — **não** `oT:Brilho()`, **não** `oI:Brilho()`.

E a mesma máquina alimenta um **go to definition** (é a mesma consulta, outro recorte de saída — e o
`rename` já senta em cima dela).

---

## Os dois achados que reordenaram o trabalho

### 1. A ferramenta JÁ resolve o receptor — o buraco é o CURSOR

`tests/fixhom/m1.prg` é, letra por letra, o exemplo acima. E `tests/run.sh:1978-1981` já assere hoje, para a
consulta **por NOME** (`usages fixhom.hbp Totem:Brilho`):

```
confirmed send (receiver class TOTEM via declared types) in USARIG  | oT:Brilho()
excluded send within the declared class graph (dispatches to FAROL:BRILHO) in USARIG  | oF:Brilho()
```

A corrente fecha **só com fato declarado**: `hbclass.ch:239` emite `_HB_CLASS Farol Farol`;
`hbclass.ch:283-284` expande `METHOD New() CONSTRUCTOR` para `_HB_MEMBER New AS CLASS _CLASS_NAME_`;
`hbmain.c:1135-1137` auto-declara o retorno da função-classe. Logo `Farol():New()` **é** um FAROL, e o
`TypeOf()` da ferramenta (src:7841) já sabe.

**O que não funciona é o cursor.** `ResolveAtQuery` camada 4 (src/hbrefactor.prg:1924-1945) vê o token `:`
anterior, diz "site de envio" e devolve a consulta **NUA** (`Brilho`, dono `NIL`) — **nunca pergunta quem é o
receptor**. Sem classe, o veredito reporta os envios das três classes juntas e as três definições.

E **`tests/run.sh:2347` fossilizou o bug como contrato**: exige `query: Brilho` sob o rótulo
*"send é dispatch dinâmico: consulta crua honesta"*. Era verdade quando foi escrito; hoje é **falso** — a
ferramenta sabe a resposta e a joga fora.

### 2. O Harbour já tem um sistema de tipos declarados — completo, e SEM ALCANCE

As três peças existem:

| peça | onde |
|---|---|
| **linguagem de anotação** — `AS <tipo>` / `AS CLASS <X>` | `harbour.y:343` (`AsType`), `:373` (params) |
| **tabela de declaração** — `DECLARE`, `_HB_CLASS`, `_HB_MEMBER`, `_HB_SUPER` | `harbour.y:1245-1269`; `hbmain.c:1078-1246` |
| **EXECUTOR** — `-kt` (`HB_SUPPORT_CHKTYPE`) emite `__HB_CHKTYPE( valor, spec, sítio )` e **impõe** as anotações em runtime | `hbmain.c:2771` (params, prólogo), `:2834` (`RETURN`) |

O programador **pode** declarar, o compilador **registra**, e o `-kt` **verifica**. A máquina inteira está
montada. **O que falta é ALCANCE.**

---

## O REENQUADRAMENTO — a frase que governa este plano

> **As paredes não são "não dá para inferir". São "o programador não tem como DIZER — e onde ele diz, o
> compilador joga fora".**

Estender o Harbour aqui **não é ensinar o compilador a adivinhar**: é dar **alcance** às anotações e deixar o
`-kt` executá-las. Toda parede cai **por declaração**, jamais por inferência. É o **oposto** de heurística —
em vez de *deduzir* fato, **fabrica-se fato declarado e verificado**.

---

## Os quatro fatos que o core DESCARTA hoje

| # | Fato descartado | Onde | Consequência |
|---|---|---|---|
| **E1** | `FUNCTION F() AS CLASS Farol` **NÃO COMPILA** — a regra `Function` não aceita `AsType` | `harbour.y:329-335` | E `hb_compChkTypeRetWrap` **já faz `hb_compDeclaredFind( pFunc->szName )` e impõe o retorno declarado** (`hbmain.c:2845`). **A execução existe e não tem o que executar**, porque só um bloco `DECLARE` separado (`harbour.y:1245`) declara — e ninguém escreve isso. **É a parede do `oX := AlgumaFabrica()`.** |
| **E2** | `AS CLASS` como **cast em expressão** é parseado e **descartado** (`{ $$ = $1; }`) | `harbour.y:845-875` | Some inclusive o `RETURN s_oClass:Instance() AS CLASS _CLASS_NAME_` que o **próprio `hbclass.ch:261`** escreve. Honrá-lo dá a **saída de emergência universal**: `oX := Factory() AS CLASS Farol`. |
| **E3** | `_HB_SUPER` é parseado e a **ação da gramática está VAZIA** | `harbour.y:1277-1278` | O core **nunca liga o pai** → `hb_compMethodFind` é own-hit only → método herdado vira falso "desconhecido", e a ferramenta teve que construir o `ClassGraph` dela sozinha (src:11022-11045). |
| **E4** | Parâmetro **já** aceita `AS CLASS` (`harbour.y:373`) e o `-kt` **já** o confere no prólogo | — | Logo `F( @oF )` com parâmetro declarado **já é fato** — e a ferramenta envenena para desconhecido **sem olhar** (src:7855-7870). **Sem mudança de gramática.** |

A **única** parede que fica de pé é a do **macro** (`o:&cMsg()`) — e ela **deve** ficar. **Recusa honesta é
produto.**

---

## A LINHA entre FATO e PALPITE *(decidida nesta sessão — é a contribuição conceitual do plano)*

O motor interprocedural **já existe** e está desligado de propósito (`hInter := NIL`, src:563 — portão RE.3,
2026-07-09): `B7FunRet`, `B7ParamType`, `B7SendRet`, `B7BlockEvalType`, `B7InlineSelfType`.

**O desligamento em bloco foi correto no efeito e GROSSO na causa.** Dentro dele há duas coisas de naturezas
opostas:

- **Dedução FECHADA** — o conjunto de fontes é **enumerável por construção** → é **FATO**, pode julgar.
  *Retorno de função*: **todos** os `RETURN` de `F` estão no corpo de `F`, e o compilador vê o corpo inteiro.
  "Todos dão a mesma classe declarada, ou desconhecido" é **exaustivo** — logo **não pode errar**.
  *Escrita do callee num parâmetro por referência*: idem, as atribuições estão no corpo do callee.
- **Dedução ABERTA** — exige enumerar o **inenumerável** → é **PALPITE**, só sugere.
  *Tipo de parâmetro pela união dos call sites*: **não se listam todos os chamadores** (macro, call-by-name,
  função exportada, outro projeto). **`B7ParamType` cai aqui e fica desligado no veredito PARA SEMPRE**; o
  lugar dele é o `annotate`, onde já está.

**Corolário**: a diferença entre "a ferramenta infere" e "o core infere" **não é o repositório onde o código
mora**. Algoritmo insano não vira são ao ser reescrito em C. O que legitima é **exaustividade +
colapso-para-desconhecido**, e só isso.

---

## O que NÃO é caminho (e por quê) — o preprocessador

O pp **varre todas as linhas** (é filtro de stream; toda linha passa por ele). Mas o que ele vê são **TOKENS**,
não **PROGRAMA**: ele não tem noção de função, escopo, declaração ou expressão — casa padrão e substitui
texto. Dar-lhe tipos exigiria tabela de símbolos, rastreio de escopo e parse de expressão — ou seja, **um
segundo parser dentro do core**, divergente do de verdade. É **réplica de gramática** (CLAUDE.md §1.2/#2 e #4)
— e seria pior que heurística na ferramenta: seria heurística **vestindo a autoridade do core**. Some a isso
que o pp **não vê os outros módulos**, e tipo é pergunta de projeto inteiro.

**E o pp já faz o papel certo nesta arquitetura**: é ele que **DECLARA** (`_HB_CLASS`, `_HB_MEMBER`,
`AS CLASS` do CONSTRUCTOR); o compilador é quem **RESOLVE**. Pedir ao pp que também resolva é pedir que ele
seja o compilador. **Os fatos já vêm dele — eles morrem DEPOIS, sem leitor.**

---

# FASE 0 — SONDAR AS PAREDES antes de derrubá-las

*Ordem do Diego: **"sondar antes de decidir"**. Mede-se a parede **antes** de gastar gramática nela.*

**Não escreve uma linha de core.** Usa a ferramenta que já existe: `SendReceiverType`/`TypeOf` (src:7841,
:8093) já sabem, para cada send do corpus, se o receptor resolve — e, quando não resolve, **em que elo a
corrente quebrou**.

**Escopo**: modo de contagem (script em `tools/`, **não** verbo da CLI — é instrumento, não produto) sobre o
**corpus do CORE** (`work/`, CLAUDE.md §3), emitindo o histograma:

```
sends totais            N
  confirmed             N
  excluded              N
  possible / unknown    N   ← e o BUCKET DO PORQUÊ:
      macro-message           N   ← parede intransponível (FICA)
      funcall-no-rettype      N   ← E1 derruba
      cast-discarded          N   ← E2 derruba
      member-not-declared     N   ← E3 derruba (herança)
      param-byref-poison      N   ← E4 derruba
      param-untyped           N   ← dedução ABERTA: nunca cai (annotate)
```

**Critério de pronto (mecânico)**: o histograma roda no corpus, e **cada experimento da Fase 1 tem um NÚMERO
atrás dele**. **Nenhum experimento sobe sem esse número.**

**Por que este é o portão certo**: se 90% dos receptores desconhecidos forem macro-dispatch, E1/E2 são
**decoração**. Se 90% forem retorno de fábrica, **E1 é o jogo inteiro**. E o número é também o **argumento
upstream** (B6): *"esta sintaxe resolve X% dos envios que o Harbour hoje não sabe checar."*
Número vive em roadmap/spec — **NUNCA em página** (CLAUDE.md §4).

---

# FASE 1 — Trilha de linguagem (os wall-breakers)

Ordem **por alavancagem MEDIDA na Fase 0**. Cada um **gateado** pelo que já existe (`fAst` /
`HB_SUPPORT_CHKTYPE`) → **sintaxe nova nunca quebra código velho**; comportamento novo só sob flag.

> ⚠️ E1/E2/E3 tocam `harbour.y` → **`HB_REBUILD_PARSER=yes`, e os TRÊS arquivos (`.y` + `.yyc` + `.yyh`)
> commitados JUNTOS**, conferindo que um rebuild default carrega a feature (CLAUDE.md §2c — armadilha
> conhecida, já cobrou caro).
> **Portão de cada um: contagem de conflitos do bison INALTERADA.**

### E1 — Retorno declarado no sítio da definição *(a maior alavanca)*
`FUNCTION F( ... ) AS CLASS Farol` / `AS Numeric`. Gramática: `AsType` na regra `Function`
(`harbour.y:329-335`), espelhando `DECLARE IdentName '(' DecList ')' AsType` (`:1245`). Na ação:
auto-`hb_compDeclaredAdd` da própria definição, com `cType`/`pClass` — **igual ao que `hbmain.c:1135-1137` já
faz para a função-classe**.

**Vem de graça, sem uma linha nova**: a imposição em runtime (`hb_compChkTypeRetWrap` acha por
`hb_compDeclaredFind( pFunc->szName )`), a emissão em `declared.functions[]`, e o ramo FUNCALL do `TypeOf` da
ferramenta.

**Pronto quando**: `LOCAL o := Fabrica()` com `FUNCTION Fabrica() AS CLASS Farol` resolve `o` → FAROL no dump;
sob `-kt`, um `RETURN` que devolve outra classe **estoura em runtime com o sítio nomeado**; e um `.prg` sem a
sintaxe compila **pcode byte-idêntico**.

### E2 — Honrar o cast `AS CLASS` em expressão *(a saída de emergência universal)*
`harbour.y:845-875`: as ações `{ $$ = $1; }` passam a **(a)** sob `fAst`, registrar (nó, classe) na **tabela
lateral do dump** (`hb_compAstCast`) — **sem tocar `src/common/expropt1.c`**, que é **compartilhado com o
macro-compilador**; **(b)** sob `-kt`, embrulhar em `__HB_CHKTYPE` (`hb_compChkTypeCastWrap`, irmão do
`RetWrap` já escrito).

**Pronto quando**: `oX := AlgumaFabrica() AS CLASS Farol` faz o cursor em `oX:Brilho()` resolver
`Farol:Brilho`; sob `-kt`, um cast **mentiroso estoura**; sem as flags, pcode byte-idêntico.

### E3 — Ligar o `_HB_SUPER` *(remove o maior risco de drift da Fase 2)*
`SuperList` (`harbour.y:1277-1278`) ganha ação (`hb_compClassSuperAdd`); `HB_HCLASS` (`hbcompdf.h:87-93`)
ganha lista de pais. Superclasse pode ser **forward ref** → guardar o **NOME** e resolver **preguiçosamente**.
`hb_compMethodFind` passa a **subir a cadeia**. Risco baixo: ele só é chamado de dentro da própria máquina
DECLARE (grep confirma).

**NUNCA ler parentesco por FORMA** (é o Q4 da [revisao-generalidade.md](revisao-generalidade.md)) — **só** pelo
canal `_HB_SUPER`.

**Pronto quando**: método herdado deixa de sair `member-not-declared`; o `ClassGraph` da ferramenta
(src:11022-11045) **CONCORDA** com o core no corpus — divergência é **bug**, e é **levantada, não escondida**.

### E4 — Levantar o veneno do `@ref` quando o parâmetro é declarado *(sem gramática)*
`Params` já aceita `AsType` e o `-kt` já confere no prólogo. Emitir a classe do parâmetro em
`declared.functions[].params` e fazer o `comptype` **não envenenar** quando o callee declara a classe daquele
parâmetro. **Cross-módulo**: o core emite o **fato de módulo**; a **ferramenta** (que carrega o projeto
inteiro) **compõe** — e **composição de fato declarado é CONSULTA, não inferência**.

**Pronto quando**: `F( @oF )` com `FUNCTION F( oOut AS CLASS Farol )` mantém `oF` → FAROL; **sem** a
declaração, continua envenenando.

### E5 — Decisão de upstream *(depois de E1-E4 MEDIDOS)*
Rodar a **Fase 0 de novo**, com os experimentos ligados: **quanto a parede encolheu, por experimento**, no
corpus do core. **Aí** decidir o que vai ao PR da B6 — **com prova, não com opinião**. Em inglês (`NEWS.md` do
core, CLAUDE.md §5). Argumento provável: *"o Harbour deixou o verificador de tipos declarados pela metade;
isto o completa, é aditivo, e o enforcement é opt-in."*

---

# FASE 2 — O cursor que consome o core mais rico

*Nada aqui **depende** de E1-E4 para funcionar — eles só **encolhem o "desconhecido"**.*

## CORE

### C0 — PROBE *(o único risco real da fase — é probe, NÃO código)*
Premissa do C1: *"o slot do último `:`+IDENT é exato no nascimento do nó SEND"* (plausível: o LALR tem **1**
token de lookahead, e sobrescrever o slot exige **dois**). **Provar antes de escrever o resto**: sonda com
`oF:Brilho():Cor()`, `::x := 1`, `o:&c()`, `WITH OBJECT` + `:msg`, `o:x += 1`. Toda posição carimbada bate com
a coluna **COMPUTADA** do arquivo (CLAUDE.md §7 — *computar, nunca contar na cabeça*).
**Falhou** → plano B: posição pela ação da gramática (`harbour.y:813`) — o que custa `HB_REBUILD_PARSER`.
**LEVAR AO DIEGO ANTES de tomar esse caminho.**

### C1 — Coluna exata da mensagem no sítio de envio
Sem isso nada pousa: nó de expressão tem só `line` + `tok` **aproximado ±1** (`compast.c:829-838`), `sends[]`
**não tem coluna nenhuma** (`:1935-1951`), e `SendReceiverType` (src:8093) hoje colhe **TODOS** os nós SEND da
linha com a mesma msg — dois sends homônimos na linha **discordam → `NIL` → `possible`**. Bug de precisão
real, **insolúvel dentro da ferramenta**.

`PHB_ASTDUMP` ganha `iMsgLine`/`iMsgCol`/`nMsgTok` + texto; `hb_compAstToken` (`:263-300`) grava ao ver IDENT
precedido de `:`; `hb_compAstNodeBorn` (`:388`) carimba o nó `HB_ET_SEND`.
**Guarda de sanidade**: texto carimbado ≠ `asMessage.szMessage` → **DESCARTA a posição**. **Nunca emitir
posição errada.** Mensagem nascida de diretiva tem `col == -1` → **sem `msgcol`**, honestamente ausente (chave
opcional → `hb_HGetDef` do lado da ferramenta, [cic §1.6]).

### C2 — Ligar cada registro de `sends[]` ao nó SEND
`HB_COMP_AST_SENDEXPR( pSelf )` no topo de `hb_compExprPushSendPop` (`hbexprb.c:4678`) e
`hb_compExprPushSendPush` (`:4724`) — macro **no-op sob `HB_MACRO_SUPPORT`** (idioma `#ifndef` já usado no
arquivo) e no-op sem `fAst`. `pAst->pPendingSend` → consumido **e limpo** por `hb_compAstSendAdd`
(`compast.c:662`). Cobre `MessageData` (a escrita `o:x := v` → `_X`), que passa a ter nó, coluna e receptor.

**Pronto quando**: `sends[]` com `pExpr != NULL` **==** total de `sends[]` no corpus. **Divergência > 0 é fato
a EXPLICAR antes de seguir**, não a esconder.

### C3 — `src/compiler/comptype.c` *(novo)*
Serviço do **compilador** ("classe declarada de uma expressão"), não preocupação do dump — e **futuro dono do
W0026**. + `include/hbcomp.h`, + `src/compiler/Makefile`.

**`hb_compTypeOfExpr(...)`** — corrente que **QUEBRA INTEIRA** ao primeiro elo desconhecido. Elos (todos fato
**escrito**): `VARIABLE` com `pClass` (o `AS CLASS`; inclui o `Self` de `hbclass.ch:265`); `VARIABLE` com
classe **propagada**; `FUNCALL` de nome em `pFirstDeclared` com `cType=='S'` (pega **qualquer** função-classe
— hbclass **ou DSL** — e, **com E1**, qualquer fábrica declarada); `SEND` cuja tabela de membros da classe do
receptor declara `AS CLASS D` (é isto que fecha `:New()` do CONSTRUCTOR); **com E2**, o cast.
**Qualquer outra coisa → desconhecido, com código de motivo.**

**`hb_compTypeResolveFunc(...)`** — ponto fixo **flow-insensitive** e monótono: semente = classes **escritas**
(travam, imutáveis); local sem classe escrita ganha a classe **se TODAS** as atribuições derem a **MESMA**
classe declarada; qualquer desconhecida, duas discordando, ou nenhuma → **desconhecido, para sempre**.
**Venenos** (→ desconhecido, sem apelação): `VARREF`/`@x` (**salvo E4**), parâmetro sem classe, escrita por
macro, controle de `FOR`/`FOR EACH`, `memvar`/`field`, `Self := x` — **PORTAR os de src:7855-7870, NÃO
inventar novos**. Itera até estabilizar (ciclo `a := b; b := a` → desconhecido, **correto**).
**Sem ordem**: `oF` tem **UMA** classe na função inteira, ou **nenhuma**.

**`hb_compTypeOfReturn(...)`** — a **dedução FECHADA**: todos os `RETURN` concordam → classe de retorno; senão
desconhecido. *(Com **E1**, o programador simplesmente **declara** e pula a dedução.)*

**Vocabulário de `piWhy`** (a recusa legível para agente, §1.6): `macro-message`, `receiver-unresolved`,
`member-not-declared`, `member-untyped`, `local-multi-class`, `local-poisoned-byref`, `local-poisoned-macro`,
`param-untyped`, `class-not-in-module`, `return-multi-class`.

**Pronto quando**: `oF`→FAROL, `oT`→TOTEM, `oI`→IDOLO em `fixhom/m1.prg`; `s`→SOL, `l`→LUA em `m2.prg` (DSL
declarativa **pura**) — **a mesma máquina, sem uma palavra de hbclass no `comptype.c`** (a **régua do caso 64
aplicada ao CORE**).

### C4 — Emissão (`ast-17`; **SÓ chaves NOVAS**)
Nó `SEND`: `+msgline`, `+msgcol`, `+rcls`, `+rwhy`. `sends[]`: `+col`, `+rcls`, `+rwhy`
(`sym`/`line`/`block` **INTACTAS**). `declarations[]`: `+rclass`, `+rhow` (`declared`|`propagated`|`cast`) —
o `class` as-written **não muda**. `functions[]`: `+retclass`. `declared.classes[]`: `+func` (o `szClassFunc`
que `hb_compClassAdd` **já recebe**, `hbmain.c:1103`) e `+super` (**com E3**).
**`occurrences[]` NÃO ganha classe** (sem ordem, a classe da ocorrência **É** a da declaração).
`HB_AST_SCHEMA` → `"ast-17"`; [ast-schema.md](ast-schema.md) **no MESMO commit**.

**Pronto quando**: `diff` de dumps ast-16 × ast-17 **filtrando as chaves novas** é **VAZIO**.

### C5 — Rebuild e regressão
`rm bin/linux/gcc/harbour bin/linux/gcc/hbmk2` e rebuildar **OS DOIS** (o hbmk2 **EMBUTE** o compilador —
CLAUDE.md §2). `tools/pcode-identity.sh`: **zero mudança de pcode** sem as flags novas.

## FERRAMENTA

- **T5** — `AstSchema()` → `"ast-17"` (src:330). **Entre C5 e T5 a suíte fica VERMELHA no caso 122** — é o
  **portão funcionando**; **não "consertar" degradando** (CLAUDE.md §1.5).
- **T1** — `ResolveAtQuery` camada 4 (src:1924-1945) **pergunta o receptor**: `FuncAtLine` → achar em
  `hFunc["sends"]` o registro com `line == nLine` **E** `col <= nCol0 < col + Len(sym)` (casamento por
  **COLUNA do core**, **único** — resolve `oF:Brilho():Cor()`) → `cOwner := hb_HGetDef( hSend, "rcls", NIL )`,
  `cQuery := iif( cOwner == NIL, cMk, cOwner + ":" + cMk )`.
  **Onde falha**: sem coluna (msg de diretiva) → comportamento de hoje + `rwhy := "no-column-at-site"`; sem
  `rcls` → query nua + o `rwhy` do core. **NUNCA** cair para "o único send da linha"; **NUNCA** casar por
  texto.
  *Efeito colateral desejado*: `ResolveRenameAt` (src:2074-2076) passa a montar `Farol:Brilho` — o
  `rename-method` a partir de um send **deixa de renomear homônimos**. É **conserto**, e entra na lista de
  drift.
- **T2** — `SendVerdict` consome o FATO: `SendReceiverType` (src:8093) passa a ler `rcls` do core; a varredura
  de nós por (linha, msg) **SAI do produto**. `TypeOf` (src:7841) **FICA**, dormente, servindo o `annotate`
  (que **sugere**, não julga). **Rótulos INALTERADOS** — só a **ORIGEM** do fato muda.
  **Pronto quando**: casos **72/73/74/84/85/86 byte-idênticos**. Divergência = **BUG**, triagem site a site.
- **T3** — **Escopo do `usages`**: extrair de `ResolveRenameAt` (src:2056-2151) um **`ResolveBindingAt(...)`**
  → `{role, sym, scope, func, file}`, **reusado nos DOIS** (rename e usages; **zero duplicação**).
  Recorte **só com `--at`**: local/param/static-de-função → **aquela função**; static de módulo → aquele
  arquivo; memvar/private/public → projeto (escopo **dinâmico** — é o fato, e o relato **diz** isso);
  field/função/método/DSL → projeto (como hoje).
  **Sem `--at` (consulta por nome), NADA muda** — não há binding, não há escopo.
- **T4** — Verbo novo **`definition`**: `hbrefactor definition <proj> <arq:linha:col> [--json <f>]`. Mesma
  máquina, projetando **SÓ** declaração/definição. Cursor em local → o sítio da declaração (coluna **exata**
  do core); em chamada → a definição; em send **resolvido** → declaração + definição **só da dona**; em send
  **não resolvido** → **RECUSA**; em **palavra de DSL** → **a linha da regra no `.ch`** (`rulefile`/`ruleid`
  **já existem**, src:1955) — **go-to-definition de keyword de DSL, de brinde**.
  EXIT: **0** com ≥1 sítio, **1** sem resolução, **2** argv. `--json` no **mesmo shape `Location[]`** do
  `usages` (a extensão **reusa o parser**).
- **X1** — **VSCode `DefinitionProvider`** (`vscode/extension.js`): reusa `atSpec` (:206) e `run`/`ctx`
  (:224-233). **Exit ≠ 0 → devolver `null`** (o editor **não pula**) + a recusa no output channel — **nunca
  pular para um palpite**. Strings em **INGLÊS** (CLAUDE.md §5).

---

## A RECUSA HONESTA — contrato exato (§1.6)

Receptor genuinamente desconhecido (macro-send; ou fábrica que o programador **não** declarou):

- **`resolve-at`**: exit **0**, `query: Brilho` + linha nova `receiver: unknown (<rwhy>)`.
- **`usages`**: exit **0** — os sends **SÃO** encontrados, cada um com `possible send (dynamic dispatch,
  receiver unknown)`, + cabeçalho dizendo que a consulta é a **mensagem nua** e que homônimos de outras
  classes aparecem como `possible`.
- **`definition`**: exit **1**, nomeando o motivo **E O QUE FAZER** — e, graças a E1/E2, o "o que fazer" é
  **REAL**:
  `cannot resolve the receiver of 'Brilho' at m1.prg:38:8 (funcall-no-rettype) — declare it: FUNCTION AlgumaFabrica() AS CLASS Farol, or cast at the site: AlgumaFabrica() AS CLASS Farol`
- **NADA de lista de candidatos.** Enumerar os três `Brilho` homônimos é **ajuda probabilística para
  conferência manual = TRIAGEM**, proibida como produto (CLAUDE.md §1).

---

## Testes

**Fixture NOVO `tests/fixsco/`** — **NÃO mexer em `fixhom`**: o `tcheck json72` assere o conjunto **EXATO** de
`Location[]`, e qualquer linha nova em `m1.prg` quebraria o caso 72 **por acidente**.

Conteúdo: 3 classes homônimas com `Brilho()` (uma por `hbclass.ch`, uma por **DSL inventada NÃO-ESPELHO** —
régua da [revisao-generalidade.md](revisao-generalidade.md) —, uma só declarativa); `UsaRig()` com
`oF`/`oT`/`oI` + `OutroUso()` com um **`oF` homônimo de outra classe**; uma linha com **dois sends**; uma
**cadeia** `oF:Brilho():Cor()`; `oX := AlgumaFabrica()` **sem** declaração (recusa) e **com** (E1/E2);
`oF:&cMsg()` (a parede que fica); `F( @oF )` com e sem parâmetro declarado (E4); uma classe **derivada** (E3);
um `static` de módulo **homônimo de um local**.

**Casos novos** (`tests/run.sh`, formato `unit_NNN()`; o último hoje é **124**):

| caso | o que trava |
|---|---|
| **125** | cursor em `oF` lista **só** o `oF` daquela função (o de `OutroUso()` **não** aparece); `--json` idem |
| **126** | cursor em `Brilho` de `oF:Brilho()` → `query: Farol:Brilho`; `oT`/`oI` **excluded** |
| **127** | **coluna**: dois sends na mesma linha resolvem para donas **diferentes** conforme a coluna; a cadeia resolve o 2º pela classe de retorno declarada do 1º |
| **128** | `definition`: local, função, método via send, e **palavra de DSL → linha do `#xcommand` no `.ch`** |
| **129** | **recusa honesta**: `definition` sai **1** com motivo **acionável**; `usages` sai **0** com `possible`; **NENHUM palpite** no stdout |
| **130** | **RÉGUA ADVERSARIAL**: 125-128 **idênticos** para a DSL inventada; e `! grep -qiwE "<palavras da fixsco>"` em **`src/hbrefactor.prg` E em `src/compiler/comptype.c`** — a régua do caso 64 **estendida ao CORE** |
| **131-134** | a trilha de linguagem: E1 (retorno declarado resolve a fábrica; `-kt` **estoura** o retorno mentiroso), E2 (cast resolve; `-kt` **estoura** o cast mentiroso), E3 (método **herdado** resolve), E4 (`@ref` com parâmetro declarado **não** envenena) |
| **122** (existente) | passa a exigir **`ast-17`** dos dois lados |
| **caso 0** | todo `.prg` de `fixsco` **limpo sob `-w3 -es2`** |

---

## DRIFT PRÉ-EXISTENTE — apresentar ao Diego ANTES de re-baselinar (CLAUDE.md §3)

1. **`tests/run.sh:2347`** — assere `query: Brilho` (nu) para o cursor em `oT:Brilho()`, sob o rótulo
   *"send é dispatch dinâmico: consulta crua honesta"*. Com T1 vira `query: Totem:Brilho`.
   **O assert CODIFICA O BUG COMO CONTRATO.** *Voto: re-baselinar.* **Decisão do Diego.**
2. **`rename` a partir de um send** (src:2074-2076): o alvo passa de `Brilho` para `Farol:Brilho` — **deixa de
   renomear homônimos**. Levantar os casos afetados **antes** de mexer.
3. **Casos 72/73/74/84/85/86**: expectativa de **ZERO drift**. Diferença = **BUG**, não contrato — ponto
   provável: **herança** (o core não sobe a cadeia; a ferramenta sobe pelo `_HB_SUPER`). **E3 deve ELIMINAR
   essa divergência**; se sobrar, **levar ao Diego antes** de codar o desempate.
4. **`TokenCols()` (src:375-390)** casa por **TEXTO** e devolve **TODAS** as colunas da linha: com dois
   `Brilho` numa linha, o `--json` de hoje aponta os dois para cada send. Trocar por `sends[].col` **conserta**
   — e **muda `Location[]` existente**. Levantar antes.

---

## Ordem e riscos

```
FASE 0  medir as paredes no corpus  (só ferramenta; nenhum número em página — §4)
   ↓
FASE 1  E1 → E2 → E3 → E4     (ordem por alavancagem MEDIDA)
   ↓                           harbour.y ⇒ HB_REBUILD_PARSER + os 3 arquivos juntos
   ↓    E5: re-medir e decidir o que vai ao PR da B6 — COM PROVA
FASE 2  C0(probe) → C1 → C2 → C3 → C4 → C5 → T5 → T1 → T2 → T3 → T4 → X1
   ↓
        fixsco + casos 125-134 → levantar drift → Diego decide → re-baseline
```

- **Risco 1** — a premissa do C1. **Por isso C0 é PROBE, não código.**
- **Risco 2** — conflito de gramática em E1/E2. **Portão: contagem de conflitos do bison INALTERADA.**
- **Risco 3** — `pAst->pPendingSend` dessincronizar (C2). **Portão: o probe de contagem.**
- **Zero risco de pcode** sem as flags: `tools/pcode-identity.sh` é o comprovante.

---

## Fora de escopo *(registrar, não executar)*

- **W0026** (`Message '%s' not known in class '%s'` — `hbgenerr.c:114-150`, **ZERO emissores**;
  `HB_COMP_WARN_MESSAGE_NOT_FOUND` é só um `#define` em `hberrors.h:161`): o `comptype.c` **É** a máquina que
  falta. Mas ligá-lo mudaria a saída do `harbour -w3` **STOCK** (quebra builds sob `-es2` — e o CLAUDE.md §1.2
  diz: **nunca mude a saída do que existe**), e daria **falso positivo em massa** sem herança no core e com
  classes que ganham método em **runtime** (`__clsAddMsg`). **Fase própria, DEPOIS do B6**, atrás de flag
  opt-in (espírito do `-kt`), e **SÓ depois de E3**.
- **Sensibilidade a FLUXO** (`oF` é Farol na linha 10 e Totem na linha 20): exige **CFG**, e o Harbour tem
  `BEGIN SEQUENCE`/`BREAK`, `LOOP`/`EXIT` e codeblocks que **destacam** locais. **"Uma classe na função
  inteira, ou nenhuma" é o ponto de parada CERTO** — variável que troca de classe no meio é rara e é código
  ruim.
- **`B7ParamType`** (tipo de parâmetro pela união dos call sites): **dedução ABERTA**. Fica desligado no
  veredito **PARA SEMPRE**; o lugar dele é o `annotate`, onde **já está**.
- **A parede do MACRO** (`o:&cMsg()`, `__clsAddMsg` em runtime, call-by-name): **fica de pé, e DEVE ficar**.
  O objetivo nunca foi zerar o resíduo — é fazer o **desconhecido ser ALTO e HONESTO**, em vez de chutado.
