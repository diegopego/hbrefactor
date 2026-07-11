# Spec P — investigação exaustiva do pp para refatoração

Portão aberto pelo Diego (2026-07-11); pré-requisito D-P0 (fase U fatia 2)
FECHADO na sessão anterior. Escopo, eixos e critério de pronto no roadmap § P.
Molde: [spec-u](spec-u-verbos-unificados.md). O achado que abriu a fase tem
registro próprio em [adr-003](adr-003-derivacao-pp-como-fato.md); a tese
arquitetural que a investigação P1 destravou — o grafo de transformação do pp
como raiz da AST, e as recomendações do Diego — está no
**[adr-004](adr-004-grafo-transformacao-pp.md)**.

## O enquadramento (nota do Diego, 2026-07-11) — o pp É, em muitas formas, um refatorador

Não é uma boutade. O preprocessador do Harbour é um **motor de reescrita de
termos** em tempo de compilação: `#define`/`#translate`/`#xtranslate`/
`#command`/`#xcommand` são regras **padrão → substituição** — casa uma FORMA
no fonte, emite uma forma TRANSFORMADA. Isso é a definição de um refatorador:
reconhecer um shape e produzir outro shape equivalente. Duas consequências que
esta fase leva a sério:

1. **O pp transforma padrões extremamente complexos.** A prova está no próprio
   corpus: uma única palavra escrita (`METHOD Info`) o pp deriva, em MÚLTIPLOS
   passes, em (a) um símbolo colado (`CAIXA_INFO`, a função gerada), (b) uma
   string de registro (`"Info"`, stringify), (c) a entrada de `__clsAddMsg` que
   liga os dois. Uma transformação multi-sítio, determinística, disparada por
   um token. Um refatorador manual que fizesse isso à mão erraria; o pp não.
2. **O pp já opera sobre TODO código Harbour.** Toda compilação passa pelo pp —
   é universal e canônico. Uma transformação expressa COMO regra de pp fala a
   MESMA língua que todo o ecossistema já usa e confia. Isso é o insumo do
   **Eixo B** (pp como INSTRUMENTO de reescrita, roadmap § P): se o motor de
   reescrita que já roda em todo build puder ser o oráculo/motor de uma
   migração de DSL, a ferramenta não precisa reimplementar um reescritor —
   reusa o do core (é o preceito da REGRA DO FATO aplicado à AÇÃO, não só ao
   fato). Veredito de viabilidade fica para P7; aqui só se registra a direção.

Esta observação NÃO afrouxa o preceito: o hbrefactor continua agindo só sobre
FATO. O ponto é que o "fato" e o "instrumento" que a fase persegue moram no
mesmo lugar — o motor de reescrita que o pp já é.

## Eixo A — P1: granularidade `paste` × `stringify`

**A pergunta (adr-003:82-86).** O `generates` (ast-12) funde `paste` (gera
SÍMBOLO, verificável por recompilação) e `stringify` (gera STRING) num único
booleano. Existe caso em que os dois precisam de vereditos DIFERENTES? Se sim,
o booleano é grosso demais e vira dois fatos (candidato `ast-13` `genOp`) ou o
stringify precisa de guarda `--force`.

**Método.** Observação por FATO no corpus (fixppm — DSL inventada não-espelho)
e por PROVA ADVERSARIAL (probes com colisão deliberada), não teoria. Cada
afirmação abaixo foi vista rodando (`bin/hbrefactor` sobre dumps `-x` reais).

### Achado 1 — a resolução do KIND não distingue paste de stringify (e não deve)

