# Roadmap — hbrefactor sobre AST do compilador

Responsável pela ferramenta: Claude (planejamento, implementação, verificação);
decisões de produto e autorizações (commits, PR upstream): Diego.

> **REGRA DE MANUTENÇÃO — este documento carrega ESTADO ATUAL + O QUE FALTA, e nada mais.**
> Fase futura só começa com escopo e critério de pronto escritos. Fase concluída ganha UMA
> LINHA no índice de entregues, e a narrativa integral migra **na mesma sessão** para o
> [arquivo](roadmap-fases-entregues.md). O mesmo vale para seção concluída dentro deste
> arquivo e para pendência de sessão resolvida.
> **Ao arquivar, EXTRAIA as pendências vivas** que a narrativa carregava — elas vão para
> § Pendências vivas, nunca para o arquivo. *(A limpeza de 2026-07-13 nasceu porque a regra
> vinha sendo violada: o roadmap tinha 1.495 linhas, quase todas registro de coisa já
> entregue, com a intenção viva enterrada no meio.)*

Fluxos definidos vivem no **Makefile**; hbmk2 direto é só experimentação.
Mapa permanente do alcançável: [limites-e-alavancas.md](limites-e-alavancas.md).
Retomada de sessão: [handoff.md](handoff.md).

> **bravo-experimento: FORA DO ESCOPO (ordem do Diego, 2026-07-05).** Corpus de validação:
> fixtures da suíte + `work/` (cópias de pastas do CORE). Projetos grandes de produção só
> quando o Diego liberar.

## O NORTE

A lei vive no **CLAUDE.md** (§ 1, A REGRA DO FATO) e a jurisprudência em
[cicatrizes.md](cicatrizes.md) — **não se duplica aqui**. O resumo de uma linha, porque é
o que decide toda fase: **o hbrefactor age só sobre FATO produzido por compilação**; fato
ausente → estender o CORE (Harbour oficial inteiro) ou usar ferramenta do core como
oráculo; nunca inferir. Classes são só um caso; o alvo é **qualquer construto**, inclusive
DSL inventada pelo usuário. Régua executável: casos 64 e 72-74.

## Fundação (provada; não re-derivar)

Compilador como oráculo (ganchos gated, `.hrb` byte-idêntico sem `-x`); **editor ≠
verificador** (recompilar, comparar, rollback); hbmk2 como resolvedor de projeto; fixtures
como contrato; réplica sintática na ferramenta é proibida. Dump por módulo `.ast.json`, com
o schema corrente **definido em UM lugar só** (`AstSchema()` na ferramenta ×
`HB_AST_SCHEMA` no core) e especificado em [ast-schema.md](ast-schema.md) — **LER antes de
mexer**. *(Nenhum número de schema se escreve aqui: em 2026-07-13 esta seção ainda dizia
`ast-8` com o core em `ast-16` — um fato velho na seção que manda não re-derivar.)*

## Fases entregues (registro completo no [arquivo](roadmap-fases-entregues.md))

| Fase | Entrega (1 linha) |
|------|-------------------|
| B0+B1 (2026-07-05) | Mecanismo `-x` no core + fundação da ferramenta; lexdiff 0; occ↔ast paridade total |
| B2 (2026-07-05) | 11 comandos re-assentados na AST; run.sh novo |
| B3 (2026-07-05) | reorder multi-linha; `inline-local` com pureza pela árvore do compilador |
| B4 (2026-07-06) | `ppRules`/`ppApplications`; `rename-dsl`; usages de palavra de DSL; lifting |
| B4b (2026-07-06) | memvars: mapa de visibilidade; `rename-memvar` fecho-fechado; WorkDir atômico |
| B4c (2026-07-06) | rename-method por âncoras de forma — **MORTAS na B4d** (registro histórico) |
| B4d (2026-07-06) | Rastro de derivação `from`; `rename-pp-marker` genérico; âncoras por forma removidas |
| B4e (2026-07-06) | Comandos cientes de construtos; extract-para-método |
| B4f (2026-07-06) | Canal de tipos da linguagem; camadas confirmed/excluded/possible no usages |
| B4f-2 (2026-07-07) | Resolução de dispatch; homônimos; declarações vinculadas à dona |
| B4f-3 (2026-07-07) | PROVA da generalidade: DSLs inventadas, cstruct real, construtos não-classe |
| B4g (2026-07-07) | A regra POR DENTRO: `match[]`/`result[]`; rename de qualquer palavra do match; `--edit-rules` |
| B-infra 1+2 (2026-07-07→08) | Suíte paralela (109 s → ~14 s); runner em Harbour, python fora do `make test` |
| B7 + B7b (2026-07-08) | Tipos interprocedurais (cadeia de construção, oráculo QSelf) + inferência fatia 3 |
| B9 fatias 1-3 (2026-07-08→10) | Tipos declarados IMPOSTOS (`-kt` no core) + materializador `annotate` com escada e rollback |
| RE (2026-07-09→10) | Re-escopo pós-revisão externa: RE.1-RE.6; B7/B7b DORMENTES; parentesco declarado (`_HB_SUPER`) fecha o furo dos homônimos |
| RD + RD-c (2026-07-10→11) | Tipo do receptor INLINE por FATO (`_HB_INLINESELF`); params tipados no nó CODEBLOCK |
| B5 + B5.1 (2026-07-07→10) | Extensão VSCode 0.6.0 → 0.13.0; `projects-of` (posse por fato, descoberta por proximidade); `.hbp` multi-alvo |
| U (2026-07-11) | Verbos unificados: `rename <arq:linha:col>` despacha pelo FATO; os 8 `rename-*` REMOVIDOS |
| P (2026-07-11→13) | pp EXAURIDO: 4 canais novos no core (`ast-13`..`ast-16`), pp vivo como oráculo, zero heurística nova |
| SITE-EX (2026-07-12) | CLI em inglês; exemplos da página EXECUTADOS (`make site-check` falha se divergir) |
| L (2026-07-13) | **MORTA no dia em que nasceu** — o `unused-locals` SAIU: não se otimiza um comando que não devia existir |
| A.2 (2026-07-13) | `snapshot`/`verify`: o verificador sai da jaula e prova edição que a ferramenta NÃO fez |
| Auditoria (2026-07-05) | Gramática duplicada morta (`NameAccepted` via compilador-biblioteca; `CoreFunction` via harbour.hbx) |

**Réplicas conservadoras remanescentes** (da auditoria, não urgentes): `StrDelimsOk`
(delimitadores de string — ideal: span original no dump); cheque textual de continuação `;`
em 2 pontos (falso positivo só recusa).

---

# FASES ATIVAS

## V — Velocidade da refatoração em PROJETO GRANDE — **ATIVA (fatia 1 entregue 2026-07-13)**

A P9 consertou o dump **por módulo**. O que sobrou é **estrutural, e é o que o usuário
sente**: todo comando re-dumpa o **projeto INTEIRO** — `AstDumps` passa `-rebuild`
([hbrefactor.prg:249](../src/hbrefactor.prg)), de propósito (*"dump sempre fresco"*: a
ferramenta jamais pode agir sobre fato velho). **A espera é a mesma para renomear 1
variável ou 20.** *(A extensão VSCode é o consumidor diário do Diego — é lá que dói.)*

**FATIA 1 ✅ ENTREGUE — onde o tempo VAI (e ela DERRUBOU o desenho das outras duas).**
Medida com a ferramenta **instrumentada por dentro** — e isso não é detalhe: por FORA,
emulando o `hbmk2` que eu *achava* que ela dispara, os números não fechavam e um projeto
quebrado passava por bom. **Cronometrar processo não é medir trabalho.** Em `work/xhb` (43
módulos, compila, lê e analisa): `call-graph` 8,4 s (gerar dumps 58%, ler+parsear 11%,
analisar 31%); `usages` 12-15 s (gerar 35%, ler ~10%, **analisar ~50%**).

**Os três vereditos:**
1. **NÃO existe gargalo único.** No `usages` — o verbo mais usado — a ANÁLISE pesa mais que
   a geração.
2. **Cache de dump ataca no máximo METADE.** Com cache perfeito o `usages` no xhb ainda
   levaria ~7-9 s. **O desenho original da fase (fatia 3 = "cache de dumps") estava ERRADO**
   — e só se soube medindo.
3. **As TRÊS etapas são proporcionais ao PROJETO**, inclusive a análise, que re-deriva os
   fatos do projeto inteiro a cada comando. O objetivo (*custo proporcional ao que você
   TOCOU*) **não se alcança sem tornar incremental o FATO ANALISADO**, não só o dump.

**FATIA 2 (RE-DESENHADA pela fatia 1) — o FATO ANALISADO por módulo, incremental.** O que
tem de ser reaproveitado quando um módulo não muda é o **resultado da análise daquele
módulo** (o que ele define, chama, declara) — o dump vem junto, de graça, pelo mesmo
critério. **REGRA DO FATO:** é PROIBIDO inventar staleness na ferramenta (mtime é
heurística; include transitivo a quebra). Quem decide o que recompilar é o **`hbmk2 -inc`**
(sondado 2026-07-13: tocando 1 de 3 módulos, **só o dump dele é regravado**); o fecho
transitivo de include vem do **`harbour -gd`** (P8).

**FATIA 3 — CANCELADA** (era paralelizar o `unused-locals`; o comando SAIU — ver fase L no
arquivo).

