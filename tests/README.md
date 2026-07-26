# A suíte — o formato de teste, e como escrever um novo

**Este arquivo é a especificação do formato.** Todo teste novo o segue; teste que
não couber nele **vira proposta de mudança AQUI**, antes de ser escrito (§ 6).

Estado da migração (o que já saiu do formato antigo, o que falta) vive em
[../docs/handoff.md](../docs/handoff.md) e no [roadmap](../docs/roadmap.md) — aqui só
entra o **contrato**, que não envelhece a cada teste migrado.

---

## 1. Um cenário é uma frase completa, num diretório só

```
tests/scenarios/<nome>/
   case.json    os escalares, com schema
   source/      o projeto ANTES - todos os arquivos
   expected/    os arquivos DEPOIS, escritos À MÃO; SÓ os que mudam
   output       a transcrição esperada, byte a byte
   oracle/      o retrato do .ppo/.ppt que o core produz para a source/
```

Roda com `make scenarios` (ou `make scenarios NOME=<nome>` para um só); o
`make test` o encadeia depois da suíte antiga.

O **nome** diz o que o cenário prova (`rename-dsl-head`, `refuse-local-name-taken`),
nunca um número — número amarra ao runner antigo, que é legado.

### `case.json`

```json
{
  "schema": "case-1",
  "kind": "command",
  "desc": "recusa: o nome novo ja' e' um LOCAL declarado na mesma funcao",
  "cmd": "rename fix01.hbp a.prg:5:10 i --json",
  "forbid": [ "MENUITEM", "MENUBOX" ],
  "creates": [ "app.astr.json" ]
}
```

| chave | obrigatória | o que é |
|---|---|---|
| `schema` | sim | `"case-1"`, **exato**. Divergiu, recusa alta nomeando as duas versões (lei § 1.5) |
| `kind` | sim | `"command"` (roda o hbrefactor). Outros tipos: § 6 |
| `desc` | sim | uma linha — o que este cenário prova. É o que a suíte imprime |
| `cmd` | sim | a linha do hbrefactor **sem o binário**, ou uma **lista** delas (roda em ordem) |
| `forbid` | não | o vocabulário desta fixture, que não pode aparecer em `src/hbrefactor.prg` |
| `creates` | não | artefatos que o comando pode legitimamente deixar no projeto |

**Não existe chave `exit`**: com N comandos o exit é por comando, e ele mora na
transcrição (§ 3), comparado byte a byte junto com a saída.

---

## 2. A REGRA QUE NÃO CEDE: o esperado se escreve, nunca se grava

> *"escreve os arquivos expected, depois escreve o arquivo que vai ser alterado, e
> compara a saída do actual vs expected"* — Diego, 2026-07-26

O `expected/` e o `output` se escrevem **À MÃO, ANTES**, derivados do **contrato** e
da fixture. **É PROIBIDA ferramenta que grave esperado** — uma foi escrita e deletada
no mesmo dia ([cicatrizes § 6.4](../docs/cicatrizes.md)).

Os dois arquivos ficam idênticos; os dois testes, **não**:

| | o que o arquivo AFIRMA | o que ele pega |
|---|---|---|
| gravado da execução | *"a ferramenta faz isto hoje"* | só que algo **mudou** |
| escrito do contrato | *"o contrato pede isto"* | que algo está **errado** |

A prova disso saiu no primeiro dia do formato: duas recusas saíam com
`reason: "unclassified"` — o campo pelo qual a extensão e o agente **decidem**. O
grep antigo passava verde; o esperado **gravado** também teria passado, porque
gravaria o defeito. Escrito antes, o cenário falha e o buraco aparece.

**Derivar não é adivinhar:** coluna se **computa** do arquivo (o dump é 0-based, a CLI
é 1-based); nome de campo do envelope se lê do contrato; texto de mensagem se lê do
fonte que a produz. O que se escreve à mão é a **afirmação**, não o palpite.

**Divergiu ao rodar? Separe os dois lados** — ou o esperado está errado (conserte o
esperado) ou a ferramenta está (conserte a ferramenta). Nunca "conserte" copiando a
saída: é o golden-file voltando pela janela.

---

## 3. As provas de cada cenário, e por que cada uma existe

1. **os fontes** — todo arquivo de `source/` bate byte a byte: com `expected/<arquivo>`
   onde o cenário edita, e **com o próprio `source/` onde não edita**. É isto que prova
   o que a ferramenta **não** tocou.
   - **`expected/` ausente SIGNIFICA "nada muda"** — é o cenário de recusa ou de
     consulta, e a promessa central da ferramenta.
   - **`expected/` que nomeie arquivo fora de `source/` REPROVA**: ele nunca seria
     comparado, e passaria por vacuidade.
2. **artefato** — arquivo novo no projeto que o `case.json` não declarou em `creates`
   reprova. A ferramenta não suja o projeto do usuário.
3. **a saída** — a **transcrição** bate byte a byte com `output`. Por comando:

   ```
   $ hbrefactor rename fix01.hbp a.prg:5:10 nSoma --json
   { ...envelope... }
   -> exit 0
   ```

   Byte a byte prova também **o que a ferramenta não disse**: um aviso a mais reprova,
   e é para reprovar mesmo.