Nos oito alvos, um marker que **gera** (paste OU stringify) resolve para
`rename-pp-marker` — o mesmo veredito. A resolução ([hbrefactor.prg:1490](../src/hbrefactor.prg#L1490))
consome o booleano `generates`, e o booleano é a granularidade CERTA aqui: a
decisão é "é o marker OU é um símbolo ligado", e essa decisão é idêntica para
paste e stringify (ambos = "o nome vira código/dado, é o marker"). Provas:

- **stringify puro**: `? EVENTO Pronto` (`#xtranslate EVENTO <n> => Anota(<"n">)`)
  → `Pronto` só existe como a string `"Pronto"`. `rename ... Pronto Feito` →
  `rename-pp-marker`, exit 0, `predicted string: "Pronto" -> "Feito"`, verificado.
  Sem `--force`, sem recusa. (caso 51)
- **paste+clone+stringify na MESMA regra**: `REGISTRO Salva` → `rename-pp-marker`,
  prediz `REG_SALVA -> REG_GRAVA` (símbolo) E `"Salva" -> "Grava"` (string). (caso 52)

### Achado 2 — a granularidade fina que a PREDIÇÃO precisa já vem do rastro `from`, não do booleano

A distinção paste↔stringify que o usuário VÊ (símbolo previsto vs string
prevista) é lida DIRETO do `from` op (ast-3): o stringify em
[hbrefactor.prg:3989](../src/hbrefactor.prg#L3989) (`hFrom["op"] == "stringify"`),
o paste pelo mapa de artefatos. O booleano `generates` NÃO participa dessa
predição. Ou seja: onde a granularidade paste/stringify importa, ela **já está
disponível** — na granularidade MAIS FINA do rastro, não no carimbo.

### Achado 3 — stringify NÃO exige `--force`

A regra "nunca editar o não-verificável" guarda a edição de CONTEÚDO de string
no fonte por coincidência de nome. A string derivada de um stringify é OUTRA
coisa: ela **não existe no fonte** — é REGENERADA pelo pp a partir do
identificador editado, e a recompilação CONFIRMA (caso 51:
`verified: derived artifacts renamed as predicted`; o runtime regenera `[Feito]`).
O `from` prova, por byte-range, que a string deriva daquele marker — a edição é
por FATO, jamais por coincidência. Logo o stringify é tão verificável quanto o
paste; a diferença é o MODELO de verificação, não a segurança:

- **paste** → gera SÍMBOLO; a rede é "a recompilação tem que resolver o novo
  símbolo, senão recusa/rollback".
- **stringify** → gera STRING; a recompilação sempre passa (string é sempre
  válida), então a rede é a **predição divulgada** (`predicted string: X -> Y`,
  mostrada ao usuário) + a regeneração conferida. Ambas honestas; garantias de
  NATUREZA diferente, ambas já implementadas.

### Veredito P1 sobre o `ast-13` (recomendação ao portão D-P3)

O split `genOp` (paste vs stringify como carimbo separado) **não se justifica
por si**: a resolução do KIND não o usa (achado 1) e a predição já tem a
distinção numa granularidade MAIS FINA — o próprio rastro `from`, cujo `op` é
`clone`/`paste`/`stringify` por FAIXA DE BYTES (achado 2); stringify não pede
`--force` (achado 3). Mas o **caminho certo não é "recusar e fechar"** — é ver
que paste e stringify são **ARESTAS de um grafo maior** (a intuição do Diego,
abaixo). O veredito honesto: **não investir num `genOp` isolado; investir no
GRAFO**, do qual os `op` já são os rótulos das arestas. Fecha adr-003:82-86 sem
gastar um canal por um booleano de nicho.

## A intuição do Diego — o grafo de transformação (pré-pp ↔ pós-pp)

> "se mapear as transformações, obviamente se tem um grafo do que houve e
> acaba-se por ser possível mapear onde um token foi recriado, então passamos a
> ter as posições originais pré-passagem do processador e pós passagem."
> (Diego, 2026-07-11)

Está certíssimo, e a investigação (por FATO, com `.ppo`/`.ppt` — a régua que o
Diego mandou usar) prova três coisas:

### 1. O rastro `from` (ast-3) JÁ É esse grafo — e reconstrói pré→pós

Andando o `from` com aritmética de faixa, cada token sintetizado devolve suas
âncoras de FONTE (pré-pp). Provado rodando o walker sobre dumps reais:

| pós-pp (gerado) | op | pré-pp (fonte) |
|---|---|---|
| `Caixa_Info` (função) | paste | `Caixa`@4:13 **+** `Info`@8:10 |
| `"Info"` (string de registro) | stringify | `Info`@8:10 |
| `mk_Vendas` (probe) | paste | `Vendas`@7:5 (o sítio `MAKE`) |
| `Vendas` no `? Vendas()` | clone | `Vendas`@4:5 (pass-through, **gera nada**) |

O grafo separa por FATO o que a granularidade sozinha não separa: `mk_Vendas`
vem de `@7:5`; o homônimo `? Vendas()` só clona a si mesmo e **não alimenta
artefato nenhum** do marker. Os `op` (clone/paste/stringify) são as arestas.

### 2. O `.ppt` é o grafo NO PRÓPRIO pp — anotado por linha-fonte (o oráculo)

O `harbour -p+` emite o `.ppt`: o traço passo-a-passo, cada linha `c1.prg(N)
>entrada<` → `#xcommand/#xtranslate/(concatenate) >saída<`. É o grafo de
transformação COMPLETO, com a posição-fonte em cada passo — inclusive a
`(concatenate)` (a paste) explícita. É o oráculo humano do Eixo B e a régua
desta investigação.

### 3. O grafo é DUAS relações — e a diretiva complexa expôs a diferença (CORREÇÃO pelo spike)

O spike (autorizado pelo Diego) investigou "por que a impl de método @17 não
aparece no grafo" e **corrigiu a hipótese** — é para isso que serve um spike.
Um diagnóstico gated no `hb_pp_drvMerge` (o funil da paste no `ppcore.c`)
mostrou, na colagem da impl:

```
DRVMERGE @line 17  'Caixa_'+'Info'  drv2=1  pos2 -> 8:10
```

O `Info` que entra no `Caixa_Info` DA IMPL carrega posição **8:10 — a
DECLARAÇÃO**, não 17. Por quê: o hbclass **GERA uma regra** na declaração
(`METHOD … Info CLASS Caixa => DECLARED METHOD … Info …`) com o nome ASSADO de
`@8`; a implementação @17 **CASA** essa regra, e o próprio `Info`@17 é
consumido-e-descartado — a saída reusa o literal derivado da declaração. Logo
`CAIXA_INFO(impl)` = `Caixa`@4:13 + `Info`@**8**:10, **fielmente**. Não há
lacuna de rastreamento: @17 é um sítio de **CASAMENTO**, e o `from` ancora os
BYTES DE SAÍDA em @8 corretamente.

Então o grafo de transformação vive como **DUAS relações** no dump, e juntas
são mais completas do que a primeira leitura creditou:

- **`from` (ast-3)** = derivação de BYTES: token de saída → faixa de fonte de
  onde os bytes vieram. Fiel (a impl → @8 é o correto).
- **`ppApplications[].tokens` (ast-2)** = CONSUMO: quais SÍTIOS-fonte cada
  regra comeu, com posição. É aqui que `Info`@17 aparece (app da METHOD, marker
  1, pos 17) — e é por aqui que a ferramenta edita @17. Editar @17 é NECESSÁRIO
  (senão a regra gerada não casa mais o nome novo), mesmo os bytes de @17 não
  sobrevivendo à saída.

**A ferramenta já usa as duas** (from para artefatos+strings; ppApplications
para os sítios de casamento). `rename-method` funciona. **Não há bug no caso de
método.** A hipótese "grafo incompleto em @17" estava ERRADA; o spike a
derrubou — e o registro honesto disso vale mais que a hipótese bonita.

### Achado adversarial — colisão de homônimo → CONSERTADO pela GENEALOGIA (a 2ª hipótese também caiu)

Um probe (DSL não-espelho `LABEL <n> => RegLabel(<"n">)` e `MAKE <n> =>
FUNCTION mk_<n>()`) com o valor do marker COINCIDINDO com uma função real
homônima (`Vendas`) revelou o defeito real: a coleta
([`PpMarkerSeeds`](../src/hbrefactor.prg)) casava por NOME lexical em todas as
aplicações e arrastava `? Vendas()` (chamada da função REAL) como sítio do
marker — degrade seguro (rollback), mas recusa confusa onde devia haver rename.

O arco das hipóteses, registrado porque é a lição da fase:

1. **"`generates` filtra a coleta"** — FALSA: derruba a impl de método (clone
   multi-passe; 3 checks caíram, revertida).
2. **"o conserto pede consciência de BINDING, não o grafo"** (a correção
   intermediária desta spec) — TAMBÉM FALSA: o que separa `? Vendas()` (fora)
   de `Info`@17 e `USA Ponto` (dentro) **é o grafo, faltava um pedaço dele**.
   A impl de método é aplicação de uma regra **GERADA** pela declaração; o
   `USA Ponto` é aplicação de uma regra gerada pelo `DEFREGRA Ponto`. O elo
   "regra → aplicação criadora" (a GENEALOGIA) existia no pp e não era
   emitido. **A visão do Diego (mapear o grafo de transformação) era o
   conserto** — zero binding no resultado final.

**A fatia entregue (ast-13 + consumidores, caso 108, 796/0):**

- **Canal `ast-13` no core**: tokens de `match[]`/`result[]` de regra GERADA
  carregam `from` (a app/marker criadora), capturado no registro
  (`ppcore.c`: `pFrom` em `HB_PP_RULETOKEN`, copiado de `hb_pp_drvFind` no
  snapshot; accessors `hb_pp_trackRuleTokenFrom*`; emissão em `compast.c`).
  Probes: DSL inventada (`DEFREGRA`→`USA`) **e** hbclass real (as regras
  `METHOD` por-método apontam a app da declaração).
- **Derivação sobrevive ao clone** (`hb_pp_tokenClone` copia as entradas de
  derivação junto com a posição): o literal de result de regra gerada mantém
  a origem através das aplicações — a string `"Ponto"` da expansão vira
  artefato previsível (`predicted string`), fechando a verificação.
- **Coleta v2** (`PpMarkerSeeds`): PARES (fecho interno) sem gate; SEMENTES
  (sítios de edição) só com pertencimento por FATO — gera (ast-12), vira
  token de regra gerada (ast-13, `hGenRef`) ou pertence a aplicação de regra
  genealogia-ligada (`lLinked`). `? Vendas()` fica fora; `Info`@17 e
  `USA Ponto` entram pelo elo da genealogia.
- **Resolução** (`ResolveAtQuery`/`ResolveRenameAt`): fato irmão `genrule` —
  o nome que VIRA regra é do marker mesmo com `generates` ausente (a
  derivação de uma diretiva gerada entra no REGISTRO da regra, não no
  stream; o reverse-scan do ast-12 não a vê).
- **Verificação** (`HrbSymbolsRenamed`): expectativa do nome CRU vira
  OPCIONAL para marker puro (`hOpt` — homônimo real FICA, clone derivado
  VIRA o novo; método continua estrito), com contagem+strings+compostos
  fechando o contrato.
- **Prova**: caso 108 (14 checks — homônimo stringify/paste editando SÓ o
  sítio da DSL, round-trips byte-exatos, a via inversa rename-function sem
  tocar markers, rename do marker que vira regra nas DUAS posições). Suíte
  **796/0**, `lexdiff 0`, ZERO drift nos 782 checks pré-existentes.

## Critério de pronto do P1 — status (FECHADO)

- [x] pergunta adr-003:82-86 com veredito registrado: `genOp` isolado
      recusado; o número `ast-13` foi para o fato CERTO — a genealogia de
      regra, primeiro pedaço do grafo do adr-004, entregue COM consumidores.
- [x] prova em DSL inventada NÃO-espelho (fixppm, fixgen) + diretiva
      complexa REAL (hbclass, regras METHOD por-método).
- [x] portões respondidos POR EXECUÇÃO com aval do Diego ("spike incremental
      agora"): a colisão de homônimo deixou de ser degrade e virou rename
      correto; o fio do grafo aterrissou como canal+consumo.
- [x] caso na suíte: **108** (14 checks). Suíte **796/0**, `lexdiff 0`.
- [x] commit do core: PENDENTE de autorização por-commit do Diego (ppcore.c,
      hbpp.h, compast.c — árvore do core editada, não commitada).

## Eixo A — P2: marker que GERA E passa adiante (adr-003:87-90) — VEREDITO FECHADO

**A pergunta.** Um marker `<n>` usado ao mesmo tempo como GERADOR (`s_<n>` paste
/ `<"n">` stringify) **e** como PASS-THROUGH (`<n>` clone) na MESMA regra — hoje
o fato `generates` (ast-12) vence e o `rename` resolve para `rename-pp-marker`.
Pode estar errado num caso que ainda não vi? A investigação foi feita com o
método-oráculo que o Diego mandou usar (adr-004 #5): observar o `.ppo` (saída
expandida) e o `.ppt` (traço passo a passo) do que o pp REALMENTE faz, e provar
por execução, nunca por teoria.

### O que o pp faz — lido do `.ppo`/`.ppt` (a evidência)

Uma palavra ESCRITA UMA VEZ no fonte o pp transforma em VÁRIAS coisas. Duas
formas, ambas em DSL inventada não-espelho (régua do caso 64):

**stringify + clone** — `#xtranslate LOG <n> => QOut( <"n">, <n> )`:
```
a.prg(6)  LOG Preco
   │ (pp)
   ▼
a.ppo     QOut( "Preco", Preco )
a.ppt     a.prg(6) >LOG Preco<
          #xtranslate >QOut( "Preco", Preco )<
```
`Preco` vira a STRING `"Preco"` (stringify — **gera**, o literal perde a ligação
com o nome) E a referência à variável local `Preco` (clone — **passa adiante**).

**paste + clone** — `#xcommand WRAP <n> => FUNCTION w_<n>() ;; RETURN <n>()`:
```
b.prg(3)  WRAP Soma
   │ (pp)
   ▼
b.ppo     FUNCTION w_Soma() ;; RETURN Soma()
b.ppt     b.prg(3) >WRAP Soma<
          #xcommand >FUNCTION w_Soma() ;; RETURN Soma()<
          b.prg(3) >w_ Soma<
          (concatenate) >w_Soma<     ← a COLAGEM: "w_" + "Soma" = "w_Soma"
```
`Soma` é COLADA em `w_Soma` (o passo `(concatenate)` do traço, **gera** um nome
de função novo) E vira a CHAMADA a `Soma()`, a função que já existe (clone —
**passa adiante**). *Nota Harbour:* o `(concatenate)` no `.ppt` é exatamente onde
o pp executa a paste; renomear a palavra do marker re-executa essa colagem.

### Os cantos extremos (levantados pelo Diego no portão) — todos provados

- **(a) Colado mais de uma vez / (b) multiplicidade sem teto.** O pp não limita
  quantos usos no destino. O fecho de artefatos da ferramenta (`PpMarkerArtifacts`,
  reverse-scan sobre TODO o rastro `from`) também não tem teto — a predição é
  proporcional às ocorrências. Provado: `BUILD <n> => FUNCTION a_<n>()… b_<n>()…
  c_<n>()` (3 pastes) prevê `A_FOO→A_BAR`, `B_FOO→B_BAR`, `C_FOO→C_BAR`; `SNAP`
  (2 pastes + 2 stringify, caso 109) prevê `G_`, `H_` e a string, tudo (stringify
  deduplicado).
- **(c) Diretivas que geram diretivas — o PRÓPRIO pp restringe.** Descoberta por
  `.ppt`: uma diretiva que gera `#xtranslate` **NÃO registra** a regra (`DEFT <n>
  => #xtranslate T_<n> => 999` deixa `T_Foo` literal, `W0001`); só `#[x]command`
  gerado entra no grafo (é o que a fixgen/caso 108 e o hbclass usam), e comando de
  keyword COLADA (`SHOW_<n>`) nem casa (`E0020`). O que de fato compila cai na
  genealogia ast-13/P1, já provado no caso 108.

### O veredito — a segurança é ESTRUTURAL

| Caso (DSL não-espelho) | forma / alvo do clone | `rename` no marker | resultado |
|---|---|---|---|
| `REGISTRO <n>` (fixppm, caso 52) | LOCAL fabricado pela expansão | exit 0 | **CORRETO** (re-deriva paste+string+local interno) |
| `WRAP Soma → Multiplica` (ausente) | função externa inexistente | rollback | degrade honesto ("contagem de símbolos mudou") |
| `LOG Preco → Zzz` (ausente) | local externo inexistente | rollback | degrade honesto ("parou de compilar", W0001+`-es2`) |
| `LOG Preco → Custo` (existe) | local externo existente | exit 0 | correto-por-semântica (re-target verificado compilando) |
| `SNAP`/`BUILD` multi-paste, chamador não-derivado | referência escrita à mão | rollback | degrade honesto (multiplicidade completa na predição) |

`generates`-vence é **SEGURO**. A razão de fundo não é o fato fino (paste vs
stringify) — é a **rede dupla** que confere o ARTEFATO COMPILADO FINAL:
(1) recompilação sob `-es2` (`AstDumps`) pega toda referência quebrada;
(2) comparação posicional de símbolos/funções do `.hrb` (`HrbSymbolsRenamed`,
[hbrefactor.prg:10999](../src/hbrefactor.prg#L10999)) pega todo delta não-previsto.
Essa rede é **indiferente à multiplicidade e ao aninhamento de diretivas** —
confere o resultado, não a forma da regra. Logo:
- clone que alcança símbolo EXTERNO ausente → rollback;
- clone que re-aponta para símbolo EXTERNO existente → compila e a diretiva passa
  a operar sobre ele (é o que "renomear o argumento da diretiva" significa);
- predição incompleta (se o fecho errasse um artefato) → o pp regenera TUDO do
  marker renomeado → delta não-previsto → rollback. Pior caso = rollback espúrio
  (provado NÃO acontecer), **jamais corrupção silenciosa**.

### Decisão do portão (Diego) e entrega

Portão submetido em duas rodadas (a 1ª com exemplo textual, a 2ª com os artefatos
`.ppo`/`.ppt` a pedido do Diego). **Decisão: opção A — fechar como o P1**: sem
canal novo, sem `genOp`, sem tocar o core ou o motor. O achado CONVERGE para "a
rede já cobre" — uma recusa de canal DOCUMENTADA, resultado legítimo do critério
de exaurir a fase (adr-003: fato sem consumidor claro = fato local, não
arquitetura). Entrega = a PROVA: fixture `tests/fixp2` (LOG/WRAP/SNAP, DSL
inventada) + **caso 109** (17 checks, incluindo re-target, os dois rollbacks e a
multiplicidade). Suíte **813/0** byte-idêntica, `lexdiff` não requerido (nada no
compilador muda). O registro destes achados É a entrega tanto quanto a prova
(ordem do Diego) — mecânica do pp e o princípio estrutural ficam no
[adr-004](adr-004-grafo-transformacao-pp.md) e no
[limites-e-alavancas.md](limites-e-alavancas.md).

## Fatias seguintes (roadmap § P, ordem)

P3 (`generates` para `usages`/find-references — a hipótese grande) · P4 (mkinds de
RESULT marker) · P5 (mkinds de MATCH) · P6 (estrutura da regra, regra sem cabeça)
· Eixo B: P7 (pp como instrumento — o enquadramento acima aterrissa aqui) · Eixo
C: P8 (rename da palavra na regra) · P9 (custo reverse-scan) · P10 (síntese).
