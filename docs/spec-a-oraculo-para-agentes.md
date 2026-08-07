# spec-a — O oráculo para agentes: contrato de máquina, `verify`, MCP

**Estado:** § 3 (**A.2 — `verify`**) ✅ **ENTREGUE em 2026-07-13** (portão aberto pelo Diego;
caso 123; suíte 978/0; extensão 0.14.0). O resto (**A.1** contrato de máquina, **A.3** MCP,
**A.4** `-ge2`) segue em **PORTÃO FECHADO** — não se implementa sem ordem dele.
Fase no [roadmap](roadmap.md) (`### A`).

> **Cicatriz da execução (2026-07-13).** Chaveei o snapshot pelo **texto do spec** — dois
> projetos homônimos (`app.hbp` em diretórios diferentes) **liam a linha de base um do outro**.
> É o **gatilho nº 5 do CLAUDE.md** ("casar arquivo por BASENAME em vez de caminho canônico"),
> escrito, e eu caí nele mesmo assim. Pego pelo **caso 123d**. Chave agora é caminho canônico.
> *(E na mesma sessão eu troquei uma string do `dump` de passagem, fora do portão autorizado, e
> quebrei 7 checks pré-existentes — revertido: aquele conserto pertence ao A.1, e o drift que ele
> traz é decisão do Diego.)*

---

## 1. A tese, e o que ela NÃO é

O programador Harbour vai pedir a um LLM *"renomeie este método no projeto inteiro"*. O LLM
vai fazer isso por **substituição de texto** — com confiança, e errado. **É exatamente o modo
de falha que o hbrefactor existe para eliminar.** O agente é, portanto, o consumidor que **mais
precisa** de um oráculo de fato.

**LLM é máquina de heurística; hbrefactor é máquina anti-heurística.** Não é contradição — é
complementaridade. **O agente propõe a INTENÇÃO; a ferramenta decide o que é PROVÁVEL, executa
verificando, e recusa com MOTIVO.**

> **NÃO-OBJETIVO (executável, não retórico).** A ferramenta **não tem modelo, não tem chave de
> API, não fala com rede, e NUNCA pergunta nada a um LLM**. Régua na suíte, família do caso 64:
> nenhum `anthropic|openai|api[_-]?key|https?://` no `src/hbrefactor.prg`.

**A fase muda a SUPERFÍCIE, jamais o motor.** Nenhum princípio cede: REGRA DO FATO, zero
inferência, recompilar-e-reverter, genérico > específico.

---

## 2. A.1 — Contrato de máquina

### 2.1 A contradição que se fecha

**A ferramenta proíbe comparação de texto no MOTOR e obriga comparação de texto no CONSUMIDOR.**

- Dos 12 comandos, só `usages`, `projects-of` e `annotate` têm `--json` — e escrevem num
  **arquivo**, nunca em stdout. Os outros oito só falam prosa.
- A extensão VSCode decide **fluxo** casando prosa: `/--force/`, `/no compile-time
  identifier/`, `/BROKEN/` (`vscode/extension.js`). Já **quebrou calada** quando a CLI foi
  traduzida.
- `Refuse()` (`src/hbrefactor.prg`) é funil ÚNICO e achata numa frase três coisas distintas.
- `usages` sai **`EXIT_REFUSED` com zero resultados** — o consumidor não distingue "não há usos"
  de "eu me recusei".
- `resolve-at` já monta o hash `{name, kind, query}` por dentro **e o imprime como prosa**.

É o **mesmo padrão que matou a fase L** (*"o compilador SABE e joga o fato fora numa string"*),
agora com a ferramenta fazendo isso com a **própria saída**.

### 2.2 O envelope

`--json` vira flag **global**, em **stdout**. A forma `--json <arquivo>` **morre** (não existe
compatibilidade para trás); a extensão é reacoplada na MESMA fase. Sem `--json`, a prosa fica
exatamente como está — o humano também é consumidor de primeira classe.

Schema versionado, à moda do `ast-16`/`rtr-1`. **Um** envelope, **nada mais** em stdout:

```json
{ "schema":  "cli-2",          // cli-2 (2026-07-26): ganhou `argv` e `exit`
  "command": "rename",
  "status":  "ok" | "refused" | "usage",
  "reason":  null | "<código>",
  "detail":  "<a mesma frase em inglês que o humano veria>",
  "result":  { },
  "edits":   [ ] }
```

- `result` é por-comando (o `usages` já tem a semente: `LocationsJson()` emite `Location[]` no
  formato LSP — **manter LSP**, não inventar dialeto).
- `edits` só aparece sob `--dry-run`: `{file, range, newText}` — o que a ferramenta **faria**.
  Isso absorve dois resíduos que o roadmap adiava por conta própria (B5 *"se a fricção pedir"*;
  P3 *`Location` estruturada, "para quando doer"*).
- `detail` **não** é para máquina consumir — é para o agente **mostrar ao humano**. Quem decide
  é o `reason`.

### 2.3 A taxonomia dos códigos — e por que ela é a peça de PRODUTO, não de formato

Hoje **três coisas diferentes saem com exit `1`**, distinguíveis só pelo texto. Separar não é
cosmética: é o que decide se o agente **relata** ou **contorna**.

> **A restrição de desenho mais séria da fase.** Um agente que recebe "recusado" e não entende
> por quê vai fazer aquilo pelo que é famoso: **editar o texto na mão** — e a ferramenta virou
> um obstáculo a contornar, não uma proteção. Portanto **cada código carrega o que o agente deve
> FAZER**, não só o que aconteceu.

