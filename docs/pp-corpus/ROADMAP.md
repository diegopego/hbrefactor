# Roadmap da exploração do PP — estado, plano e o CHECKLIST ANTI-ERRO

Este arquivo existe porque a exploração do pp é LONGA e eu me perdi (ordem do
Diego, 2026-07-12: *"mantenha um roadmap dentro de docs/pp-corpus para não se
perder mais"*). Duas partes: **(1)** onde a exploração está e para onde vai;
**(2)** o **checklist anti-erro** — cada item nasceu de um erro REAL que eu cometi
e o Diego teve que pegar. Ler ANTES de retomar a exploração.

---

# PARTE 1 — O CHECKLIST ANTI-ERRO (ler primeiro, sempre)

> Erros meus nesta fase, cada um virou uma regra. Nenhum foi por falta de
> capacidade — todos por pular uma disciplina que o projeto já tinha. **Rodar o
> checklist não é burocracia: é o que impede o Diego de ter que ser o meu revisor.**
>
> ⚠️ **FONTE ÚNICA DE REGRA = [CLAUDE.md](../../CLAUDE.md)** (ordem do Diego,
> 2026-07-12, depois de eu escrever um catálogo de erros NOVO no CLAUDE.md
> duplicando este checklist — o mesmo pecado de me perder, um nível acima).
> Aqui fica a **NARRATIVA com evidência** (o erro concreto, o furo, quem pegou);
> a **regra durável** vive no CLAUDE.md § *GATILHOS da REGRA DO FATO*. Ao aprender
> um erro novo: narrativa aqui, regra lá, **nunca as duas**.

### ❶ Provar, nunca afirmar — inclusive a CLASSIFICAÇÃO
**Erro:** rotulei lacunas como "[Consumo futuro] — derivável do `ppApplications`"
**por raciocínio**, sem rodar o dump. O Diego perguntou "não foram resolvidas?" e,
ao verificar, os rótulos até se confirmaram — mas eu não sabia disso quando
escrevi.
**Regra:** todo item de Lacuna traz **VERIFICADO** + o **trecho do dump colado**.
Sem evidência, é hipótese, não classificação. Vale para o meta-julgamento também:
*"é derivável"* é uma afirmação de fato e exige prova como qualquer outra.

### ❷ Comando que falha NÃO é evidência de ausência
**Erro:** `grep -rn --include=*.ch '<@>'` falhou (erro de glob no zsh, *"no matches
found"*) e eu li o silêncio como **"o `<@>` não tem uso nenhum no core"** — e quase
enterrei o marker mais interessante do pp. O Diego mandou procurar de novo.
**Regra:** antes de concluir "não existe", **conferir o exit code e a forma do
comando**. Silêncio de ferramenta quebrada ≠ ausência de fato. Se a busca é
importante, fazer por dois caminhos.

### ❸ Falta de fato → VÁ AO CORE. "Zero mudança no core" é SINAL DE ALERTA
**Erro:** o recheio de um marker não-numerado chegava com `marker: 0`, igual a uma
palavra da regra. Remendei **na ferramenta**, comparando TEXTO — e repeti "zero
mudança no core" como se fosse virtude. Furo provado em uma linha: `ANOTA ANOTA`
(com `#xcommand ANOTA <*x*>`) classificava conteúdo do usuário como palavra de
regra. **O fato faltava no core** (o pp descartava o casamento) → `ast-14`.
**Regra (agora no [CLAUDE.md](../../CLAUDE.md)):** ao detectar falta de informação,
a primeira reação é **estender o core**. Se um conserto precisou de esperteza na
ferramenta, quase sempre o fato faltava no core e a esperteza é o sintoma.
**Pergunta de controle:** *"o pp SABE isso e não exporta?"* Se sim → core.

### ❹ Régua do caso 64: NENHUMA palavra de fixture no fonte da ferramenta
**Erro:** escrevi `RECOZE MODO <m: FRIO, QUENTE>` num **comentário** de
`src/hbrefactor.prg`. O caso 64 quebrou — corretamente.
**Regra:** exemplos em comentário usam nomes **genéricos** (`<m: A, B>`). A régua
vale para comentário também.

### ❺ Documentação anda JUNTO com o código, não atrás
**Erro:** implementei P4/P5 inteiro (core + ferramenta) com a doc em lugar nenhum.
O Diego perguntou *"a documentação está ficando para trás?"* — e estava, com a
suíte VERMELHA ainda por cima.
**Regra:** ao fechar um achado, **documentar antes de abrir o próximo**. Ordem
quando há regressão: (a) contrato verde primeiro, (b) doc, (c) próximo achado.

### ❻ Achado sobre o PP mora AQUI (`docs/pp-corpus/`)
**Erro:** documentei P4/P5 no `ast-schema`/`spec-p`/`roadmap` e **esqueci o
corpus** — que é justamente a pasta de exploração do pp. O Diego lembrou.
**Regra:** todo fato novo sobre o **pp** ganha entrada no corpus (família própria,
1 arquivo), além do canal técnico (`ast-schema`) e do registro de fase (`spec-p`).

### ❼ Canal CORRETO, não o mais BARATO (Diego, 2026-07-12)
**Erro:** ia responder "de quem é este include?" lendo o **dump** (`ppRules[].file`)
porque era barato. O canal certo — **`harbour -gd`**, a lista de dependências
oficial, com **caminho resolvido** e **fecho transitivo** — já existia e eu não
tinha procurado.
**Regra (CLAUDE.md § GATILHOS, item 6):** *"tem que usar o canal correto, não apenas
o mais barato"*. **Barato ≠ correto; "não achei" quase sempre = "não procurei".**

### ❽ Não declarar IMPOSSÍVEL sem VARRER o core (Diego, 2026-07-12)
**Erro:** recusei "o pp como motor de reescrita" (P7) olhando **só** o `.ppo`
destrutivo → **veredito ERRADO publicado**. O Diego apontou
`tests/hbpp/hbpptest.prg`: `__pp_init`/`__pp_process` dão o pp **vivo, linha a
linha** — a destruição era do canal de ARQUIVO, não do pp.
**Regra:** recusa é afirmação **sobre o core** e exige varredura ANTES, registrada:
`--help` inteiro · API pública (`hbpp.h`) · **`tests/` do core** · ChangeLog.
É o irmão do ❷ (silêncio de busca minha ≠ ausência de fato).

### ❾ Réplica de gramática = bug esperando (2026-07-12)
**Erro:** `AbbrevClash` reescrevia à mão a abreviação dBase (`ppcore.c:2533`) e o
rename **adivinhava por prefixo** qual literal um site casou. Furo: keyword
secundária que é prefixo da cabeça → **RECUSA FALSA** → cabeça da DSL
**irrenomeável**. → `ast-15` (`ruletok`). Ver [abbreviation.md](abbreviation.md).
**Regra:** constante mágica de gramática (`>= 4`) no fonte da ferramenta é o cheiro.
O pp **sabe**; pergunte a ele.

### ❿ Ferramenta do core: PROBE, nunca memória (2026-07-12)
**Erro:** assumi que `harbour -gd` grava o `.d` ao lado do fonte (como o `.ppo`).
Grava no **CWD** → deixei **lixo no repo** e a função devolvia vazio para fonte em
subdiretório.
**Regra:** sonde ONDE escreve e O QUE reporta, **com fonte em subdiretório**; mande
a saída para onde você quer (`-o<tmp>`). Depois de rodar o compilador ao lado dos
fontes, **conferir `git status`**.

### ⓫ Achado sobre o pp mora AQUI — DE NOVO (2026-07-12)
**Erro:** o ❻ abaixo já dizia isso, e mesmo assim P3/P6/P7/P8/`ast-15` foram **todos**
para o `spec-p`, que virou monolito de **832 linhas** (2,2× o maior spec do repo) —
e o corpus ficou vazio. O Diego percebeu ("estou ficando confuso").
**Regra (organização, ordem do Diego):** fato de **pp** → **corpus** (1 arquivo por
tema) · canal → **ast-schema** · veredito de fatia → **spec-p** (1 parágrafo + link)
· regra durável → **CLAUDE.md**. **Não duplicar.** Se o spec-p crescer, é sintoma.

### ❼bis Drift em teste PRÉ-EXISTENTE → apresentar ANTES de re-baselinar
Regra que já existia no CLAUDE.md e vale reforçar aqui: quando uma mudança faz um
teste antigo divergir, **apresentar o drift site a site** e deixar o Diego decidir
qual lado cede. Teste novo da própria entrega não precisa de consulta.

---

# PARTE 2 — Estado e plano da exploração

## Método (não negociar)

**Os QUATRO oráculos**, sempre juntos: `.ppo` (expandido) + `.ppt` (traço) +
**ast dump** (o fato estruturado) + **fixture COMPILÁVEL**. Sintaxe e semântica
saem do **fonte do core** (`ppcore.c`, `hbpp.h`, `compast.c`, `ChangeLog.txt`),
nunca de memória. Suíte separada: **`make ppcorpus`** (o `make test` é o contrato e
fica byte-idêntico).

**Classificação de lacuna** (ver [README.md](README.md)): *Consumo futuro* (o dado
ESTÁ nos oráculos → fatia de consumo) × *LACUNA real* (o dado NÃO está → **pausa a
exploração + experimento no core, imediatamente**).

## Famílias do corpus — entregues

| Família | Ensina | Arquivo |
|---|---|---|
| SET EXACT | `restrict` + `strsmart`; multi-passe com `#define` | [set-exact.md](set-exact.md) |
| `@ … SAY` | grupos opcionais (`opt-open`/`opt-close`) + seleção de forma | [say.md](say.md) |
| STORE | o grupo opcional que REPETE | [store.md](store.md) |
| hbclass | o dialeto OO É pp: paste, genealogia, `AS CLASS Self` | [class.md](class.md) |
| **MARKERS** | **os 15 tipos de `<x>`** (6 match + 9 result), com veredito | [markers.md](markers.md) |
| **`<@>`** | **o guarda anti-recursão** de regras circulares | [reference-guard.md](reference-guard.md) |
| **regra que gera regra** | genealogia (`ast-13`) + os limites do pp | [generated-rules.md](generated-rules.md) |
| **DERIVAÇÃO** | `clone` × `paste` × `stringify` — a distinção que explicou 3 bugs | [derivation.md](derivation.md) |
| **ESTRUTURA da regra** | sem cabeça · opcionais fora de ordem · multi-passe | [rule-structure.md](rule-structure.md) |
| **ABREVIAÇÃO dBase** | keyword pela metade; `ast-15`/`ruletok` | [abbreviation.md](abbreviation.md) |
| **PP como INSTRUMENTO** | os canais do core: o que cada um dá e o que DESTRÓI | [pp-as-instrument.md](pp-as-instrument.md) |

## Fatias da fase P (roadmap principal: [../roadmap.md](../roadmap.md) § P)

- **P1 ✅** granularidade paste×stringify → `genOp` recusado; `ast-13` (genealogia).
- **P2 ✅** marker que gera E passa adiante → veredito ESTRUTURAL (a rede confere o
  artefato compilado final; indiferente a multiplicidade/aninhamento).
- **P4 ✅ + P5 ✅** os 15 mkinds EXAURIDOS → 13 consumidos, 2 com recusa
  documentada; **`ast-14`** (todo marker de match numerado); `restrict` validado,
  `wild`/descarte separado por fato, `logical`/`nul` relatados. Caso 111.
- **P3 ✅** `generates` para `usages` → o `--at` estreita pelo PAPEL do site (antes
  misturava marker de pp com símbolo homônimo). Caso 112.
- **P6 ✅** estrutura da regra → sem cabeça (funciona por construção) · opcionais
  fora de ordem · multi-passe (+ limite honesto) · **guarda de órfão consertada**.
  Caso 113. → [rule-structure.md](rule-structure.md)
- **P7 ✅** (Eixo B) o pp como INSTRUMENTO → **veredito PARTIDO**: oráculo VIÁVEL (já
  em produção); escritor recusado **pelo canal `.ppo`** — e a recusa foi CORRIGIDA
  pelo Diego (`__pp_process` derruba a premissa). → [pp-as-instrument.md](pp-as-instrument.md)
- **P8 ✅** (Eixo C) rename do **nome de marker** da regra (alpha-rename) + o `.ch`
  alcançável por fato (`harbour -gd`). Caso 114.
- **P-AUDIT ✅ (1º achado)** → **`ast-15`** (`ruletok`): matou a adivinhação por
  texto e a RECUSA FALSA. Caso 115. → [abbreviation.md](abbreviation.md)
- **P9** custo do reverse-scan · **P10** síntese/completude.
- **P11** — **`__pp_process`/`hb_compileFromBuf`**: o pp **in-process**. Reabre o P7
  e mata o resíduo do `AbbrevClash`. → [pp-as-instrument.md](pp-as-instrument.md) § 4
- **P-AUDIT (continua)** — `ResolveInclude`, os "se não é X então é Y", comparações
  de texto onde o dump já tem id.

## Famílias planejadas para o corpus

- Um **contrib** rico (hbct/Clipper Tools) — MEDIÇÃO, não capacidade (nuance xhb do
  CLAUDE.md: número vindo só de lá não justifica capacidade).
- `TEXT … ENDTEXT` — a maquinaria de **stream** (`#pragma __text`), onde o
  `strdump`/`%s` de fato vive.
- Diretivas com **`#define` dinâmico** (`__FILE__`/`__LINE__`) — o `dynval`.

## Critério de "fase P exaurida"

Cada pergunta do [adr-003](../adr-003-derivacao-pp-como-fato.md) com veredito ·
cada mkind com fixture provando consumo OU recusa documentada (**✅ feito, P4/P5**)
· Eixo B com veredito · todo fato sobrevivente com consumidor + caso na suíte
(nenhum `ast-N` sem cliente) · toda prova em DSL inventada NÃO-espelho.
