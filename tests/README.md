# A suíte — especificação do formato de teste

**Este arquivo é a ESPECIFICAÇÃO, e é independente de linguagem.** Ele diz *o
que* um teste deve fazer e provar; *como* é decisão de cada implementação, que
deve usar o que a sua stack tem de melhor — nunca traduzir a outra.

> Ordem que não se pula *(Diego, 2026-07-26)*: **primeiro a especificação, depois
> cada implementação a partir dela.** Implementar numa linguagem e traduzir para
> a outra produz duas versões estranhas às duas — foi o que aconteceu quando o
> runner bash virou Python e depois Go carregando a mesma estrutura.

Estado da migração vive em [../docs/handoff.md](../docs/handoff.md) e no
[roadmap](../docs/roadmap.md); aqui só entra o contrato.

---

## 1. Duas classes de teste

| | **A — transformação** | **B — estudo** |
|---|---|---|
| o que prova | o hbrefactor transforma (ou recusa) como deve | como um recurso do Harbour funciona |
| entrada | um projeto | um projeto |
| ação | 1..N comandos do hbrefactor | nenhuma, ou o pp vivo |
| verifica | o projeto depois + o que a ferramenta relatou | o valor e o texto que a diretiva produz |
| explicação | não exigida | **obrigatória** |
| hoje | `tests-go/suite/` (Go) | `tests/ppc-*` (pp-corpus) |

A classe B tem hoje um ocupante — o **pp-corpus**, com método próprio
(`METODO-V2`) e `hbtest`. Ali o objeto de estudo é Harbour, e escrever o teste em
Harbour dá acesso direto ao pp vivo; ele **não** migra para o formato da classe A.

O resto desta especificação é sobre a **classe A**.

---

## 2. Um caso é uma pasta auto-contida

Um caso são **duas coisas**: o **teste**, que é código, e o **`testdata/`**, que
são os quatro artefatos escritos à mão:

```
   <teste>            o teste do caso — no idioma da linguagem
   testdata/<nome>/
      source/         o projeto ANTES — todos os arquivos
      expected/       o projeto DEPOIS, escrito À MÃO — todos os arquivos
      outputs.json    o que a ferramenta relatou, na ordem dos comandos
      oracle/         o retrato .ppo/.ppt que o core produz para a source/
```

*Onde isso mora é decisão da implementação* — hoje, em Go:
`tests-go/suite/<nome>_test.go` ao lado de `tests-go/suite/testdata/<nome>/`
(`testdata/` é a pasta que o toolchain do Go ignora de propósito).

- **O caso é dono da própria entrada.** Cada um tem a sua cópia da fixture;
  entrada compartilhada apodrece calada. Duplicação aqui é deliberada — é o que
  faz cada caso ser legível e falhar sozinho.
- **`expected/` espelha `source/` arquivo a arquivo**, inclusive os que não
  mudam (aí é o original copiado de propósito). Ausência não pode significar
  nada: um par esquecido ficaria indistinguível de um deliberado.
- **O nome diz o que o caso prova** (`rename-local-beside-define`), nunca um
  número — número amarra a uma posição num runner.
- A pasta É a lista: casos são descobertos, não registrados.

---

## 3. A REGRA QUE NÃO CEDE: o esperado se escreve, nunca se grava

> *"escreve os arquivos expected, depois escreve o arquivo que vai ser alterado,
> e compara a saída do actual vs expected"* — Diego, 2026-07-26

| | o que o arquivo AFIRMA | o que ele pega |
|---|---|---|
| gravado da execução | *"a ferramenta faz isto hoje"* | só que algo **mudou** |
| escrito do contrato | *"o contrato pede isto"* | que algo está **errado** |

**Derivar não é adivinhar:** coluna se **computa** do arquivo (o dump é 0-based,
a CLI é 1-based); nome de campo se lê do contrato; texto de mensagem se lê do
fonte que a produz. O que se escreve à mão é a **afirmação**, não o palpite.

**Divergiu ao rodar? Separe os dois lados** — ou o esperado está errado, ou a
ferramenta está. Nunca "conserte" copiando a saída.

**Única exceção: o `oracle/`** (§6).

---

## 4. O que TODA invocação da ferramenta deve satisfazer