**PORTÃO:** resultado **byte-idêntico** ao modo de hoje — a mesma régua de equivalência que
provou a P9 (suíte inteira verde nos dois modos).

**Riscos honestos:** (i) cache é a classe de bug mais cara que existe, e *"agiu sobre fato
velho"* é **exatamente** o que esta ferramenta promete nunca fazer — fail-closed em qualquer
dúvida; (ii) a análise pode ter um piso irredutível (o veredito de um send depende do
PROJETO, não do módulo) — se tiver, isso é **limite honesto a registrar**, não a esconder.

**PRONTO da fase:** num projeto de dezenas de módulos, um comando que toca 1 módulo custa
proporcional a **1 módulo** — com equivalência byte-idêntica provada contra o `-rebuild` de
hoje.

## A — A IA COMO CONSUMIDOR DE PRIMEIRA CLASSE (jamais FONTE de fato) — **ATIVA: A.2 entregue; A.1/A.3/A.4 em PORTÃO FECHADO**

Spec: **[spec-a-oraculo-para-agentes.md](spec-a-oraculo-para-agentes.md)**. Regra durável:
CLAUDE.md § 1.6.

**A tese (Diego, 2026-07-13).** O programador Harbour vai pedir a um LLM *"renomeie este
método no projeto inteiro"*. O LLM vai fazer isso por **substituição de texto** — com
confiança, e errado: homônimo entre classes, nome que também é palavra de DSL, site gerado
por diretiva, string que casa por coincidência. **É exatamente o modo de falha que o
hbrefactor existe para eliminar.** O agente não é "mais um consumidor": é o que **MAIS
PRECISA** de um oráculo de fato. **O hbrefactor é o que torna a refatoração por IA em
Harbour SEGURA** — tese de produto, não recurso.

**O enquadramento que impede a leitura errada.** LLM é máquina de **heurística**; hbrefactor
é máquina **anti-heurística**. Complementaridade: **o agente propõe a INTENÇÃO**; **a
ferramenta decide o que é PROVÁVEL, executa verificando, e recusa com MOTIVO.** A fase muda
a **SUPERFÍCIE**, jamais o motor.

> **NÃO-OBJETIVO, executável e não retórico:** a ferramenta **não tem modelo, não tem chave
> de API, não fala com rede, e NUNCA pergunta nada a um LLM**. Régua no fonte, na família do
> caso 64.

**A REFRAME — o catálogo de verbos NÃO é o produto.** O produto é o **VERIFICADOR**:
compilar antes/depois, comparar o pcode byte a byte, reverter. Essa máquina é **agnóstica de
verbo** — e estava **trancada dentro dos 12 comandos**. Um agente nunca vai querer só os 12:
ele vai querer *"converta este `DO CASE` em `SWITCH`"*. **O catálogo jamais alcança a
imaginação de um LLM; o verificador alcança — porque não sabe nem se importa com qual foi a
edição.**

### A.1 — Contrato de máquina na CLI *(base: sem isto, nada em cima se apoia)* — PORTÃO FECHADO

