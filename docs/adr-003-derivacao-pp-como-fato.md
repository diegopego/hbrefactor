# ADR 003 — a operação de derivação do pp (`clone`/`paste`/`stringify`) como FATO de resolução

Data: 2026-07-11. Status: **ACHADO REGISTRADO** (não um portão fechado — uma
descoberta que ABRE perguntas). Contexto executável: `ast-12` em
[ast-schema.md](ast-schema.md); consumo em
[spec-u-verbos-unificados.md](spec-u-verbos-unificados.md) § Revisão (rodada
2); origem no compilador: `src/pp/ppcore.c` (tabela de derivação
`hb_pp_trackPos`), `src/compiler/compast.c` (`hb_compAstMarkerGenerates`).

> **Por que um ADR e não só uma linha de spec.** O Diego pediu (2026-07-11)
> que este achado fosse documentado à parte porque "pode até ser
> classificado como arquitetural … e isso pode levar a novas descobertas que
> podem ser boas ou ruins". Este documento é o registro HONESTO do que o
> achado É, do que ele NÃO é, e das perguntas que ele deixa em aberto — sem
> vender mais do que foi provado.

## O achado, em uma frase

**O que um token-fonte SIGNIFICA pode depender do que o preprocessador FAZ
com ele** — e o pp já sabe: cada pedaço de token sintetizado carrega a
operação que o gerou (`'c'lone` = o valor copiado como está; `'p'aste` =
concatenado num novo identificador; `'s'tringify` = despejado numa string).
`paste`/`stringify` **transformam o nome em CÓDIGO** (um símbolo colado dele,
uma string com o nome dele) — o nome "vira outra coisa". `clone` é
**pass-through** — o nome atravessa e continua sendo o que era.

Antes deste achado a ferramenta tratava um recheio de match marker como uma
coisa só ("é um marker"). Na verdade há DOIS papéis semânticos distintos, e o
pp os distingue por FATO. O `ast-12` expõe esse fato como `"generates": true`
no marker que pasteia/stringifica.

## O problema concreto que forçou o achado

Na fase U (verbo `rename` unificado), duas leituras opostas do MESMO site
davam ambas errado:

- **role-first** (papel de pp primeiro): `? nTotal` — um LOCAL passado a um
  comando (`?` é `#command`, seus args são marker tokens) — virava
  `rename-pp-marker`. Errado: `nTotal` é o local.
- **binding-first** (escopo declarado primeiro): `REGISTRO Salva` — um marker
  que GERA `reg_Salva`, mas cuja expansão `=> …LOCAL <n>` também fabrica um
  `LOCAL Salva` na linha da diretiva — virava `rename-local` de 1 site,
  perdendo os artefatos. Errado: `Salva` é o marker que gera.

Nenhuma ORDEM entre "binding" e "papel de pp" acerta os dois. O que acerta é
o TERCEIRO fato: `Salva` **gera** (paste), `nTotal` **não gera** (clone). Com
ele: gera → é o marker (rename-pp-marker, carrega os derivados); não gera →
resolve pelo binding (o local/param que ele é).

## Por que isto pode ser arquitetural

1. **É um eixo de fato novo.** Não é "qual regra/marker" (B4-B4g) nem "qual
   tipo declarado" (B4f/B9) — é "o que a diretiva FAZ com o nome". Um recorte
   ortogonal aos que a ferramenta já consumia.