Estas valem para qualquer comando, e a implementação as verifica **no ato de
invocar** — não como uma lista que o teste percorre depois, e nem como algo que
o teste precise lembrar de pedir:

1. **o stdout é UM envelope e uma quebra de linha** — nada antes, nada depois;
2. **o stderr fica vazio** — aviso é `diagnostics[]` no envelope;
3. **o exit do processo bate com o campo `exit`** do envelope;
4. **`--json` não se escreve no teste** — é implícito, porque o passo 3 da fase
   A.1 arranca a flag e o caso testa o que vai sobreviver.

Violar qualquer uma é falha imediata, apontando o comando.

---

## 5. O que CADA caso verifica

Duas comparações, e o diff é responsabilidade do framework:

```
o projeto depois  ==  expected/
o que foi relatado ==  outputs.json
```

Mais o que aquele caso quiser afirmar (o `editCount`, o `reason`, o `proof`).

- **Recusa é subcaso, não classe à parte**: `expected/` é igual ao `source/`, e
  a comparação prova que nada foi tocado. O caso terá outros asserts (o código
  de recusa, a ação sugerida, o rollback).
- **Artefato novo no projeto reprova**, a menos que o caso o declare. A
  ferramenta não suja o projeto do usuário.
- **Um caso que roda a ferramenta e não compara nada reprova** — senão passa
  verde sem verificar. É anti-vacuidade, e não julga o resultado: só cobra que a
  comparação existiu.

---

## 6. `oracle/` — a única coisa que se GRAVA, e por quê

`.ppo` (no que o código vira) e `.ppt` (o que o pp fez, linha a linha) de cada
módulo da `source/`. **Ali a autoridade é o CORE, não nós**: não é asserção de
correção nossa, é rastreamento de uma dependência externa.

Serve a duas coisas: **rastrear** (mexeu no pp do core e o caso mostra o diff, e
atualizar vira ato deliberado, revisado no commit) e **estudar** (é onde a
lacuna do core aparece — falta informação no `.ppt`? então o conserto é estender
o core, nunca adivinhar na ferramenta).

**Regravar usa o MESMO caminho de código que compara** — senão o retrato gravado
pode divergir do comparado. A implementação expõe isso como o idioma da sua
stack (uma flag do próprio teste), nunca como um programa à parte.

**A AST não fica no `oracle/`**: 76 KB para uma fixture de 28 linhas é diff que
ninguém lê. Ela é gerada sob demanda para a explicação (classe B) e descartada.

**A exceção não vaza:** o `oracle/` nunca serve de esperado da saída da ferramenta.

---

## 7. Propriedades de cada fixture

Verdades sobre o `testdata/`, não sobre um comando — verificadas uma vez por
caso, e não a cada invocação:

1. **compila** — `source/` + `expected/` por cima compila limpo sob `-w3 -es2`.
   Repare: compila o que **eu escrevi**, nunca o que a ferramenta produziu. É a
   rede que impede "consertar" o esperado copiando a saída.
2. **vocabulário** — nenhuma palavra de diretiva da fixture aparece em
   `src/hbrefactor.prg` (a régua do caso 64). Capacidade sobre uma DSL só conta
   como genérica se o fonte da ferramenta não conhece as palavras dela.
3. **retrato** — o `oracle/` está atualizado (§6).

---

## 8. O que a implementação NÃO deve fazer

Cada linha aqui custou uma reescrita:

- **inventar framework**: descoberta de testes, tabela de casos, lista de
  verificações percorrida à mão. A stack já tem — use;
- **escrever `diff` à mão**: os dois ecossistemas mostram diferença de estrutura
  sozinhos;
- **interpretar um arquivo de configuração** para saber o que rodar. O teste é
  código; um JSON pode **descrever** o teste, nunca executá-lo;
- **traduzir a outra implementação**;
- **mock e monkeypatch** — recusados por padrão; usar exige consulta.

---

## 9. Mudança no formato

Teste que não couber é **proposta de mudança aqui**, antes de ser escrito:
(a) o que o teste prova, (b) por que o formato não modela, (c) o que resolveria,
(d) o que custa a quem lê um caso.

E a régua que governa: **uma exigência só entra nesta spec quando as
implementações a honram** — spec que descreve o que ninguém verifica é pior que
spec omissa, porque quem lê acha que está coberto.