| classe | `status` | exit | o que o agente deve fazer | códigos |
|---|---|---|---|---|
| **recusa de política** — seria incorreto | `refused` | 1 | **PARE. Conte ao humano.** | `verification-failed-rolled-back`, `ambiguous-position`, `no-fact-at-position`, `homonym-not-unique` |
| **recusa acionável** — é possível, falta consentimento | `refused` | 1 | **Peça ao humano e repita com a flag.** | `textual-refs-require-force` *(o `rule-edit-required` estava previsto aqui para o `--edit-rules`; a flag morreu na P27 — editar diretiva do projeto deixou de precisar de consentimento, então a classe ficou com um código só)* |
| **ambiente quebrado** — não é recusa, é o toolchain | `refused` | 1 | **Não é sobre a refatoração.** Conserte o projeto. | `project-does-not-compile`, `project-unresolved`, `dump-missing`, `schema-mismatch` |
| **resposta vazia legítima** — não é recusa nenhuma | **`ok`** | **0** | Siga: a resposta é "não há". | — |

### 2.4 LEVANTAMENTO DO DRIFT (2026-07-13) — feito ANTES de codar, e ele é assimétrico

Eu tinha apresentado ao Diego "duas decisões de drift" como se fossem simétricas. **Não são.**

**(a) `usages` com zero hits deixa de sair `1` — quase NÃO há drift.** Varridos os 100 sítios de
`usages` na suíte: **nenhum teste depende do exit `1` em "zero resultados"**. O único que exige
exit ≠ 0 é `run.sh:2356`, e ele é uma **recusa de verdade** (posição sem identificador de
compile-time) — na taxonomia nova continua recusando, com `no-fact-at-position`. Sítios no fonte:
`hbrefactor.prg` `RETURN iif( nHits > 0, EXIT_OK, EXIT_REFUSED )` em **dois** lugares (o `usages`
normal e o de marker de regra). **O comportamento errado nunca foi contratado por ninguém — ele
só existe.**

**(b) A morte do `--json <arquivo>` — é AQUI que está o trabalho.** Não é difícil; é volume:

| onde | o quê |
|---|---|
| fonte | 4 comandos com escrita em arquivo (`usages`, `projects-of`, `annotate`; + `--out` do `exec-registry`) |
| suíte | **17** sítios usando `--json <arquivo>` |
| extensão | **2 fluxos** que escrevem num temp e leem de volta (`ownerOf`, `cmdUsages` — `tmpJson()`/`readFileSync`/`unlinkSync`) |

**(c) O alvo real do A.1, contado: os regexes de PROSA da extensão são TRÊS.**

```
extension.js:287  /no compile-time identifier/
extension.js:337  /--force/
extension.js:412  /BROKEN/          <- escrito por mim na A.2, em 2026-07-13
```

*(Eram quatro; o `/--edit-rules/` morreu na P27 junto com a flag. Não conte isso como
progresso do A.1: o regex sumiu porque a decisão que ele mediava deixou de existir, não
porque a extensão passou a ler campo. Os três que ficam decidem fluxo casando prosa, e é
esse o alvo.)*

**A entrega do `verify` AUMENTOU a dívida em um.** Para oferecer o rollback no `BROKEN`, o
primeiro consumidor do comando novo já casa texto em inglês para decidir fluxo — e vai quebrar
calado no dia em que alguém reescrever a mensagem. **Não é argumento retórico sobre o futuro: é
uma linha de código.** O critério de pronto do A.1 mata as três.

---

### 2.5 OS DOIS CONSUMIDORES — a extensão VSCode e o agente

*(Escrita por ordem do Diego, 2026-07-24: **"quero que o Claude crie a especificação para a
interface CLI que seja ideal para o Claude usá-la"**; **revisada na mesma sessão** pela
correção dele: **"os principais consumidores do hbrefactor são o VSCode e o Claude"**.)*

> **Declaração de interesse, e ela vem antes de tudo.** Quem escreve esta seção é UM dos dois
> consumidores sendo projetados. Isso dá informação que ninguém mais tem — eu sei como eu erro —
> e cria um **conflito** em dois eixos: pedir o que me é CONVENIENTE em vez do que mantém a
> ferramenta honesta, e **projetar para mim degradando o outro consumidor**. A primeira versão
> desta seção fez exatamente isso (ver a correção na §2.5.4, que é uma decisão de desenho, não
> um detalhe de redação). Toda regra passou por um teste: *ela me tornaria mais capaz de
> RELATAR, ou mais capaz de CONTORNAR?* A que não sobreviveu está na §2.6.

**Os dois são de primeira classe, e nenhum é hipotético.** A extensão é o consumidor de **uso
diário do Diego** (CLAUDE.md §5: *"todo comando novo tem que chegar à `extension.js`"*); o
agente é a tese da fase. Eles têm um **substrato comum** e **divergem num eixo só** — e é
preciso ser exato sobre qual, porque projetar para um deles no eixo errado quebra o outro.

|  | extensão VSCode | agente (Claude) |
|---|---|---|
| escrita contra | **uma versão**, por quem leu | um **prior difuso**, que pode estar errado |
| erra | uma vez, no desenvolvimento | **a cada chamada**, de formas novas |
| o que faz com a saída | **decide fluxo** e desenha UI | decide fluxo e **relata ao humano** |
| custo do volume | ~zero (filtra e vira lista virtual) | **alto** — disputa espaço com o problema |
| posição | `vscode.Location` é a API **nativa** | LSP é conhecimento que eu **já tenho** |

#### 2.5.0 A PROSA É UMA VISTA DO FATO, não um canal paralelo

*(Correção de rumo do Diego, 2026-07-24, no meio da implementação: **"a prosa a meu ver é
apenas um dos argumentos de saída; as ferramentas como IDE e o Claude via MCP precisam de
dados adequados além da prosa"**. Ele estava certo, e o erro era meu — de arquitetura, não de
formato.)*

**O que eu tinha construído:** dois caminhos paralelos — os `Prose()` de um lado, a coleta de
`result` do outro. Sintoma de que estava errado: eu precisei forçar o rótulo (`kind`) a sair da
**mesma variável** que a prosa, um remendo manual contra a divergência.

**A prova de que era errado, medida no próprio código:**

