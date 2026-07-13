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
- A extensão VSCode decide **fluxo** casando prosa: `/--force/`, `/--edit-rules/`, `/no
  compile-time identifier/` (`vscode/extension.js`). Já **quebrou calada** quando a CLI foi
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
{ "schema":  "cli-1",
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
| **recusa acionável** — é possível, falta consentimento | `refused` | 1 | **Peça ao humano e repita com a flag.** | `textual-refs-require-force`, `rule-edit-required` |
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

**(c) O alvo real do A.1, contado: os regexes de PROSA da extensão são QUATRO.**

```
extension.js:235  /no compile-time identifier/
extension.js:280  /--edit-rules/
extension.js:290  /--force/
extension.js:368  /BROKEN/          <- escrito por mim na A.2, em 2026-07-13
```

**A entrega do `verify` AUMENTOU a dívida em um.** Para oferecer o rollback no `BROKEN`, o
primeiro consumidor do comando novo já casa texto em inglês para decidir fluxo — e vai quebrar
calado no dia em que alguém reescrever a mensagem. **Não é argumento retórico sobre o futuro: é
uma linha de código.** O critério de pronto do A.1 mata as quatro.

---

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
