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

## Perguntas em aberto (podem levar a coisas boas OU ruins)

- **Granularidade.** `generates` funde `paste` e `stringify` num booleano.
  Existe caso em que `paste` (gera SÍMBOLO, verificável por recompilação) e
  `stringify` (gera STRING, NÃO editável sem `--force`) precisam de vereditos
  DIFERENTES? Se sim, o booleano é grosso demais e vira dois fatos. Não sei
  ainda.
- **Marker que gera E passa adiante.** Um `<n>` usado como `s_<n>` (paste) E
  `<n>` (clone) na MESMA regra: gera E é pass-through. Hoje `generates` vence
  → pp-marker. Pode estar errado num caso que ainda não vi. É contrived, mas
  existe.
- **Acoplamento.** A resolução da ferramenta passa a depender de um conceito
  INTERNO do pp (a operação de derivação). É principiado (é FATO exposto pelo
  core), mas amarra o modelo de resolução à mecânica do pp — se a semântica
  de derivação do pp mudar, o fato muda junto. Bom (fica fiel ao compilador)
  e arriscado (menos independência) ao mesmo tempo.
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
- **Descoberta que pode ser RUIM.** Se `generates` se mostrar um
  special-case que NÃO generaliza, teremos pago um canal de core (schema bump,
  rebuild) por um problema de nicho do `rename`. O critério honesto de matar:
  se nenhum outro consumidor pedir o fato e nenhum caso novo o exercitar além
  do rename, ele fica como o que é — um fato local do rename — e não vira
  "arquitetura". Registrar isso agora evita o viés retrospectivo de o chamar
  de arquitetural só porque custou trabalho.

## Prova executável (o que ESTÁ fechado)

`ast-12`: `"generates": true` no dump (reverse-scan do `from`, op `p`/`s`),
zero impacto no pcode (`make lexdiff` 0 divergências reais). Caso 107 (29
checks) exercita o fato end-to-end: mirror `REGISTRO Salva`→pp-marker; clone
`nX`/param de método→rename-param; `? nTotal`→rename-local. Suíte 797/0.
Fixtures `fixppm` (gera), `fixmth` (param de método clone), `fix01`
(pass-through). Commit do core sob autorização por-commit do Diego.