```
$ hbrefactor usages app.hbp Dobro          $ hbrefactor usages app.hbp Dobro --json
app.prg:5: call in MAIN  | nTotal += ...     { "kind": "call", "owner": "MAIN",
                           ^^^^^^^^^^^^        "certainty": "confirmed" }
                     a linha do FONTE                     (sem ela)
```

**O consumidor de MÁQUINA recebia MENOS que o humano.** A IDE precisa daquele texto para o
preview do find-references; um servidor MCP teria de **reabrir o arquivo** para completar a
resposta — e reler é DECIDIR, o que **reprova o critério de matar da §4** (*"se o servidor
precisar decidir algo que a CLI não decidiu, ele morre — e a necessidade dele prova que o
contrato do A.1 ficou ruim"*). Ou seja: o buraco reprovaria a A.3 lá na frente.

**O modelo correto:**

```
        FATO (o result estruturado)
              ├── renderizado como prosa  → humano no terminal
              └── emitido como JSON       → IDE, MCP, agente
```

Com isso duas coisas ficam **impossíveis por construção**, em vez de dependerem do meu cuidado:
a prosa mostrar algo que o dado não tem, e os dois divergirem.

**Corolário — o dado é SUPERCONJUNTO da prosa, nunca o contrário.** O JSON pode carregar mais
(o `text` da definição, que a prosa não imprime); o que ele **não pode** é carregar menos.

**O que NÃO entra, e a discordância é minha:** a prosa **não** vira campo do JSON (`"prose":
"<o texto inteiro>"`). Seria dado redundante — para o agente custa contexto, para a IDE é
inútil porque ela renderiza do jeito dela. A prosa é **derivada**, não **transportada**. O
`detail` de uma frase continua, porque esse serve para o consumidor **mostrar** sem compor
nada.

**Portão** (`tests/regua-canais.sh`): para cada `arquivo:linha` que a prosa cita, o JSON tem de
trazer a location correspondente; e se a prosa mostra a linha do fonte, o dado tem de carregar
o campo `text`. *(A régua nasceu passando por VACUIDADE — sem `HB_BIN` o binário não rodava e
as duas listas ficavam vazias. Ela agora se recusa a passar sem ter medido: é a mesma cicatriz
do §T, e não é coincidência que tenha reaparecido.)*

#### 2.5.1 O que os DOIS precisam igualmente (e é a maior parte)

- **Nenhuma decisão de fluxo por prosa.** Hoje a extensão casa `/--force/`,
  `/no compile-time identifier/`, `/BROKEN/` — e eu faria o mesmo, pior. `reason` + `action`
  como campos servem aos dois **exatamente igual**.
- **Aviso é DADO, não prosa no stderr.** *(Buraco da primeira versão desta seção, achado ao ler
  a extensão: ela concatena `res.stderr + res.stdout` para regexar.)* Sob `--json`, tudo o que
  hoje sai por `OutErr` — referências textuais, macro vivo (P16 c), alcance incompleto (P17) —
  entra no envelope como **`diagnostics[]`**, cada item com `code`, `severity`, `location` e
  `detail`. **Sem isto o `--json` é meia-entrega**: o stdout fica estruturado e o consumidor
  continua regexando prosa do stderr. Sob `--json`, **stderr só carrega falha de processo**.
- **`edits[]` sob `--dry-run`** — para a extensão é um `WorkspaceEdit` aplicável e um preview
  nativo; para mim é o que eu mostro ao humano antes de aplicar. Mesmo dado, dois usos.
- **Incerteza como campo POSITIVO, jamais ausência** (a regra da §2.5.3, que vale para os dois).
- **Determinismo byte a byte** — a extensão cacheia, eu comparo execuções.
- **Nomes estáveis** entre comandos, `Location` LSP em todo lugar.
- **`describe --json`** serve aos dois por motivos diferentes, e o da extensão eu não tinha
  visto: para mim é **descoberta** (não decorei o manual); para ela é **detecção de
  descompasso** — ela confere no startup que o binário encontrado fala o schema que ela espera,
  em vez de falhar estranho no terceiro comando. É o mesmo remédio do caso 122, do lado do
  consumidor.

#### 2.5.2 O que só EU preciso — porque eu erro de um jeito que um programa não erra

- **Alucino flags.** Vou inventar `--recursive`, `--all`, `--format=json`, `-y`. Flag
  desconhecida tem de **reprovar sempre** (`usage`, exit ≠ 0) **ecoando o conjunto válido** — e
  **sem abreviação e sem prefixo único**: `--for` não pode virar `--force`. Adivinhar a minha
  intenção seria a ferramenta fazendo heurística, que é o que ela proíbe. *(Coerente com a §7 do
  CLAUDE.md: o projeto já escolheu a família `x` do pp para não ter casamento por abreviação.)*
  Para a extensão isso é inócuo — ela não inventa flag.
- **Meu contexto é finito.** Ver a §2.5.4, que é onde os dois divergem de verdade.
- **A recusa precisa dizer o que FAZER**, não só o que houve. A extensão pode traduzir um
  `reason` num botão porque foi programada para isso; eu, diante de um código que não entendo,
  faço o que sou famoso por fazer: **edito o texto na mão**. Daí `action` ser campo:

  ```json
  { "status": "refused",
    "reason": "textual-refs-require-force",
    "action": "ask-human-then-retry",
    "retry": { "flag": "--force" },
    "detail": "textual references found - repeat with --force to proceed without touching them" }
  ```

  `stop-and-report` × `ask-human-then-retry` × `fix-environment` — a taxonomia da §2.3 virada
  dado. O `reason` diz o que houve; o `action` diz o que fazer. **Os dois, sempre.**

#### 2.5.3 A regra que eu só sei porque sou eu que erro

**INCERTEZA É CAMPO POSITIVO, NUNCA AUSÊNCIA.**

Se a dúvida for expressa **pela falta** de um campo — sem `certainty`, logo é certo — eu **vou**
perder. Não às vezes: por construção. Eu generalizo do que está presente; ausência não me chama
atenção, e quando eu resumo ao humano o que não estava escrito não aparece.

- `certainty` **explícito e sempre presente** (`possible`/`confirmed`/`excluded`/`guaranteed` —
  a escada que a ferramenta já tem), inclusive no caso fácil;
- alcance incompleto é **campo**, não observação no `detail`. A P17 (entregue hoje) é o exemplo
  vivo: `"scope": { "complete": false, "unseen": [ { "file": "...", "line": 248,
  "cond": "__PLATFORM__WINDOWS" } ] }` — e `"complete": true` sai **igualmente explícito**
  quando não há região pulada. Se "completo" for a ausência de `scope`, eu leio todo rename como
  completo;
- vale também para o que a ferramenta decidiu **CALAR** por fato (a ocorrência em dado da
  P16 a): num JSON o silêncio não se distingue do nada, então a supressão deliberada precisa
  aparecer.

Para a extensão essa regra é barata (um `if` a mais). Para mim é a diferença entre relatar e
enganar. **Custo assimétrico, benefício assimétrico — e por isso ela entra.**

#### 2.5.4 Onde os dois DIVERGEM — e a correção que a revisão do Diego forçou

O único eixo de conflito real é **volume**: eu preciso de pouco, a extensão aguenta tudo.

**A primeira versão desta seção resolvia isso errado:** *"compacto por padrão, `--verbose` para
o resto"*. Isso obrigaria a extensão a passar `--verbose` sempre — ou seja, o **default estaria
errado para um dos dois consumidores principais** — e, pior, criaria **duas FORMAS de envelope**
para testar, com cada consumidor podendo receber a que não espera.

**A regra que fica, e ela é geral:**

> **Flag nenhuma muda a FORMA do envelope — só o VOLUME.** Os mesmos campos, sempre, com o
> mesmo significado. `--limit N` corta **quantos itens** vêm; jamais quais campos cada item tem.

Assim há **um** schema para testar, e o consumidor que quer menos pede menos **explicitamente**
— o que é auditável, ao contrário de um default que muda por baixo.

E o corolário que a P17 acabou de comprar na marra: **truncagem DECLARADA**.
`"truncated": true, "total": 4127, "returned": 200`. Lista curta calada é indistinguível de
lista completa, e eu relato *"são 200 usos"* com toda a confiança do mundo. É a mesma regra do
CLAUDE.md §4 (*"no silent caps"*), agora do lado do consumidor.

O `detail` em prosa fica fora do caminho de decisão dos dois — mas com um requisito prático que
vem de ambos: a extensão o mostra num modal, eu o copio ao humano. Logo ele tem de ser **uma
frase que faz sentido sozinha**, sem o resto do JSON em volta.

#### 2.5.5 Os quatro pontos em que eu sou diferente, resumidos

Ficam aqui porque cada um virou requisito acima: **(a)** não li o manual e minha lembrança dele
pode estar errada → `describe`; **(b)** alucino flags → reprovação com o conjunto válido;
**(c)** contexto finito → `--limit` com truncagem declarada, forma estável; **(d)** trabalho em
loop propor→verificar→relatar → `edits[]` no dry-run e `action` na recusa.

**(a) Eu não li o manual, e a minha lembrança dele pode estar ERRADA.** Chamo a ferramenta a
partir de um prior difuso — o que vi de CLIs parecidas, o que li desta há dez mil tokens, o
que eu *acho* que uma ferramenta assim deveria ter. Requisito: **descoberta em tempo de
execução**, não decoreba.

- `hbrefactor describe --json` emite o **manifesto de capacidades**: comandos, argumentos
  posicionais, flags (com tipo e default), os `reason` que cada comando pode devolver, e a
  versão de schema de cada `result`. É o mesmo fato que o MCP anuncia pelo protocolo (§4) —
  **uma fonte, dois transportes**.
- O manifesto é gerado **do mesmo lugar** que a `Usage()` humana. Manifesto que se escreve à
  mão envelhece — e envelhecer calado é o modo de falha que esta fase existe para matar.

**(b) Eu ALUCINO flags.** Vou inventar `--recursive`, `--all`, `--format=json`, `-y`. Se a
ferramenta **ignorar em silêncio** o que não conhece, eu acredito que usei — e relato ao humano
uma garantia que nunca existiu. Requisito:

- **flag/argumento desconhecido = `usage`, exit ≠ 0, SEMPRE.** Nunca ignorar.
- a recusa **ecoa o conjunto válido** para aquele comando. Sem isso eu tento de novo às cegas, e
  o loop de tentativa é onde eu queimo contexto e paciência do humano.
- **sem abreviação e sem prefixo único.** `--for` não pode virar `--force`: eu escrevo prefixo
  errado com frequência, e adivinhar a minha intenção é heurística — do lado da ferramenta,
  justamente o que ela proíbe. *(Coerente com a §7 do CLAUDE.md: o projeto escolheu a família
  `x` do pp exatamente para não ter casamento por abreviação.)*

**(c) O meu contexto é FINITO, e a saída disputa espaço com o problema do usuário.** Um `usages`
de 4.000 hits não me deixa mais informado: me deixa **sem espaço para pensar**. Requisito:

- **compacto por padrão**, `--verbose` para o resto. Nada de campo decorativo em toda linha.
- **`--limit N` com truncagem DECLARADA**: `"truncated": true, "total": 4127, "returned": 200`.
  **Silêncio jamais** — uma lista truncada calada é indistinguível de uma lista completa, e eu
  vou relatar "são 200 usos" com toda a confiança do mundo. *(É a mesma regra que o CLAUDE.md
  §4 já impõe aos números da página: "no silent caps".)*
- o `detail` em prosa fica **fora** do caminho de decisão (§2.2 já diz isso) — mas vale a
  consequência prática: ele existe para eu **copiar ao humano**, então tem que ser uma frase
  que faz sentido sozinha, sem o resto do JSON.

**(d) Eu trabalho em LOOP: propor → verificar → relatar.** A ferramenta não é o meu destino, é
o meu **oráculo** no meio do loop. Requisito: cada resposta tem que me dizer **em que ponto do
loop eu estou**.

- `--dry-run --json` devolve `edits[]` como **dado** — é assim que eu mostro ao humano ANTES de
  aplicar, que é a única forma de ele consentir de verdade.
- A recusa carrega o que FAZER, e isso é **campo**, não parágrafo:

  ```json
  { "status": "refused",
    "reason": "textual-refs-require-force",
    "action": "ask-human-then-retry",
    "retry": { "flag": "--force" },
    "detail": "textual references found - repeat with --force to proceed without touching them" }
  ```

  Os três valores de `action` são a taxonomia da §2.3 virada dado: `stop-and-report`
  (recusa de política), `ask-human-then-retry` (recusa acionável), `fix-environment`
  (ambiente quebrado). **O `reason` diz o que houve; o `action` diz o que fazer.** Eu preciso
  dos dois: sem o `reason` eu não sei relatar; sem o `action` eu improviso — e improviso, para
  um LLM, quer dizer editar o texto na mão.

**(e) A regra mais importante desta seção: INCERTEZA É CAMPO POSITIVO, NUNCA AUSÊNCIA.**

Esta é a que eu só sei porque sou eu que erro. Se a dúvida for expressa **pela falta** de um
campo — sem `certainty`, logo é certo — eu **vou** perder. Não às vezes: por construção. Eu
generalizo do que está presente; ausência não me chama atenção, e quando eu resumo ao humano
o que não estava escrito não aparece.

- todo veredito traz `certainty` **explícito e sempre presente** (`possible` / `confirmed` /
  `excluded` / `guaranteed` — a escada que a ferramenta já tem), inclusive quando é o caso
  fácil;
- todo relato de alcance incompleto é **campo**, não observação no `detail`. A P17 (entregue
  hoje) é o exemplo vivo: `"scope": { "complete": false, "unseen": [ { "file": "...",
  "line": 248, "cond": "__PLATFORM__WINDOWS" } ] }` — e `"complete": true` sai **igualmente
  explícito** quando não há região pulada. Se "alcance completo" for a ausência de `scope`, eu
  vou tratar todo rename como completo;
- o mesmo vale para o `possible` do `usages`, para a string que é macro vivo (P16 c) e para a
  ocorrência em dado suprimida por fato (P16 a) — **o que a ferramenta decidiu CALAR também é
  fato**, e num JSON o silêncio não se distingue do nada.

**(f) Nomes ESTÁVEIS entre comandos.** Eu generalizo de exemplo: se `usages` chama de `file` e
`rename` chama de `path`, eu vou usar o errado na metade das vezes. Mesmo conceito → mesma
chave, em toda a superfície. Posição é **LSP `Location`** em todo lugar (a `LocationsJson()` já
é a semente) — não porque LSP seja bonito, mas porque **eu já o conheço**, e conhecimento que
eu já tenho é contexto que eu não gasto.

**(g) Determinismo byte a byte.** Mesma entrada → mesma saída, sem timestamp, sem caminho
absoluto de temporário, sem ordem de hash. Isso me deixa **comparar duas execuções** — que é
como eu verifico que uma mudança fez o que eu disse que faria — e é o que torna a fase T
(fixture esperada) possível do lado do agente também.

### 2.6 O que eu pedi e RETIREI — o teste do "relatar × contornar"

Registrado porque o conflito de interesse da §2.5 só é honesto se as rejeições aparecerem.

- **`"confidence": 0.87`** — REJEITADO. Número contínuo é convite à inferência: eu compararia
  com um limiar que eu mesmo inventei, e a ferramenta inteira existe para não ter limiar
  inventado. A certeza aqui é **categórica** e vem de fato (§2.5e).
- **`"suggestion"` com o comando pronto para contornar a recusa** — REJEITADO na forma geral.
  Dizer *"a flag que permitiria isto é `--force`"* é FATO e fica (`retry.flag`). Dizer *"rode
  isto para resolver"* transforma toda recusa em **degrau**, e o §1.6 é explícito: a recusa tem
  de ser legível para eu RELATAR, não para CONTORNAR.
- **Modo "força bruta": aplicar sem verificar, para ganhar tempo** — REJEITADO. É o motor, não
  a superfície. A latência se resolve na fase V, não desligando a prova.
- **A ferramenta aceitar intenção em linguagem natural** (`hbrefactor "renomeie o método X"`) —
  REJEITADO, e este era o mais tentador. Parsear intenção é heurística, e colocá-la DENTRO da
  ferramenta contamina o motor. A tradução intenção → comando é **minha**, e é exatamente a
  fronteira que o §1.6 desenha: eu proponho a intenção, ela decide o que é fato.
- **`--yes` global** (pular confirmação) — REJEITADO: consentimento é do humano, e um agente que
  pode pular consentimento é o modo de falha que este produto existe para eliminar.

### 2.7 O que esta seção NÃO resolve, e é honesto dizer

- **Latência.** Cada comando re-dumpa o projeto inteiro; num loop de agente isso é o custo
  dominante, e nenhum formato de saída conserta. É a fase V (fatia 2), e o A.5 já a nomeia como
  **pré-requisito, não detalhe**. **Dói nos DOIS consumidores** — na extensão é a espera que o
  Diego sente todo dia; em mim é o custo de cada passo do loop.
- **Progresso de operação longa.** A extensão hoje mostra spinner indeterminado, porque um
  comando de 10 s sem sinal parece travado. Progresso real exigiria **stream** (NDJSON), o que
  colide com *"um envelope, nada mais em stdout"*. **Fica FORA da A.1, de propósito**: resolver
  latência (fase V) é melhor que instrumentar a espera. Registrado para não parecer esquecido.
- **Cancelamento.** A extensão pode ter o usuário fechando o diálogo no meio. Hoje é matar o
  processo — o que é seguro porque a ferramenta só escreve depois de provar, e reverte se
  falhar. Nenhum requisito novo, mas vale estar escrito.
- **Lote.** Eu frequentemente quero renomear dez coisas; hoje são dez carregamentos de projeto.
  Um `--batch` é tentador e **fica fora desta fase de propósito**: sem a fase V ele só esconde o
  custo, e com verificação por operação ele muda a semântica da prova (o que é "rollback" de um
  lote parcialmente aplicado?). Registrado como pergunta aberta, não como item.

## 3. A.2 — `verify`: o oráculo exposto

### 3.1 O reframe

**O catálogo de 12 verbos não é o produto. O VERIFICADOR é** — e ele é **agnóstico de verbo**,
hoje trancado dentro dos comandos. Um agente nunca vai querer só os 12: vai querer *"converta
este `DO CASE` em `SWITCH`"*, *"extraia isto para uma classe"*. **O catálogo jamais alcança a
imaginação de um LLM; o verificador alcança — porque não sabe nem se importa com qual foi a
edição.**

```
hbrefactor snapshot <project>            → grava a linha de base (.hrb de cada módulo)
   … o agente edita à vontade …
hbrefactor verify <project> [--rollback] → o DELTA SEMÂNTICO da edição, como FATO
```

### 3.2 A escada de equivalência — **ela JÁ EXISTE, por verbo, e já é honesta**

Lendo o fonte, a ferramenta **já usa quatro relações diferentes**, e já admite o limite da mais
fraca:

| # | relação | quem usa | força |
|---|---|---|---|
| 1 | **`.hrb` byte-idêntico** | renames de local/static/memvar/param, dsl, marker | **prova** |
| 2 | **identidade sob renomeação** (`HrbEquivalent`): mesma contagem de símbolos/funções, cada símbolo igual OU exatamente o renomeado, **pcode de cada função byte-idêntico** | `rename-function`/`rename-method` | **prova** |
| 3 | **fatos previstos** (`HrbExtractCheck`): o pcode **muda legitimamente**; verifica-se que os símbolos de antes sobrevivem e aparece exatamente o novo esperado | `extract-function` | **mais fraca** — e a ferramenta **admite**: imprime *"run your test suite to confirm behaviour"* |
| 4 | **módulo não editado não muda** (byte a byte) | **todos** | **invariante transversal** |

**Consequência para o `verify` de edição ARBITRÁRIA, e é o ponto central desta spec:** os
degraus 2 e 3 dependem de **saber o que se esperava mudar** ("o rename esperado", "a função nova
esperada"). Numa edição que a ferramenta **não fez**, **não existe expectativa** — logo os
degraus 2 e 3 **não estão disponíveis**, e usá-los seria inventar intenção. Restam o **1** e o
**4**.

### 3.3 O veredito — três estados, e nenhum deles é um juízo sobre a intenção

| veredito | fato | o que significa |
|---|---|---|
| `broken` | não compila | **erro objetivo.** `--rollback` devolve o fonte byte a byte |
| `preserved` | todo módulo byte-idêntico | **PROVA de preservação de comportamento** |
| `changed` | compila, e o `.hrb` mudou | **NEM prova NEM condenação** — vem o **DELTA** |

> ⚠ **O LIMITE, e a fase MORRE se eu cair nele.** Identidade de pcode é oráculo **DE UM LADO
> SÓ**: **"sim" é PROVA; "não" NÃO é prova de quebra.** Um `extract-function` legítimo muda o
> pcode. Ler `changed` como *"está errado"* seria **heurística** — a ferramenta estaria
> chutando intenção. `changed` diz *"não provei preservação"*, **nunca** *"você quebrou"*.

**E é por isso que o `changed` é a saída MAIS valiosa, não a pior.** Ele traz o **delta
semântico como fato** — a máquina já existe (`HrbParse` lê símbolos e funções do `.hrb`):

```
changed: pcode de MAIN mudou; símbolo novo: CALCULATOTAL; símbolo removido: nenhum
```

**Um diff de texto mostra linhas. Isto mostra o que o COMPILADOR entendeu que mudou.** É o que
nenhum LLM consegue fingir e nenhum grep consegue dar — e é exatamente o que o agente precisa
para **relatar ao humano** o efeito real da edição que ele propôs. O `verify` não julga a
intenção: ele **descreve a consequência**.

### 3.4 SONDA (2026-07-13) — o oráculo é insensível a LINHA, e isso não é sorte

O risco que derrubaria metade do desenho: o pcode do Harbour carrega **número de linha**
(`HB_P_LINE`, para debugger e relato de erro). Se fosse assim, **qualquer** edição de agente
que deslocasse uma linha mudaria o `.hrb`, e o veredito `preserved` **nunca dispararia**.

**Sondado, editando o MESMO arquivo in-place (o que a ferramenta faz):**

| edição | com `-gh -l` (o que a ferramenta já usa) | sem `-l` |
|---|---|---|
| inserir linhas em branco + comentário | **`preserved`** (`.hrb` byte-idêntico) | **DIFERE** — o nº da linha entra no pcode |
| `n := 1` → `n := 2` | **`changed`** (detectou) | — |

O **`-l` suprime a informação de linha** (`harbour --help`: *"suppress line number
information"*), e a ferramenta **já compila com `-gh -l`**. O oráculo é, portanto, **insensível
a formatação e sensível a semântica** — exatamente o que o `verify` precisa. **Já estava lá.**

*(Limite achado na mesma sonda: o `.hrb` embute o **nome do módulo** — dois arquivos de nomes
diferentes com o mesmo conteúdo produzem `.hrb` distintos. Irrelevante para edição in-place;
vira limite honesto se o agente **renomear o arquivo**.)*

### 3.5 Venenos

- **Veneno 1 — o `verify` virar gate de qualidade.** Se alguém (eu) começar a tratar `changed`
  como reprovação, a ferramenta passou a opinar. Caso na suíte: edição legítima que muda o pcode
  → veredito `changed` **com delta**, exit **0**, e **nenhuma** palavra de reprovação na saída.
- **Veneno 2 — snapshot velho.** O `snapshot` tem de morrer se o projeto mudar por fora
  (fail-closed). É a mesma classe de bug da fase V: *"agiu sobre fato velho"* é o que esta
  ferramenta promete nunca fazer.
- **Veneno 3 — `--rollback` sem snapshot íntegro** = destruir o trabalho do usuário. Fail-closed.

---

## 4. A.3 — Servidor MCP

O agente do usuário chama `resolve-at`/`usages`/`rename`/`verify` como **ferramenta nativa**, em
vez de dar shell e regexar prosa. **É aqui que a tese vira produto:** o programador aponta o
agente dele para o servidor, e as refatorações passam a **atravessar o oráculo**.

- **Só existe DEPOIS do A.1.** MCP sobre a saída de hoje seria um regexador com outro nome — o
  anti-padrão vestido de feature.
- **CRITÉRIO DE MATAR** (o teste da fase L virado contra nós): **o servidor não pode conter
  DECISÃO.** Se precisar decidir algo que a CLI não decidiu, ele **morre** — a decisão pertence à
  ferramenta, e a necessidade dele **prova que o contrato do A.1 ficou ruim**. Ele é ADAPTADOR de
  um contrato, nunca dono de lógica. Verificação: leitura do fonte do servidor; se houver um `IF`
  sobre conteúdo de resultado, ele falhou.
- **Subsome o "manifesto de capacidades"**: o MCP anuncia os schemas pelo protocolo —
  **descoberta em vez de decoreba**. Morre a classe de bug *"o manual do agente envelheceu"*.

**Linguagem — decisão em aberto, prós e contras honestos:**

| | Harbour | Node |
|---|---|---|
| **a favor** | MCP stdio é JSON-RPC sobre stdin/stdout; `hb_jsonEncode`/`hb_jsonDecode` bastam; **dogfooding real**; zero dependência nova; fica no mesmo `make` | a extensão já é JS; **existe SDK oficial**; menos protocolo à mão |
| **contra** | **não há SDK MCP em Harbour** — escreveríamos o protocolo à mão | uma segunda toolchain no projeto; e o servidor deixa de ser "Harbour falando com o mundo" |

**Inclinação: Harbour** — mas a decisão é do Diego, e o contra é real.

---

## 5. A.4 — `-ge2`: diagnóstico do compilador em JSON *(core)*

**O que é.** `-ge<mode>` **já existe** e escolhe o formato do diagnóstico: `0` = Clipper
(`foo.prg(2) Error E0020  ...`), `1` = IDE (`foo.prg:2: error E0020  ...`). O `-ge2` seria um
terceiro formato: **JSON**. **Modo novo de opção existente**, não flag nova.

**O que se ganha (não é cosmética):**

| hoje (`-ge1`) | com `-ge2` |
|---|---|
| `a.prg:7: warning W0032  Variable 'nEdits' assigned but not used` | `{"module":"a.prg","line":7,"severity":"warning","level":3,"code":"W0032","args":["nEdits"],"message":"..."}` |

- **O identificador é o FATO**, e hoje só existe **dentro da frase em inglês**. Para saber *qual*
  variável, o consumidor **parseia texto** — o anti-padrão que este projeto proíbe.
- **O nível do warning** (o que o `-w1/2/3` filtra) está escondido **no primeiro caractere da
  string** da tabela `hb_comp_szWarnings[]`. Não sai.

**Custo.** `hb_compOutMsg()` (`src/compiler/hbcomp.c`) é o **formatador único** e **já recebe
tudo desmontado** (módulo, linha, severidade, número, template, args) — e só então achata numa
string. ~15 linhas, **uma** função.

**Limite honesto.** **Não há COLUNA** — nem chega ao formatador. **Sondar se o lexer tem, antes
de prometer.** Se não tiver, o `-ge2` sai sem coluna e isso se registra, não se inventa.

**É útil? Sim — e o hbrefactor é o consumidor MAIS FRACO dele.** A ferramenta usa o compilador
como **oráculo binário** ("compila ou não?") e tira os fatos do **dump**; não precisa saber
*qual* erro. O consumidor interno que serviria de prova — o `unused-locals`, que raspava
`stderr` — **está morto** (fase L). **Vendê-lo como "acelera o desenvolvimento" seria o
argumento inflado que o CLAUDE.md proíbe.** O que o sustenta, em ordem de força:

1. **É o PR fácil que abre a porta do PR difícil.** A B6 pede **um** canal (o dump da AST) num
   diff grande e intrusivo (`ppcore.c`, `harbour.y`, `hbmain.c`). O `-ge2` é um diff **minúsculo
   e não-controverso**, com valor imediato para **qualquer** usuário de IDE. Ele estabelece a
   narrativa *"o Harbour fala com máquinas"* **antes** do pedido grande. **Estrategicamente, pode
   ser o PRIMEIRO PR.**
2. **O painel Problems da extensão** — hoje ela não tem diagnóstico nenhum.
3. **O agente do usuário** que recebe *"conserta este erro"*.

**No PR a palavra "AI" não aparece**: lá isso se chama *machine-readable diagnostics*. Não é
disfarce — é o nome certo, e é por isso que passa.

**Portão do core:** trabalho no `harbour-core` é livre; **commit continua sob autorização
por-commit do Diego**.

---

## 6. A.5 — Latência: pré-requisito, não detalhe

Um humano faz 3 perguntas por hora; um agente faz 30 por minuto. Hoje um `usages` no `work/xhb`
custa **12–15 s** (medido na fatia 1 da fase V, 2026-07-13). **Um MCP com essa latência entrega
uma ferramenta que o agente PODE chamar e NÃO VAI QUERER chamar.**

Isso é a **fase V**, e o caminho já está sondado (`hb_compileFromBuf`/`hb_compMainExt`,
in-process, com includes virtuais e callback de mensagens). **Ordem sugerida: V.2 antes do A.3.**
O A.1 e o A.2 são independentes e podem ir antes.

---

## 7. Considerado e REJEITADO *(o teste da fase L, aplicado ANTES de escrever)*

- **Comando `describe` ("dê ao agente o mapa do projeto").** Soa ótimo — e **já existe**: o
  `dump` gera os `.ast.json`. O que falta é ele **imprimir um caminho em vez de uma frase** (e em
  português, ainda por cima). **Não é capacidade nova**; é conserto de 3 linhas dentro do A.1.
- **Regras de refatoração em linguagem natural.** É a heurística entrando pela janela. **Não.**
- **"O agente sugere onde refatorar".** É **TRIAGEM**, que a REGRA DO FATO já proíbe como produto.

**Conexão registrada:** a **P12** (o pp como engenho de busca) **ganha aqui o consumidor que lhe
faltava** — a primeira coisa que um agente faz antes de editar é **PROCURAR**, e hoje ele grepa.

---

## 8. Do lado da CRIAÇÃO: a conclusão que me surpreendeu

O Diego quer *"facilitar o acesso da IA para desenvolver a ferramenta melhor e mais rápido"*.
**Discordo em parte, e o registro tem de dizer**: ler prosa **não é** o que me atrasa. O que
**está medido** é a **latência** e o ciclo de rebuild do core.

E há isto: **do lado da criação, este repo JÁ É AI-first — e não por JSON.** O portão do `git
commit`, o hook `anti-heuristica.sh`, a régua-grep do caso 64, o schema EXATO que **berra** em
vez de degradar: tudo isso é **guarda EXECUTÁVEL contra o modo de falha de um contribuidor
heurístico** — que é o que eu sou. **O padrão que funciona aqui já foi achado.** Se o objetivo é
me tornar melhor, a alavanca é **mais portão executável**, não mais documento — e é barato.

*(O que o contrato de máquina realmente compra no meu loop, e vale: mata a classe de bug em que
eu **leio a saída errado**; e o MCP mata o "o manual do agente envelheceu". Isso é
confiabilidade, não velocidade. Não misturar as duas.)*

---

## 9. PRONTO da fase (executável)

- Todo comando sob `--json` emite **um** envelope válido em stdout, e **nada mais** ali.
- **Nenhuma** decisão de fluxo da extensão casa prosa — os três regexes morrem, e um caso da
  suíte **prova** que morreram (grep no fonte da extensão).
- Toda recusa carrega código, e o código distingue **pare** de **repita com `--force`**.
- "Zero resultados" deixa de ser recusa (drift aprovado pelo Diego).
- `--dry-run --json` devolve as edições como dado nos quatro verbos que editam.
- **`verify` prova preservação de uma edição que a ferramenta NÃO fez**; a edição que quebra é
  revertida **byte a byte**; e **o caso que trava o LIMITE**: edição legítima que muda o pcode →
  `changed` **com delta**, exit **0**, **nenhuma** palavra de reprovação.
- MCP: o agente lista e chama `resolve-at`/`usages`/`rename`/`verify`, recebe **fato**, e o
  servidor **não contém decisão nenhuma**.
- Régua do não-objetivo: nenhum `anthropic|openai|api[_-]?key|https?://` no fonte da ferramenta.
- `make test` verde; `make site-check` verde.

**Acrescentado pela §2.5 (os DOIS consumidores), tudo executável:**

- **A prosa não mostra fato que o JSON não tenha** (`tests/regua-canais.sh`, §2.5.0) — e a
  régua **recusa passar sem ter medido**, porque régua vazia é pior que régua nenhuma.
- **Nenhum comando sai CALADO sob `--json`** (`tests/regua-json.sh`): o portão vive no ponto
  ÚNICO de saída, então comando futuro nenhum escapa. *(Cicatriz: ao separar o canal humano eu
  fiz os dez comandos não-migrados devolverem stdout VAZIO com exit 0 — silêncio indistinguível
  de sucesso — e a suíte inteira passou verde por cima, porque nenhum caso os rodava com
  `--json`.)*
- **`diagnostics[]` no envelope**: sob `--json`, **stderr não carrega aviso nenhum** — só falha
  de processo. Caso na suíte roda um comando que hoje avisa (macro vivo, alcance da P17) e
  prova que o stderr saiu **vazio** e o aviso está no envelope. *(Sem isto o `--json` é
  meia-entrega: a extensão hoje regexa `stderr + stdout`.)*
- `describe --json` lista **todos** os comandos que o binário expõe — régua: comando vivo fora
  do manifesto **reprova a suíte** (é a mesma classe de portão da régua da P17, que pegou o meu
  próprio rot).
- **Flag desconhecida reprova com `usage`** e o conjunto válido na saída — caso na suíte com uma
  flag inventada; e `--for` **não** resolve para `--force` (sem prefixo, sem abreviação).
- **`certainty` presente em 100%** dos vereditos emitidos, inclusive no caso fácil — caso que
  falha se algum veredito sair sem o campo.
- **`scope` presente sempre**, com `complete: true` explícito quando não há região pulada
  (consome o `ppSkipped` do `ast-19`, entregue na P17).
- **A FORMA do envelope não muda com flag** — só o volume: caso na suíte compara o **conjunto de
  chaves** com e sem `--limit`, e ele tem de ser **idêntico**.
- **Truncagem declarada**: `--limit N` sobre um resultado maior emite `truncated: true` com
  `total`; caso na suíte prova que a lista curta **nunca** sai calada.
- **Determinismo**: o mesmo comando duas vezes → stdout **byte-idêntico** (sem tempo, sem
  caminho de temporário, sem ordem de hash). Caso na suíte compara as duas execuções.
- **A extensão reacoplada NA MESMA FASE**, e a régua: **zero** regex de prosa em
  `vscode/extension.js` (os quatro morrem), provado por grep no fonte dela — o mesmo tipo de
  portão que a §9 já exigia, agora contado.
- Formato dos casos novos: **fixture esperada** (fase T, `tests/casedir.sh`) — o `out` byte a
  byte é o que prova o envelope inteiro, inclusive o que ele **não** traz.