4. **o retrato do core** — `.ppo`/`.ppt` de cada módulo (§ 4).
5. **o vocabulário** — nenhuma palavra de `forbid` aparece em `src/hbrefactor.prg`
   (a régua do caso 64). Fica no cenário que **introduz** o vocabulário, senão quem
   criar fixture nova precisa lembrar de escrever a régua dela.
6. **compila** — o estado que o cenário **afirma** (`source/` + `expected/` por cima)
   compila limpo sob `-w3 -es2`. Repare: compila o que **eu escrevi**, nunca o que a
   ferramenta produziu — é a rede que impede um erro de digitação meu de virar uma
   falha que se "conserta" regravando.

Falha mostra **diff**, nunca "um grep não casou".

**Normalização:** só duas coisas — `<CWD>` (o diretório do cenário) e `<CORE>` (a
árvore do harbour-core, que muda de máquina). Qualquer outra variação é drift de
verdade.

---

## 4. `oracle/` — a ÚNICA exceção, e ela é estreita

`.ppo` (no que o código vira) e `.ppt` (o que o pp fez, linha a linha) de cada módulo
da `source/`. Estes se **gravam** — `make oracle NOME=<nome>` — porque ali **a
autoridade é o core, não nós**: não é asserção de correção nossa, é rastreamento de
uma dependência.

Servem a duas coisas:

- **rastrear** — mexeu no pp do core e o cenário mostra o diff, legível, de poucas
  linhas; atualizar o retrato é ato **deliberado**, revisado no commit que mexeu no core;
- **estudar** — ao ler um cenário, ver o que o pp fez ali é metade do entendimento. É
  também onde a **lacuna do core** aparece: falta informação no `.ppt`? Então o conserto
  é **estender o core**, nunca adivinhar na ferramenta (CLAUDE.md § 1.2).

**A AST não se congela**: 76 KB para uma fixture de 28 linhas — diff que ninguém lê não
rastreia nada. Para ela ficam a relação 1:1 contra o `.ppt` e a superfície do schema.

**A exceção não vaza:** retrato do core mora em `oracle/` e só é comparado contra
artefato do core. Ele nunca serve de esperado de saída do hbrefactor.

---

## 5. Escrevendo um cenário novo — a ordem

1. `mkdir -p tests/scenarios/<nome>/source` e ponha ali o projeto **inteiro** (o
   cenário é dono da entrada; entrada compartilhada apodrece calada).
2. Escreva o `case.json` (§ 1). `bin/tcheck scen <arquivo>` valida sozinho.
3. **Escreva o `expected/`** — os arquivos como devem ficar. Sem `expected/` se a
   promessa é que nada mude.
4. **Escreva o `output`** — a transcrição inteira, do contrato.
5. `make oracle NOME=<nome>` e **leia** o que o core produziu.
6. `make scenarios NOME=<nome>`. Divergiu? § 2.
7. Migrando um teste antigo: **tire-o do `tests/run.sh`** (migrar é mover, não copiar —
   o mesmo fato provado em dois lugares é drift esperando acontecer).
8. `make test` verde.

---

## 6. O que ainda NÃO cabe, e como propor mudança

**A regra do schema:** uma chave só entra no validador (`tcheck scen`) **quando o
runner a honra**. Chave aceita e ignorada é pior que chave desconhecida — o cenário a
declara, acha que provou, e ninguém confere. Mudança incompatível de forma vira
`case-2`, e o runner recusa alto o que estiver fora de passo.

Projetado e **ainda não implementado** (entra junto com o primeiro teste que precisar):

| categoria | forma proposta | estado |
|---|---|---|
| identidade de saída de **programa** (compila, roda, compara) | `"runs": true` + arquivo `program-output` | decisão pendente: declarar o que o programa imprime × só "antes == depois" |
| sonda que compara o modelo da ferramenta com artefato do core (`.ppt` 1:1, lexdiff) | `"kind": "oracle"` + `"check": "<comparador>"` | comparadores já existem no `tcheck` |
| harness externo (a extensão VSCode é JS) | `"kind": "harness"` + `"run"` + `"needs": ["node"]` | dependência ausente **falha nomeando-a** e aponta o `make deps`; nunca pula em silêncio |

**Teste que não couber no formato é uma proposta, não uma exceção.** Traga (a) o que o
teste prova, (b) por que o formato não modela, (c) a chave ou o `kind` que resolveria,
(d) o que ela custa a quem lê um cenário. Melhoria no formato é bem-vinda pelo mesmo
caminho — é assim que a lista acima nasceu.

---

## 7. O formato ANTIGO (`tests/run.sh`, `tests/cases/`) — em migração

O `run.sh` é imperativo e assere por `grep` na saída; `tests/cases/` é um formato
declarativo intermediário. **Os dois são legado**: todo teste migra para `scenarios/`.
Enquanto isso os dois rodam, e o `make test` só fecha com os dois verdes.

Nada de teste **novo** ali.