2. **É por-MARKER, não por-declaração.** A tentativa ingênua ("marcar
   declaração gerada") QUEBRA: o param de método (`METHOD Soma(nQtd)`) mora
   numa função de nome GERADO (`CAIXA_SOMA`) mas é do USUÁRIO — clone,
   renomeável como param. O fato certo é sobre o que o marker faz com o
   valor, não sobre onde a declaração aterrissou.
3. **Pode generalizar além do rename.** O `usages`/find-references vive do
   mesmo `resolve-at`; a mesma distinção (nome que vira código × símbolo
   ligado) plausivelmente refina "achar referências" de um nome de diretiva.
   NÃO está provado — ver limites.
4. **Fiel à REGRA DO FATO.** O fato já existia no compilador (a tabela de
   derivação); estendê-lo (canal `generates` no dump) para o consumidor lê-lo
   direto, em vez de a ferramenta re-derivar, é a perna "estender o core para
   o fato existir" — não inferência.

## O que o achado NÃO é (contra o exagero)

- **NÃO** faz a ferramenta "entender" DSLs. Continua consumo puro de fato; o
  `generates` é um carimbo derivado do rastro `from` que já existia.
- **NÃO** substitui o rastro de derivação (`from`). É uma conveniência (um
  booleano por-marker) computada dele. Um consumidor que precise da
  granularidade fina (QUAL artefato, QUAL operação, QUE faixa de bytes)
  continua usando `from`.
- **NÃO** foi provado geral. Foi provado para UMA coisa: a resolução de kind
  do `rename` nos oito alvos (caso 107, 29 checks). Tudo além é hipótese.

## Perguntas em aberto — **TODAS RESPONDIDAS (P10, 2026-07-13; fase P encerrada)**

> Este ADR foi escrito para ABRIR perguntas, com um **critério de matar** explícito.
> Fechá-lo é responder cada uma **pelo critério que ele fixou** — não pelo viés
> retrospectivo de chamar de arquitetural o que deu trabalho. Segue o veredito de
> cada uma, com a fatia que a decidiu.

- **Granularidade.** ~~`generates` funde `paste` e `stringify` num booleano.
  Existe caso em que `paste` (gera SÍMBOLO, verificável por recompilação) e
  `stringify` (gera STRING, NÃO editável sem `--force`) precisam de vereditos
  DIFERENTES? Se sim, o booleano é grosso demais e vira dois fatos. Não sei
  ainda.~~
  **NÃO — o booleano está certo (P1).** O `genOp` (separar os dois num fato) foi
  **recusado por prova**: a RESOLUÇÃO só precisa saber *"gera ou não"* (casos
  51/52/107); a PREDIÇÃO, que precisa da operação, já a lê do rastro `from` (que
  carrega `op: clone|paste|stringify` por item); e o `stringify` não exige
  `--force` — o artefato é re-derivado, não editado às cegas. Fato sem consumidor
  não vira canal.
- **Marker que gera E passa adiante.** ~~Um `<n>` usado como `s_<n>` (paste) E
  `<n>` (clone) na MESMA regra: gera E é pass-through. Hoje `generates` vence
  → pp-marker. Pode estar errado num caso que ainda não vi. É contrived, mas
  existe.~~
  **`generates` vencer está certo, e a segurança é ESTRUTURAL (P2, caso 109).** Não
  há corrupção silenciosa possível: a rede dupla (recompilação `-es2` + identidade
  de símbolos do `.hrb`) confere o **artefato compilado final**, indiferente à
  multiplicidade (provado com paste×3 e paste×2+stringify×2) e ao aninhamento. Todo
  caso é rollback honesto OU re-derivação verificada.
- **Acoplamento.** ~~A resolução da ferramenta passa a depender de um conceito
  INTERNO do pp (a operação de derivação). É principiado (é FATO exposto pelo
  core), mas amarra o modelo de resolução à mecânica do pp — se a semântica
  de derivação do pp mudar, o fato muda junto. Bom (fica fiel ao compilador)
  e arriscado (menos independência) ao mesmo tempo.~~
  **O acoplamento era a VIRTUDE, não o risco — e a fase P andou na direção de MAIS
  acoplamento, de propósito.** O medo aqui era perder independência; o que a fase
  provou é que **independência do core é exatamente o que produz réplica degradada**.
  Cada desacoplamento que restava virou bug: o `AbbrevClash` reimplementava a
  abreviação dBase e **recusava renames seguros** (P-AUDIT/`ast-15`), e a predição de
  colisão só ficou correta quando parou de calcular e passou a **perguntar ao pp
  vivo** (P11, `__pp_init`/`__pp_process`). Se a semântica do pp mudar, a resposta
  muda junto — e isso é o que se QUER: é a diferença entre acompanhar o compilador e
  divergir dele em silêncio.
- **Custo.** ~~`hb_compAstMarkerGenerates` é reverse-scan O(tokens × from) por
  marker consultado. Barato no dump de um módulo; um ponto a vigiar se o dump
  crescer muito ou se o fato for consultado em massa.~~
  **MEDIDO E CONSERTADO na P9 (2026-07-13) — e este parágrafo estava ERRADO nos
  dois adjetivos.** Não era barato e não era um ponto a vigiar: o custo era
  **quadrático no tamanho do módulo** (a varredura rodava por token consultado, e o
  número de tokens consultados cresce com o número de aplicações), e um módulo de
  16 mil linhas expandidas levava **69 s** para dumpar. O erro de julgamento é
  instrutivo: escrevi "barato" olhando o dump de uma FIXTURE — corpus pequeno esconde
  quadrática. Conserto: o fato é propriedade do par (aplicação, marker), então o
  conjunto se computa **uma vez por módulo** e o token responde por lookup; 16k
  passou a **0,21 s** e o crescimento virou linear, com os dumps do corpus inteiro
  byte-idênticos. [spec-p § P9](spec-p-pp-refatoracao.md).
- **Descoberta que pode ser RUIM.** ~~Se `generates` se mostrar um
  special-case que NÃO generaliza, teremos pago um canal de core (schema bump,
  rebuild) por um problema de nicho do `rename`. O critério honesto de matar:
  se nenhum outro consumidor pedir o fato e nenhum caso novo o exercitar além
  do rename, ele fica como o que é — um fato local do rename — e não vira
  "arquitetura".~~
  **PASSOU no próprio critério — e por pouco.** O critério era: *outro consumidor
  pediu o fato?* **Sim, e não por elegância: por BUG.** O `usages --at` misturava um
  marker de pp com um símbolo homônimo do programa (`LABEL Vendas` × `FUNCTION
  Vendas()`), devolvendo o mesmo punhado de hits em qualquer um dos quatro sites —
  porque calculava `generates`/`genrule` e os **descartava**. Consertar exigiu o
  find-references CONSUMIR o fato (P3, caso 112). Então o `ast-12` deixou de ser
  local do `rename` **pela porta certa**: um segundo consumidor precisou dele para
  não estar errado. *(Honestidade sobre o "por pouco": se a P3 não tivesse achado
  aquele bug, o veredito deste bullet seria o outro — fato local, não arquitetura.)*

## Veredito final (P10, 2026-07-13) — a fase P está encerrada

**O que o `ast-12` virou:** um fato com **dois** consumidores (rename e
find-references), um custo **medido e consertado** (P9), e uma granularidade
**recusada por prova** (P1). Vira arquitetura pelo critério escrito aqui em
2026-07-11, não pelo trabalho que custou.

**O que a fase P provou, além do fato:** que o caminho é sempre em direção ao core.
Toda esperteza que sobrou na ferramenta caiu — a réplica da abreviação dBase
(`ast-15`), a inferência do recheio por comparação de texto (`ast-14`), a aritmética
de colisão (P11, substituída pelo **pp vivo**), a busca de include à mão (P8,
substituída pelo `harbour -gd`). O saldo: **quatro canais novos** no core
(`ast-13`..`ast-16`), **zero heurística nova** na ferramenta, e três erros meus
registrados com nome (o custo que chamei de barato, a recusa que declarei sem varrer,
o número do stress que publiquei como se fosse o produto).

## Prova executável (o que ESTÁ fechado)

`ast-12`: `"generates": true` no dump (reverse-scan do `from`, op `p`/`s`),
zero impacto no pcode (`make lexdiff` 0 divergências reais). Caso 107 (29
checks) exercita o fato end-to-end: mirror `REGISTRO Salva`→pp-marker; clone
`nX`/param de método→rename-param; `? nTotal`→rename-local. Suíte 797/0.
Fixtures `fixppm` (gera), `fixmth` (param de método clone), `fix01`
(pass-through). Commit do core sob autorização por-commit do Diego.