**A contradição que se fecha:** a ferramenta **proíbe comparação de texto no MOTOR e obriga
comparação de texto no CONSUMIDOR**. A extensão decide **fluxo** casando prosa (`/--force/`,
`/--edit-rules/`, `/no compile-time identifier/` — `vscode/extension.js`), e já **quebrou
calada** quando a CLI foi traduzida. É o **mesmo padrão da fase L** (*"o compilador SABE e
joga o fato fora numa string"*), agora com a ferramenta fazendo isso com a **própria saída**.

- `--json` vira flag **global, em STDOUT** — hoje só 3 dos 12 comandos têm, e escrevem em
  **arquivo**. A forma antiga **morre**; a extensão é reacoplada **na mesma fase**.
- **Envelope único, schema versionado.** Semente pronta: `LocationsJson()` já emite
  `Location[]` no formato LSP.
- **Toda recusa carrega CÓDIGO.** `Refuse()` já é funil único. A taxonomia **separa o que
  hoje está fundido**: recusa de política × ambiente quebrado × **resposta vazia legítima** —
  hoje `usages` com **zero resultados sai `EXIT_REFUSED`**: o agente não distingue "não há
  usos" de "eu me recusei".
- **`--dry-run --json` devolve as EDIÇÕES como dado.** Absorve dois resíduos que o roadmap
  adiava por conta própria (preview da B5; `Location` estruturada para artefato derivado, da P3).

> **Restrição de desenho que vem da tese, e é a mais séria da fase:** a recusa tem de ser
> legível o bastante para o agente **RELATAR**, não para **CONTORNAR**. Um agente que recebe
> "recusado" sem entender por quê vai fazer aquilo pelo que é famoso: **editar o texto na
> mão** — e aí a ferramenta virou obstáculo que se contorna, não proteção. O código precisa
> distinguir *"pare e conte ao humano"* de *"repita com `--force`"*.

### A.2 — `verify`: o ORÁCULO EXPOSTO — ✅ **ENTREGUE (2026-07-13; caso 123, suíte 978/0, extensão 0.14.0)**

`snapshot <project>` grava a linha de base; o agente edita à vontade; `verify <project>
[--rollback]` responde `PRESERVED` (prova) / `CHANGED` (**ausência** de prova, com o delta
que o compilador viu) / `BROKEN` (`--rollback` restaura byte a byte). Narrativa completa no
[arquivo](roadmap-fases-entregues.md); duas coisas ficam AQUI porque governam o resto da
fase:

> **O LIMITE, e é o CORAÇÃO do desenho:** identidade de pcode é oráculo **DE UM LADO SÓ**.
> **`PRESERVED` é PROVA; `CHANGED` NÃO é prova de quebra** — um `extract-function` legítimo
> muda o pcode. Ler "mudou" como "está errado" seria **chutar a intenção do autor** =
> heurística. Por isso o `CHANGED` **sai com exit 0** e **nenhuma palavra de reprovação**, e
> o caso 123 trava isso com régua textual. **Não "melhore" isso.**

**Fica de fora, honesto:** a equivalência do `verify` é a **mais estrita** (identidade byte a
byte do `.hrb`). Os degraus mais frouxos que os verbos usam por dentro (`HrbEquivalent`,
`HrbExtractCheck`) **dependem de saber o que se esperava mudar** — e numa edição que a
ferramenta não fez **não existe expectativa**. Usá-los seria inventar intenção.

### A.3 — Servidor MCP *(a porta pela qual o agente entra)* — PORTÃO FECHADO

O agente do usuário chama `resolve-at`/`usages`/`rename`/`verify` como **ferramenta nativa**,
em vez de dar shell e regexar prosa.

- **Só existe DEPOIS do A.1** — MCP sobre a saída de hoje seria um regexador com outro nome.
- **CRITÉRIO DE MATAR (o teste da fase L virado contra nós):** o servidor **não pode conter
  DECISÃO**. Se precisar decidir algo que a CLI não decidiu, ele **morre** — a decisão
  pertence à ferramenta, e a necessidade dele **prova que o contrato do A.1 ficou ruim**.
  Adaptador, nunca dono de lógica.
- **Subsome o "manifesto de capacidades"**: o MCP anuncia os schemas pelo protocolo —
  descoberta em vez de decoreba, e morre a classe de bug "o manual do agente envelheceu".
- Linguagem: **Harbour** (JSON-RPC sobre stdin/stdout; `hb_jsonEncode` basta; dogfooding
  real) × **Node** (a extensão já é JS; há SDK). Inclinação: Harbour — contra honesto:
  escreveríamos o protocolo à mão.

### A.4 — `-ge2`: diagnóstico do compilador em JSON *(core; fecha a sonda da fase L)* — PORTÃO FECHADO

`-ge<mode>` **já existe** (`0=Clipper`, `1=IDE`) → **`-ge2` é MODO NOVO de opção existente**,
não flag nova. E `hb_compOutMsg()` é o **formatador único**, que **já recebe tudo desmontado**
(módulo, linha, severidade, número, template, args) — e só então **achata numa string**.

**É útil? Sim — mas o hbrefactor é o consumidor MAIS FRACO dele, e isso fica escrito.** A
ferramenta usa o compilador como **oráculo binário** e tira os fatos do **dump**. O que o
sustenta, em ordem de força: **(1)** é o **PR fácil que abre a porta do PR difícil** (a B6
pede um canal num diff grande e intrusivo; o `-ge2` é minúsculo e não-controverso, e
estabelece a narrativa *"o Harbour fala com máquinas"* ANTES do pedido grande); **(2)** o
**painel Problems** da extensão; **(3)** o agente do usuário que recebe *"conserta este
erro"*. **Limite honesto: não há COLUNA** no diagnóstico — sondar se o lexer tem, antes de
prometer. **No PR a palavra "AI" não aparece**: lá isso se chama *machine-readable
diagnostics*.

### A.5 — Latência: **o contrato sem velocidade entrega uma ferramenta que o agente não vai querer chamar**

Um humano faz 3 perguntas por hora; um agente faz 30 por minuto. Um `usages` no `work/xhb`
custa **12-15 s**. Isso **não é detalhe da fase A — é pré-requisito dela**, e é a **fase V**.
**Ordem sugerida: V.2 antes do A.3** (A.1 e A.2 são independentes).

### O que foi considerado e REJEITADO *(o teste da fase L, aplicado ANTES de escrever)*

- **Comando `describe` ("dê ao agente o mapa do projeto")** — soa ótimo e **já existe**: o
  `dump` gera os `.ast.json`. Falta ele **imprimir um caminho em vez de uma frase**. Não é
  capacidade nova; é conserto de 3 linhas dentro do A.1.
- **Regras de refatoração em linguagem natural** — é a heurística entrando pela janela. **Não.**
- **"O agente sugere onde refatorar"** — é TRIAGEM, que a REGRA DO FATO já proíbe como produto.

### Riscos honestos

1. **O `verify` vira heurística** se "mudou o pcode" for lido como "está errado". Risco nº 1.
2. **O agente contorna a recusa** que não entende — recusa ilegível não protege, só é ignorada.
3. **O rótulo é cavalo de Troia da heurística** se mal escrito → não-objetivo executável.
4. **Drift em teste PRÉ-EXISTENTE → vai ao Diego, site a site.** Dois sítios já
   identificados: `usages` com zero hits deixa de sair `1`; `--json <arquivo>` some. Quebram
   a suíte **e** a extensão.
5. **Superfície nova é peso** (régua da fase L). O envelope **não** é capacidade nova; o
   **MCP e o `verify` são**, e por isso nascem com critério de matar.
6. **Custo:** toca a saída dos 12 comandos, e o `verify` mexe no núcleo de verificação — a
   parte do fonte onde um bug é mais caro.

### PRONTO da fase (executável, se o portão abrir)

- Todo comando sob `--json` emite **um** envelope válido em stdout, e **nada mais** ali.
- **Nenhuma** decisão de fluxo da extensão casa prosa — os três regexes morrem, e um caso da
  suíte **prova** que morreram.
- Toda recusa carrega código, e o código distingue *pare* de *repita com `--force`*.
- "Zero resultados" deixa de ser recusa (com o drift aprovado pelo Diego).
- `verify` prova preservação de edição que a ferramenta NÃO fez; edição que quebra volta byte
  a byte; e um caso trava o LIMITE (edição legítima que muda o pcode → *"não provei
  preservação"*, **nunca** *"está errado"*).
- MCP: o agente lista e chama os verbos, recebe **fato**, e o servidor **não contém decisão
  nenhuma** (verificado por leitura).
- `make test` verde; `make site-check` verde.

---

# PENDÊNCIAS VIVAS (herdadas de fases encerradas)

*Cada item aqui sobreviveu ao arquivamento porque é trabalho POR FAZER, não registro.*

## Portões abertos a submeter ao Diego

- **D-P5 — migração de DSL como VERBO novo.** O instrumento existe e está PROVADO (P11: o pp
  vivo como oráculo, `__pp_init`/`__pp_process`); o desenho está pronto (P7c: o pp computa o
  texto novo com `-u`, a FERRAMENTA escreve por posição de byte a partir do span da
  statement, preservando comentário e formatação). Barrado por DUAS regras do projeto, não
  por dificuldade: é **verbo novo** (portão do Diego) e o **critério de matar do adr-003**
  (*"fato sem consumidor = fato local, não arquitetura"*). **Pergunta ao Diego, não decisão
  minha.**
- **B9 — resíduos (portão de ESCOPO):** (1) anotação de PARÂMETRO de assinatura (colapsa em
  `tokens[]`, pede o idioma `SigParamHits`; rendimento auto-escrevível baixo hoje); (2)
  candidato (f) de core ADIADO (New implícito); (3) F4.3 (escrita da execução controlada)
  **MORTA POR MEDIÇÃO** — spec na gaveta, padrão B8.

## P12 — o pp como ENGENHO DE BUSCA *(ideia do Diego, 2026-07-12; **NADA PROVADO AINDA**)*

Usar o casador do pp para **ACHAR**, não para transformar — busca estrutural, lint com regras
do usuário, codemod. O trunfo não é técnico e sim de adoção: a linguagem de consulta seria a
do `#xcommand`, que **todo programador Harbour já sabe escrever** — e quem casa é o casador
do CORE, não uma réplica. Hipótese central a sondar: o canal de fato **já existe**
(`ppApplications` + `ast-13/14/15` dão site, posições e o que casou em cada marker); falta
**injetar a regra de consulta** — e uma regra **no-op** com o `<@>` (o guarda anti-recursão)
pode registrar a aplicação **sem alterar o código**. O mecanismo de injeção/remoção com
escopo é o `ast-16` (P13). Se confirmar, a 1ª versão sai **sem mudança no core**.
Plano, usos candidatos e limites: **[pp-corpus/pp-as-search.md](pp-corpus/pp-as-search.md)**
— **o arquivo é plano, não registro.**

> **CONSUMIDOR NOMEADO pela fase A:** a primeira coisa que um agente faz antes de editar é
> **PROCURAR** — e hoje ele grepa. Busca estrutural cujo casador é o do core é capacidade de
> agente por excelência. A fase A não executa a P12; ela responde a pergunta que a P12 deixava
> no ar (*"quem consome isto?"*).

## P14 — TIPOS DECLARADOS COM ALCANCE, e o cursor que os consome *(situação levantada pelo Diego, 2026-07-13; **EXPLORATÓRIA — NADA PROVADO AINDA**)*

Plano completo: **[plano-tipos-com-alcance.md](plano-tipos-com-alcance.md)** — **o arquivo é
plano, não registro.**

**O pedido**: com três classes homônimas (todas com `METHOD Brilho()`), a COLUNA do cursor tem
de selecionar qual símbolo está em jogo em `oF:Brilho()` — cursor em `oF` dá os usos **daquele**
`oF`; cursor em `Brilho` dá declaração + definição do método **de Farol** e só os envios que
atingem Farol. A mesma máquina alimenta um **go to definition** (o `rename` já senta nela).

**Dois achados que reordenaram o trabalho:**

1. **A ferramenta JÁ resolve o receptor** — `tests/fixhom/m1.prg` é, letra por letra, o exemplo;
   `run.sh:1978-1981` já assere `confirmed send (receiver class TOTEM...)` / `excluded send
   (dispatches to FAROL:BRILHO)` para a consulta **por NOME**. **O buraco é o CURSOR**:
   `ResolveAtQuery` camada 4 (src:1924-1945) vê o `:` e devolve a consulta **NUA**, sem nunca
   perguntar o receptor. E **`run.sh:2347` fossilizou o bug como CONTRATO** (exige
   `query: Brilho`, sob o rótulo *"consulta crua honesta"* — era verdade quando foi escrito).
2. **O Harbour já tem um sistema de tipos declarados COMPLETO — e SEM ALCANCE**: a linguagem de
   anotação (`AS CLASS`), a tabela (`DECLARE`/`_HB_CLASS`/`_HB_MEMBER`/`_HB_SUPER`) e — neste
   branch — o **EXECUTOR** (`-kt`, que impõe as anotações em runtime via `__HB_CHKTYPE`).

> **O REENQUADRAMENTO que governa a fase:** *as paredes não são "não dá para inferir" — são **"o
> programador não tem como DIZER, e onde ele diz, o compilador JOGA FORA"***. Estender o Harbour
> aqui **não é ensinar o compilador a adivinhar**: é dar **alcance** às anotações e deixar o `-kt`
> executá-las. Toda parede cai **por DECLARAÇÃO**, jamais por inferência — é o **oposto** de
> heurística: em vez de *deduzir* fato, **fabrica-se fato declarado e verificado**.

**Os quatro fatos que o core descarta hoje** (cada um é um experimento):
**E1** `FUNCTION F() AS CLASS Farol` **não compila** (`harbour.y:329-335`) — e
`hb_compChkTypeRetWrap` (`hbmain.c:2845`) **já existe para impor o retorno declarado e não tem o
que impor**. É a parede do `oX := AlgumaFabrica()`, e é a **maior alavanca do sistema**.
**E2** o cast `AS CLASS` em expressão é parseado e **descartado** (`harbour.y:845-875`) — honrá-lo
dá a **saída de emergência universal**. **E3** `_HB_SUPER` é parseado e a **ação da gramática está
VAZIA** (`:1277-1278`) — o core nunca liga o pai. **E4** parâmetro já aceita `AS CLASS` e o `-kt`
já o confere: `F( @oF )` declarado **já é fato**, e a ferramenta envenena sem olhar.
A **única** parede que fica de pé é a do **macro** — e **deve** ficar: recusa honesta é produto.

**A LINHA entre FATO e PALPITE** *(decidida na sessão; é a contribuição conceitual)*: o motor
interprocedural **já existe** e está desligado (`hInter := NIL`, src:563 — portão RE.3). O
desligamento em bloco foi **certo no efeito e GROSSO na causa**. **Dedução FECHADA** (fontes
enumeráveis por construção — *todos os `RETURN` de F estão no corpo de F*) é **FATO** e pode
julgar. **Dedução ABERTA** (exige enumerar o inenumerável — *"todos os chamadores passam um
Farol"*) é **PALPITE** e só sugere: **`B7ParamType` fica desligado no veredito PARA SEMPRE**.
*Corolário: a diferença entre "a ferramenta infere" e "o core infere" **não é o repositório onde o
código mora** — o que legitima é **exaustividade + colapso-para-desconhecido**, e só isso.*

**Não é caminho — o preprocessador** *(tiro no escuro do Diego, respondido)*: ele varre todas as
linhas, mas vê **TOKENS, não PROGRAMA**. Dar-lhe tipos = **segundo parser dentro do core**
(réplica de gramática, §1.2/#2) — heurística **vestindo a autoridade do core**. E ele **já faz o
papel certo**: é ele que **DECLARA**; o compilador é quem **RESOLVE**. Os fatos já vêm dele —
morrem **depois**, sem leitor.

**Escopo** — três fases, nesta ordem (**decisão do Diego: experimentos PRIMEIRO**):
- **Fase 0 — SONDAR AS PAREDES** *(ordem do Diego: "sondar antes de decidir")*. **Zero linha de
  core**: script em `tools/` (instrumento, **não** verbo da CLI) que roda no corpus do CORE
  (`work/`) e emite o histograma dos sends por veredito e, nos desconhecidos, **o bucket do
  PORQUÊ** (`macro-message` / `funcall-no-rettype` / `cast-discarded` / `member-not-declared` /
  `param-byref-poison` / `param-untyped`). **É o portão que ORDENA a Fase 1** — se 90% for
  macro-dispatch, E1/E2 são decoração; se for retorno de fábrica, **E1 é o jogo inteiro**.
- **Fase 1 — trilha de linguagem**: E1 → E2 → E3 → E4, **na ordem da alavancagem MEDIDA**, cada um
  gateado pelo que já existe (`fAst` / `-kt`) → **sintaxe nova nunca quebra código velho**. Fecha
  com **E5**: re-medir e decidir **com prova** o que vai ao PR da B6.
- **Fase 2 — o cursor**: coluna exata da mensagem no sítio de envio + classe do receptor **por
  sítio** vindas do core (`comptype.c` novo, `ast-17`); `ResolveAtQuery` passa a **perguntar o
  receptor**; `usages` ganha **recorte por escopo** (reusando o `FuncAtLine` que o `rename` já
  usa — hoje o `usages` **vaza homônimos de outras funções**); verbo novo **`definition`** +
  **`DefinitionProvider`** na extensão VSCode.

**Critério de pronto (mecânico)**:
- Fase 0: o histograma roda no corpus e **cada experimento da Fase 1 tem um NÚMERO atrás dele**.
  **Nenhum experimento sobe sem esse número.** *(Número vive aqui e na spec — **nunca em página**,
  §4.)*
- Fase 1: por experimento — contagem de conflitos do bison **INALTERADA**; pcode **byte-idêntico**
  sem as flags; e, sob `-kt`, a **anotação mentirosa ESTOURA** com o sítio nomeado.
- Fase 2: cursor em `oF` lista só o `oF` daquela função; cursor em `Brilho` dá
  `query: Farol:Brilho` com `oT`/`oI` **excluded**; `definition` sai **1 com motivo ACIONÁVEL** no
  receptor desconhecido (**nada de lista de candidatos — isso é TRIAGEM**); casos 72/73/74/84/85/86
  **byte-idênticos** (divergência = **BUG**, não contrato); régua adversarial do caso 64
  **estendida ao `comptype.c` do core**.

> ⚠️ **DRIFT PRÉ-EXISTENTE, a submeter ao Diego ANTES de re-baselinar** (§3): `run.sh:2347`
> (o assert que **codifica o bug como contrato**), o `rename` a partir de um send (passa a
> **não** renomear homônimos — é conserto), e o `TokenCols()` que casa por TEXTO e aponta
> **todas** as colunas da linha (muda `Location[]` existente).

> **W0026 fica FORA** (`hbgenerr.c:114-150`, **zero emissores**): o `comptype.c` **é** a máquina que
> falta a ele, mas ligá-lo mudaria a saída do `harbour -w3` **STOCK**. Fase própria, **depois do
> B6**, atrás de flag opt-in — e **só depois de E3**.

## P15 — o PROFILER do core, e a pergunta da COBERTURA *(pista do Diego, 2026-07-13; **EXPLORATÓRIA — NADA EXPLORADO AINDA**)*

**O arquivo a abrir**: `~/devel/harbour-core/harbour/tests/profiler.prg` — o driver; a camada
de relatório é `src/rtl/profiler.prg` (classes `HBProfile*`, `CREATE CLASS`), e o canal do VM é
`__SetProfiler( <lLiga> )` (hvm.c:12343). **A pista do Diego**: *"ele pode até ser ou ajudar a
criar cobertura de código"*.

**O que o canal dá HOJE** *(lido no fonte, não suposto)*: contadores no VM — por **função**
(símbolo, via `__dynsGetPrf()`), por **método** (classes.c) e por **opcode** (globais
`hb_ulOpcodesCalls`/`hb_ulOpcodesTime`, hvm.c:1342-1357), cada um com **chamadas + ticks**. O
opcode é **agregado no processo inteiro**, não por site. Build gated por `HB_NO_PROFILER`.

**Logo, a leitura honesta antes de sonhar**: a granularidade nativa é
**função/método chamado ≥ 1 vez** — isso é *alcançabilidade de símbolo*, **não** cobertura de
linha, de site nem de ramo. A pergunta da exploração é a de sempre (§1.2): **o core passa a
contar por SITE/LINHA?** (o pcode já carrega `HB_P_LINE`; um contador por linha/por site de
chamada é **hipótese plausível, não fato**) — e a resposta certa, se ele não conta, é
**estender o core**, nunca inferir cobertura na ferramenta.

**Consumos a avaliar** (nenhum aprovado):
- **Cobertura da nossa própria suíte** — ferramenta de PROCESSO nosso, fora do produto: qual
  código de `src/hbrefactor.prg` os 120+ casos nunca executam. É o uso de menor risco e o que
  não precisa passar pelo portão da Fase D.
- **Cobertura como fato do PROJETO DO USUÁRIO** — aí sim é produto, e cai direto no portão
  abaixo.

> ⚠️ **PORTÃO HERDADO — leia a Fase D antes de escrever uma linha**: evidência de execução como
> camada que *prioriza conferência manual* é **TRIAGEM, e triagem não é produto** (fechado pelo
> Diego, 2026-07-08). Cobertura só volta com **consumo 100% fato** (ex.: alimentar cheque
> imposto/verificação, não "olhe aqui primeiro"). **Um fato de execução não vira veredito
> sozinho**: "nunca executado" ≠ "morto" (`possible` continua `possible`).

## P-AUDIT — fila remanescente da varredura anti-heurística

A varredura de 2026-07-12 fechou A1-A4 (todos entregues). **Sobra na fila:**

- **(i) `ResolveInclude`** — re-implementa a busca de include do compilador (gatilho 4). Hoje
  inofensivo porque o dump já traz o caminho RESOLVIDO (`hb_pp_FileNew` reescreve
  `szFileName`, ppcore.c:2945-3060), mas é **cópia degradada por design**: ou morre, ou passa
  a consumir `ModuleDeps`/`harbour -gd`.
- **(iii)** varrer os *"se não é X, então é Y"* (gatilho 3) e as comparações de TEXTO onde o
  dump já tem número/id (gatilho 1).
- **(v)** toda chave OPCIONAL do dump lida SEM `hb_HGetDef` (`marker`, `ruletok`, `from`,
  `col`, `undoes`, `generates`) — acesso direto é **BASE/1132 em produção** e a suíte não
  pega.
- **`HeadClashWitness` fica sob vigilância** (passou na auditoria, não é achado): quem julga
  cada candidato é o pp vivo, mas a **completude do conjunto de candidatos** é raciocínio meu
  sobre o core (`hb_pp_tokenValueCmp`, ppcore.c:2704) — verdadeiro hoje, auditável sempre.
- **Hipótese registrada (não consegui quebrar):** família `y` (case-sensitive) — a ferramenta
  uniformiza toda palavra de regra com `Upper()` e fundiria duas regras `y` que o core vê como
  distintas. **Erro fail-closed, sem quebra demonstrada.**

> **A P-AUDIT é para uma SESSÃO DEDICADA E LIMPA** — prompt pronto em
> [prompt-revisao-anti-heuristica.md](prompt-revisao-anti-heuristica.md). Não a rode como
> apêndice de uma entrega: **quem acabou de escrever o código é o pior juiz dele.**

## P-DOC — corpus explicativo do PP *(ESSENCIAL, ordem do Diego; RETOMÁVEL)*

Bateria que casa diretivas REAIS do Harbour com seus `.ppo` e `.ppt`, explicando também para
o **programador Harbour** — fonte de conhecimento do pp para o Diego, para o usuário e para
as próprias fatias. Método = os QUATRO oráculos (`.ppo` + `.ppt` + dump + fixture
COMPILÁVEL); suíte SEPARADA do contrato (`make ppcorpus`, não `make test`).
**Famílias 1-4 entregues** (SET EXACT, @…SAY, STORE, hbclass) + as do eixo P (markers, `<@>`,
regra-que-gera-regra, derivação, estrutura, abreviação, instrumento, escopo). **Regra de lacuna — TROCADA pelo Diego em 2026-07-13**: era *"a lacuna PAUSA a exploração e vira
experimento de core imediato"* (foi ela que pariu o rename-DATA); passa a ser **PROVE, MARQUE e
SIGA** — repro executável + fase no roadmap com critério de pronto, e o conserto vira **fatia
própria sob autorização**. Motivo: a exploração dos **USOS** produz lacuna mais rápido do que se
conserta, parar a cada uma mata o mapa (que é o produto da fase), e consertar no calor do achado
é como se pula o portão. *(Exceção: achado em que a ferramenta QUEBRA código do usuário sobe na
hora — urgência de aviso ≠ urgência de conserto.)* Régua completa:
[pp-corpus/README.md](pp-corpus/README.md). Spec: [spec-pdoc-corpus-pp.md](spec-pdoc-corpus-pp.md); corpus vivo:
[pp-corpus/README.md](pp-corpus/README.md).

**Família de MEDIÇÃO ✅ (2026-07-13) — e o veredito que ela derrubou.** O alvo previsto (o
`hbct` como "contrib rico") **não existe**: medido, o hbct não declara **uma** diretiva de
comando. A medição foi feita onde as diretivas de fato estão — dump do core sobre os **33
headers do ecossistema que declaram diretiva**, **4.582 regras distintas** — e derrubou uma
**recusa documentada do P4/P5**: o mkind `strdump` *"não existe em regra"* é **FALSO**. Ele é o
**`#<x>`** (`ppcore.c:4277`), **31 regras** o emitem e **6 estão no `std.ch`** — auto-incluído
em todo programa Harbour (`MENU TO`, `SET COLOR TO`, `RELEASE ALL LIKE`, `RUN`, `JOIN`). Placar
real dos mkinds: **14 consumidos, 1 recusado** (só o `dynval`). Guarda: `corpus_strdump`
(`make ppcorpus` 47/0); conhecimento: [pp-corpus/strdump.md](pp-corpus/strdump.md).

**Família TEXT/ENDTEXT ✅ (2026-07-13) — LACUNA REAL achada e FECHADA no core (`ast-17`).** Num
bloco de stream (`TEXT…ENDTEXT`, `#pragma __text|__stream|__cstream`) o fonte do programador
**vira DADO**: cada linha crua sai como string (o pp FABRICA um marker `strdump`,
`ppcore.c:5821`). E essas strings chegavam ao dump com **`line: 0`, `col: null`, `prov: "n"`** —
**sem origem nenhuma** —, enquanto uma string comum do fonte vem posicionada. Não era regra de
string: era a maquinaria de stream **descartando** a linha que ela acabara de ler.
**Por que é correção**: o conteúdo é dado e a ferramenta **não o edita nem com opt-in** (§1) —
mas sem posição ela não podia sequer **RELATAR**. Renomear um símbolo homônimo deixava o bloco
dizendo a coisa antiga **em silêncio**, e nada no mundo podia avisar. **`ast-17`** (em
`hb_pp_tokenAddStreamFunc`, gated por `fTrackPos`): a linha do bloco chega com a sua linha-fonte
e `prov: "s"`. Expansão intacta — `make test` **990/0**, `make ppcorpus` **53/0**. Guarda:
`corpus_text`; conhecimento: [pp-corpus/text-stream.md](pp-corpus/text-stream.md).
*(Commit do core pendente de autorização.)*

**Família DEFINE DINÂMICO ✅ (2026-07-13) — a última recusa de mkind, agora MEDIDA.** O `dynval`
**sobreviveu** à medição que matou a do `strdump`: **0 em 4.582 regras** reais; as únicas duas
são builtin do pp (`__FILE__`/`__LINE__`, `ppcore.c:7253`), e o dump **as exporta**, com cada
aplicação e a sua linha. *(Correção de fato: o `ast-schema` listava `__DATE__` como dinâmico —
não é; dinâmicos são dois, e só dois.)* **O achado é a SENSIBILIDADE A POSIÇÃO**: `__LINE__`
vale a linha corrente, logo **todo verbo que desloca linhas muda o programa** — verificado, o
`extract-function` mudou o valor de 12 para 11. **E isso NÃO é bug**: o statement mudou de linha
mesmo, e a ferramenta não alegou preservação (o verbo cria função nova; identidade de pcode
nunca esteve na mesa). O que falta é o **aviso**. Guarda: `corpus_dyn` (`make ppcorpus` 58/0);
conhecimento: [pp-corpus/dynval.md](pp-corpus/dynval.md).

### P16 — o relato do NÃO-VERIFICÁVEL *(aberto 2026-07-13; **consumo do `ast-17` + `dynval`; A RESOLVER**)*

**Escopo**: o `usages` (e o relatório dos verbos de edição) passam a **RELATAR** — nunca editar —
o que a ferramenta enxerga e hoje cala. **Duas fontes, o mesmo dever** (§1 do CLAUDE.md:
*detecção e relato preciso, jamais edição automática*):
- **(a) ocorrência em DADO** — o nome dentro de bloco de stream, que ganhou posição no `ast-17`.
  Hoje: renomeia-se `cSaldo`, a ferramenta edita certo e verifica certo, e o `TEXT` segue
  imprimindo `cSaldo` **sem uma palavra**.
- **(b) módulo SENSÍVEL A POSIÇÃO** — o que expande `__LINE__` (fato: as aplicações, com linha).
  Um verbo que desloca linhas deve dizer *"este módulo expande `__LINE__` em N sítios; o valor
  deles muda com esta edição"*. **Não congelar o valor** — o valor novo é o certo; o produto é
  o aviso. **Lacuna de COMPLETUDE medida (2026-07-15, `corpus_dyn`)**: a provenância do `dynval`
  é **severada na camada de statement** — o literal injetado chega como `NUMERIC` comum, token
  `prov:"n"` mas **sem `from`**; a origem só existe em `ppApplications`, ligada ao statement
  **por linha** (o eixo frágil). Um verbo que anda o statement AST é cego a isso. **Decisão do
  Diego** (spec antes de código): (a) o consumidor cruza `ppApplications` por linha; **ou** (b)
  **estende-se o core** para povoar `from` no token expandido do `dynval` — canal que a família
  `derivation` já usa —, tornando o vínculo independente da linha. É o caminho-padrão do §1.2
  (estender o core), barrado só pelo portão de commit no core.
- **(c) STRING que é MACRO VIVO** *(fonte nova, 2026-07-14, descoberta por assert)* — uma string
  literal que contém `&nome` é **reavaliada em runtime** e vale o **valor do memvar**. Renomear um
  memvar muda o comportamento de toda string que o mencione. O `usages` já relata *"possible
  reference in string"* — o que falta é o **rename** dizer o mesmo, e dizer **por quê** (hoje o
  usuário lê "possible" sem saber que é executável). Fato no dump: `usesMacro` + a string com
  posição. Prova: [`tests/ppc-strfam/sf.prg`](../../tests/ppc-strfam/sf.prg).
**A régua do §1 é dura e vale inteira**: detecção e relato preciso, **jamais** edição automática
— nem com opt-in. O relato é aviso ao humano/agente, não sugestão de edição.
**Critério de pronto (mecânico)**: caso novo — `usages cSaldo` lista a ocorrência do bloco
marcada como **DADO** (com arquivo:linha), separada das ocorrências de símbolo; o `rename` a
reporta e **não a edita** (fonte do bloco byte a byte intacto, verificação byte-idêntica);
nenhuma palavra de fixture em `src/hbrefactor.prg` (régua do caso 64); `make test` verde.

### P-REV — a REVISÃO do corpus para o método v2 *(aberta 2026-07-14; **EM CURSO**)*

**Por que existe:** o corpus antigo nasceu no método velho — conhecimento no markdown, prova por
`grep` no `.ppo`. O Diego pegou, num único arquivo, **três frases falsas** e um comentário que
**afirmava mais do que o teste provava**. *"Esta documentação é séria"* — e ela vai **treinar o
Claude do futuro**: o que estiver torto aqui vira erro herdado.

**O método v2** (régua completa: [pp-corpus/METODO.md](pp-corpus/METODO.md) § 4b): o
conhecimento mora no **`.prg`**, que **compila, RODA e se afirma** (`hbtest`); o comentário
**INTERPRETA** o oráculo (não o transcreve, não vira ensaio); e nada se afirma sem (a) assert,
(b) oráculo, ou (c) citação do core com `arquivo:linha`.

**Marcação MECÂNICA** *(ordem do Diego)*: fixture revisada leva o selo `METODO-V2(<data>)` no
cabeçalho, e a guarda **`corpus_metodo`** (em `make ppcorpus`) **imprime o placar e NOMEIA a
fila** a cada execução — a pendência não some de vista. Ela **reprova selo mentiroso** (arquivo
selado sem assert próprio nem irmão que asserte).

**DOIS EIXOS, e o segundo depende do primeiro** *(2026-07-15)*. Provar a **diretiva** (camadas
A/B) não fecha a família: falta provar que o **loop dos quatro oráculos rodou até não sobrar
buraco** (METODO §5b/§7). São duas provas, ordem parcial — não se julga a completude da AST de
uma diretiva ainda não provada:

| eixo | guarda | o que prova | estado (2026-07-15) |
|---|---|---|---|
| **diretiva** | `corpus_metodo` | a diretiva VIRA (texto) e VALE (runtime) | **24 selos** · fila `ppc-instr`·`ppc-live`·`ppc-pragma` + os 3 `fix*` |
| **completude** | `corpus_completude` | o loop dos 4 oráculos convergiu (§5b respondida no dump) | **1** (`ppc-dyn`=`HOLE:P16`) · **14 pendentes** |

Ambas as filas são **NOMEADAS a cada `make ppcorpus`** (não-bloqueantes; reprovam só selo/veredito
mentiroso) — não congelar aqui, ler do guarda. Vereditos de completude: `COMPLETE(data)` /
`HOLE=Pxx` (aponta a fase que fecha o buraco) / `⏳` (V2 feito, loop não rodou) / `—` (V2 não
feito → n/a). Exemplo da forma:

| família | diretiva | completude |
|---|---|---|
| `ppc-dyn` | ✅ 07-15 | 🕳 `HOLE=P16` |
| `ppc-deriv` | ✅ 07-15 | ⏳ (loop não rodou) |
| `ppc-instr` | ⏳ | — (n/a até V2) |

⚠️ **Cuidado à parte**: `markers`, `rule-structure` e `abbreviation` usam fixtures de `tests/fix*`
**compartilhadas com o contrato** (`make test`, casos 111/113/115) — revisar ali (ou até **selar**)
mexe no contrato e exige apresentar o drift antes (CLAUDE.md §3).

**Critério de pronto (mecânico) — eixo diretiva**: `corpus_metodo` acusa **0 pendentes**; toda
família tem guarda que **RODA** o `.prg` (não só `grep`); todo `.md` de família cabe em índice +
lacunas.

### P-COMPLETUDE — o LOOP dos oráculos rodou até não sobrar buraco? *(aberta 2026-07-15; **EM CURSO**)*

**Por que existe:** a P-REV provou a **diretiva** de cada família (camadas A/B) mas **nunca rodou o
loop dos quatro oráculos** — entender via `.ppo`/`.ppt`/dump/fixture, e quando um oráculo **falta
informação, melhorar o oráculo** (estender o core), até não sobrar buraco (METODO §5b/§7). O buraco
do `dynval` (o literal do `__LINE__` chega ao statement AST **sem `from`** de volta à origem) foi
achado **por sorte**, não pelo método. Regra: "regra nova sem portão novo é regra que eu vou violar
de novo" (CLAUDE.md §1.6).

**A infra (entregue 2026-07-15) — o loop vive no METODO §5b (o passo a passo) e é cobrado pelo
portão `corpus_completude`.** *(Um skill dedicado foi tentado e DESCARTADO, 2026-07-15: o baseline
mostrou agentes rodando o loop **sem** ele — o portão + o METODO §5b já bastam. "Se dá para o portão
cobrar, não é doc: automatize" — writing-skills.)*
- o **portão `corpus_completude`** cobra, por família, um veredito de **rastro executável de
  polaridade casada**: selo `// COMPLETUDE(<data>): COMPLETE|HOLE=Pxx` na fixture **casado** com um
  check tagueado `COMPLETUDE(<fam>=COMPLETE|HOLE:Pxx)` no guarda — `COMPLETE` ⟺ o check **lê a AST**;
  `HOLE=Pxx` ⟺ check **negativo** + `### Pxx` vivo aqui. Não-bloqueante (nomeia a fila), reprova só
  a mentira estrutural.

**A fila:** toda família `METODO-V2` roda o loop e registra o veredito. **Primeiro item nomeado —
o piloto:** `from`-no-dynval (a extensão de core da **P16 (b)**, `src/pp/ppcore.c:5501-5522`) fecha
o buraco do `ppc-dyn` e faz o veredito transitar `HOLE=P16 → COMPLETE` (a asserção negativa do
`corpus_dyn` inverte para positiva). É fatia própria, **sob autorização por-commit do Diego** (o
schema bump move os dois repos juntos — caso 122 vermelho no meio, de propósito).

**Critério de pronto (mecânico):** `corpus_completude` acusa **0 vereditos mal-formados** e a **fila
vazia** (toda família V2 com um `COMPLETUDE` casado e verificado).

### P-NOVOS — continuar avançando nos casos do core *(a fila que a revisão não substitui)*

O combinado com o Diego: **revisar o que existe E seguir achando o que falta**. A fila de
espécimes está em [pp-corpus/uses-core.md](pp-corpus/uses-core.md), e a ordem de estudo dos
testes do próprio pp está em [pp-corpus/METODO.md](pp-corpus/METODO.md) § 2b —
`tests/pragma.prg` (a superfície do `#pragma`, **começada e estacionada**), `tests/ppapi.prg` e
`tests/hbpp/` (o pp vivo, caminho do P12). Achado recente que virou família:
[pass-cycle.md](pp-corpus/pass-cycle.md) — *o pp esgota o comando antes de avançar de linha*
(levantado pelo Diego, provado no fonte e nos três oráculos).

### P18 — o símbolo DENTRO do macro chega SEM POSIÇÃO *(aberto 2026-07-13; **A RESOLVER**)*

**Achado do estudo de `harbour/tests/pp.prg`** (o teste que os autores do pp escreveram para
o pp — indicação do Diego). Diante de um **macro puro**, o `<"z">`/`<(z)>` **não estringificam**:
o pp **desfaz o `&`** e emite o identificador como **código** (`ppcore.c:5250-5262`, `value + 1`,
derivação registrada como **`clone`**). É a semântica Clipper (`USE &cArquivo` tem de virar a
variável). **Logo o nome dentro do macro é SÍMBOLO DE VERDADE** — o compilador o lê, e
`occurrences[]` o registra.

**O buraco:** o recheio consumido (`&cAlvo`) **tem posição** (linha, col, len); o símbolo
**emitido não tem** (`col: null`, `prov: "n"`), e o `at` da derivação é **0** — aponta o `&`,
não o nome. **Verificado:** o `usages` acerta (relata o *read*), mas o `rename` edita **só a
declaração**, o `.hrb` muda e o verificador reverte — **recusa falsa num rename que seria
byte-a-byte legítimo**.

**E a ferramenta NÃO pode se virar sozinha:** deduzir *"pule 1 caractere (2 se terminar em
ponto)"* é **réplica de gramática do core** (§1.2, gatilho 2). O core **acabou de calcular**
`value + 1` — e não conta a ninguém. **LACUNA REAL → experimento de core.**
*(Cuidado com a intuição fácil: **isto NÃO é a parede do macro**. Não há macro em runtime — o
pp o desfez em tempo de compilação. Tratar todo `&` como opaco é heurística por aparência.)*

**Critério de pronto (mecânico)**: o token emitido pelo macro-unwrap chega com `line`/`col`
apontando o **NOME** (não o `&`) e `prov: "s"`, e o `at` da derivação bate; o `rename` do
símbolo passa a editar `&cAlvo` → `&cNovo` e **verifica byte-idêntico**; a guarda
`corpus_strfam` (que hoje assere a LACUNA) inverte de sinal; `lexdiff` 0; `make test` verde.

### P17 — a COMPILAÇÃO CONDICIONAL esconde diretiva, e a ferramenta QUEBRA O CÓDIGO *(aberto 2026-07-13; **A RESOLVER — o mais grave em aberto**)*

**Achado da medição de USO** (direção do Diego: estudar o pp no fonte real do Harbour). O core
declara diretiva **dentro do próprio `.prg`** em **152 dos 419 módulos** do corpus (36%), com
**1.640 comandos inventados** e 6.528 aplicações. E o padrão campeão — `rddtst.prg`, a DSL de
teste do RDD, **1.881 usos** — declara **DUAS regras rivais com a MESMA cabeça**, uma em cada
ramo de um `#ifdef`.

**O dump só enxerga o ramo ATIVO.** As diretivas do ramo desligado não existem em canal nenhum
(nem `.ppo`, nem `.ppt`, nem dump) — o pp as pula e não deixa rastro.

**Consequência, VERIFICADA (repro mínimo, Harbour puro):**

```harbour
#ifdef MODO_RASCUNHO
   #xcommand PINTA <x> => pt_Rascunho( <x> )   // <-- INVISÍVEL a esta compilação
#else
   #xcommand PINTA <x> => pt_Final( <x> )
#endif
PROCEDURE Main()
   PINTA 7
```

`rename PINTA -> COLORE` edita a diretiva do `#else` **e o uso**, deixa o ramo `#ifdef` com
`PINTA`, e **anuncia sucesso**: *"verified: 1 application site(s) + 1 directive occurrence(s);
.ppo and .hrb byte-identical"*. E então:

```
$ harbour m.prg -DMODO_RASCUNHO
m.prg(9) Error E0030  Syntax error "syntax error at '7'"
```

**A ferramenta escreveu uma árvore quebrada e disse que estava tudo certo.** É a promessa
central do produto sendo violada — e em silêncio, porque a rede de verificação (`.ppo`/`.hrb`
byte-idênticos) é sobre a **configuração que ela viu**, e a outra configuração é **outro
programa**.

**Classificação: LACUNA REAL** (o fato não está em oráculo nenhum) → **experimento de core**.
O pp **sabe** que pulou aquelas linhas (`iCondCompile`); ele só não conta.

**A resposta NÃO é editar os dois ramos** — o ramo desligado é **não-verificável** nesta
compilação, e o §1 é explícito: não se edita o que não se pode provar. A resposta é o **fato que
permite RECUSAR com motivo**: *"esta cabeça também é declarada em região pulada por compilação
condicional (linha N) — o rename não pode provar aquele ramo; recusando"*.
**Critério de pronto (mecânico)**: o dump exporta as diretivas puladas por `#if[n]def`/`#if`
(posição + cabeça, sem entrar no mérito do ramo); o `rename` de cabeça de DSL **recusa** com
motivo acionável quando existe declaração homônima em região pulada; o repro acima passa a
recusar em vez de quebrar; `lexdiff` 0 e `make test` verde.

### P15 — o rename através do `#<x>`: um BUG e uma decisão *(aberto 2026-07-13; **A RESOLVER**)*

**(1) BUG — VERIFICADO, sem decisão pendente.** Num `MENU TO nEscolha` (Harbour puro, zero
include), o `usages --at` no sítio da diretiva devolve **1 resultado** e chama o `nEscolha` de
*"marker name (no identifiable owner)"* — **perde a declaração e a leitura do LOCAL**. O
`rename` daí edita só o sítio da DSL; o verificador vê a contagem de símbolos mudar e reverte
(fonte intacto, mas **recusa falsa por resolução errada**). Causa:
[src/hbrefactor.prg:2106](../src/hbrefactor.prg#L2106) — `generates` *"vence QUALQUER binding
homônimo"*, regra escrita para o local que a **expansão fabrica** e que não separa esse caso do
local que a diretiva apenas **referencia** (gatilho §1.2/3: *"se não é X, então é Y"* sem fato
que separe). **O fato que separa JÁ ESTÁ NO DUMP**, em dois eixos, os dois verificados: (i) o
recheio só é símbolo se a derivação tiver **`clone`** (`from[].op`) — só-`stringify` é DADO, e
esse eixo a ferramenta **já respeita** (renomear o local não toca um `LAVRA nLastro` homônimo:
guarda `corpus_strdump`); (ii) o dono do símbolo sai de `declarations[].nameLine`/`nameCol`, que
**coincide** com o recheio no local FABRICADO pela expansão e **não coincide** no local do
programador — e é este eixo que falta. Identidade posicional contra `ppApplications[]`, zero
texto. É **consumo**, não core.
**Critério de pronto (mecânico)**: caso novo na suíte com `MENU TO` do `std.ch` — `usages` no
sítio da DSL lista **as 3** posições do local; o `rename` a partir do sítio da DSL resolve
`rename-local` (não `rename-pp-marker`); o caso do local FABRICADO (`<n> => LOCAL <n>`) segue
resolvendo o marker, byte-idêntico; `make test` verde.

**(2) DECISÃO DE PRODUTO — do Diego, NÃO implementar antes da ordem.** Resolvido o bug, o
rename edita as 3 posições e o `.hrb` **muda de verdade**: a string derivada é outra. E ela é
**viva em runtime** — o `__MenuTo` (`src/rtl/menuto.prg`) faz `__mvPublic( cVariable )` (cria um
memvar com aquele NOME) e `ReadVar( Upper( cVariable ) )`, que qualquer bloco de `SET KEY` pode
ler. Logo **não existe rename preservador** aqui, e a reversão do verificador está **certa**.
A pergunta é: rename cuja mudança de comportamento é **derivada, prevista e exibida** (a
ferramenta já imprime `predicted string: "nEscolha" -> "nOpcao"`) é **recusa honesta** ou
**opt-in explícito**? O §1 do CLAUDE.md manda relatar e nunca editar o não-verificável — mas
isto **não é** não-verificável: a derivação é FATO do ast-12.

## Rename de DATA/VAR member — fatia 2

A fatia 1 entregou (caso 110): `rename` sobre `VAR nSaldo`/`::nSaldo` edita declaração +
getter + setter, mapeia `NOME→novo` E `_NOME→_novo`, e recusa homônimo entre classes. **Falta:
`ACCESS`/`ASSIGN` (getter/setter explícitos), DATA herdada de superclasse, e o `resolve-at` de
`::membro` escopando a classe** (rename a partir do site de USO). Spec:
[spec-rename-data.md](spec-rename-data.md).

## Dívidas e limites conhecidos

- **Dívida da SITE-EX:** as seções profundas da `site/index.html` (rename de DATA, genealogia
  de regra, tempo de vida de diretiva, sequestro por abreviação) ainda têm transcript **colado
  à mão** — corretos hoje, mas **FORA do portão** do `make site-check`, e portanto sujeitos ao
  apodrecimento que a fase existiu para matar. Migrá-los para `tests/site/`.
- ~~**Limite conhecido (B5.1):** dois alvos com módulos de mesmo nome-base colidiriam no
  `ReadAst`; "só afeta análise, não a posse".~~ **FECHADO por RECUSA (2026-07-13, caso 124)** —
  e a linha acima era **complacente e errada**: medido, a ferramenta não "degradava a análise",
  ela **mentia** (`MAIN -> ALFACALC [external]`, com **exit 0**, porque o dump de `subA/util.prg`
  era sobrescrito pelo de `subB/util.prg`). O guard agora vive no `LoadProject` — que já tem a
  lista canônica de fontes de TODOS os alvos —, **cobre todo verbo de uma vez**, e recusa
  nomeando os dois caminhos e o remédio.
  **A recusa é DEFINITIVA, não provisória** *(decisão do Diego, 2026-07-13)*: suportar o caso
  exigiria nome de artefato derivado do CAMINHO no harbour/hbmk2, e **isso não faz sentido —
  o alcance da ferramenta é o alcance do toolchain.** *(A conclusão da P-AUDIT — "o basename é
  único por FATO do builder" — vale só para alvo ÚNICO: lá o link falha. Um `.hbp` multi-alvo
  com workdir por alvo **builda**, e é por essa porta que a colisão entrava.)*

- > ⚠️ **RETRATAÇÃO (2026-07-13).** Escrevi aqui um "bug novo": *o `-rebuild` não desce para
  > os sub-projetos de um container, então o `LoadProject` recusa projeto bom, de forma
  > intermitente.* **NÃO REPRODUZ.** Re-sondado de forma determinística (tudo limpo →
  > pós-build → pós-build repetido), o `-rebuild` imprime as duas linhas de comando em
  > **todos** os estados. O que eu vi (*"Target up to date"*, zero comandos) aconteceu num
  > diretório **sujo de builds que haviam FALHADO** durante a própria sonda — e eu construí
  > mecanismo e manchete em cima de ruído, sem repetir o experimento no limpo. É o **§3.2 das
  > cicatrizes** de novo (*medir o que eu acho, não o que roda*), agora dentro de uma sessão
  > cujo assunto era exatamente isso. **O bug não existe até que alguém o reproduza.**

- **✅ O CANAL do `LoadProject` — CONSERTADO NO CORE (2026-07-13; suíte 990/0, ZERO drift).**
  *(Régua do Diego: **para projeto, o hbmk2 é SEMPRE a fonte de verdade** — build, onde estão
  os arquivos, includes. E o corolário, que é a regra e não a exceção: **necessidade
  identificada → o CORE passa a responder**.)*
  **O que estava errado:** a ferramenta **não perguntava** nada ao hbmk2 — ela **raspava o
  efeito colateral de um build** (`-traceonly` → a linha *"Harbour compiler command"*). Essa
  linha é montada a partir de `l_aPRG_TO_DO` (hbmk2.prg:6201): os fontes **a (re)compilar**,
  não os fontes do ALVO — em modo incremental com o alvo em dia ela **nem sai**. Daí a muleta
  do `-rebuild`, que forçava **recompilar o projeto inteiro só para descobrir de que ele é
  feito**. E ainda exigia o `CmdTokens`, uma tokenização de shell (aspas, parênteses)
  replicada na ferramenta. *Gatilho 6: o canal barato funcionava, então ninguém perguntou se
  era o correto.*
  **A varredura (§1.3), antes de estender:** `hbmk2 --help` inteiro — `--hbinfo[=nested]` dá
  JSON por alvo, mas só de **configuração de build** (`targetname`/`targettype`/`outputname`),
  **nem fontes, nem includes, nem flags**; a API de plugin já fora descartada na B5.1 (expõe
  escrita, não a lista resolvida). **O canal de consulta não existia.**
  **O core passou a responder — comando NOVO `--hbproject[=nested]`** (ordem do Diego: *"se
  mudar a saída de algum comando, crie um comando novo"* — o `--hbinfo` fica **byte-idêntico**).
  Devolve **um bloco JSON por alvo** com o conteúdo **resolvido** (`.hbp`/`.hbc`/`.hbm`, `-i`,
  `${macros}`, filtros `{...}` já expandidos): `sources` (`.prg` **e** `.hbx` — o hbmk2 os põe
  no mesmo array de entradas, hbmk2.prg:3748), `incpaths`, `prgflags`. **Responde ANTES de
  qualquer build** (`RETURN _EXIT_OK`) — a pergunta *"de que este projeto é feito?"* deixou de
  depender do estado do diretório de build, e responde **até para projeto que não compila**
  (medido no `gtwvg`).
  **Armadilha achada ao integrar:** emitir só o `aOPTPRG` **não basta** — o compilador também
  recebe `-n1`/`-n2`, os `-u+` dos headers do `.hbc`, `-j`/`-gd` e as flags de plataforma. Com
  um subconjunto, o consumidor compilaria o alvo **diferente de como o hbmk2 compila** (59
  falhas na suíte, todas nos verbos que editam-e-verificam: sem `-n2` o pcode muda). O
  `prgflags` monta agora **a lista exata que o compilador recebe**.
  **Na ferramenta:** o `LoadProject` consome o JSON; o **`CmdTokens` MORREU** (réplica a menos);
  o `-rebuild` sai da consulta. **Zero drift** — as 990 asserções, incluindo o projeto com
  `-inc`/`.hbc`/`.hbx` (caso 29), passam sem re-baseline. **Commits (core + ferramenta)
  pendentes de autorização por-commit do Diego; `NEWS.md` do core e `CHANGELOG.md` a escrever.**
- **B5 — critério vivo da extensão:** Diego usa no dia a dia; sem regressão. **Todo comando
  novo do CLI chega à `extension.js` na fase que o entrega** (regra no CLAUDE.md).

## H — HIGIENE DE DIRETÓRIOS TEMPORÁRIOS *(pista do Diego, 2026-07-14; **H.1 e H.2 ENTREGUES 2026-07-14 — suíte 990/0, sem re-baseline**)*

**O problema, medido:** a ferramenta espalha `hbrefactor_<rand>` e `hbrefactor-snap-<md5>`
**soltos** dentro de `hb_DirTemp()` (`/tmp`), sem teto comum — milhares de dirs acumulados,
limpeza só com glob perigoso. (O scratchpad do Claude Code — `/tmp/claude-*/…/` — encheu em
paralelo, 1.7 G numa sessão morta, mas isso é comportamento do harness, não da ferramenta;
entra só como alvo de medição na H.2.) **Decisão do Diego:** raiz única + aviso determinístico
sob controle dele — **nada de auto-limpeza** (ação silenciosa é o que ele recusa).

### Fase H.1 — Raiz única sob `$TMPDIR/hbrefactor/{work,snap}`

**Escopo**
- Nova `STATIC FUNCTION WorkRoot()` → `hb_DirSepAdd( hb_DirTemp() ) + "hbrefactor"`, com
  `hb_DirBuild` uma vez.
- `WorkDir()` (o chokepoint do efêmero, hoje em `src/hbrefactor.prg` ~L360) passa a criar sob
  `WorkRoot() + sep + "work" + sep + <rand>` — preservando o laço anti-colisão do `hb_RandomInt`.
- `SnapDir()` (`src/hbrefactor.prg:903`) passa a devolver `WorkRoot() + sep + "snap" + sep +
  hb_MD5( cwd + spec )`.
- **Nenhum outro site**: os subdirs (`ktwork` L9349, a sonda de regra L3056) já descendem de
  `WorkDir()`/`cTmp` — descem junto de graça.
- **Contrato preservado**: o `dump` continua imprimindo `dumps em: <path>` (`src/hbrefactor.prg:862`)
  — só o *valor* muda, e a suíte lê esse valor da stdout, não uma constante.

**Critério de pronto (mecânico)**
- `make test` verde **sem re-baseline**: a suíte é agnóstica ao valor do caminho — os casos
  capturam o path via `sed -n 's/^dumps em: //p'` (`tests/run.sh:1091,1815,2372,…`), não há
  normalizador para tocar.
- Após um `dump` + `snapshot` num projeto do corpus: `ls "${TMPDIR:-/tmp}/hbrefactor"` mostra
  **só** `work/` e `snap/`, e **zero** `hbrefactor_*`/`hbrefactor-snap-*` solto em `$TMPDIR`.
- Round-trip intacto: `snapshot` → editar quebrando o build → `verify --rollback` restaura byte
  a byte (o `SnapDir()` é o mesmo dos dois lados, então escrita e leitura continuam alinhadas).
- Sem superfície de CLI nova → **extensão não afetada** (nada a propagar para `extension.js`).

### Fase H.2 — `make tmp-usage`: aviso determinístico de limite (NUNCA apaga)

**Escopo**
- `tools/tmp-usage.sh` + target `tmp-usage` no Makefile (a família de `tools/*.sh` de ops do
  Diego; mensagens em PT, como as demais — não é superfície de produto).
- Mede `du -s` de **dois alvos, reportados em separado**: (a) `${TMPDIR:-/tmp}/hbrefactor` e
  (b) o scratchpad do Claude Code deste projeto (`/tmp/claude-*/…hbrefactor*/`).
- Limite default **500 M**, override por env `HBREFACTOR_TMP_WARN_MB`.
- Acima do limite: imprime o tamanho, a divisão `work` × `snap`, e **o comando exato de limpeza
  para colar** — distinguindo o `rm -rf …/hbrefactor/work` (sempre seguro) do
  `rm -rf …/hbrefactor` (inclui o `snap`, que é o buffer de `--rollback`: aviso no texto).
- Abaixo: uma linha `OK`. **Nunca deleta.** Exit code: `0` abaixo, `!=0` acima (composável).
- Gatilho **só manual** (`make tmp-usage`) — sem hook, sem gatilho passivo.

**Critério de pronto (mecânico)**
- Com `$TMPDIR/hbrefactor` acima de 500 M, `make tmp-usage` sai `!=0`, imprime os comandos, e
  `ls`/`git status` confirmam que **nada foi apagado**.
- Vazio ou abaixo do limite → sai `0` com a linha `OK`.
- `HBREFACTOR_TMP_WARN_MB=1 make tmp-usage` dispara o aviso (prova do override).

**Ao commitar** (fora do escopo de código, via `/update-manual`): entrada de `CHANGELOG.md` no
registro do programador — *onde a ferramenta passa a escrever seus temporários e como limpar* —,
já que o local dos `.ast.json`/snapshots muda de forma visível.

---

# PORTÕES FECHADOS / EM ESPERA

## D — Evidência de execução — **PORTÃO FECHADO NA FORMA PROPOSTA (Diego, 2026-07-08)**

A forma proposta (camada `observed` anotando sites `possible` para priorizar conferência
manual) é **TRIAGEM — e triagem não é produto** (REGRA DO FATO). A spec fica como registro
dos fatos re-auditados (o funil real é `hb_objGetMethod`, classes.c:1802):
[spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md). **Evidência de execução só
volta se tiver consumo 100% fato** (ex.: alimentar cheques impostos) — decisão do Diego.
**Canal candidato levantado depois** (o profiler do VM, `__SetProfiler`): **P15** — ele passa
por ESTE portão, não por um novo.

## B8 — Macros — **EM ESPERA (rebaixada pela M-cov, 2026-07-08)**

A M-cov achou **zero receptor por macro** no corpus e o Diego despriorizou macros. **Spec
pronta na gaveta; executa quando a fricção real pedir**:
[spec-b8-macros.md](spec-b8-macros.md) (fatias, dialética do pipe, venenos, critério de
matar). Adendo verificado: a AST de toda macro existe completa em runtime (macro.y:257; gate
único em vm/macro.c:798) — o dump de macro em runtime é o gêmeo do funil `hb_vmSend`, e viaja
com a alavanca D, não com esta fase.

## B6 — PR upstream — **BLOQUEADA (só quando o Diego mandar)**

Mensagem com consumidor real; 1 arquivo novo + ganchos opt-in; prova de zero impacto; build
limpo (corrigir o `-Wtype-limits` de compast.c:658 — tirar o `iType >= 0`); regen bison 3.8.2
documentado; split opcional em 2 PRs; ChangeLog via `bin/commit.hb`; uncrustify.

**O que NÃO vai no PR** (e é pequeno, e é **nosso**): `CLAUDE.md`, `.gitignore`, `NEWS.md`, o
banner do `README.md` e o diretório `site/` (a proposta é a EMBALAGEM do PR, não conteúdo
dele — e já vive publicada no [gh-pages do fork](https://diegopego.github.io/harbour-core/)).
Fora isso, o branch é o trabalho de AST: `compast.c` (novo), `ppcore.c` (a maior intrusão),
`hbmain.c`, `harbour.y`, `classes.c`, headers, mais os `.yyc`/`.yyh` do bison.
**A limpeza é executada só quando o Diego for abrir o PR** (ordem dele, 2026-07-12).

> ⚠️ **A CICATRIZ QUE GOVERNA ESTA FASE:** eu acusei o branch de carregar "6 commits alheios"
> — **ERRADO: são do UPSTREAM.** Comparei contra o `master` LOCAL, 7 commits atrasado. **Base
> errada → achado errado, e publicado.** Ao medir o branch, a base é **`upstream/master`**
> (`git fetch upstream` primeiro), nunca o `master` local.

**Prova de impacto zero — com SCRIPT** (`tools/pcode-identity.sh`): era medida à mão, e por
isso os números da proposta envelheceram sem ninguém notar (afirmava `1085/1085` e `112/112`,
irreproduzíveis). Medido em **2026-07-12: 889/889 módulos com pcode byte-idêntico, ZERO
divergências** (switches desligados, remendado vs `master`). A afirmação se sustenta; a
contagem é que era fantasia. **Rodar o script antes de citar — nunca a contagem de memória.**

---

# Backlog (por valor)

0. **Manutenção de doc de USUÁRIO em atraso (2026-07-12)**: o `docs/manual.md` está com
   baseline em `hbrefactor@437a6a6` — várias entregas atrás; a `site/index.html` deriva dele.
   Os DOIS CHANGELOGs estão em dia (têm ponteiro próprio); o manual não. Rodar a
   `/update-manual` em modo catch-up — **o delta do manual exige o OK do Diego antes de
   aplicar** (invariante 1 da skill). Não é bloqueante para nenhuma fase.

0b. **Higiene: o compilador deixa lixo no repo (2026-07-12)**: cada `make test` deixa um
   `sh1.c` na RAIZ (o `harbour` grava o `.c` no **CWD**, não ao lado do fonte — a mesma
   armadilha do `.d` do `-gd`). Conserto: mandar a saída para um tmp (`-o<dir>`) no site que
   roda o compilador a partir da raiz. Ecoa *"ferramenta do core: PROBE, nunca memória"*.

1. **Dedup pré/pós-decremento**: não-fazer mantido (v2).

2. **Projetos grandes de produção** (quando o Diego liberar): dogfooding final — só depois de
   suíte + hbhttpd verdes. **Recalibrado (Diego, 2026-07-10, regra no CLAUDE.md)**: antes de
   qualquer produção/bravo, a maturação acontece em corpus do CORE ampliado (copiar mais
   pastas pertinentes de `harbour-core/harbour` para `work/`); o bravo é só exploração até a
   ferramenta estar sólida no código do core.
